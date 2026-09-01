#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' \
    "$root/senemos-nabu-kernel-mainline-unstable.spec")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

curl -L --fail --retry 3 --output "$work/linux-$version.tar.xz" \
    "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$version.tar.xz"
(cd "$work" && sha256sum -c "$root/upstream.sha256")
tar -xf "$work/linux-$version.tar.xz" -C "$work"
git -C "$work/linux-$version" init -q
git -C "$work/linux-$version" config user.name 'SENEMOS patch gate'
git -C "$work/linux-$version" config user.email 'mcc45tr@gmail.com'
git -C "$work/linux-$version" add -A
git -C "$work/linux-$version" commit -qm "Linux $version"
(cd "$root/patches" && sha256sum -c ../patches.sha256)
git -C "$work/linux-$version" am "$root"/patches/*.patch
test "$(git -C "$work/linux-$version" rev-list --count HEAD)" -eq 31
grep -Fxq 'CONFIG_LOCALVERSION="-nabu-senemos-mainline-unstable"' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_VIDEO_QCOM_IRIS=m' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_VIDEO_QCOM_CAMSS=m' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
test -s "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris-camera.dts"
printf 'PASS: 30 checksum-locked Nabu patches apply to Linux %s\n' "$version"
