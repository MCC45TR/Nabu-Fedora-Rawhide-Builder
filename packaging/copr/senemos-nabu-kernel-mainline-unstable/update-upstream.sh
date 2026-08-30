#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sums_url=https://cdn.kernel.org/pub/linux/kernel/v7.x/sha256sums.asc
spec=$root/senemos-nabu-kernel-mainline-unstable.spec
current=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
sums=$(mktemp)
saved_spec=$(mktemp)
saved_sum=$(mktemp)
cleanup() {
    rm -f -- "$sums" "$saved_spec" "$saved_sum"
}
restore() {
    cp "$saved_spec" "$spec"
    cp "$saved_sum" "$root/upstream.sha256"
    cleanup
}
trap restore ERR INT TERM

curl -L --fail --retry 3 --output "$sums" "$sums_url"
archive=$(sed -nE \
    's/^[0-9a-f]{64}  (linux-7[.]2([.][0-9]+)?[.]tar[.]xz)$/\1/p' \
    "$sums" | sort -V | tail -n1)
[[ -n $archive ]]
latest=${archive#linux-}
latest=${latest%.tar.xz}

if [[ $latest == "$current" ]]; then
    printf 'Linux %s is already current.\n' "$current"
    trap - ERR INT TERM
    cleanup
    exit 0
fi

cp "$spec" "$saved_spec"
cp "$root/upstream.sha256" "$saved_sum"
grep -E "^[0-9a-f]{64}  ${archive//./[.]}$" "$sums" >"$root/upstream.sha256"
sed -i -E "s/^Version:[[:space:]]+.*/Version:        $latest/" "$spec"

"$root/test-patch-series.sh"
trap - ERR INT TERM
cleanup
printf 'Accepted Linux %s after the complete Nabu patch gate.\n' "$latest"
