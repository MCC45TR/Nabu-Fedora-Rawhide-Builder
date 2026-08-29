#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="$ROOT/gnome-builder/profile.env"
WRAPPER="$ROOT/gnome-builder/build-gnome.sh"
COMPOSE="$ROOT/gnome-builder/container-compose.sh"
README="$ROOT/gnome-builder/README.md"
WORKFLOW="$ROOT/.github/workflows/build-gnome-from-core-manual.yml"
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

check 'GNOME scripts have valid Bash syntax' bash -n "$WRAPPER" "$COMPOSE"
check 'GNOME profile is Rawhide AArch64 with minimal default' \
    bash -c 'source "$1"; [[ "$GNOME_TARGET_ARCH" == aarch64 && "$GNOME_RELEASEVER" == rawhide && "$GNOME_DEFAULT_PROFILE" == minimal && "$GNOME_ESP_LOGICAL_SECTOR_SIZE" == 4096 ]]' _ "$PROFILE"
check 'GNOME package lists are split into individual package arguments' \
    bash -c 'grep -Fq "read -r -a profile_packages" "$1" && grep -Fq "profile_packages+=(\"\${optimal_packages[@]}\")" "$1"' _ "$COMPOSE"
check 'builder requires an explicit CORE system and ESP copy' \
    bash -c 'grep -Fq -- "--core-system" "$1" && grep -Fq -- "--core-esp" "$1" && grep -Fq "Cloning CORE before any FUSE access" "$1" && grep -Fq "cp --reflink=auto" "$1"' _ "$WRAPPER"
check 'GNOME closure uses signed COPR and disables weak dependencies' \
    bash -c 'grep -Fq "gpgcheck=1" "$1" && grep -Fq "GNOME_COPR_GPGKEY" "$1" && grep -Fq "install_weak_deps=False" "$1" && grep -Fq "dnf-forward-sync.log" "$1" && grep -Fq -- "--assumeno" "$1"' _ "$COMPOSE"
check 'GNOME session payload and GDM are explicit' \
    bash -c 'grep -Fq "gdm gnome-shell gnome-session" "$1" && grep -Fq "gnome-control-center" "$1" && grep -Fq "ptyxis" "$1" && grep -Fq "systemctl --root=" "$1"' _ "$COMPOSE"
check 'CORE alpha, meta and rEFInd are read back after layering' \
    bash -c 'grep -Fq "nabu-core-meta senemos-nabu-kernel-alpha nabu-boot-refind" "$1" && grep -Fq "core-selection-readback.txt" "$2"' _ "$COMPOSE" "$WRAPPER"
check 'RPM ownership and special modes are restored after FUSE' \
    bash -c 'grep -Fq "rpm-file-ownership.tsv" "$1" && grep -Fq "nabu_restore_rpm_special_modes" "$2" && grep -Fq "nabu_verify_rpm_special_modes" "$2" && grep -Fq "core_verify_no_overflow_ownership" "$2"' _ "$COMPOSE" "$WRAPPER"
check 'ESP keeps alpha UKI and Android return path' \
    bash -c 'grep -Fq "Reboot2Android.efi" "$1" && grep -Fq "EFI/SENEMOS/SENEMOS" "$1" && grep -Fq "core_verify_esp" "$1"' _ "$WRAPPER"
check 'workflow is manual-only and rebuilds CORE on native ARM64' \
    bash -c '[[ -f "$1" ]] && grep -Eq "^[[:space:]]*workflow_dispatch:" "$1" && ! grep -Eq "^[[:space:]]*(push|pull_request|schedule):" "$1" && grep -Fq "runs-on: ubuntu-24.04-arm" "$1" && grep -Fq "fuse2fs" "$1" && grep -Fq "build-core.sh" "$1" && grep -Fq "build-gnome.sh" "$1"' _ "$WORKFLOW"
check 'README documents the copy and nobody gate' \
    bash -c 'grep -Fq "verified CORE image" "$1" && grep -Fq "UID/GID 65534" "$1"' _ "$README"

printf '1..%d\n' "$((passed + failed))"
printf '# %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
