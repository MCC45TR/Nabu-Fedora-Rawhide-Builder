#!/usr/bin/bash
set -Eeuo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
legacy_dir="${project_dir}/../nabu-kde-integration"
topdir="${project_dir}/.rpmbuild"
spec="${project_dir}/nabu-runtime-integration.spec"

install -d "$topdir/BUILD" "$topdir/BUILDROOT" "$topdir/RPMS" \
    "$topdir/SOURCES" "$topdir/SPECS" "$topdir/SRPMS"
find "$topdir/RPMS" "$topdir/SRPMS" -type f -name '*.rpm' -delete

install -m0644 "${legacy_dir}/LICENSE" "$topdir/SOURCES/LICENSE"
install -m0644 "${legacy_dir}/README.md" "$topdir/SOURCES/README.md"
for source in \
    nabu-pmic-rtc-sync nabu-slpi-suspend senemos-nabu-status \
    nabu-pmic-rtc-sync.service nabu-slpi-suspend.service \
    mnt-vendor-persist.mount 90-senemos-nabu.preset \
    10-nabu-sensor-stack.conf 80-nabu-disable-efi-rtc-wakeup.rules \
    81-nabu-suspend-wake.rules 90-nabu-unneeded-storage.conf \
    90-nabu-mcc45tr.hwdb fastfetch-config.jsonc; do
    install -m0644 "${legacy_dir}/files/${source}" "$topdir/SOURCES/${source}"
done
install -m0644 "$spec" "$topdir/SPECS/nabu-runtime-integration.spec"

rpmbuild -ba --define "_topdir ${topdir}" "$topdir/SPECS/nabu-runtime-integration.spec"

install -d "${project_dir}/out/rpm" "${project_dir}/out/srpm"
find "${project_dir}/out/rpm" "${project_dir}/out/srpm" -type f -name '*.rpm' -delete
find "$topdir/RPMS" -type f -name '*.rpm' -exec install -m0644 -t "${project_dir}/out/rpm" {} +
find "$topdir/SRPMS" -type f -name '*.src.rpm' -exec install -m0644 -t "${project_dir}/out/srpm" {} +

"${project_dir}/tests/test-package.sh"
