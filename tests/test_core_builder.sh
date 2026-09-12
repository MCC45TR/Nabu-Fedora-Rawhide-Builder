#!/usr/bin/env bash

set -uo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="$ROOT/core-builder/profile.env"
WRAPPER="$ROOT/core-builder/build-core.sh"
COMPOSE="$ROOT/core-builder/container-compose.sh"
VERIFY="$ROOT/core-builder/lib/verify.sh"
SELINUX_RELABEL="$ROOT/tools/lib/relabel-ext4-selinux.sh"
SELINUX_HELPER="$ROOT/tools/lib/ext4-selinux-labels.py"
LOCALE_HELPER="$ROOT/tools/lib/find-missing-rpm-locales.py"
DRACUT_POLICY="$ROOT/core-builder/rootfs/etc/dracut.conf.d/90-nabu-release.conf"
DRACUT_MODULE="$ROOT/core-builder/rootfs/usr/lib/dracut/modules.d/90nabu-release-policy/module-setup.sh"
WORKFLOW="$ROOT/.github/workflows/build-core-manual.yml"
passed=0
failed=0

check() {
    local name="$1"
    shift
    if "$@"; then
        printf 'ok %d - %s\n' "$((passed + failed + 1))" "$name"
        ((passed += 1))
    else
        printf 'not ok %d - %s\n' "$((passed + failed + 1))" "$name"
        ((failed += 1))
    fi
}

check 'CORE scripts have valid Bash syntax' \
    bash -n "$WRAPPER" "$COMPOSE" "$VERIFY" "$SELINUX_RELABEL" "$DRACUT_MODULE"
check 'offline SELinux and locale helpers have valid Python syntax' \
    python3 -m py_compile "$SELINUX_HELPER" "$LOCALE_HELPER"
check 'profile selects Rawhide AArch64 EXT4 stable 7.2.x, stable meta, camera, Plymouth and rEFInd' \
    bash -c 'source "$1"; [[ "$CORE_PROFILE_VERSION" == 3 && "$CORE_BUILD_FLAVOR" == release && "$CORE_TARGET_ARCH" == aarch64 && "$CORE_RELEASEVER" == rawhide && "$CORE_FILESYSTEM" == ext4 && "$CORE_KERNEL_PACKAGE" == senemos-nabu-kernel-mainline && "$CORE_KERNEL_VERSION" == 7.2.4 && "$CORE_KERNEL_RELEASE" == 6 && "$CORE_META_VERSION" == 3.0.0 && "$CORE_META_RELEASE" == 83 && "$CORE_CAMERA_SUPPORT_PACKAGE" == nabu-camera-support && "$CORE_IRIS_VAAPI_PACKAGE" == iris-vaapi-nabu && "$CORE_BOOTLOADER" == refind && "$CORE_BOOT_VERSION" == 2.0.0 && "$CORE_BOOT_RELEASE" == 42.test && "$CORE_PLYMOUTH_PACKAGE" == senemos-nabu-plymouth && "$CORE_IMAGE_SIZE" == 8G ]]' _ "$PROFILE"
check 'compose explicitly installs CORE meta, one stable 7.2.x kernel, camera stack, Plymouth and rEFInd' \
    bash -c 'grep -Fq "\"\$CORE_META_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_KERNEL_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_CAMERA_SUPPORT_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_IRIS_VAAPI_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_PLYMOUTH_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_BOOT_PACKAGE\"" "$1" && grep -Fq -- "--exclude=senemos-nabu-kernel-alpha" "$1"' _ "$COMPOSE"
check 'sole stable COPR gate fails closed, verifies signatures and pins stable EVRs' \
    bash -c 'source "$1"; [[ "$CORE_COPR_STABLE_BASEURL" == *"/nabu-linux/fedora-rawhide-aarch64/" && "$CORE_COPR_STABLE_GPGKEY" == *"/nabu-linux/pubkey.gpg" ]] && ! grep -Rq "CORE_COPR_TEST\|nabu-core-test-compose\|priority=10" "$1" "$2" "$3" && grep -Fq "skip_if_unavailable=False" "$2" && grep -Fq "gpgcheck=1" "$2" && grep -Fq "Unexpected mainline kernel EVR" "$2" && grep -Fq "Unexpected stable-channel CORE meta EVR" "$2" && grep -Fq "The test COPR repository entered" "$2" && grep -Fq "install_weak_deps=False" "$2" && grep -Fq "dnf-forward-sync.log" "$2" && grep -Fq "core_dnf_retry" "$2" && grep -Fq "dnf-bootstrap.log" "$2" && grep -Fq " dracut " "$2" && grep -Fq "rc=\$?" "$2"' _ "$PROFILE" "$COMPOSE" "$ROOT/core-builder/lib/common.sh"
check 'nobody and initramfs setid gates are present' \
    bash -c 'grep -Fq "core_verify_no_overflow_ownership" "$1" && grep -Fq "core_verify_initramfs_listing" "$1" && grep -Fq "User:[[:space:]]+0" "$2"' _ "$COMPOSE" "$VERIFY"
check 'locked-root verification reads shadow without requiring chroot on FUSE' \
    bash -c 'grep -Fq "core_verify_root_locked_shadow" "$1" && grep -Fq "Target root account is not locked" "$1" && grep -Fq "password" "$1"' _ "$VERIFY"
check 'only SENEMOS7 is generated and moved under the Fedora EFI directory' \
    bash -c 'grep -Fq -- "--family SENEMOS7" "$1" && ! grep -Fq -- "--family SENEMOS6" "$1" && ! grep -Fq -- "--family SENEMOS616" "$1" && grep -Fq "Expected exactly one generated SENEMOS7 UKI" "$1" && ! grep -Fq "senemos-SENEMOS7.conf" "$1" && grep -Fq "/EFI/fedora/\$mainline_name" "$1" && grep -Fq "mainline-kernel-uname.txt" "$1" && grep -Fq "SENEMOS Nabu Mainline 7.2.x" "$1" && grep -Fq "An unstable EFI artifact entered" "$1"' _ "$COMPOSE"
check 'rEFInd verification enforces exactly Fedora and Android entries' \
    bash -c 'grep -Fq "recovery timeout differs" "$1" && grep -Fq "scanfor manual" "$1" && grep -Fq "exactly Fedora and Android entries" "$1" && grep -Fq "exactly one Fedora kernel entry" "$1" && grep -Fq "/EFI/android/Reboot2Android.efi" "$1" && grep -Fq "Packaged rEFInd EFI loader is missing" "$2" && grep -Fq "Packaged Nabu rEFInd theme is missing" "$2"' _ "$VERIFY" "$COMPOSE"
check 'ESP32 recovery starts after switch-root without adding CDC logging to initramfs' \
    bash -c '! grep -RqE "dmesg --follow|journalctl --boot --follow|add_dracutmodules.*nabu-esp32|add_drivers.*cdc_acm" "$1/core-builder/rootfs" && grep -Fq "ESP32/CDC logging entered" "$2" && grep -Fq "nabu-esp32-cdc-log.service nabu-mainline-late-xhci.service" "$3" && grep -Fq "ln_r /dev/null /etc/systemd/system/debug-shell.service" "$4" && grep -Fq "nabu-release-policy" "$5"' _ "$ROOT" "$VERIFY" "$COMPOSE" "$DRACUT_MODULE" "$DRACUT_POLICY"
check 'recovery networking avoids wait-online and enables bounded SSH access' \
    bash -c 'grep -Fq "enable NetworkManager.service firewalld.service sshd.service" "$1" && grep -Fq "mask initial-setup.service NetworkManager-wait-online.service" "$1" && grep -Fq "PermitRootLogin yes" "$1" && grep -Fq "firewall-offline-cmd --add-service=ssh" "$1"' _ "$COMPOSE"
check 'UKI and serialized ESP verify exact kernel, DTB and uname payloads' \
    bash -c 'grep -Fq "objcopy --dump-section .linux" "$1" && grep -Fq "objcopy --dump-section .dtb" "$1" && grep -Fq "UKI .linux payload differs" "$1" && grep -Fq "Serialized ESP UKI uname differs" "$2" && grep -Fq "kernel_hash" "$2" && grep -Fq "dtb_hash" "$2"' _ "$COMPOSE" "$VERIFY"
check 'SELinux labels are applied before EXT4 and read back from the image' \
    bash -c 'grep -Fq "setfiles -F -r" "$1" && grep -Fq "system_u:object_r:init_exec_t:s0" "$1" && grep -Fq "ea_get /usr/lib/systemd/systemd security.selinux" "$2" && grep -Fq "relabel-ext4-selinux.sh" "$1" && grep -Fq "all_inodes" "$3" && grep -Fq "UNSAFE_TYPES" "$3" && grep -Fq -- '\''-c "$binary_policy"'\'' "$4"' _ "$COMPOSE" "$VERIFY" "$SELINUX_HELPER" "$SELINUX_RELABEL"
check 'release policy enables root, masks onboarding and removes noisy boot options' \
    bash -c 'source "$1"; [[ " $CORE_KERNEL_CMDLINE " == *" quiet "* && " $CORE_KERNEL_CMDLINE " == *" splash "* && " $CORE_KERNEL_CMDLINE " == *" loglevel=3 "* && " $CORE_KERNEL_CMDLINE " == *" console=tty0 "* && " $CORE_KERNEL_CMDLINE " == *" rw "* && " $CORE_KERNEL_CMDLINE " != *" ro "* && " $CORE_KERNEL_CMDLINE " != *" rd.driver.pre=cdc_acm "* && " $CORE_KERNEL_CMDLINE " != *" deferred_probe_timeout=0 "* ]] && grep -Fq "root:1234" "$2" && grep -Fq "enable NetworkManager.service firewalld.service sshd.service" "$2" && grep -Fq "mask initial-setup.service" "$2" && grep -Fq "mask debug-shell.service" "$2" && grep -Fq "scsi_debug" "$3"' _ "$PROFILE" "$COMPOSE" "$DRACUT_POLICY"
check 'CORE sets nabu hostname and keeps every RPM language in composer and target' \
    bash -c 'grep -Fq "macros.zz-nabu-languages" "$1" && grep -Fq "macros.nabu-languages" "$1" && grep -Fq "find-missing-rpm-locales.py" "$1" && grep -Fq "printf '\''nabu\\n'\''" "$1" && grep -Fq "FILEFLAGS:fflags" "$2" && grep -Fq '\''if "g" in flags:'\'' "$2"' _ "$COMPOSE" "$LOCALE_HELPER"
check 'writable root, persistent ESP and ordered Initial Setup are image contracts' \
    bash -c 'grep -Eq "^PARTLABEL=linux[[:space:]]+/[[:space:]]+ext4[[:space:]]+rw,[^[:space:]]*x-systemd.growfs" "$1" && grep -Eq "^LABEL=ESPNABU[[:space:]]+/boot/efi[[:space:]]+vfat[[:space:]]+rw," "$1" && grep -Fq "Requires=systemd-remount-fs.service systemd-logind.service" "$2" && grep -Fqx "ConditionPathIsReadWrite=/" "$2" && ! grep -Fq "mountpoint -q -w" "$2" && grep -Fq "Release UKI does not request a writable root" "$3"' _ "$ROOT/core-builder/rootfs/etc/fstab" "$ROOT/core-builder/rootfs/etc/systemd/system/initial-setup.service.d/10-nabu-writable-root.conf" "$VERIFY"
check 'confined iio-sensor-proxy QRTR SELinux policy is installed by compose' \
    bash -c 'grep -Fq "iiosensorproxy_t self" "$1" && grep -Fq "qipcrtr_socket" "$1" && grep -Fq "semodule -p" "$2" && grep -Fq -- "-N -X 300" "$2" && grep -Fq "selinux-modules.txt" "$2" && grep -Fq "nabu-iiosensorproxy-qrtr" "$2"' _ "$ROOT/core-builder/rootfs/usr/share/selinux/packages/nabu-iiosensorproxy-qrtr.cil" "$COMPOSE"
check 'ESP contract is 320 MiB with 4096-byte sectors and Android hash pinning' \
    bash -c 'source "$1"; [[ "$CORE_ESP_SIZE_BYTES" == 335544320 && "$CORE_ESP_LOGICAL_SECTOR_SIZE" == 4096 && ${#CORE_REBOOT2ANDROID_SHA256} == 64 ]]' _ "$PROFILE"
check 'mandatory SLPI firmware is source and hash pinned' \
    bash -c 'source "$1"; [[ "$CORE_SLPI_FIRMWARE_URL" =~ /raw/[0-9a-f]{40}/slpi_nb[.]mbn$ && ${#CORE_SLPI_FIRMWARE_SHA256} == 64 ]] && grep -Fq "slpi-firmware-sha256.log" "$2" && grep -Fq -- "--retry-max-time 300" "$2" && grep -Fq "install -m0644 \"\$slpi_firmware.partial\" \"\$slpi_firmware\"" "$2"' _ "$PROFILE" "$COMPOSE"
check 'workflow is manual-only on native ARM64 and derives KDE from its CORE' \
    bash -c '[[ -f "$1" ]] && grep -Eq "^[[:space:]]*workflow_dispatch:" "$1" && ! grep -Eq "^[[:space:]]*(push|pull_request|schedule):" "$1" && grep -Fq "runs-on: ubuntu-24.04-arm" "$1" && grep -Fq "kde-builder/build-kde.sh" "$1" && grep -Fq "KDE-from-CORE compose seconds" "$1" && grep -Fq "always() && !inputs.solve_only && !inputs.keep_uncompressed" "$1" && grep -Fq "find \"\$output_root\" -type f -name '\''*.img'\'' -delete" "$1"' _ "$WORKFLOW"

printf '1..%d\n' "$((passed + failed))"
printf '# %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
