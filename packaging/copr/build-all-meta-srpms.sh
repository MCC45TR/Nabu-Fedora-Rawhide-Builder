#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top_dir=${1:-"$root/meta-rpmbuild"}
version_file="$root/nabu-meta-version"
version=$($root/generate-meta-version)

temporary="${version_file}.tmp.$$"
trap 'rm -f -- "$temporary"' EXIT
printf '%s\n' "$version" >"$temporary"
mv -f -- "$temporary" "$version_file"

mkdir -p "$top_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
install -m0644 "$version_file" "$top_dir/SOURCES/nabu-meta-version"

specs=(
    "$root/nabu-meta/nabu-meta.spec"
    "$root"/nabu-core-meta/*.spec
    "$root"/nabu-desktop-meta/*.spec
)

for spec in "${specs[@]}"; do
    staged_spec="$top_dir/SPECS/$(basename -- "$spec")"
    install -m0644 "$spec" "$staged_spec"
    rpmbuild -bs --define "_topdir $top_dir" "$staged_spec"
done

count=$(find "$top_dir/SRPMS" -maxdepth 1 -type f -name "*-${version}-1*.src.rpm" | wc -l)
[[ $count -eq 14 ]] || {
    printf 'Expected 14 meta SRPMs for %s, found %s\n' "$version" "$count" >&2
    exit 1
}

printf 'Built %s meta SRPMs with shared version %s\n' "$count" "$version"
