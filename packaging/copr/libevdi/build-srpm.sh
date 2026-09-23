#!/usr/bin/bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:?usage: build-srpm.sh OUTPUT}
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
top=$(cd -- "$top" && pwd)
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$root/libevdi.spec")
archive=evdi-$version.tar.gz
if [[ -n ${NABU_EVDI_ARCHIVE:-} ]]; then
    install -m0644 "$NABU_EVDI_ARCHIVE" "$top/SOURCES/$archive"
elif [[ ! -s $top/SOURCES/$archive ]]; then
    curl -fL --retry 3 "https://github.com/DisplayLink/evdi/archive/refs/tags/v$version.tar.gz" \
        -o "$top/SOURCES/$archive"
fi
install -m0644 "$root/upstream.sha256" "$root/nabu-displaylink-status.cpp" \
    "$root/test-status.py" "$root/README.md" "$top/SOURCES/"
(cd "$top/SOURCES" && sha256sum -c upstream.sha256)
rpmbuild -bs --define "_topdir $top" "$root/libevdi.spec"
