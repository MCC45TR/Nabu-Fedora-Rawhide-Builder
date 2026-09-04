#!/usr/bin/bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_name=senemos-fastfetch-config
package_version=1.1.0
source_root="$source_dir/source"
output_dir=${1:-"$source_dir/out"}
build_root=$(mktemp -d --tmpdir senemos-fastfetch-rpmbuild.XXXXXX)

cleanup() {
    [[ "$build_root" == /tmp/senemos-fastfetch-rpmbuild.* ]] && rm -rf -- "$build_root"
}
trap cleanup EXIT

for command_name in rpmbuild tar python3; do
    command -v "$command_name" >/dev/null
done

test -x "$source_root/bin/senemos-fastfetch"
test "$(find "$source_root/i18n" -maxdepth 1 -name '*.jsonc' | wc -l)" -eq 27

mkdir -p "$build_root"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$output_dir"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -C "$source_dir" -czf "$build_root/SOURCES/$package_name-$package_version.tar.gz" \
    --transform "s,^source,$package_name-$package_version," source
install -m0644 "$source_dir/$package_name.spec" "$build_root/SPECS/$package_name.spec"

rpmbuild -bs --define "_topdir $build_root" "$build_root/SPECS/$package_name.spec"
install -m0644 "$build_root/SRPMS/$package_name-$package_version-"*.src.rpm "$output_dir/"
sha256sum "$output_dir/$package_name-$package_version-"*.src.rpm
