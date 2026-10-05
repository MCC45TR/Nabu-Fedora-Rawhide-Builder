#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
name=senemos-nabu-plymouth-1.0.0
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

tar --zstd -cf "$top/SOURCES/$name.tar.zst" \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    --transform "s,^source,$name," -C "$root" source
install -m0644 "$root/senemos-nabu-plymouth.spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/senemos-nabu-plymouth.spec"
