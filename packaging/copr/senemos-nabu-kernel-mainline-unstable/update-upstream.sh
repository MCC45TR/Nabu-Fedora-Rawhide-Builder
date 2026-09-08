#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
releases_url=https://www.kernel.org/releases.json
spec=$root/senemos-nabu-kernel-mainline-unstable.spec
current=$(sed -nE \
    's/^%global upstream_version[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
metadata=$(mktemp)
archive=$(mktemp)
saved_spec=$(mktemp)
saved_sum=$(mktemp)
cleanup() {
    rm -f -- "$metadata" "$archive" "$saved_spec" "$saved_sum"
}
restore() {
    local status=$?
    trap - ERR INT TERM EXIT
    if (( status == 0 )); then
        status=1
    fi
    if [[ -s $saved_spec && -s $saved_sum ]]; then
        cp "$saved_spec" "$spec"
        cp "$saved_sum" "$root/upstream.sha256"
    fi
    cleanup
    exit "$status"
}
trap cleanup EXIT

curl -L --fail --retry 3 --output "$metadata" "$releases_url"
latest=$(python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    releases = json.load(stream)["releases"]
print(next(item["version"] for item in releases
           if item["moniker"] == "mainline"))
' "$metadata")
[[ $latest =~ ^[0-9]+[.][0-9]+([.][0-9]+|[-]rc[0-9]+)?$ ]]

if [[ $latest == "$current" ]]; then
    printf 'Linux %s is already the current mainline release.\n' "$current"
    exit 0
fi

cp "$spec" "$saved_spec"
cp "$root/upstream.sha256" "$saved_sum"
trap restore ERR INT TERM

archive_name=linux-$latest.tar.gz
source_url=https://git.kernel.org/torvalds/t/$archive_name
curl -L --fail --retry 3 --output "$archive" "$source_url"
archive_hash=$(sha256sum "$archive" | cut -d' ' -f1)
printf '%s  %s\n' "$archive_hash" "$archive_name" > "$root/upstream.sha256"
rpm_version=${latest/-rc/~rc}
if [[ $latest =~ ^([0-9]+)[.]([0-9]+)-rc([0-9]+)$ ]]; then
    kernel_version=${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0-rc${BASH_REMATCH[3]}
elif [[ $latest =~ ^[0-9]+[.][0-9]+$ ]]; then
    kernel_version=$latest.0
else
    kernel_version=$latest
fi
sed -i -E \
    "s/^%global upstream_version[[:space:]]+.*/%global upstream_version $latest/" \
    "$spec"
sed -i -E \
    "s/^%global kernel_version[[:space:]]+.*/%global kernel_version $kernel_version/" \
    "$spec"
sed -i -E "s/^Version:[[:space:]]+.*/Version:        $rpm_version/" "$spec"

TMPDIR=${TMPDIR:-/tmp} "$root/test-patch-series.sh"
trap - ERR INT TERM
printf 'Accepted Linux %s after the complete Nabu patch gate.\n' "$latest"
