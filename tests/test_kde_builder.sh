#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="$ROOT/kde-builder/profile.env"; HOST="$ROOT/kde-builder/build-kde.sh"; COMPOSE="$ROOT/kde-builder/container-compose.sh"
passed=0; failed=0
check() { local n=$1; shift; if "$@"; then echo "ok $((passed+failed+1)) - $n"; ((passed++)); else echo "not ok $((passed+failed+1)) - $n"; ((failed++)); fi; }
check 'KDE scripts have valid Bash syntax' bash -n "$HOST" "$COMPOSE"
check 'KDE profile pins stable COPR, meta and mainline kernel' bash -c 'source "$1"; [[ "$KDE_COPR_BASEURL" == *"/nabu-linux/fedora-rawhide-aarch64/" && "$KDE_META_PACKAGE" == kde-plasma-nabu-meta && "$KDE_META_RELEASE" == 103 && "$KDE_CORE_META_RELEASE" == 83 && "$KDE_KERNEL_PACKAGE" == senemos-nabu-kernel-mainline && "$KDE_KERNEL_VERSION" == 7.2.4 && "$KDE_KERNEL_RELEASE" == 5 ]]' _ "$PROFILE"
check 'KDE never enables test COPR or another kernel' bash -c '! grep -Rq "nabu-linux-test.*repofrompath\|KDE_COPR_TEST" "$1" "$2" && grep -Fq -- "--exclude=senemos-nabu-kernel-mainline-unstable" "$2" && grep -Fq "Forbidden kernel entered KDE" "$2"' _ "$PROFILE" "$COMPOSE"
check 'DE locks root and masks CDC while keeping onboarding userless' bash -c 'grep -Fq "usermod -L root" "$1" && grep -Fq "mask nabu-esp32-cdc-log.service" "$1" && grep -Fq "regular-users.txt" "$1" && grep -Fq ".unconfigured" "$1" && grep -Fq "plasmalogin.service" "$1"' _ "$COMPOSE"
check 'locale regression repair and driver stack have hard gates' bash -c 'grep -Fq "locale-rpm-files.txt" "$1" && grep -Fq "FILESTATES" "$1" && grep -Fq "state == \"0\"" "$1" && grep -Fq "locale_repair_packages" "$1" && grep -Fq "dnf-locale-repair.log" "$1" && grep -Fq "normal-state locale files remain missing" "$1" && grep -Fq "glibc-all-langpacks" "$1" && grep -Fq "nabu-camera-support iris-vaapi-nabu iio-sensor-proxy-nabu libssc-nabu python3-ssc-nabu" "$1"' _ "$COMPOSE"
check 'KDE preserves ESP byte-for-byte and relabels SELinux' bash -c 'grep -Fq "cmp -s \"\$CORE_ESP\" \"\$esp_image\"" "$1" && grep -Fq "relabel-ext4-selinux.sh" "$1" && grep -Fq "core_verify_ext4_root_identity" "$1" && grep -Fq "nabu_restore_rpm_special_modes" "$1"' _ "$HOST"
printf '1..%d\n# %d passed, %d failed\n' "$((passed+failed))" "$passed" "$failed"
[[ $failed -eq 0 ]]
