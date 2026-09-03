#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")" && pwd)
topdir=${1:-"$root/.rpmbuild"}
source_name=mutter-51.rc.tar.xz
source_url=https://download.gnome.org/sources/mutter/51/$source_name

mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
if [[ ! -f "$topdir/SOURCES/$source_name" ]]; then
    curl --fail --location --retry 3 --output "$topdir/SOURCES/$source_name" "$source_url"
fi
(cd "$topdir/SOURCES" && sha512sum -c "$root/sources.sha512")
install -m 0644 "$root/mutter.spec" "$topdir/SPECS/mutter.spec"
rpmbuild -bs --define "_topdir $topdir" "$topdir/SPECS/mutter.spec"
find "$topdir/SRPMS" -maxdepth 1 -type f -name 'mutter-*.src.rpm' -print
