#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

SCRIPT_DIR=/workspace/core-builder
PROFILE="$SCRIPT_DIR/profile.env"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/verify.sh"
core_load_profile "$PROFILE"
core_assert_profile

[[ "$(uname -m)" == aarch64 ]] || core_die "Compose container is not native/emulated AArch64: $(uname -m)"

run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_id="core-rawhide-alpha-refind-$run_stamp"
artifact_dir="/output/$run_id"
work_dir="/output/.work-$run_id"
root="$work_dir/root"
esp_tree="$work_dir/esp-tree"
reports="$artifact_dir/reports"
metadata="$artifact_dir/metadata"
system_image="$artifact_dir/fedora-rawhide-nabu-core-alpha-$run_stamp-system.img"
esp_image="$artifact_dir/fedora-rawhide-nabu-core-alpha-$run_stamp-esp.img"

mkdir -p "$artifact_dir" "$reports" "$metadata" "$root/boot/efi" "$esp_tree/EFI/android"

core_dnf_retry() {
    local log_file="${1:?log file is required}"
    shift
    local attempt=1 delay=3 rc=0
    : >"$log_file"
    while ((attempt <= 5)); do
        core_log "DNF attempt $attempt/5"
        if dnf5 "$@" >>"$log_file" 2>&1; then
            return 0
        else
            rc=$?
        fi
        printf '\nCORE_DNF_ATTEMPT_%d_RC=%d\n' "$attempt" "$rc" >>"$log_file"
        ((attempt += 1))
        if ((attempt <= 5)); then
            sleep "$delay"
            ((delay < 30)) && delay=$((delay * 2))
        fi
    done
    return "$rc"
}

cleanup_mounts() {
    local path
    for path in "$root/run" "$root/sys" "$root/proc" "$root/dev" "$root/boot/efi"; do
        if findmnt --mountpoint "$path" >/dev/null 2>&1; then
            umount -l "$path" || :
        fi
    done
}
trap cleanup_mounts EXIT

core_log "Installing compose tools"
core_dnf_retry "$reports/compose-tools.log" \
    -y --disablerepo='*openh264*' --setopt=install_weak_deps=False install \
    binutils cpio curl dosfstools dracut e2fsprogs findutils jq kmod mtools rpm shadow-utils \
    util-linux zstd

cat >/etc/yum.repos.d/nabu-core-compose.repo <<EOF
[nabu-core-compose]
name=Nabu CORE compose
baseurl=$CORE_COPR_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=$CORE_COPR_GPGKEY
skip_if_unavailable=False
metadata_expire=0
EOF

dnf_args=(
    -y --forcearch="$CORE_TARGET_ARCH" --use-host-config
    --installroot="$root" --releasever="$CORE_RELEASEVER"
    --disablerepo='*openh264*'
    --setopt=install_weak_deps=False
    --setopt=keepcache=True
    --setopt=retries=10
    --setopt=timeout=120
)
required_packages=(
    "$CORE_META_PACKAGE"
    "$CORE_DEFAULT_KERNEL_PACKAGE"
    "$CORE_BOOT_PACKAGE"
    NetworkManager NetworkManager-wifi firewalld openssh-server
    bash-completion nano less iproute iputils glibc-langpack-tr systemd-boot-unsigned
)
bootstrap_packages=(
    filesystem setup basesystem bash coreutils rpm dnf5
    systemd systemd-udev util-linux-core shadow-utils
)

core_log "Resolving current Rawhide AArch64 + signed COPR transaction"
set +e
dnf5 "${dnf_args[@]}" install "${required_packages[@]}" --assumeno \
    >"$reports/dnf-solve.log" 2>&1
solve_rc=$?
set -e
if [[ $solve_rc -ne 1 ]] || ! grep -Fq 'Operation aborted by the user' "$reports/dnf-solve.log"; then
    tail -160 "$reports/dnf-solve.log" >&2
    core_die "DNF forward solve failed (expected a solved --assumeno transaction)"
fi
grep -Fq "$CORE_META_PACKAGE" "$reports/dnf-solve.log" || core_die "CORE meta is absent from solve"
grep -Fq "$CORE_DEFAULT_KERNEL_PACKAGE" "$reports/dnf-solve.log" || core_die "Alpha kernel is absent from solve"
grep -Fq "$CORE_BOOT_PACKAGE" "$reports/dnf-solve.log" || core_die "rEFInd selector is absent from solve"

if [[ "${CORE_SOLVE_ONLY:-false}" == true ]]; then
    cp "$reports/dnf-solve.log" "/output/dnf-solve-$run_stamp.log"
    core_log "Live DNF closure passed"
    exit 0
fi

core_log "Installing CORE root filesystem"
core_dnf_retry "$reports/dnf-bootstrap.log" \
    "${dnf_args[@]}" --disablerepo=nabu-core-compose install "${bootstrap_packages[@]}"
core_dnf_retry "$reports/dnf-install.log" \
    "${dnf_args[@]}" install "${required_packages[@]}"

rpm --root "$root" -q "${required_packages[@]}" >"$metadata/installed-required-nevra.txt"
rpm --root "$root" -qa --qf '%{NAME}|%{EPOCHNUM}:%{VERSION}-%{RELEASE}|%{ARCH}\n' \
    | sort >"$metadata/rpm-manifest.txt"
rpm --root "$root" -q "$CORE_META_PACKAGE" "$CORE_DEFAULT_KERNEL_PACKAGE" "$CORE_BOOT_PACKAGE" \
    >"$metadata/core-selection.txt"
if rpm --root "$root" -q senemos-nabu-kernel senemos-nabu-kernel-mainline-alpha >/dev/null 2>&1; then
    core_die "Stable or mainline selector entered the alpha CORE image"
fi
[[ "$(find "$root/usr/lib/nabu-boot/managers" -maxdepth 1 -name '*.selected' -printf '%f\n')" == refind.selected ]] || \
    core_die "Exactly the rEFInd boot-manager marker was not selected"

printf 'LANG=%s\n' "$CORE_LOCALE" >"$root/etc/locale.conf"
ln -sfn "../usr/share/zoneinfo/$CORE_TIMEZONE" "$root/etc/localtime"
printf '%s\n' "$CORE_TIMEZONE" >"$root/etc/timezone"
chroot "$root" passwd -l root >/dev/null
chroot "$root" systemctl enable NetworkManager.service firewalld.service >/dev/null
chroot "$root" systemctl disable sshd.service >/dev/null 2>&1 || :

core_log "Running installed-root DNF integrity and forward-upgrade gates"
dnf5 "${dnf_args[@]}" check >"$reports/dnf-check.log" 2>&1
set +e
dnf5 "${dnf_args[@]}" distro-sync --assumeno >"$reports/dnf-forward-sync.log" 2>&1
sync_rc=$?
set -e
if [[ $sync_rc -ne 0 && $sync_rc -ne 1 ]]; then
    tail -120 "$reports/dnf-forward-sync.log" >&2
    core_die "Future Rawhide distro-sync solver gate failed"
fi
! grep -Eiq 'conflicting requests|problem [0-9]+:|failed to resolve' "$reports/dnf-forward-sync.log" || \
    core_die "Future Rawhide distro-sync reports dependency problems"

core_verify_no_overflow_ownership "$root" "$reports/root-overflow-ownership.txt"

core_log "Installing hash-pinned Nabu SLPI firmware required by the alpha initramfs"
slpi_firmware="$root/usr/lib/firmware/qcom/sm8150/xiaomi/nabu/slpi_nb.mbn"
install -d -m0755 "${slpi_firmware%/*}"
curl -fL --retry 5 --retry-all-errors --connect-timeout 30 \
    "$CORE_SLPI_FIRMWARE_URL" -o "$slpi_firmware.partial"
printf '%s  %s\n' "$CORE_SLPI_FIRMWARE_SHA256" "$slpi_firmware.partial" \
    | sha256sum -c - >"$reports/slpi-firmware-sha256.log"
install -m0644 "$slpi_firmware.partial" "$slpi_firmware"
rm -f -- "$slpi_firmware.partial"

core_log "Fetching and pin-verifying Reboot2Android"
curl -fL --retry 5 --retry-all-errors --connect-timeout 30 \
    "$CORE_REBOOT2ANDROID_URL" -o "$esp_tree/EFI/android/Reboot2Android.efi"
printf '%s  %s\n' "$CORE_REBOOT2ANDROID_SHA256" "$esp_tree/EFI/android/Reboot2Android.efi" \
    | sha256sum -c - >"$reports/reboot2android-sha256.log"

core_log "Preparing bind mounts for offline dracut/UKI generation"
mount --bind "$esp_tree" "$root/boot/efi"
mount --rbind /dev "$root/dev"
mount --make-rslave "$root/dev"
mount --bind /proc "$root/proc"
mount --bind /sys "$root/sys"
mount --bind /run "$root/run"

mapfile -t nabu_kernel_versions < <(
    find "$root/usr/lib/modules" -mindepth 4 -maxdepth 4 -type f \
        -path '*/dtb/qcom/sm8150-xiaomi-nabu.dtb' -printf '%P\n' \
        | sed 's@/dtb/qcom/sm8150-xiaomi-nabu[.]dtb$@@' \
        | while IFS= read -r candidate; do
            [[ -s "$root/boot/vmlinuz-$candidate" ]] && printf '%s\n' "$candidate"
        done \
        | sort -Vu
)
(( ${#nabu_kernel_versions[@]} == 1 )) || \
    core_die "Expected exactly one installed Nabu alpha kernel, found ${#nabu_kernel_versions[@]}"
kver="${nabu_kernel_versions[0]}"

core_log "Generating dynamic alpha UKI and rEFInd configuration for $kver"
chroot "$root" /usr/bin/nabu-regenerate-uki "$kver" >"$reports/uki-generation.log" 2>&1
uki="$(find "$esp_tree/EFI/SENEMOS" -maxdepth 1 -type f -name 'SENEMOS*.efi' -print -quit)"
[[ -s "$uki" ]] || core_die "Dynamic SENEMOS UKI was not generated"
grep -Fq "loader /EFI/SENEMOS/${uki##*/}" "$esp_tree/EFI/BOOT/refind.conf" || \
    core_die "rEFInd does not point to the generated alpha UKI"
first_loader="$(sed -nE 's/^[[:space:]]*loader[[:space:]]+(.+)/\1/p' "$esp_tree/EFI/BOOT/refind.conf" | head -n1)"
[[ "$first_loader" == "/EFI/SENEMOS/${uki##*/}" ]] || core_die "Alpha UKI is not the first/default rEFInd entry"
grep -Fq '/EFI/android/Reboot2Android.efi' "$esp_tree/EFI/BOOT/refind.conf" || core_die "Android return entry is missing"

objcopy --dump-section .initrd="$work_dir/final-initramfs.img" "$uki"
lsinitrd "$work_dir/final-initramfs.img" >"$reports/final-initramfs-contents.txt"
core_verify_initramfs_listing "$reports/final-initramfs-contents.txt"

cleanup_mounts
trap - EXIT

core_log "Creating and validating the 8 GiB EXT4 image"
truncate -s "$CORE_IMAGE_SIZE" "$system_image.partial"
mkfs.ext4 -q -F -L "$CORE_FILESYSTEM_LABEL" -d "$root" "$system_image.partial"
core_verify_ext4_root_identity "$system_image.partial" "$reports/ext4-validation.log"
mv "$system_image.partial" "$system_image"

core_log "Creating and validating the 320 MiB / 4 KiB-sector rEFInd ESP"
truncate -s "$CORE_ESP_SIZE_BYTES" "$esp_image.partial"
mkfs.vfat -F 32 -S "$CORE_ESP_LOGICAL_SECTOR_SIZE" -s 1 -R 32 -n "$CORE_ESP_LABEL" "$esp_image.partial" \
    >"$reports/esp-mkfs.log" 2>&1
MTOOLS_NO_VFAT=1 mcopy -s -i "$esp_image.partial" "$esp_tree"/* ::/
core_verify_esp "$esp_image.partial" "$CORE_REBOOT2ANDROID_SHA256" "$reports/esp-validation.log"
mv "$esp_image.partial" "$esp_image"

cp "$esp_tree/EFI/BOOT/refind.conf" "$metadata/refind.conf"
cp "$reports/final-initramfs-contents.txt" "$metadata/final-initramfs-contents.txt"
dnf5 --version >"$metadata/dnf-version.txt"
rpm --version >"$metadata/rpm-version.txt"
printf '%s\n' "${CORE_CONTAINER_IMAGE_ID:-unknown}" >"$metadata/container-image-id.txt"
printf '%s\n' "$kver" >"$metadata/kernel-uname.txt"
printf '%s\n' "${uki##*/}" >"$metadata/uki-filename.txt"

zstd -T0 -"$CORE_COMPRESSION_LEVEL" -f "$system_image" -o "$system_image.zst"
zstd -T0 -"$CORE_COMPRESSION_LEVEL" -f "$esp_image" -o "$esp_image.zst"
(
    cd "$artifact_dir"
    sha256sum ./*.img ./*.img.zst metadata/* reports/* >SHA256SUMS
)

cat >"$artifact_dir/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide CORE alpha image

- Architecture: AArch64
- Filesystem: EXT4, label \`$CORE_FILESYSTEM_LABEL\`, size \`$CORE_IMAGE_SIZE\`
- Boot manager: rEFInd
- Kernel package: \`$CORE_DEFAULT_KERNEL_PACKAGE\`
- Kernel uname: \`$kver\`
- UKI: \`${uki##*/}\`
- CORE meta: \`$CORE_META_PACKAGE\`
- COPR: \`mcc45tr/nabu-linux\`, GPG verification enabled
- ESP: $CORE_ESP_SIZE_BYTES bytes, $CORE_ESP_LOGICAL_SECTOR_SIZE-byte logical sectors
- Root account: locked; no pre-created user
- SSH daemon: installed but disabled
- nobody/nobody overflow ownership: absent from rootfs and final initramfs
- Physical Nabu boot/HIL: not performed by the image compose
EOF

if [[ "${CORE_KEEP_UNCOMPRESSED:-1}" != 1 ]]; then
    rm -f -- "$system_image" "$esp_image"
    (cd "$artifact_dir" && sha256sum ./*.zst metadata/* reports/* >SHA256SUMS)
fi
rm -rf -- "$work_dir"
core_log "CORE artifacts completed: $artifact_dir"
