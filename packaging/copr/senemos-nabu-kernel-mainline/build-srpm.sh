#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
spec=$root/senemos-nabu-kernel-mainline.spec
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
archive=linux-$version.tar.xz
url=https://cdn.kernel.org/pub/linux/kernel/v7.x/$archive
evdi_version=$(sed -nE 's/^%global evdi_version ([^[:space:]]+).*/\1/p' "$spec")
[[ $evdi_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
evdi_archive=evdi-$evdi_version.tar.gz

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
if [[ -n ${NABU_UPSTREAM_ARCHIVE:-} ]]; then
    install -m0644 "$NABU_UPSTREAM_ARCHIVE" "$top/SOURCES/$archive"
elif [[ ! -s $top/SOURCES/$archive ]]; then
    curl -L --fail --retry 3 --output "$top/SOURCES/$archive" "$url"
fi

if [[ -n ${NABU_EVDI_ARCHIVE:-} ]]; then
    install -m0644 "$NABU_EVDI_ARCHIVE" "$top/SOURCES/$evdi_archive"
elif [[ ! -s $top/SOURCES/$evdi_archive ]]; then
    curl -L --fail --retry 3 --output "$top/SOURCES/$evdi_archive" \
        "https://github.com/DisplayLink/evdi/archive/refs/tags/v$evdi_version.tar.gz"
fi

install -m0644 "$root/upstream.sha256" "$root/patches.sha256" "$root/evdi.sha256" \
    "$top/SOURCES/"
install -m0644 "$root"/patches/*.patch "$top/SOURCES/"
install -m0644 "$root/91-nabu-mainline-omit-early-xhci.conf" \
    "$root/nabu-mainline-late-xhci.service" \
    "$root/90-nabu-mainline.preset" "$root/test-dsi-pll.py" \
    "$root/test-runtime-payload.sh" "$root/test-audio-power.py" \
    "$root/nabu-displaylink.config" "$top/SOURCES/"

(
    cd "$top/SOURCES"
    sha256sum -c upstream.sha256
    sha256sum -c patches.sha256
    sha256sum -c evdi.sha256
)

if [[ -n ${NABU_BUILD_STAMP:-} ]]; then
    stamp=$NABU_BUILD_STAMP
elif [[ $(TZ=Europe/Istanbul date +%z) == +0300 ]]; then
    stamp=$(TZ=Europe/Istanbul date +%y%m%d%H%M)
else
    stamp=$(date -u --date='+3 hours' +%y%m%d%H%M)
fi
[[ $stamp =~ ^[0-9]{10}$ ]]
printf '%s\n' "$stamp" >"$top/SOURCES/nabu-build-stamp"

install -m0644 "$spec" "$top/SPECS/"
sed -i "s/^%global nabu_build_stamp .*/%global nabu_build_stamp $stamp/" \
    "$top/SPECS/${spec##*/}"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/${spec##*/}"
