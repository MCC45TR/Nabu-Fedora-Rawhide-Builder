#!/usr/bin/bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top_dir=${1:-"$source_dir/rpmbuild"}

mkdir -p "$top_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
for spec in "$source_dir"/*.spec; do
    cp -f "$spec" "$top_dir/SPECS/"
    rpmbuild -bs --define "_topdir $top_dir" "$top_dir/SPECS/$(basename "$spec")"
done
