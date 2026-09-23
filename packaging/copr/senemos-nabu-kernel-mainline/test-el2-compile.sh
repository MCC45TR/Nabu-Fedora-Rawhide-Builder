#!/usr/bin/bash
# Build-host only. Reuse the production source/config; do not patch hardware.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source=${1:?usage: test-el2-compile.sh KERNEL_SOURCE OUTPUT PRODUCTION_CONFIG}
output=${2:?missing separate output directory}
baseline=${3:?missing production .config}
mkdir -p "$output"
output=$(cd -- "$output" && pwd)
install -m0644 "$baseline" "$output/.config"
KCONFIG_CONFIG="$output/.config" "$source/scripts/kconfig/merge_config.sh" -m -r \
    "$output/.config" "$root/nabu-el2-experimental.config"
make -s -C "$source" O="$output" ARCH=arm64 LLVM=1 olddefconfig
for setting in CONFIG_KVM=y CONFIG_VIRTUALIZATION=y CONFIG_ARM_GIC_V3=y \
    CONFIG_ARM_ARCH_TIMER=y CONFIG_ARM_PSCI_FW=y CONFIG_ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT=y; do
    grep -Fx "$setting" "$output/.config"
done
make -C "$source" O="$output" ARCH=arm64 LLVM=1 -j8 \
    arch/arm64/kvm/ qcom/sm8150-xiaomi-nabu-iris-camera.dtb
python3 "$root/test-el2-dtb.py" "$output/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris-camera.dtb"
llvm-readobj --file-headers "$output/arch/arm64/kvm/hyp/nvhe/kvm_nvhe.o" | grep -F 'Arch: aarch64'
printf 'PASS: upstream KVM host/VHE/nVHE object gate and compiled Nabu DTB; not a firmware or guest test\n'
