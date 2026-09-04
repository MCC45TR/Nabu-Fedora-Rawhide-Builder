#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
spec=$root/senemos-nabu-kernel-lts.spec
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
archive=linux-$version.tar.xz
url=https://cdn.kernel.org/pub/linux/kernel/v6.x/$archive

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
if [[ ! -s $top/SOURCES/$archive ]]; then
    curl -L --fail --retry 3 --output "$top/SOURCES/$archive" "$url"
fi
install -m0644 "$root/upstream.sha256" "$root/patches.sha256" \
    "$root/91-nabu-lts-omit-early-xhci.conf" \
    "$root/91-nabu-lts-late-xhci.conf" "$top/SOURCES/"
install -m0644 "$root"/patches/*.patch "$top/SOURCES/"
(cd "$top/SOURCES" && sha256sum -c upstream.sha256 && sha256sum -c patches.sha256)

if [[ -n ${NABU_BUILD_STAMP:-} ]]; then
    stamp=$NABU_BUILD_STAMP
elif [[ $(TZ=Europe/Istanbul date +%z) == +0300 ]]; then
    stamp=$(TZ=Europe/Istanbul date +%y%m%d%H%M)
else
    # Minimal COPR source-builder images may not ship zoneinfo. Turkey uses a
    # fixed UTC+03 offset; keep release EVRs monotonic across local midnight.
    stamp=$(date -u --date='+3 hours' +%y%m%d%H%M)
fi
[[ $stamp =~ ^[0-9]{10}$ ]]
printf '%s\n' "$stamp" > "$top/SOURCES/nabu-build-stamp"
install -m0644 "$spec" "$top/SPECS/"
sed -i "s/^%global nabu_build_stamp .*/%global nabu_build_stamp $stamp/" \
    "$top/SPECS/${spec##*/}"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/${spec##*/}"
