#!/usr/bin/bash
set -Eeuo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
copr_dir=$(cd -- "$source_dir/.." && pwd)
top_dir=${1:-"$source_dir/rpmbuild"}
mkdir -p "$top_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

integration_name=nabu-system-integration-2.0.0
integration_source="$source_dir/vendor-src/$integration_name"
integration_archive="$source_dir/vendor/$integration_name.tar.zst"
[[ -d $integration_source ]] || {
    printf 'Missing canonical integration source: %s\n' "$integration_source" >&2
    exit 1
}
tar --zstd -cf "$integration_archive" \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -C "$source_dir/vendor-src" "$integration_name"

install -m0644 "$copr_dir/nabu-repository-config/nabu-linux-copr.repo" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-repository-config/90-nabu-disable-cisco-openh264.repo" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kernel-maintenance/nabu-kernel-maintenance.service" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kernel-maintenance/nabu-kernel-maintenance.timer" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kernel-maintenance/nabu-kernel-maintenance.path" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kernel-maintenance/90-nabu-kernel-maintenance.preset" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-plasma-base/95-nabu-plasma-login.preset" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-plasma-login-theme/80-nabu-plasma-login-theme.conf" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-plasma-login-theme/nabu-plasma-login.svg" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kde-mobile-base/plasma-mobile.desktop" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kde-mobile-base/20-nabu-mobile-session.conf" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kde-mobile-base/90-nabu-mobile-login.conf" "$top_dir/SOURCES/"
install -m0644 "$copr_dir/nabu-kde-mobile-base/95-nabu-plasma-mobile.preset" "$top_dir/SOURCES/"
install -m0755 "$source_dir/nabu" "$source_dir/nabu-kernel-maintenance" "$top_dir/SOURCES/"
install -m0755 "$source_dir/nabu-kernel-offline-finalize" "$top_dir/SOURCES/"
install -m0755 "$source_dir/test-kernel-maintenance-family.sh" "$top_dir/SOURCES/"
install -m0755 "$source_dir/test-offline-kernel-finalize.sh" "$top_dir/SOURCES/"
install -m0644 "$source_dir/nabu.8" "$source_dir/kernel.conf" "$top_dir/SOURCES/"
install -m0644 "$source_dir/gnome-mobile-copr.repo" \
    "$source_dir/nabu-gnome-mobile-sync.service" \
    "$source_dir/nabu-gnome-mobile-sync.timer" \
    "$source_dir/90-nabu-gnome-mobile-sync.preset" \
    "$source_dir/20-nabu-mobile-user-mode.conf" "$top_dir/SOURCES/"
install -m0755 "$source_dir/nabu-gnome-mobile-sync" \
    "$source_dir/test-gnome-mobile-repo-sync.sh" "$top_dir/SOURCES/"
install -m0644 "$source_dir/80-nabu-kernel-retention.conf" "$top_dir/SOURCES/"
install -m0644 "$source_dir/90-nabu-offline-uki-finalize.conf" "$top_dir/SOURCES/"
install -m0644 "$source_dir"/vendor/*.{c,gz,zst} "$top_dir/SOURCES/"
install -m0644 "$source_dir/vendor/nabu-pen-autopair" "$source_dir/vendor/82-nabu-pen-autopair.rules" "$source_dir/vendor/nabu-pen-autopair@.service" "$top_dir/SOURCES/"

for spec in "$source_dir"/*.spec; do
    staged="$top_dir/SPECS/$(basename -- "$spec")"
    install -m0644 "$spec" "$staged"
    rpmbuild -bs --define "_topdir $top_dir" "$staged"
done

count=$(find "$top_dir/SRPMS" -maxdepth 1 -type f -name '*.src.rpm' | wc -l)
[[ $count -eq 6 ]] || {
    printf 'Expected six unified meta SRPMs, found %s\n' "$count" >&2
    exit 1
}
printf 'Built one CORE and five DE meta SRPMs: %s\n' "$top_dir/SRPMS"
