#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="$ROOT/kde-builder/profile.env"; HOST="$ROOT/kde-builder/build-kde.sh"; COMPOSE="$ROOT/kde-builder/container-compose.sh"
passed=0; failed=0
check() { local n=$1; shift; if "$@"; then echo "ok $((passed+failed+1)) - $n"; ((passed++)); else echo "not ok $((passed+failed+1)) - $n"; ((failed++)); fi; }
check 'KDE scripts have valid Bash syntax' bash -n "$HOST" "$COMPOSE"
check 'KDE profile pins stable COPR, meta and mainline kernel' bash -c 'source "$1"; [[ "$KDE_COPR_BASEURL" == *"/nabu-linux/fedora-rawhide-aarch64/" && "$KDE_META_PACKAGE" == kde-plasma-nabu-meta && "$KDE_META_RELEASE" == 103 && "$KDE_CORE_META_RELEASE" == 83 && "$KDE_KERNEL_PACKAGE" == senemos-nabu-kernel-mainline && "$KDE_KERNEL_VERSION" == 7.2.4 && "$KDE_KERNEL_RELEASE" == 6 ]]' _ "$PROFILE"
check 'KDE never enables test COPR or another kernel' bash -c '! grep -Rq "nabu-linux-test.*repofrompath\|KDE_COPR_TEST" "$1" "$2" && grep -Fq -- "--exclude=senemos-nabu-kernel-mainline-unstable" "$2" && grep -Fq "Forbidden kernel entered KDE" "$2"' _ "$PROFILE" "$COMPOSE"
check 'DE locks root and masks CDC while keeping onboarding userless' bash -c 'grep -Fq "usermod -L root" "$1" && grep -Fq "mask nabu-esp32-cdc-log.service" "$1" && grep -Fq "regular-users.txt" "$1" && grep -Fq ".unconfigured" "$1" && grep -Fq "plasmalogin.service" "$1"' _ "$COMPOSE"
check 'locale payload policy and driver stack have hard gates' bash -c 'grep -Fq "macros.zz-nabu-languages" "$1" && grep -Fq "find-missing-rpm-locales.py" "$1" && grep -Fq "locale_repair_packages" "$1" && grep -Fq "dnf-locale-repair.log" "$1" && grep -Fq "installed locale files remain missing" "$1" && grep -Fq "glibc-all-langpacks" "$1" && grep -Fq "nabu-camera-support iris-vaapi-nabu iio-sensor-proxy-nabu libssc-nabu python3-ssc-nabu" "$1"' _ "$COMPOSE"
check 'KDE uses Plasma Camera, inherits nabu hostname and rejects Kamoso' bash -c 'grep -Fq "plasma-camera" "$1" "$2" && ! grep -Fq "KDE_EXTRA_PACKAGES=\"systemd-pam kamoso" "$1" && grep -Fq "Kamoso entered KDE" "$2" && grep -Fq "KDE did not inherit the nabu hostname" "$2"' _ "$PROFILE" "$COMPOSE"
check 'final image verifies complete RPM ownership map' bash -c 'grep -Fq "final-rpm-ownership.txt" "$1" && grep -Fq "Final KDE /etc ownership is not root:root" "$1" && grep -Fq "Final KDE /usr ownership is not root:root" "$1"' _ "$HOST"
check 'KDE report keeps its literal nabu hostname without shell substitution' grep -Fq 'Default hostname: \`nabu\`' "$HOST"
check 'KDE preserves ESP byte-for-byte and relabels SELinux' bash -c 'grep -Fq "cmp -s \"\$CORE_ESP\" \"\$esp_image\"" "$1" && grep -Fq "relabel-ext4-selinux.sh" "$1" && grep -Fq "core_verify_ext4_root_identity" "$1" && grep -Fq "nabu_restore_rpm_special_modes" "$1"' _ "$HOST"
check 'RPM 6-safe ownership and special-mode capture plus SELinux bindings are required' bash -c 'grep -Fq -- "-qa --dump" "$1" && grep -Fq '\''["rpm", "--root", root, "-qa", "--dump"]'\'' "$2" && ! grep -Fq "FILEUSERNAME" "$2" && ! grep -Fq "FILEMODES:octal" "$1" && grep -Fq "python3-selinux" "$3"' _ "$ROOT/gnome-builder/lib/rpm-special-modes.sh" "$COMPOSE" "$ROOT/.github/workflows/build-core-manual.yml"
check 'Ubuntu host final readback uses the Fedora rpmdb path' grep -Fq -- '--dbpath /usr/lib/sysimage/rpm' "$HOST"
printf '1..%d\n# %d passed, %d failed\n' "$((passed+failed))" "$passed" "$failed"
[[ $failed -eq 0 ]]
