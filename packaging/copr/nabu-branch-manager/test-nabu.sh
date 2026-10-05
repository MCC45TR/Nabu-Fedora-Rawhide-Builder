#!/usr/bin/bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$source_dir/nabu"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ $(meta_for_branch stable) == nabu-core-stable-meta ]] || fail stable
[[ $(meta_for_branch alpha) == nabu-core-alpha-meta ]] || fail alpha
[[ $(meta_for_branch unstable) == nabu-core-unstable-meta ]] || fail unstable
if meta_for_branch testing >/dev/null 2>&1; then
    fail 'unknown branch accepted'
fi

help=$(main --help)
grep -Fq 'nabu branch stable|alpha|unstable' <<<"$help" || fail help
brunch_help=$(main brunch help)
grep -Fq 'nabu branch stable|alpha|unstable' <<<"$brunch_help" || fail brunch
brucnh_help=$(main brucnh help)
grep -Fq 'nabu branch stable|alpha|unstable' <<<"$brucnh_help" || fail brucnh
if main branch testing >/dev/null 2>&1; then
    fail 'invalid branch command accepted'
fi

spec_dir="$source_dir/../nabu-core-meta"
for branch in stable alpha unstable; do
    spec="$spec_dir/nabu-core-$branch-meta.spec"
    [[ -s $spec ]] || fail "missing $spec"
    grep -Fq 'Provides:       nabu-core-branch' "$spec" || fail "$branch provider"
    for other in stable alpha unstable; do
        [[ $branch == "$other" ]] && continue
        grep -Fq "Conflicts:      nabu-core-$other-meta" "$spec" || \
            fail "$branch does not conflict with $other"
    done
done

printf 'PASS: nabu branch manager static tests\n'
