#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

bash -n "$root/nabu" "$root/nabu-kernel-maintenance" "$root/build-srpms.sh"
mapfile -t specs < <(find "$root" -maxdepth 1 -type f -name '*.spec' | sort)
[[ ${#specs[@]} -eq 6 ]] || fail "expected six specs"

for spec in "${specs[@]}"; do
    rpmspec -P "$spec" >/dev/null
    name=$(rpmspec -q --qf '%{name}\n' "$spec")
    [[ $name != *-minimal-* && $name != *-optimal-* ]] || fail "legacy profile name: $name"
done

core="$root/nabu-core-meta.spec"
grep -Fq 'Requires:       (senemos-nabu-kernel-alpha or senemos-nabu-kernel or senemos-nabu-kernel-mainline-alpha or senemos-nabu-kernel-lts)' "$core" || fail "kernel OR requirement"
grep -Fq 'Recommends:     senemos-nabu-kernel-alpha' "$core" || fail "alpha recommendation"
for old in nabu-core-stable-meta nabu-core-alpha-meta nabu-core-unstable-meta nabu-core-base nabu-meta; do
    grep -Eq "^Obsoletes:[[:space:]]+$old" "$core" || fail "missing CORE transition for $old"
done

for spec in "$root"/*-nabu-meta.spec; do
    grep -Fq 'Requires:       nabu-core-meta >= 2.0.0' "$spec" || fail "missing CORE dependency in $spec"
    grep -Fq 'Requires:       glibc-all-langpacks' "$spec" || fail "missing hard locale dependency in $spec"
    grep -Fq 'Requires:       nabu-language-support' "$spec" || fail "missing Nabu locale dependency in $spec"
    grep -Eq '^Recommends:' "$spec" && fail "weak dependency in release manifest $spec"
done

for spec in "$root"/*.spec; do
    if grep -E '^Obsoletes:' "$spec" | grep -Ev '^Obsoletes:[[:space:]]+nabu-' >/dev/null; then
        fail "non-Nabu package obsoleted by $spec"
    fi
done

grep -Rq '^Name:.*minimal\|^Name:.*optimal' "$root" && fail "minimal/optimal package remains"
printf 'PASS: unified two-meta release policy\n'

