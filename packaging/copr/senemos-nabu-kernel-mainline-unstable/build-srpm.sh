#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
spec=$root/senemos-nabu-kernel-mainline-unstable.spec
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
archive=linux-$version.tar.xz
url=https://cdn.kernel.org/pub/linux/kernel/v7.x/$archive

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
if [[ ! -s $top/SOURCES/$archive ]]; then
    curl -L --fail --retry 3 --output "$top/SOURCES/$archive" "$url"
fi
install -m0644 "$root/upstream.sha256" "$root/patches.sha256" \
    "$root/91-nabu-mainline-unstable-omit-early-xhci.conf" \
    "$root/nabu-mainline-unstable-late-xhci.service" \
    "$root/90-nabu-mainline-unstable.preset" "$top/SOURCES/"
install -m0644 "$root"/patches/*.patch "$top/SOURCES/"
(cd "$top/SOURCES" && sha256sum -c upstream.sha256 && sha256sum -c patches.sha256)

stamp=${NABU_BUILD_STAMP:-$(TZ=Europe/Istanbul date +%y%m%d%H%M)}
[[ $stamp =~ ^[0-9]{10}$ ]]
printf '%s\n' "$stamp" > "$top/SOURCES/nabu-build-stamp"
install -m0644 "$spec" "$top/SPECS/"
sed -i "s/^%global nabu_build_stamp .*/%global nabu_build_stamp $stamp/" \
    "$top/SPECS/${spec##*/}"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/${spec##*/}"
