#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
spec=$root/material-decoration.spec
old_commit=$(sed -nE 's/^%global upstream_commit ([0-9a-f]{40})$/\1/p' "$spec")
old_version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+)$/\1/p' "$spec")
[[ $old_commit =~ ^[0-9a-f]{40}$ && $old_version =~ ^[0-9]{8}\.[0-9]{6}$ ]] || {
    echo 'Invalid current Material Decoration source lock' >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'if [[ -n ${tmp:-} && -d $tmp ]]; then rm -rf -- "$tmp"; fi' EXIT
git clone --quiet --depth 1 --branch master \
    https://github.com/guiodic/material-decoration.git "$tmp/upstream"
new_commit=$(git -C "$tmp/upstream" rev-parse HEAD)
[[ $new_commit =~ ^[0-9a-f]{40}$ ]] || exit 1
if [[ $new_commit == "$old_commit" ]]; then
    echo 'Material Decoration upstream is unchanged.'
    exit 0
fi

new_version=$(TZ=UTC git -C "$tmp/upstream" show -s --format=%cd \
    --date=format-local:%Y%m%d.%H%M%S HEAD)
[[ $new_version =~ ^[0-9]{8}\.[0-9]{6}$ && $new_version > $old_version ]] || {
    echo "Non-monotonic upstream version $new_version (current $old_version); manual review required" >&2
    exit 1
}
short_commit=${new_commit:0:7}
archive="material-decoration-$new_commit.tar.gz"
curl --fail --location --retry 3 --output "$tmp/$archive" \
    "https://codeload.github.com/guiodic/material-decoration/tar.gz/$new_commit"
tar -tzf "$tmp/$archive" | sed -n '1p' | grep -Fx "material-decoration-$new_commit/" >/dev/null
hash=$(sha256sum "$tmp/$archive" | awk '{print $1}')
[[ $hash =~ ^[0-9a-f]{64}$ ]] || exit 1

sed -E \
    -e "s/^%global upstream_commit [0-9a-f]{40}$/%global upstream_commit $new_commit/" \
    -e "s/^Version:[[:space:]]+[^[:space:]]+$/Version:        $new_version/" \
    -e "s/^Release:[[:space:]]+[^[:space:]]+$/Release:        1.git$short_commit%{?dist}/" \
    "$spec" >"$tmp/spec"
awk -v entry="* $(date -u '+%a %b %d %Y') SENEMOS Project <mcc45tr@gmail.com> - $new_version-1.git$short_commit" \
    -v detail="- Update pinned upstream master to $new_commit." \
    '{ print; if ($0 == "%changelog") { print entry; print detail; print "" } }' \
    "$tmp/spec" >"$tmp/spec.with-changelog"
install -m0644 "$tmp/spec.with-changelog" "$spec"
printf '%s  %s\n' "$hash" "$archive" >"$root/upstream.sha256"

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    printf 'updated=true\nversion=%s\ncommit=%s\n' \
        "$new_version" "$new_commit" >>"$GITHUB_OUTPUT"
fi
echo "Pinned Material Decoration $new_version ($new_commit)."
