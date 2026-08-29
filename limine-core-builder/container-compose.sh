#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

SCRIPT_DIR=/workspace/limine-core-builder
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/verify.sh"
limine_core_load_profile "$SCRIPT_DIR/profile.env"
limine_core_assert_profile

[[ "$(uname -m)" == aarch64 ]] || limine_core_die "Compose container is not AArch64: $(uname -m)"

run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_id="core-rawhide-alpha-limine-$run_stamp"
artifact_dir="/output/$run_id"
work_dir="/output/.work-$run_id"
root="$work_dir/root"
esp_tree="$work_dir/esp-tree"
reports="$artifact_dir/reports"
metadata="$artifact_dir/metadata"
system_image="$artifact_dir/fedora-rawhide-nabu-core-alpha-$run_stamp-system.img"
esp_image="$artifact_dir/fedora-rawhide-nabu-core-alpha-$run_stamp-esp.img"
stage_file="$reports/stages.tsv"
current_stage=initialization
failure_handled=0

mkdir -p "$artifact_dir" "$reports" "$metadata" "$root/boot/efi" "$esp_tree/EFI/android"
printf 'timestamp_utc\tstage\tstate\tdetail\n' >"$stage_file"

stage_event() { printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$3" >>"$stage_file"; }
stage_begin() { current_stage="$1"; stage_event "$1" BEGIN "$2"; limine_core_log "STAGE $1: $2"; }
stage_pass() { stage_event "$current_stage" PASS "$1"; }

cleanup_mounts() {
    local path
    for path in "$root/run" "$root/sys" "$root/proc" "$root/dev" "$root/boot/efi"; do
        if findmnt --mountpoint "$path" >/dev/null 2>&1; then umount -l "$path" || :; fi
    done
}
on_error() {
    local rc=$1 line=$2
    (( failure_handled == 0 )) || exit "$rc"
    failure_handled=1
    stage_event "$current_stage" FAIL "rc=$rc line=$line"
    cleanup_mounts
    exit "$rc"
}
trap 'on_error $? $LINENO' ERR
trap cleanup_mounts EXIT

dnf_retry() {
    local log_file="${1:?log file is required}" attempt=1 delay=3 rc=0
    shift
    : >"$log_file"
    while (( attempt <= 5 )); do
        limine_core_log "DNF attempt $attempt/5"
        if dnf5 "$@" >>"$log_file" 2>&1; then return 0; else rc=$?; fi
        printf '\nLIMINE_CORE_DNF_ATTEMPT_%d_RC=%d\n' "$attempt" "$rc" >>"$log_file"
        ((attempt += 1))
        if (( attempt <= 5 )); then sleep "$delay"; (( delay < 30 )) && delay=$((delay * 2)); fi
    done
    return "$rc"
}

stage_begin compose-tools 'Install deterministic compose tooling'
dnf_retry "$reports/compose-tools.log" -y --disablerepo='*openh264*' \
    --setopt=install_weak_deps=False install \
    binutils cpio curl diffutils dosfstools dracut e2fsprogs file findutils jq kmod mtools rpm \
    shadow-utils util-linux zstd
for command in cmp debugfs dumpe2fs e2fsck fsck.vfat lsinitrd mcopy mdir mkfs.ext4 \
    mkfs.vfat mtype objcopy rpm sha256sum zstd; do
    limine_core_require_command "$command"
done
stage_pass 'Compose tools installed'

cat >/etc/yum.repos.d/nabu-limine-compose.repo <<EOF
[nabu-limine-compose]
name=Nabu Limine CORE compose
baseurl=$LIMINE_CORE_COPR_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=$LIMINE_CORE_COPR_GPGKEY
skip_if_unavailable=False
metadata_expire=0
EOF

dnf_args=(
    -y --forcearch="$LIMINE_CORE_TARGET_ARCH" --use-host-config
    --installroot="$root" --releasever="$LIMINE_CORE_RELEASEVER"
    --disablerepo='*openh264*' --setopt=install_weak_deps=False
    --setopt=keepcache=True --setopt=retries=10 --setopt=timeout=120
)
required_packages=(
    "$LIMINE_CORE_META_PACKAGE" "$LIMINE_CORE_DEFAULT_KERNEL_PACKAGE"
    "$LIMINE_CORE_BOOT_PACKAGE" "$LIMINE_CORE_PLYMOUTH_PACKAGE"
    NetworkManager NetworkManager-wifi firewalld openssh-server
    bash-completion nano less iproute iputils glibc-langpack-tr systemd-boot-unsigned
)
bootstrap_packages=(
    filesystem setup basesystem bash coreutils rpm dnf5
    systemd systemd-udev util-linux-core shadow-utils
)

stage_begin dnf-solve 'Resolve live Fedora Rawhide AArch64 and signed COPR closure'
if dnf5 "${dnf_args[@]}" install "${required_packages[@]}" --assumeno \
    >"$reports/dnf-solve.log" 2>&1; then
    solve_rc=0
else
    solve_rc=$?
fi
if [[ $solve_rc -ne 1 ]] || ! grep -Fq 'Operation aborted by the user' "$reports/dnf-solve.log"; then
    tail -160 "$reports/dnf-solve.log" >&2
    limine_core_die 'DNF solve failed'
fi
for package in "$LIMINE_CORE_META_PACKAGE" "$LIMINE_CORE_DEFAULT_KERNEL_PACKAGE" \
    "$LIMINE_CORE_BOOT_PACKAGE" "$LIMINE_CORE_PLYMOUTH_PACKAGE"; do
    grep -Fq "$package" "$reports/dnf-solve.log" || limine_core_die "Package absent from solve: $package"
done
stage_pass 'DNF closure solved without conflicts'

if [[ "${LIMINE_CORE_SOLVE_ONLY:-false}" == true ]]; then
    cp "$reports/dnf-solve.log" "/output/dnf-solve-$run_stamp.log"
    trap - ERR
    limine_core_log 'Live DNF closure passed'
    exit 0
fi

stage_begin rootfs-install 'Install fresh CORE root filesystem'
dnf_retry "$reports/dnf-bootstrap.log" "${dnf_args[@]}" --disablerepo=nabu-limine-compose \
    install "${bootstrap_packages[@]}"
dnf_retry "$reports/dnf-install.log" "${dnf_args[@]}" install "${required_packages[@]}"
rpm --root "$root" -q "${required_packages[@]}" >"$metadata/installed-required-nevra.txt"
rpm --root "$root" -qa --qf '%{NAME}|%{EPOCHNUM}:%{VERSION}-%{RELEASE}|%{ARCH}\n' \
    | sort >"$metadata/rpm-manifest.txt"
rpm --root "$root" -q "$LIMINE_CORE_META_PACKAGE" "$LIMINE_CORE_DEFAULT_KERNEL_PACKAGE" \
    "$LIMINE_CORE_BOOT_PACKAGE" "$LIMINE_CORE_PLYMOUTH_PACKAGE" >"$metadata/core-selection.txt"
if rpm --root "$root" -q nabu-boot-refind nabu-boot-systemd >/dev/null 2>&1; then
    limine_core_die 'A second boot manager entered the image'
fi
mapfile -t manager_markers < <(find "$root/usr/lib/nabu-boot/managers" -maxdepth 1 -name '*.selected' -printf '%f\n')
(( ${#manager_markers[@]} == 1 )) && [[ "${manager_markers[0]}" == limine.selected ]] || \
    limine_core_die 'Exactly one Limine manager marker was not selected'
stage_pass 'CORE, alpha kernel, Bash, Limine and Plymouth installed'

stage_begin rootfs-policy 'Apply first-boot and Plymouth policy'
printf 'LANG=%s\n' "$LIMINE_CORE_LOCALE" >"$root/etc/locale.conf"
ln -sfn "../usr/share/zoneinfo/$LIMINE_CORE_TIMEZONE" "$root/etc/localtime"
printf '%s\n' "$LIMINE_CORE_TIMEZONE" >"$root/etc/timezone"
chroot "$root" passwd -l root >/dev/null
systemctl --root="$root" enable NetworkManager.service firewalld.service >/dev/null
systemctl --root="$root" disable sshd.service >/dev/null 2>&1 || :
systemctl --root="$root" set-default multi-user.target >/dev/null
install -d -m0755 "$root/etc/kernel/nabu-verbose-disabled.d"
touch "$root/etc/kernel/nabu-uki.conf"
grep -v '^NABU_VERBOSE_MARKER_DIR=' "$root/etc/kernel/nabu-uki.conf" >"$work_dir/nabu-uki.conf"
printf 'NABU_VERBOSE_MARKER_DIR=/etc/kernel/nabu-verbose-disabled.d\n' >>"$work_dir/nabu-uki.conf"
install -m0644 "$work_dir/nabu-uki.conf" "$root/etc/kernel/nabu-uki.conf"
chroot "$root" plymouth-set-default-theme "$LIMINE_CORE_PLYMOUTH_THEME" >/dev/null
grep -Eq "^Theme=$LIMINE_CORE_PLYMOUTH_THEME$" "$root/etc/plymouth/plymouthd.conf" || \
    limine_core_die 'Plymouth theme was not selected'
[[ -s "$root/usr/bin/bash" ]] || limine_core_die 'Bash is missing'
stage_pass 'Root locked, services set, Plymouth normal boot forced'

stage_begin dnf-forward-gates 'Verify DNF database and future Rawhide transaction'
dnf5 "${dnf_args[@]}" check >"$reports/dnf-check.log" 2>&1
if dnf5 "${dnf_args[@]}" distro-sync --assumeno >"$reports/dnf-forward-sync.log" 2>&1; then
    sync_rc=0
else
    sync_rc=$?
fi
if [[ $sync_rc -ne 0 && $sync_rc -ne 1 ]]; then limine_core_die 'Future distro-sync solver failed'; fi
! grep -Eiq 'conflicting requests|problem [0-9]+:|failed to resolve' "$reports/dnf-forward-sync.log" || \
    limine_core_die 'Future distro-sync has dependency conflicts'
limine_core_verify_no_overflow_ownership "$root" "$reports/root-overflow-ownership.txt"
stage_pass 'DNF and nobody:nobody rootfs gates passed'

stage_begin pinned-payloads 'Install hash-pinned SLPI and Android payloads'
slpi="$root/usr/lib/firmware/qcom/sm8150/xiaomi/nabu/slpi_nb.mbn"
install -d -m0755 "${slpi%/*}"
curl -fL --retry 5 --retry-all-errors --connect-timeout 30 "$LIMINE_CORE_SLPI_FIRMWARE_URL" -o "$slpi.partial"
printf '%s  %s\n' "$LIMINE_CORE_SLPI_FIRMWARE_SHA256" "$slpi.partial" | sha256sum -c - \
    >"$reports/slpi-firmware-sha256.log"
install -m0644 "$slpi.partial" "$slpi"
rm -f -- "$slpi.partial"
android="$esp_tree/EFI/android/Reboot2Android.efi"
curl -fL --retry 5 --retry-all-errors --connect-timeout 30 "$LIMINE_CORE_REBOOT2ANDROID_URL" -o "$android"
printf '%s  %s\n' "$LIMINE_CORE_REBOOT2ANDROID_SHA256" "$android" | sha256sum -c - \
    >"$reports/reboot2android-sha256.log"
stage_pass 'Pinned payload hashes verified'

stage_begin uki 'Generate dynamic alpha UKI and Limine configuration'
mount --bind "$esp_tree" "$root/boot/efi"
mount --rbind /dev "$root/dev"; mount --make-rslave "$root/dev"
mount --bind /proc "$root/proc"; mount --bind /sys "$root/sys"; mount --bind /run "$root/run"
mapfile -t kernel_versions < <(
    find "$root/usr/lib/modules" -mindepth 4 -maxdepth 4 -type f \
        -path '*/dtb/qcom/sm8150-xiaomi-nabu.dtb' -printf '%P\n' \
        | sed 's@/dtb/qcom/sm8150-xiaomi-nabu[.]dtb$@@' \
        | while IFS= read -r candidate; do [[ -s "$root/boot/vmlinuz-$candidate" ]] && printf '%s\n' "$candidate"; done \
        | sort -Vu
)
(( ${#kernel_versions[@]} == 1 )) || limine_core_die "Expected one alpha kernel, found ${#kernel_versions[@]}"
kver="${kernel_versions[0]}"
chroot "$root" /usr/bin/nabu-regenerate-uki "$kver" >"$reports/uki-generation.log" 2>&1
mapfile -t ukis < <(find "$esp_tree/EFI/SENEMOS" -maxdepth 1 -type f -name 'SENEMOS*.efi' -print)
(( ${#ukis[@]} == 1 )) || limine_core_die "Expected one canonical UKI, found ${#ukis[@]}"
uki="${ukis[0]}"; uki_name="${uki##*/}"
[[ -s "$esp_tree/EFI/BOOT/BOOTAA64.EFI" && -s "$esp_tree/EFI/limine/BOOTAA64.EFI" ]] || \
    limine_core_die 'Limine EFI payload was not generated'
cmp "$root/usr/share/nabu/bootloader/limine/BOOTAA64.EFI" "$esp_tree/EFI/BOOT/BOOTAA64.EFI"
objcopy --dump-section .cmdline="$metadata/kernel-cmdline.bin" "$uki"
objcopy --dump-section .initrd="$work_dir/final-initramfs.img" "$uki"
tr -d '\000' <"$metadata/kernel-cmdline.bin" >"$metadata/kernel-cmdline.txt"
lsinitrd "$work_dir/final-initramfs.img" >"$reports/final-initramfs-contents.txt"
limine_core_verify_uki_cmdline "$metadata/kernel-cmdline.bin"
limine_core_verify_initramfs "$reports/final-initramfs-contents.txt"
cleanup_mounts
stage_pass 'Dynamic UKI, quiet splash, Plymouth initramfs and Limine verified'

stage_begin ext4-image 'Serialize and validate fresh EXT4 Linux image'
truncate -s "$LIMINE_CORE_IMAGE_SIZE" "$system_image.partial"
mkfs.ext4 -q -F -L "$LIMINE_CORE_FILESYSTEM_LABEL" -d "$root" "$system_image.partial"
limine_core_verify_ext4 "$system_image.partial" "$reports/ext4-validation.log"
mv "$system_image.partial" "$system_image"
stage_pass 'EXT4 fsck, label and root ownership passed'

stage_begin esp-image 'Serialize and validate 4 KiB-sector Limine ESP image'
truncate -s "$LIMINE_CORE_ESP_SIZE_BYTES" "$esp_image.partial"
mkfs.vfat -F 32 -S "$LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE" -s 1 -R 32 \
    -n "$LIMINE_CORE_ESP_LABEL" "$esp_image.partial" >"$reports/esp-mkfs.log" 2>&1
MTOOLS_NO_VFAT=1 mcopy -s -i "$esp_image.partial" "$esp_tree"/* ::/
limine_core_verify_esp "$esp_image.partial" "$LIMINE_CORE_REBOOT2ANDROID_SHA256" \
    "$uki_name" "$reports/esp-validation.log"
mv "$esp_image.partial" "$esp_image"
stage_pass 'ESP fsck, Limine, UKI and Android gates passed'

stage_begin provenance 'Record package, tool and boot provenance'
cp "$esp_tree/limine.conf" "$metadata/limine.conf"
cp "$reports/final-initramfs-contents.txt" "$metadata/final-initramfs-contents.txt"
dnf5 --version >"$metadata/dnf-version.txt"; rpm --version >"$metadata/rpm-version.txt"
printf '%s\n' "${LIMINE_CORE_CONTAINER_IMAGE_ID:-unknown}" >"$metadata/container-image-id.txt"
printf '%s\n' "$kver" >"$metadata/kernel-uname.txt"
printf '%s\n' "$uki_name" >"$metadata/uki-filename.txt"
printf '%s\n' "$LIMINE_CORE_PLYMOUTH_THEME" >"$metadata/plymouth-theme.txt"
cat >"$artifact_dir/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide CORE alpha Limine image

- Architecture: AArch64
- Filesystem: EXT4, label \`$LIMINE_CORE_FILESYSTEM_LABEL\`, size \`$LIMINE_CORE_IMAGE_SIZE\`
- Boot manager: Limine
- Shell: Bash
- Kernel: \`$kver\` from \`$LIMINE_CORE_DEFAULT_KERNEL_PACKAGE\`
- UKI: \`$uki_name\`
- Plymouth: \`$LIMINE_CORE_PLYMOUTH_THEME\`, enabled by \`quiet splash\`
- CORE meta: \`$LIMINE_CORE_META_PACKAGE\`
- ESP: $LIMINE_CORE_ESP_SIZE_BYTES bytes, $LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE-byte sectors
- COPR signatures: enabled
- Root: locked; SSH daemon: installed but disabled
- DNF forward solve: passed
- nobody:nobody overflow ownership: absent from rootfs and final initramfs
- Physical Nabu boot/HIL: pending until the tablet exposes a Linux shell
EOF
stage_pass 'Build report and immutable evidence written'

stage_begin compression 'Compress artifacts and produce final checksums'
zstd -T0 -"$LIMINE_CORE_COMPRESSION_LEVEL" -f "$system_image" -o "$system_image.zst"
zstd -T0 -"$LIMINE_CORE_COMPRESSION_LEVEL" -f "$esp_image" -o "$esp_image.zst"
if [[ "${LIMINE_CORE_KEEP_UNCOMPRESSED:-1}" != 1 ]]; then rm -f -- "$system_image" "$esp_image"; fi
stage_pass 'Compression completed'
(
    cd "$artifact_dir"
    find . -type f ! -name SHA256SUMS ! -name sha256-verify.log -print0 \
        | sort -z | xargs -0 sha256sum >SHA256SUMS
    sha256sum -c SHA256SUMS >reports/sha256-verify.log
)
rm -rf -- "$work_dir"
trap - ERR
trap - EXIT
limine_core_log "Build complete: $artifact_dir"
