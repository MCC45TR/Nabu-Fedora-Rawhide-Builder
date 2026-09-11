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
run_id="core-rawhide-mainline-7.2-recovery-$CORE_RELEASE_TAG"
artifact_dir="/output/$run_id"
work_dir="/output/.work-$run_id"
root="$work_dir/root"
esp_tree="$work_dir/esp-tree"
reports="$artifact_dir/reports"
metadata="$artifact_dir/metadata"
system_image="$artifact_dir/fedora-rawhide-mainline-7.2-recovery-core-$CORE_RELEASE_TAG-system.img"
esp_image="$artifact_dir/fedora-rawhide-mainline-7.2-recovery-core-$CORE_RELEASE_TAG-esp.img"
stage_file="$reports/stages.tsv"
current_stage=initialization

mkdir -p "$artifact_dir" "$reports" "$metadata" "$root/boot/efi" "$esp_tree/EFI/android"
printf 'timestamp_utc\tstage\tstate\tdetail\n' >"$stage_file"

stage_begin() {
    current_stage="$1"
    printf '%s\t%s\tBEGIN\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" >>"$stage_file"
    core_log "STAGE $1: $2"
}

stage_pass() {
    printf '%s\t%s\tPASS\t%s\n' "$(date -u +%FT%TZ)" "$current_stage" "$1" >>"$stage_file"
}

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

stage_begin compose-tools "Installing deterministic compose tools"
core_dnf_retry "$reports/compose-tools.log" \
    -y --disablerepo='*openh264*' --setopt=install_weak_deps=False install \
    attr binutils cpio curl diffutils dosfstools dracut e2fsprogs findutils fuse3 jq kmod mtools \
    policycoreutils python3 python3-libselinux rpm shadow-utils util-linux zstd
for command in cmp debugfs e2fsck fsck.vfat fuse2fs fusermount3 getfattr lsinitrd mcopy mdir mkfs.ext4 \
    mkfs.vfat objcopy python3 rpm setfiles sha256sum zstd; do
    core_require_command "$command"
done
stage_pass "Compose tools installed"

cat >/etc/yum.repos.d/nabu-core-stable-compose.repo <<EOF
[nabu-core-stable-compose]
name=Nabu CORE stable compose
baseurl=$CORE_COPR_STABLE_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=$CORE_COPR_STABLE_GPGKEY
skip_if_unavailable=False
metadata_expire=0
priority=20
EOF
cat >/etc/yum.repos.d/nabu-core-test-compose.repo <<EOF
[nabu-core-test-compose]
name=Nabu CORE test compose
baseurl=$CORE_COPR_TEST_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=$CORE_COPR_TEST_GPGKEY
skip_if_unavailable=False
metadata_expire=0
priority=10
EOF

dnf_args=(
    -y --forcearch="$CORE_TARGET_ARCH" --use-host-config
    --installroot="$root" --releasever="$CORE_RELEASEVER"
    --disablerepo='*openh264*'
    --setopt=install_weak_deps=False
    --setopt=keepcache=True
    --setopt=retries=10
    --setopt=timeout=120
    --exclude=senemos-nabu-kernel
    --exclude=senemos-nabu-kernel-alpha
    --exclude=senemos-nabu-kernel-mainline-alpha
    --exclude=senemos-nabu-kernel-mainline-unstable
    --exclude=senemos-nabu-kernel-legacy-stable
)
required_packages=(
    "$CORE_META_PACKAGE"
    "$CORE_KERNEL_PACKAGE"
    "$CORE_CAMERA_SUPPORT_PACKAGE"
    "$CORE_IRIS_VAAPI_PACKAGE"
    "$CORE_BOOT_PACKAGE"
    "$CORE_PLYMOUTH_PACKAGE"
    NetworkManager NetworkManager-wifi firewalld openssh-server
    bash-completion nano less iproute iputils glibc-langpack-tr systemd-boot-unsigned policycoreutils
)
bootstrap_packages=(
    filesystem setup basesystem bash coreutils rpm dnf5
    systemd systemd-udev util-linux-core shadow-utils
)

stage_begin dnf-solve "Resolving Rawhide AArch64 plus signed COPR single-kernel closure"
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
grep -Fq "$CORE_KERNEL_PACKAGE" "$reports/dnf-solve.log" || core_die "Mainline 7.2.x kernel is absent from solve"
grep -Fq "$CORE_CAMERA_SUPPORT_PACKAGE" "$reports/dnf-solve.log" || core_die "Camera support is absent from solve"
grep -Fq "$CORE_IRIS_VAAPI_PACKAGE" "$reports/dnf-solve.log" || core_die "Iris VA-API is absent from solve"
grep -Fq "$CORE_BOOT_PACKAGE" "$reports/dnf-solve.log" || core_die "rEFInd selector is absent from solve"
grep -Fq "$CORE_PLYMOUTH_PACKAGE" "$reports/dnf-solve.log" || core_die "Plymouth package is absent from solve"
! grep -Eq 'senemos-nabu-kernel-(alpha|mainline-alpha|legacy-stable)' "$reports/dnf-solve.log" || \
    core_die "A forbidden 6.17/old-mainline kernel entered the solve"
! grep -Fq 'senemos-nabu-kernel-mainline-unstable' "$reports/dnf-solve.log" || \
    core_die "The unstable kernel entered the recovery solve"
stage_pass "Single mainline 7.2.x DNF transaction solved without conflicts"

if [[ "${CORE_SOLVE_ONLY:-false}" == true ]]; then
    cp "$reports/dnf-solve.log" "/output/dnf-solve-$run_stamp.log"
    core_log "Live DNF closure passed"
    exit 0
fi

stage_begin rootfs-install "Installing a fresh CORE root filesystem"
core_dnf_retry "$reports/dnf-bootstrap.log" \
    "${dnf_args[@]}" --disablerepo='nabu-core-*-compose' install "${bootstrap_packages[@]}"
core_dnf_retry "$reports/dnf-install.log" \
    "${dnf_args[@]}" install "${required_packages[@]}"

rpm --root "$root" -q "${required_packages[@]}" >"$metadata/installed-required-nevra.txt"
rpm --root "$root" -qa --qf '%{NAME}|%{EPOCHNUM}:%{VERSION}-%{RELEASE}|%{ARCH}\n' \
    | sort >"$metadata/rpm-manifest.txt"
rpm --root "$root" -q "$CORE_META_PACKAGE" "$CORE_KERNEL_PACKAGE" "$CORE_BOOT_PACKAGE" \
    >"$metadata/core-selection.txt"
rpm --root "$root" -q "$CORE_CAMERA_SUPPORT_PACKAGE" "$CORE_IRIS_VAAPI_PACKAGE" "$CORE_PLYMOUTH_PACKAGE" \
    >>"$metadata/core-selection.txt"
kernel_evr=$(rpm --root "$root" -q --qf '%{VERSION}-%{RELEASE}\n' "$CORE_KERNEL_PACKAGE")
[[ $kernel_evr =~ ^${CORE_KERNEL_VERSION}-${CORE_KERNEL_RELEASE}[.]fc[0-9]+$ ]] || \
    core_die "Unexpected mainline kernel EVR: $kernel_evr"
meta_evr=$(rpm --root "$root" -q --qf '%{VERSION}-%{RELEASE}\n' "$CORE_META_PACKAGE")
[[ $meta_evr =~ ^${CORE_META_VERSION}-${CORE_META_RELEASE}[.]fc[0-9]+$ ]] || \
    core_die "Unexpected test-channel CORE meta EVR: $meta_evr"
for forbidden_kernel in senemos-nabu-kernel senemos-nabu-kernel-alpha senemos-nabu-kernel-mainline-alpha \
    senemos-nabu-kernel-mainline-unstable senemos-nabu-kernel-legacy-stable senemos-nabu-kernel-lts; do
    ! rpm --root "$root" -q "$forbidden_kernel" >/dev/null 2>&1 || \
        core_die "Forbidden kernel package entered CORE: $forbidden_kernel"
done
[[ "$(find "$root/usr/lib/nabu-boot/managers" -maxdepth 1 -name '*.selected' -printf '%f\n')" == refind.selected ]] || \
    core_die "Exactly the rEFInd boot-manager marker was not selected"

cp -a "$SCRIPT_DIR/rootfs/." "$root/"
chmod 0755 "$root/usr/lib/dracut/modules.d/90nabu-release-policy/module-setup.sh"
install -d -m0700 "$root/var/lib/nabu-boot-backup"
install -m0644 /etc/yum.repos.d/nabu-core-test-compose.repo \
    "$root/etc/yum.repos.d/nabu-linux-test.repo"
stage_pass "CORE, single 7.2.x kernel, camera/Iris stack, rEFInd, Bash and Plymouth installed"

stage_begin rootfs-policy "Applying boot, service and Plymouth policy"
printf 'LANG=%s\n' "$CORE_LOCALE" >"$root/etc/locale.conf"
ln -sfn "../usr/share/zoneinfo/$CORE_TIMEZONE" "$root/etc/localtime"
printf '%s\n' "$CORE_TIMEZONE" >"$root/etc/timezone"
printf 'root:1234\n' | chroot "$root" /usr/sbin/chpasswd
chroot "$root" /usr/bin/passwd -S root | tee "$metadata/root-password-status.txt" | \
    grep -Eq '^root[[:space:]]+P[[:space:]]' || core_die "Root account is not password-enabled"
systemctl --root="$root" enable NetworkManager.service firewalld.service sshd.service \
    getty@tty1.service nabu-esp32-cdc-log.service nabu-mainline-late-xhci.service >/dev/null
systemctl --root="$root" mask initial-setup.service NetworkManager-wait-online.service >/dev/null 2>&1 || :
systemctl --root="$root" set-default multi-user.target >/dev/null
systemctl --root="$root" mask debug-shell.service >/dev/null
install -d -m0755 "$root/etc/systemd/system-generators"
ln -sfn /dev/null "$root/etc/systemd/system-generators/systemd-debug-generator"
install -d -m0755 "$root/etc/kernel/nabu-verbose-disabled.d"
install -d -m0755 "$root/etc/nabu"
printf 'preferred=mainline\n' >"$root/etc/nabu/kernel.conf"
printf 'refind_timeout=%s\n' "$CORE_REFIND_TIMEOUT" >"$root/etc/nabu/boot.conf"
install -d -m0755 "$root/etc/ssh/sshd_config.d"
printf '%s\n' \
    '# Recovery CORE: remove after installing a personal SSH key.' \
    'PermitRootLogin yes' \
    'PasswordAuthentication yes' \
    'KbdInteractiveAuthentication no' \
    'MaxAuthTries 4' \
    >"$root/etc/ssh/sshd_config.d/20-nabu-recovery.conf"
chroot "$root" /usr/bin/firewall-offline-cmd --add-service=ssh \
    >"$reports/firewalld-ssh.log" 2>&1
touch "$root/etc/kernel/nabu-uki.conf"
grep -v '^NABU_VERBOSE_MARKER_DIR=' "$root/etc/kernel/nabu-uki.conf" >"$work_dir/nabu-uki.conf"
printf 'NABU_VERBOSE_MARKER_DIR=/etc/kernel/nabu-verbose-disabled.d\n' >>"$work_dir/nabu-uki.conf"
install -m0644 "$work_dir/nabu-uki.conf" "$root/etc/kernel/nabu-uki.conf"
boot_policy="$root/usr/lib/senemos-nabu/boot-policy.conf"
[[ -s "$boot_policy" ]] || core_die "Packaged boot policy is missing"
grep -v '^NABU_KERNEL_CMDLINE=' "$boot_policy" >"$work_dir/boot-policy.conf"
printf "NABU_KERNEL_CMDLINE='%s'\n" "$CORE_KERNEL_CMDLINE" >>"$work_dir/boot-policy.conf"
install -m0644 "$work_dir/boot-policy.conf" "$boot_policy"
chroot "$root" plymouth-set-default-theme "$CORE_PLYMOUTH_THEME" >/dev/null
grep -Eq "^Theme=$CORE_PLYMOUTH_THEME$" "$root/etc/plymouth/plymouthd.conf" || \
    core_die "Plymouth theme was not selected"
[[ -s "$root/usr/bin/bash" ]] || core_die "Bash is absent"
[[ -L "$root/etc/systemd/system/debug-shell.service" && \
   "$(readlink "$root/etc/systemd/system/debug-shell.service")" == /dev/null ]] || \
    core_die "debug-shell is not masked"
[[ -L "$root/etc/systemd/system-generators/systemd-debug-generator" && \
   "$(readlink "$root/etc/systemd/system-generators/systemd-debug-generator")" == /dev/null ]] || \
    core_die "systemd debug generator is not masked"
[[ -L "$root/etc/systemd/system/getty.target.wants/getty@tty1.service" ]] || \
    core_die "Physical tty1 getty was not enabled"
grep -Fqx "NABU_KERNEL_CMDLINE='$CORE_KERNEL_CMDLINE'" "$boot_policy" || core_die "Release cmdline was not committed"
grep -Eq '^PARTLABEL=linux[[:space:]]+/[[:space:]]+ext4[[:space:]]+rw,' "$root/etc/fstab" || \
    core_die "Writable root fstab contract is missing"
grep -Eq '^LABEL=ESPNABU[[:space:]]+/boot/efi[[:space:]]+vfat[[:space:]]+rw,' "$root/etc/fstab" || \
    core_die "Persistent ESP mount contract is missing"
[[ " $CORE_KERNEL_CMDLINE " == *' rw '* && " $CORE_KERNEL_CMDLINE " != *' ro '* ]] || \
    core_die "Release kernel cmdline does not request a writable root"
[[ -L "$root/etc/systemd/system/initial-setup.service" && \
   "$(readlink "$root/etc/systemd/system/initial-setup.service")" == /dev/null ]] || \
    core_die "CORE Initial Setup is not masked"
for enabled_unit in NetworkManager.service firewalld.service sshd.service getty@tty1.service \
    nabu-esp32-cdc-log.service nabu-mainline-late-xhci.service; do
    systemctl --root="$root" is-enabled "$enabled_unit" | grep -Eq '^(enabled|static)$' || \
        core_die "Recovery service is not enabled: $enabled_unit"
done
[[ -L "$root/etc/systemd/system/NetworkManager-wait-online.service" && \
   "$(readlink "$root/etc/systemd/system/NetworkManager-wait-online.service")" == /dev/null ]] || \
    core_die "NetworkManager wait-online is not masked"

semodule -p "$root" -X 300 -i \
    "$root/usr/share/selinux/packages/nabu-iiosensorproxy-qrtr.cil" \
    >"$reports/selinux-iiosensorproxy-qrtr.log" 2>&1
semodule -p "$root" -X 300 -lfull | grep -Eq '^[[:space:]]*300[[:space:]]+nabu-iiosensorproxy-qrtr[[:space:]]+cil' || \
    core_die "Nabu iio-sensor-proxy QRTR SELinux policy was not installed"
stage_pass "Recovery networking, SSH, late XHCI, CDC logging, SELinux and Plymouth policy selected"

stage_begin dnf-forward-gates "Checking DNF integrity and future Rawhide solve"
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
rpm --root "$root" -qa --qf '%{NAME}\n' | sort >"$reports/installed-package-names.txt"
if grep -Eq '(-debuginfo|-debugsource)$|^(gdb|strace|systemtap|crash|kdump)$' \
    "$reports/installed-package-names.txt"; then
    core_die "Debug tooling entered the release rootfs"
fi
if grep -Eq '^(gdm|sddm|plasma-login-manager|gnome-shell|plasma-workspace|kwin|phosh)$' \
    "$reports/installed-package-names.txt"; then
    core_die "A desktop session or display manager entered CORE"
fi
stage_pass "DNF forward solve and nobody:nobody rootfs gates passed"

stage_begin pinned-payloads "Installing hash-pinned SLPI and Android payloads"
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
stage_pass "Pinned payload hashes verified"

stage_begin uki "Generating the single stable mainline 7.2.x UKI"
mount --bind "$esp_tree" "$root/boot/efi"
mount --rbind /dev "$root/dev"
mount --make-rslave "$root/dev"
mount --bind /proc "$root/proc"
mount --bind /sys "$root/sys"
mount --bind /run "$root/run"

kernel_version_for_package() {
    local package="${1:?package is required}"
    rpm --root "$root" -ql "$package" \
        | sed -nE 's@^/usr/lib/modules/([^/]+)/dtb/qcom/sm8150-xiaomi-nabu[.]dtb$@\1@p' \
        | sort -Vu
}

mapfile -t mainline_versions < <(kernel_version_for_package "$CORE_KERNEL_PACKAGE")
(( ${#mainline_versions[@]} == 1 )) || core_die "Expected one mainline kernel, found ${#mainline_versions[@]}"
mainline_kver="${mainline_versions[0]}"
[[ -s "$root/boot/vmlinuz-$mainline_kver" ]] || core_die "Kernel image is missing: $mainline_kver"
[[ -s "$root/usr/lib/modules/$mainline_kver/dtb/qcom/sm8150-xiaomi-nabu.dtb" ]] || core_die "Nabu DTB is missing: $mainline_kver"
[[ "$(find "$root/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | wc -l)" == 1 ]] || \
    core_die "CORE contains more than one vmlinuz"
[[ "$(find "$root/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | wc -l)" == 1 ]] || \
    core_die "CORE contains more than one kernel module tree"
grep -Fqx 'CONFIG_SM_CAMCC_8150=y' "$root/boot/config-$mainline_kver" || core_die "SM8150 CAMCC is not built in"
grep -Fqx 'CONFIG_SM_VIDEOCC_8150=y' "$root/boot/config-$mainline_kver" || core_die "SM8150 VIDEOCC is not built in"
grep -Fqx 'CONFIG_DMABUF_HEAPS_SYSTEM=y' "$root/boot/config-$mainline_kver" || core_die "DMA-BUF system heap is not built in"
grep -Fqx 'CONFIG_DMABUF_HEAPS_CMA=y' "$root/boot/config-$mainline_kver" || core_die "DMA-BUF CMA heap is not built in"
grep -Fqx 'CONFIG_USB_ACM=y' "$root/boot/config-$mainline_kver" || core_die "CDC ACM is not built in"

chroot "$root" /usr/bin/nabu-regenerate-uki --family SENEMOS7 "$mainline_kver" >"$reports/uki-mainline-generation.log" 2>&1
mapfile -t generated_mainline_ukis < <(find "$esp_tree/EFI/fedora" -maxdepth 1 -type f \
    -name 'SENEMOS7-*.efi' -printf '/EFI/fedora/%f\n' | sort)
(( ${#generated_mainline_ukis[@]} == 1 )) || \
    core_die "Expected exactly one generated SENEMOS7 UKI, found ${#generated_mainline_ukis[@]}"
mainline_efi=${generated_mainline_ukis[0]}
[[ -s "$esp_tree$mainline_efi" ]] || core_die "Mainline default UKI was not generated"
install -d -m0755 "$esp_tree/EFI/fedora"
mainline_name="senemos-nabu-kernel-mainline-7.2-$CORE_RELEASE_TAG.efi"
mv "$esp_tree$mainline_efi" "$esp_tree/EFI/fedora/$mainline_name"
mainline_efi="/EFI/fedora/$mainline_name"
find "$esp_tree/EFI/SENEMOS" -type f -delete 2>/dev/null || :
rmdir "$esp_tree/EFI/SENEMOS" 2>/dev/null || :
find "$esp_tree/loader/entries" -type f -delete 2>/dev/null || :
grep -Fxq "timeout $CORE_REFIND_TIMEOUT" "$esp_tree/EFI/BOOT/refind.conf" || \
    core_die "Packaged rEFInd timeout policy was not applied"
objcopy --dump-section .initrd="$work_dir/mainline-initramfs.img" "$esp_tree$mainline_efi"
objcopy --dump-section .cmdline="$metadata/mainline-kernel-cmdline.bin" "$esp_tree$mainline_efi"
objcopy --dump-section .linux="$work_dir/mainline-linux.bin" "$esp_tree$mainline_efi"
objcopy --dump-section .dtb="$work_dir/mainline-nabu.dtb" "$esp_tree$mainline_efi"
objcopy --dump-section .uname="$metadata/mainline-kernel-uname.bin" "$esp_tree$mainline_efi"
tr -d '\000' <"$metadata/mainline-kernel-cmdline.bin" >"$metadata/mainline-kernel-cmdline.txt"
tr -d '\000\n' <"$metadata/mainline-kernel-uname.bin" >"$metadata/mainline-kernel-uname-from-uki.txt"
cmp -s "$work_dir/mainline-linux.bin" "$root/boot/vmlinuz-$mainline_kver" || \
    core_die "UKI .linux payload differs from the installed kernel RPM"
cmp -s "$work_dir/mainline-nabu.dtb" \
    "$root/usr/lib/modules/$mainline_kver/dtb/qcom/sm8150-xiaomi-nabu.dtb" || \
    core_die "UKI .dtb payload differs from the installed Nabu DTB"
grep -Fxq "$mainline_kver" "$metadata/mainline-kernel-uname-from-uki.txt" || \
    core_die "UKI .uname differs from the installed module tree"
sha256sum "$root/boot/vmlinuz-$mainline_kver" "$work_dir/mainline-linux.bin" \
    >"$metadata/mainline-kernel-payload-sha256.txt"
sha256sum "$root/usr/lib/modules/$mainline_kver/dtb/qcom/sm8150-xiaomi-nabu.dtb" \
    "$work_dir/mainline-nabu.dtb" >"$metadata/mainline-dtb-payload-sha256.txt"
kernel_payload_hash=$(sha256sum "$root/boot/vmlinuz-$mainline_kver" | cut -d' ' -f1)
dtb_payload_hash=$(sha256sum \
    "$root/usr/lib/modules/$mainline_kver/dtb/qcom/sm8150-xiaomi-nabu.dtb" | cut -d' ' -f1)
lsinitrd "$work_dir/mainline-initramfs.img" >"$reports/mainline-initramfs-contents.txt"
core_verify_initramfs_listing "$reports/mainline-initramfs-contents.txt"
core_verify_release_cmdline "$metadata/mainline-kernel-cmdline.txt"
cat >"$esp_tree/EFI/BOOT/refind.conf" <<EOF
timeout $CORE_REFIND_TIMEOUT
scanfor manual
scan_driver_dirs drivers
rotation 3
include themes/refind-theme-regular-nabu-2x-v1/theme.conf
default_selection "SENEMOS Nabu Mainline 7.2.x"
menuentry "SENEMOS Nabu Mainline 7.2.x" {
    icon /EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/icons/256-96/os_fedora.png
    loader $mainline_efi
}
menuentry "Android" {
    icon /EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/icons/256-96/os_android.png
    loader /EFI/android/Reboot2Android.efi
}
EOF

[[ $(find "$esp_tree" \( -iname '*SENEMOS7U*' -o -iname '*unstable*' \) -print | wc -l) -eq 0 ]] || \
    core_die "An unstable EFI artifact entered the recovery ESP"

cleanup_mounts
trap - EXIT
stage_pass "Single hash-matched 7.2.x UKI and Android entry verified"

stage_begin selinux-labels "Applying and verifying targeted SELinux labels"
setfiles -F -r "$root" "$root/etc/selinux/targeted/contexts/files/file_contexts" "$root" \
    >"$reports/selinux-setfiles.log" 2>&1
getfattr -n security.selinux --only-values "$root/usr/lib/systemd/systemd" \
    >"$reports/systemd-selinux-label.txt"
grep -Fq 'system_u:object_r:init_exec_t:s0' "$reports/systemd-selinux-label.txt" || \
    core_die "systemd did not receive init_exec_t"
core_verify_no_overflow_ownership "$root" "$reports/root-overflow-ownership-after-labels.txt"
stage_pass "SELinux labels and ownership recheck passed"

stage_begin ext4-image "Creating and validating the 8 GiB EXT4 image"
truncate -s "$CORE_IMAGE_SIZE" "$system_image.partial"
mkfs.ext4 -q -F -L "$CORE_FILESYSTEM_LABEL" -d "$root" "$system_image.partial"
"/workspace/tools/lib/relabel-ext4-selinux.sh" "$system_image.partial" "$reports/selinux-ext4"
core_verify_ext4_root_identity "$system_image.partial" "$reports/ext4-validation.log"
mv "$system_image.partial" "$system_image"
stage_pass "EXT4 fsck, root ownership and serialized SELinux label passed"

stage_begin esp-image "Creating and validating the 320 MiB 4 KiB-sector rEFInd ESP"
truncate -s "$CORE_ESP_SIZE_BYTES" "$esp_image.partial"
mkfs.vfat -F 32 -S "$CORE_ESP_LOGICAL_SECTOR_SIZE" -s 1 -R 32 -n "$CORE_ESP_LABEL" "$esp_image.partial" \
    >"$reports/esp-mkfs.log" 2>&1
MTOOLS_NO_VFAT=1 mcopy -s -i "$esp_image.partial" "$esp_tree"/* ::/
core_verify_esp "$esp_image.partial" "$CORE_REBOOT2ANDROID_SHA256" \
    "$reports/esp-validation.log" "$kernel_payload_hash" "$dtb_payload_hash" "$mainline_kver"
mv "$esp_image.partial" "$esp_image"
stage_pass "ESP fsck, single Fedora UKI and Android gates passed"

stage_begin provenance "Recording package, tool and boot provenance"
cp "$esp_tree/EFI/BOOT/refind.conf" "$metadata/refind.conf"
cp "$reports/mainline-initramfs-contents.txt" "$metadata/mainline-initramfs-contents.txt"
dnf5 --version >"$metadata/dnf-version.txt"
rpm --version >"$metadata/rpm-version.txt"
printf '%s\n' "${CORE_CONTAINER_IMAGE_ID:-unknown}" >"$metadata/container-image-id.txt"
printf '%s\n' "$mainline_kver" >"$metadata/mainline-kernel-uname.txt"
printf '%s\n' "$mainline_name" >"$metadata/mainline-uki-filename.txt"
printf '%s\n' "$CORE_PLYMOUTH_THEME" >"$metadata/plymouth-theme.txt"
printf '%s\n' enabled-after-switch-root >"$metadata/esp32-cdc-logging.txt"
printf '%s\n' enabled >"$metadata/sshd.txt"
printf '%s\n' masked >"$metadata/NetworkManager-wait-online.txt"
stage_pass "Immutable build evidence written"

stage_begin build-report "Writing the build and physical-HIL boundary report"
cat >"$artifact_dir/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide CORE 7.2.x recovery image

- Architecture: AArch64
- Filesystem: EXT4, label \`$CORE_FILESYSTEM_LABEL\`, size \`$CORE_IMAGE_SIZE\`
- Boot manager: rEFInd
- Build flavor: release; rEFInd timeout: $CORE_REFIND_TIMEOUT second
- Only kernel: \`$mainline_kver\` from \`$CORE_KERNEL_PACKAGE\`
- Fedora UKI: \`/EFI/fedora/$mainline_name\`
- Android EFI: \`/EFI/android/Reboot2Android.efi\`
- Plymouth: \`$CORE_PLYMOUTH_THEME\`, enabled by \`quiet splash\`
- UKI payload gate: embedded kernel, DTB and uname match the installed RPM payload byte-for-byte
- ESP32-S3/CDC logging: enabled after switch-root and deliberately absent from initramfs
- CORE meta: \`$CORE_META_PACKAGE\`
- COPR candidate: \`mcc45tr/nabu-linux-test\`; dependency base: \`mcc45tr/nabu-linux\`; GPG verification enabled
- ESP: $CORE_ESP_SIZE_BYTES bytes, $CORE_ESP_LOGICAL_SECTOR_SIZE-byte logical sectors
- Root account: enabled with the requested installation password; no pre-created user
- Desktop session/display manager: absent
- Root mount: explicitly writable in both UKI cmdline and \`/etc/fstab\`
- ESP mount: \`LABEL=ESPNABU\` at \`/boot/efi\` with a bounded, non-fatal device wait
- Initial Setup: masked for the CORE profile
- Sensors: confined \`iiosensorproxy_t\` QRTR socket policy installed
- SSH daemon: enabled; root password recovery is temporary and must be replaced with a personal key
- NetworkManager wait-online: masked so absent Wi-Fi cannot hold the boot critical path
- Debug shell/generator: masked; debug packages and debug cmdline options: absent
- nobody/nobody overflow ownership: absent from rootfs and initramfs
- SELinux labels: applied before EXT4 serialization and verified from the image
- Physical Nabu boot/HIL: not performed by the image compose
EOF
stage_pass "Build report written"

stage_begin compression "Compressing artifacts and producing final checksums"
zstd -T0 -"$CORE_COMPRESSION_LEVEL" -f "$system_image" -o "$system_image.zst"
zstd -T0 -"$CORE_COMPRESSION_LEVEL" -f "$esp_image" -o "$esp_image.zst"
if [[ "${CORE_KEEP_UNCOMPRESSED:-1}" != 1 ]]; then
    rm -f -- "$system_image" "$esp_image"
fi
stage_pass "Compression completed"
(
    cd "$artifact_dir"
    find . -type f ! -name SHA256SUMS ! -name sha256-verify.log -print0 \
        | sort -z | xargs -0 sha256sum >SHA256SUMS
    sha256sum -c SHA256SUMS >reports/sha256-verify.log
)
rm -rf -- "$work_dir"
core_log "CORE artifacts completed: $artifact_dir"
