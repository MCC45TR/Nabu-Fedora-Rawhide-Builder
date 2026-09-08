#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
releases_url=https://www.kernel.org/releases.json
spec=$root/senemos-nabu-kernel-mainline.spec
current=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
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
read -r latest source_url < <(python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    releases = json.load(stream)["releases"]
stable = [item for item in releases if item["moniker"] == "stable"]
selected = max(stable, key=lambda item: tuple(map(int, item["version"].split("."))))
print(selected["version"], selected["source"])
' "$metadata")
[[ $latest =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]
[[ $source_url == https://cdn.kernel.org/pub/linux/kernel/v*.x/linux-$latest.tar.xz ]]

if [[ $latest == "$current" ]]; then
    printf 'Linux %s is already the current stable release.\n' "$current"
    exit 0
fi

cp "$spec" "$saved_spec"
cp "$root/upstream.sha256" "$saved_sum"
trap restore ERR INT TERM

archive_name=linux-$latest.tar.xz
curl -L --fail --retry 3 --output "$archive" "$source_url"
archive_hash=$(sha256sum "$archive" | cut -d' ' -f1)
printf '%s  %s\n' "$archive_hash" "$archive_name" > "$root/upstream.sha256"
sed -i -E "s/^Version:[[:space:]]+.*/Version:        $latest/" "$spec"

TMPDIR=${TMPDIR:-/tmp} "$root/test-patch-series.sh"
trap - ERR INT TERM
printf 'Accepted Linux %s after the complete Nabu stable patch gate.\n' "$latest"
