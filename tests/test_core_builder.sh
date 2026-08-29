#!/usr/bin/env bash

set -uo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="$ROOT/core-builder/profile.env"
WRAPPER="$ROOT/core-builder/build-core.sh"
COMPOSE="$ROOT/core-builder/container-compose.sh"
VERIFY="$ROOT/core-builder/lib/verify.sh"
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

check 'CORE scripts have valid Bash syntax' bash -n "$WRAPPER" "$COMPOSE" "$VERIFY"
check 'profile selects Rawhide AArch64 EXT4 bash alpha and rEFInd' \
    bash -c 'source "$1"; [[ "$CORE_TARGET_ARCH" == aarch64 && "$CORE_RELEASEVER" == rawhide && "$CORE_FILESYSTEM" == ext4 && "$CORE_DEFAULT_KERNEL_PACKAGE" == senemos-nabu-kernel-alpha && "$CORE_BOOTLOADER" == refind && "$CORE_IMAGE_SIZE" == 8G ]]' _ "$PROFILE"
check 'compose explicitly installs CORE meta, alpha and rEFInd' \
    bash -c 'grep -Fq "\"\$CORE_META_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_DEFAULT_KERNEL_PACKAGE\"" "$1" && grep -Fq "\"\$CORE_BOOT_PACKAGE\"" "$1" && grep -Fq "systemd-boot-unsigned" "$1"' _ "$COMPOSE"
check 'DNF gates fail closed and disable weak dependencies' \
    bash -c 'grep -Fq "skip_if_unavailable=False" "$1" && grep -Fq "gpgcheck=1" "$1" && grep -Fq "install_weak_deps=False" "$1" && grep -Fq "dnf-forward-sync.log" "$1" && grep -Fq "core_dnf_retry" "$1" && grep -Fq "dnf-bootstrap.log" "$1" && grep -Fq " dracut " "$1" && grep -Fq "rc=\$?" "$1"' _ "$COMPOSE"
check 'nobody and initramfs setid gates are present' \
    bash -c 'grep -Fq "core_verify_no_overflow_ownership" "$1" && grep -Fq "core_verify_initramfs_listing" "$1" && grep -Fq "User:[[:space:]]+0" "$2"' _ "$COMPOSE" "$VERIFY"
check 'ESP contract is 320 MiB with 4096-byte sectors and Android hash pinning' \
    bash -c 'source "$1"; [[ "$CORE_ESP_SIZE_BYTES" == 335544320 && "$CORE_ESP_LOGICAL_SECTOR_SIZE" == 4096 && ${#CORE_REBOOT2ANDROID_SHA256} == 64 ]]' _ "$PROFILE"
check 'mandatory SLPI firmware is source and hash pinned' \
    bash -c 'source "$1"; [[ "$CORE_SLPI_FIRMWARE_URL" =~ /raw/[0-9a-f]{40}/slpi_nb[.]mbn$ && ${#CORE_SLPI_FIRMWARE_SHA256} == 64 ]] && grep -Fq "slpi-firmware-sha256.log" "$2" && grep -Fq "install -m0644 \"\$slpi_firmware.partial\" \"\$slpi_firmware\"" "$2"' _ "$PROFILE" "$COMPOSE"
check 'workflow is manual-only on a native ARM64 runner' \
    bash -c '[[ -f "$1" ]] && grep -Eq "^[[:space:]]*workflow_dispatch:" "$1" && ! grep -Eq "^[[:space:]]*(push|pull_request|schedule):" "$1" && grep -Fq "runs-on: ubuntu-24.04-arm" "$1"' _ "$WORKFLOW"

printf '1..%d\n' "$((passed + failed))"
printf '# %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
