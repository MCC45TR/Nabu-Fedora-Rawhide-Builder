#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
copr_dir=$(cd -- "$root/.." && pwd)
unified=$copr_dir/nabu-unified-meta
top=${1:-$root/rpmbuild}
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
"$root/generate-family-spec.py"

install -m0644 \
    "$unified/vendor/nabu-kde-l10n-1.1.0.tar.gz" \
    "$unified/vendor/nabu-flashlight-integration-1.0.0.tar.gz" \
    "$unified/vendor/nabu-kde-integration-1.4.0.1.tar.gz" \
    "$unified/vendor/nabu-kde-widgets-debug-1.0.1.tar.zst" \
    "$copr_dir/nabu-plasma-base/95-nabu-plasma-login.preset" \
    "$copr_dir/nabu-plasma-login-theme/80-nabu-plasma-login-theme.conf" \
    "$copr_dir/nabu-plasma-login-theme/nabu-plasma-login.svg" \
    "$unified/90-nabu-powerdevil.conf" \
    "$unified/90-nabu-compositor-realtime.conf" \
    "$copr_dir/nabu-kde-mobile-base/plasma-mobile.desktop" \
    "$copr_dir/nabu-kde-mobile-base/20-nabu-mobile-session.conf" \
    "$copr_dir/nabu-kde-mobile-base/90-nabu-mobile-login.conf" \
    "$copr_dir/nabu-kde-mobile-base/95-nabu-plasma-mobile.preset" \
    "$unified/gnome-mobile-copr.repo" \
    "$unified/nabu-gnome-mobile-sync.service" \
    "$unified/nabu-gnome-mobile-sync.timer" \
    "$unified/90-nabu-gnome-mobile-sync.preset" \
    "$unified/20-nabu-mobile-user-mode.conf" \
    "$top/SOURCES/"
install -m0755 \
    "$unified/nabu-gnome-mobile-sync" \
    "$unified/test-gnome-mobile-repo-sync.sh" \
    "$top/SOURCES/"
install -m0644 "$root/nabu-desktop-metas.spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/nabu-desktop-metas.spec"
