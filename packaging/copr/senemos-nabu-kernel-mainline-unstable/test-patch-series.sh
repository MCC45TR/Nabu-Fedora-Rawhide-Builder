#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
! grep -Eq '^Provides:[[:space:]]+kernel-uname-r' \
    "$root/senemos-nabu-kernel-mainline-unstable.spec"
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
test "$(git -C "$work/linux-$version" rev-list --count HEAD)" -eq 78
grep -Fxq 'CONFIG_LOCALVERSION="-nabu-senemos-mainline-unstable"' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_VIDEO_QCOM_IRIS=m' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_VIDEO_QCOM_CAMSS=m' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
test -s "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris-camera.dts"
grep -Fxq 'CONFIG_USB_DWC3_DUAL_ROLE=y' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_REGULATOR_QCOM_USB_VBUS=y' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_REGULATOR_QCOM_REFGEN=y' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
grep -Fxq 'CONFIG_MODULE_SIG=y' \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"

config_dir="$work/config"
make -C "$work/linux-$version" O="$config_dir" ARCH=arm64 HOSTCC=gcc defconfig
KCONFIG_CONFIG="$config_dir/.config" \
    "$work/linux-$version/scripts/kconfig/merge_config.sh" -m -r \
    "$config_dir/.config" \
    "$work/linux-$version/senemos/configs/nabu-minimal.config"
"$work/linux-$version/senemos/configs/prune-nabu-config.sh" \
    "$config_dir/.config"
make -C "$work/linux-$version" O="$config_dir" ARCH=arm64 HOSTCC=gcc olddefconfig
make -s -C "$work/linux-$version" O="$config_dir" \
    ARCH=arm64 HOSTCC=gcc syncconfig
rm -f "$config_dir/include/config/kernel.release"
kernel_release=$(LOCALVERSION= make -s -C "$work/linux-$version" O="$config_dir" \
    ARCH=arm64 HOSTCC=gcc kernelrelease)
if [[ $kernel_release != "$version-nabu-senemos-mainline-unstable" ]]; then
    grep '^CONFIG_LOCALVERSION' "$config_dir/.config" >&2 || true
    printf 'ERROR: unexpected kernel release: %s\n' "$kernel_release" >&2
    exit 1
fi

for setting in \
    'CONFIG_VIDEO_QCOM_IRIS=m' \
    'CONFIG_VIDEO_QCOM_CAMSS=m' \
    'CONFIG_I2C_QCOM_CCI=m' \
    'CONFIG_VIDEO_CN3927=m' \
    'CONFIG_VIDEO_OV13B10=m' \
    'CONFIG_VIDEO_OV8856=m' \
    'CONFIG_DRM_MSM=y' \
    'CONFIG_REGULATOR_QCOM_REFGEN=y' \
    'CONFIG_NF_TABLES=m' \
    'CONFIG_NFT_CT=m' \
    'CONFIG_NFT_REJECT_INET=m' \
    'CONFIG_ZRAM=m' \
    'CONFIG_ZRAM_DEF_COMP_ZSTD=y' \
    'CONFIG_SCSI_UFS_QCOM=y' \
    'CONFIG_TOUCHSCREEN_NT36523_SPI=m' \
    'CONFIG_ATH10K_SNOC=m' \
    'CONFIG_USB_DWC3_DUAL_ROLE=y' \
    'CONFIG_USB_ACM=y' \
    'CONFIG_MODULE_SIG=y' \
    'CONFIG_GPIO_SHARED_PROXY=y' \
    'CONFIG_SECURITY_SELINUX=y' \
    'CONFIG_DEFAULT_SECURITY_SELINUX=y' \
    'CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,selinux,ipe,bpf"'; do
    grep -Fxq "$setting" "$config_dir/.config"
done
grep -Fxq '# CONFIG_VIDEO_QCOM_VENUS is not set' "$config_dir/.config"
grep -Fxq '# CONFIG_RPMB is not set' "$config_dir/.config"
grep -Fq 'nvmem-cells = <&rtc_offset>;' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts"
! grep -Fq 'allow-set-time;' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts"
grep -Fq 'IRQF_NO_AUTOEN' \
    "$work/linux-$version/drivers/remoteproc/qcom_q6v5.c"
grep -Fq 'console-size = <0x200000>;' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris.dtsi"
grep -Fq 'ftrace-size = <0x200000>;' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts"
grep -Fq '#define FASTRPC_SDSP_IOVA_BASE' \
    "$work/linux-$version/drivers/misc/fastrpc.c"
grep -Fq 'dev->bus_dma_limit = iova_start + FASTRPC_SDSP_IOVA_SIZE - 1;' \
    "$work/linux-$version/drivers/misc/fastrpc.c"
grep -A10 -F '&pm8150b_adc {' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts" \
    | grep -Fq 'status = "okay";'
grep -Fq 'try-power-role = "sink";' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts"
grep -Fq 'Link each sensor as soon as it binds.' \
    "$work/linux-$version/drivers/media/platform/qcom/camss/camss.c"
grep -A50 -F 'static int camss_subdev_notifier_bound' \
    "$work/linux-$version/drivers/media/platform/qcom/camss/camss.c" \
    | grep -Fq 'v4l2_device_register_subdev_nodes'
! grep -Fxq 'CONFIG_DEBUG_INFO=y' "$config_dir/.config"
! grep -Eq '^CONFIG_DEBUG_INFO_BTF(=y|=m)$' "$config_dir/.config"
module_count=$(grep -c '=m$' "$config_dir/.config")
test "$module_count" -lt 450

printf 'PASS: 77 checksum-locked Nabu patches apply to Linux %s; %s modules enabled\n' \
    "$version" "$module_count"
