#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stable_version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' \
    "$root/senemos-nabu-kernel-mainline.spec")
mainline_version=$(sed -nE \
    's/^%global upstream_version[[:space:]]+([^[:space:]]+).*/\1/p' \
    "$root/../senemos-nabu-kernel-mainline-unstable/senemos-nabu-kernel-mainline-unstable.spec")
[[ $stable_version =~ ^7[.]2[.][0-9]+$ ]]
old_version=7.2.$(( ${stable_version##*.} - 1 ))
fixture=$(mktemp)
trap 'rm -f -- "$fixture"' EXIT
jq -n --arg stable "$stable_version" --arg older "$old_version" \
    --arg mainline "$mainline_version" '
    {releases: [
        {moniker: "stable", version: "7.1.20", source: "unused"},
        {moniker: "stable", version: $older, source: "unused"},
        {moniker: "stable", version: $stable,
         source: ("https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-" + $stable + ".tar.xz")},
        {moniker: "mainline", version: $mainline, source: "unused"}
    ]}
' > "$fixture"
metadata=file://$fixture
stable=$(NABU_RELEASES_URL="$metadata" "$root/update-upstream.sh")
unstable=$(NABU_RELEASES_URL="$metadata" \
    "$root/../senemos-nabu-kernel-mainline-unstable/update-upstream.sh")
[[ $stable == "Linux $stable_version is already the current 7.2.x stable release." ]]
[[ $unstable == "Linux $mainline_version is already the current mainline release." ]]
