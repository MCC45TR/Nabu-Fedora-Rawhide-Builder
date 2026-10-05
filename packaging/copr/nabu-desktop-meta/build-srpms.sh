#!/usr/bin/bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top_dir=${1:-"$source_dir/rpmbuild"}
version_file=${NABU_META_VERSION_FILE:-"$source_dir/../nabu-meta-version"}

mkdir -p "$top_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
[[ $(<"$version_file") =~ ^[0-9]{10}$ ]]
install -m0644 "$version_file" "$top_dir/SOURCES/nabu-meta-version"
for spec in "$source_dir"/*.spec; do
    install -m0644 "$spec" "$top_dir/SPECS/$(basename -- "$spec")"
    rpmbuild -bs --define "_topdir $top_dir" "$top_dir/SPECS/$(basename "$spec")"
done
