#!/usr/bin/bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
source_name=nabu-boot-integration-2.0.0
archive="$root/vendor/$source_name.tar.zst"
plymouth_name=senemos-nabu-plymouth-1.0.0
plymouth_archive="$root/vendor/$plymouth_name.tar.zst"
mkdir -p "$root/vendor"
[[ -d $root/source ]] || {
	printf 'Missing canonical boot-integration source: %s\n' "$root/source" >&2
	exit 1
}
tar --zstd -cf "$archive" \
	--sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
	--transform="s,^source,$source_name," -C "$root" source
tar --zstd -cf "$plymouth_archive" \
	--sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
	--transform="s,^plymouth-source,$plymouth_name," -C "$root" plymouth-source
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
install -m0644 "$archive" "$top/SOURCES/"
install -m0644 "$plymouth_archive" "$top/SOURCES/"
install -m0644 "$root/nabu-boot-integration.spec" "$top/SPECS/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/nabu-boot-integration.spec"
