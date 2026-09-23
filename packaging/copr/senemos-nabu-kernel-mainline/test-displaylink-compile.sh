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
# Regression: RPM exports userspace CFLAGS and EVDI adds them to ccflags-y.
# Poison the environment deliberately: the command-line reset must keep these
# out while Kbuild retains the target kernel's own hardening flags.
CFLAGS='-specs=/nonexistent/nabu-userspace-gcc.specs -DNABU_CFLAGS_LEAK_SENTINEL' \
make -C "$source" O="$output" ARCH=arm64 LLVM=1 CFLAGS= -j8 \
    M="$evdi/module" evdi.o
if grep -Fq 'NABU_CFLAGS_LEAK_SENTINEL' "$evdi/module/.evdi_platform_drv.o.cmd"; then
    echo 'FAIL: userspace RPM CFLAGS leaked into EVDI' >&2
    exit 1
fi
make -C "$source" O="$output" ARCH=arm64 LLVM=1 -j8 \
    drivers/gpu/drm/udl/udl.o
llvm-readobj --file-headers "$evdi/module/evdi.o" \
    | grep -F 'Arch: aarch64'
printf 'PASS: EVDI and UDL arm64 objects; full link/signature/depmod requires RPM build\n'
