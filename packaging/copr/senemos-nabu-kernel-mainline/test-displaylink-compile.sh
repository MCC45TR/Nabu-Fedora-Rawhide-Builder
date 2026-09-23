#!/usr/bin/bash
# Source/compile gate, not a dock or load test. Run in the kernel toolchain.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source=${1:?usage: test-displaylink-compile.sh KERNEL_SOURCE OUTPUT EVDI_SOURCE}
output=${2:?missing separate output directory}
evdi=${3:?missing extracted EVDI source}
mkdir -p "$output"
output=$(cd -- "$output" && pwd)
make -s -C "$source" O="$output" ARCH=arm64 LLVM=1 defconfig
KCONFIG_CONFIG="$output/.config" "$source/scripts/kconfig/merge_config.sh" -m -r \
    "$output/.config" "$source/senemos/configs/nabu-minimal.config"
"$source/senemos/configs/prune-nabu-config.sh" "$output/.config"
KCONFIG_CONFIG="$output/.config" "$source/scripts/kconfig/merge_config.sh" -m -r \
    "$output/.config" "$source/senemos/configs/nabu-security.config" \
    "$source/senemos/configs/nabu-rng.config" "$root/nabu-displaylink.config"
make -s -C "$source" O="$output" ARCH=arm64 LLVM=1 olddefconfig
grep -Fx 'CONFIG_DRM_UDL=m' "$output/.config"
make -s -C "$source" O="$output" ARCH=arm64 LLVM=1 -j8 modules_prepare
make -C "$source" O="$output" ARCH=arm64 LLVM=1 -j8 \
    M="$evdi/module" evdi.o
make -C "$source" O="$output" ARCH=arm64 LLVM=1 -j8 \
    drivers/gpu/drm/udl/udl.o
llvm-readobj --file-headers "$evdi/module/evdi.o" \
    | grep -F 'Arch: aarch64'
printf 'PASS: EVDI and UDL arm64 objects; full link/signature/depmod requires RPM build\n'
