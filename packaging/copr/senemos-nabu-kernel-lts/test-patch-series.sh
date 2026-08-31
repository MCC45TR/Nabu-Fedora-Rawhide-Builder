#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' \
    "$root/senemos-nabu-kernel-lts.spec")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

curl -L --fail --retry 3 --output "$work/linux-$version.tar.xz" \
    "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$version.tar.xz"
(cd "$work" && sha256sum -c "$root/upstream.sha256")
tar -xf "$work/linux-$version.tar.xz" -C "$work"
git -C "$work/linux-$version" init -q
git -C "$work/linux-$version" config user.name 'SENEMOS patch gate'
git -C "$work/linux-$version" config user.email 'mcc45tr@gmail.com'
(cd "$root/patches" && sha256sum -c ../patches.sha256)

# Only index upstream paths touched by this series. Indexing the entire kernel
# tree is unnecessary for git-am and consumes much more memory in CI/COPR.
mapfile -t patch_paths < <(
    sed -nE 's#^diff --git a/([^ ]+) b/.*#\1#p' "$root"/patches/*.patch |
        sort -u
)
for path in "${patch_paths[@]}"; do
    if [[ -e $work/linux-$version/$path ]]; then
        git -C "$work/linux-$version" add -- "$path"
    fi
done
git -C "$work/linux-$version" commit -qm "Linux $version patch baseline"
git -C "$work/linux-$version" am "$root"/patches/*.patch
test "$(git -C "$work/linux-$version" rev-list --count HEAD)" -eq 25
grep -Fxq 'CONFIG_LOCALVERSION="-nabu-senemos-lts"' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
printf 'PASS: 24 checksum-locked Nabu patches apply to Linux %s\n' "$version"
