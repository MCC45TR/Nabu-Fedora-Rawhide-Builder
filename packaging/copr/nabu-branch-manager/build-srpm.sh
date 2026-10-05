#!/usr/bin/bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top_dir=${1:-"$source_dir/rpmbuild"}
mkdir -p "$top_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp -f "$source_dir/nabu" "$source_dir/nabu.8" "$top_dir/SOURCES/"
cp -f "$source_dir/nabu-branch-manager.spec" "$top_dir/SPECS/"
rpmbuild -bs --define "_topdir $top_dir" "$top_dir/SPECS/nabu-branch-manager.spec"
