#!/usr/bin/bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
source_name=nabu-boot-integration-2.0.0
archive="$root/vendor/$source_name.tar.zst"
[[ -d $root/source ]] || {
	printf 'Missing canonical boot-integration source: %s\n' "$root/source" >&2
	exit 1
}
tar --zstd -cf "$archive" \
	--sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
	--transform="s,^source,$source_name," -C "$root" source
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
install -m0644 "$archive" "$top/SOURCES/"
install -m0644 "$root/nabu-boot-integration.spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/nabu-boot-integration.spec"
