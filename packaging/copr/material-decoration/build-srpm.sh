#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
spec=$root/material-decoration.spec
commit=$(sed -nE 's/^%global upstream_commit ([0-9a-f]{40})$/\1/p' "$spec")
[[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid upstream commit' >&2; exit 1; }
archive="material-decoration-$commit.tar.gz"

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
if [[ -n ${MATERIAL_DECORATION_ARCHIVE:-} ]]; then
    install -m0644 "$MATERIAL_DECORATION_ARCHIVE" "$top/SOURCES/$archive"
elif [[ ! -s $top/SOURCES/$archive ]]; then
    curl --fail --location --retry 3 \
        --output "$top/SOURCES/$archive" \
        "https://codeload.github.com/guiodic/material-decoration/tar.gz/$commit"
fi

install -m0644 "$root/upstream.sha256" "$top/SOURCES/"
(
    cd "$top/SOURCES"
    sha256sum --check upstream.sha256
)
install -m0644 "$spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/material-decoration.spec"
