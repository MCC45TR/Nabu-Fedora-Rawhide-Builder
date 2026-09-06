#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
(
    cd "$root/sources"
    sha256sum -c SHA256SUMS
)
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
install -m0644 "$root"/sources/* "$top/SOURCES/"
install -m0644 "$root/nabu-desktop-integration.spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/nabu-desktop-integration.spec"
