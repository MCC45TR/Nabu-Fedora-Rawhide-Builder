#!/usr/bin/bash
set -Eeuo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
files_dir="${project_dir}/files"
spec="${project_dir}/senemos-nabu-kde.spec"
version="$(rpmspec -q --qf '%{VERSION}\n' "$spec" | head -n1)"
name=nabu-kde-debug
topdir="${project_dir}/.rpmbuild"
stage="$(mktemp -d "${TMPDIR:-/tmp}/senemos-nabu-kde.XXXXXX")"
source_root="${stage}/${name}-${version}"

cleanup() {
    rm -rf -- "$stage"
}
trap cleanup EXIT

install -d "$source_root/runtime" "$source_root/kde"
install -m0644 "${project_dir}/LICENSE" "$source_root/LICENSE"
install -m0644 "${project_dir}/README.md" "$source_root/README.md"

install -m0755 "${files_dir}/nabu-pmic-rtc-sync" "$source_root/runtime/nabu-pmic-rtc-sync"
install -m0755 "${files_dir}/nabu-slpi-suspend" "$source_root/runtime/nabu-slpi-suspend"
install -m0755 "${files_dir}/nabu-sensor-registry-runtime" \
    "$source_root/runtime/nabu-sensor-registry-runtime"
install -m0755 "${files_dir}/senemos-nabu-status" "$source_root/runtime/senemos-nabu-status"
install -m0644 "${files_dir}/nabu-pmic-rtc-sync.service" "$source_root/runtime/nabu-pmic-rtc-sync.service"
install -m0644 "${files_dir}/nabu-slpi-suspend.service" "$source_root/runtime/nabu-slpi-suspend.service"
install -m0644 "${files_dir}/nabu-sensor-registry-runtime.service" \
    "$source_root/runtime/nabu-sensor-registry-runtime.service"
install -m0644 "${files_dir}/mnt-vendor-persist.mount" "$source_root/runtime/mnt-vendor-persist.mount"
install -m0644 "${files_dir}/90-senemos-nabu.preset" "$source_root/runtime/90-senemos-nabu.preset"
install -m0644 "${files_dir}/10-nabu-sensor-stack.conf" "$source_root/runtime/10-nabu-sensor-stack.conf"
install -m0644 "${files_dir}/20-nabu-runtime-registry.conf" \
    "$source_root/runtime/20-nabu-runtime-registry.conf"
install -m0644 "${files_dir}/90-nabu-compositor-realtime.conf" \
    "$source_root/runtime/90-nabu-compositor-realtime.conf"
install -m0644 "${files_dir}/80-nabu-disable-efi-rtc-wakeup.rules" \
    "$source_root/runtime/80-nabu-disable-efi-rtc-wakeup.rules"
install -m0644 "${files_dir}/81-nabu-suspend-wake.rules" \
    "$source_root/runtime/81-nabu-suspend-wake.rules"
install -m0644 "${files_dir}/90-nabu-unneeded-storage.conf" \
    "$source_root/runtime/90-nabu-unneeded-storage.conf"
install -m0644 "${files_dir}/90-nabu-mcc45tr.hwdb" "$source_root/runtime/90-nabu-mcc45tr.hwdb"
install -m0644 "${files_dir}/fastfetch-config.jsonc" "$source_root/runtime/fastfetch-config.jsonc"

install -m0755 "${files_dir}/nabu-audio-orientation" "$source_root/kde/nabu-audio-orientation"
install -m0755 "${files_dir}/senemos-nabu-display-profile" "$source_root/kde/senemos-nabu-display-profile"
install -m0644 "${files_dir}/nabu-audio-orientation.service" "$source_root/kde/nabu-audio-orientation.service"
install -m0644 "${files_dir}/90-senemos-nabu-user.preset" "$source_root/kde/90-nabu-kde.preset"
install -m0644 "${files_dir}/90-senemos-nabu-startupsound.conf" "$source_root/kde/90-senemos-nabu-startupsound.conf"
install -m0644 "${files_dir}/kwinoutputconfig.json" "$source_root/kde/kwinoutputconfig.json"
install -m0644 "${files_dir}/powerdevilrc" "$source_root/kde/powerdevilrc"

install -d "$topdir/BUILD" "$topdir/BUILDROOT" "$topdir/RPMS" "$topdir/SOURCES" "$topdir/SPECS" "$topdir/SRPMS"
find "$topdir/RPMS" "$topdir/SRPMS" -type f -name '*.rpm' -delete
tar --sort=name --mtime='UTC 2026-08-15' --owner=0 --group=0 --numeric-owner \
    -C "$stage" -czf "$topdir/SOURCES/${name}-${version}.tar.gz" "${name}-${version}"
install -m0644 "$spec" "$topdir/SPECS/${name}.spec"

rpmbuild -ba --define "_topdir ${topdir}" "$topdir/SPECS/${name}.spec"

install -d "${project_dir}/out/rpm" "${project_dir}/out/srpm"
find "${project_dir}/out/rpm" "${project_dir}/out/srpm" -maxdepth 1 -type f -name '*.rpm' -delete
find "$topdir/RPMS" -type f -name '*.rpm' -exec install -m0644 -t "${project_dir}/out/rpm" {} +
find "$topdir/SRPMS" -type f -name '*.src.rpm' -exec install -m0644 -t "${project_dir}/out/srpm" {} +
(
    cd "${project_dir}/out"
    find rpm srpm -type f -name '*.rpm' -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS
)

"${project_dir}/tests/test-package.sh"
printf 'RPMs:  %s\n' "${project_dir}/out/rpm"
printf 'SRPM:  %s\n' "${project_dir}/out/srpm"
