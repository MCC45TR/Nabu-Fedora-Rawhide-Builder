#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
! grep -Eq '^Provides:[[:space:]]+kernel-uname-r' \
    "$root/senemos-nabu-kernel-mainline-unstable.spec"
grep -Fq 'KALLSYMS_EXTRA_PASS=1' \
    "$root/senemos-nabu-kernel-mainline-unstable.spec"
version=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' \
    "$root/senemos-nabu-kernel-mainline-unstable.spec")
work=$(mktemp -d)
cleanup() {
	if [[ ${KEEP_TEST_WORK:-0} == 1 ]]; then
		printf 'Preserved test worktree: %s\n' "$work" >&2
		return
	fi
    find "$work" -depth -delete 2>/dev/null || :
}
trap cleanup EXIT

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
# Match RPM %%autosetup -S git_am, including its reject-mode context rules.
git -C "$work/linux-$version" am --reject -q "$root"/patches/*.patch
patch_count=$(find "$root/patches" -maxdepth 1 -type f -name '*.patch' | wc -l)
test "$(git -C "$work/linux-$version" rev-list --count HEAD)" \
    -eq "$((patch_count + 1))"
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
	'CONFIG_I2C_QCOM_CCI=y' \
	'CONFIG_SM_CAMCC_8150=y' \
	'CONFIG_SM_VIDEOCC_8150=y' \
	'CONFIG_DMABUF_HEAPS_SYSTEM=y' \
	'CONFIG_DMABUF_HEAPS_CMA=y' \
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
    'CONFIG_PSI=y' \
    'CONFIG_LRU_GEN=y' \
    'CONFIG_LRU_GEN_ENABLED=y' \
    'CONFIG_LRU_GEN_WALKS_MMU=y' \
    'CONFIG_SND_SEQUENCER=m' \
    'CONFIG_INTERCONNECT_QCOM_OSM_L3=y' \
    'CONFIG_BT_RFCOMM=m' \
    'CONFIG_BT_RFCOMM_TTY=y' \
    'CONFIG_BT_BNEP=m' \
    'CONFIG_BT_BNEP_MC_FILTER=y' \
    'CONFIG_BT_BNEP_PROTO_FILTER=y' \
    'CONFIG_HIDRAW=y' \
    'CONFIG_UHID=y' \
    'CONFIG_SCSI_UFS_QCOM=y' \
    'CONFIG_TOUCHSCREEN_NT36523_SPI=m' \
    'CONFIG_ATH10K_SNOC=m' \
    'CONFIG_USB_DWC3_DUAL_ROLE=y' \
    'CONFIG_USB_ACM=y' \
    'CONFIG_MODULE_SIG=y' \
    'CONFIG_GPIO_SHARED_PROXY=y' \
    'CONFIG_SECURITY_SELINUX=y' \
    'CONFIG_DEFAULT_SECURITY_SELINUX=y' \
    'CONFIG_QCOM_SSC_CCT=m' \
    'CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,selinux,ipe,bpf"'; do
    if ! grep -Fxq "$setting" "$config_dir/.config"; then
        printf 'ERROR: final Nabu config is missing required setting: %s\n' \
            "$setting" >&2
        exit 1
    fi
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
grep -Fq 'const struct firmware_version *min_fw;' \
    "$work/linux-$version/drivers/media/platform/qcom/venus/core.h"
grep -Fq 'if (!core->res->min_fw)' \
    "$work/linux-$version/drivers/media/platform/qcom/venus/hfi_msgs.c"
grep -A50 -F 'static int camss_subdev_notifier_bound' \
    "$work/linux-$version/drivers/media/platform/qcom/camss/camss.c" \
    | grep -Fq 'v4l2_device_register_subdev_nodes'
grep -Fq '.compatible = "ovti,ov13b10"' \
    "$work/linux-$version/drivers/media/i2c/ov13b10.c"
grep -Fq 'MODULE_DEVICE_TABLE(of, ov13b10_of_match);' \
    "$work/linux-$version/drivers/media/i2c/ov13b10.c"
grep -A10 -F '&q6afedai {' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts" \
    | grep -Fq 'qcom,tdm-data-delay = <1>;'
grep -Fq 'u8 wm, dma_addr_t addr,' \
    "$work/linux-$version/drivers/media/platform/qcom/camss/camss-vfe.h"
grep -A4 -F 'case CAMSS_845:' \
    "$work/linux-$version/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c" \
    | grep -Fq 'case CAMSS_8150:'
# Nabu has one physical sensor placement. Keep its board matrix in the DT and
# require FastRPC to expose it through the kernel ABI for every desktop stack.
test "$(grep -c 'mount-matrix = "-1", "0", "0",' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts")" -eq 2
test "$(grep -c '"0", "-1", "0",' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts")" -eq 2
test "$(grep -c '"0", "0", "1";' \
    "$work/linux-$version/arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts")" -eq 2
grep -Fq 'static DEVICE_ATTR_RO(mount_matrix);' \
    "$work/linux-$version/drivers/misc/fastrpc.c"
grep -Fq 'fdev->miscdev.groups = fastrpc_sensor_groups;' \
    "$work/linux-$version/drivers/misc/fastrpc.c"
recover_line=$(grep -n -F 'gpu->funcs->recover(gpu);' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gpu.c" | cut -d: -f1)
retire_line=$(grep -n -F 'retire_submits(gpu);' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gpu.c" | head -n1 | cut -d: -f1)
test "$recover_line" -lt "$retire_line"
grep -A18 -F 'msm_gem_vm_bo_validate' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gem_vma.c" \
    | grep -Fq 'drm_gpuvm_bo_evict(vm_bo, false);'
grep -Fq 'smp_load_acquire(&ctx->vm)' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_drv.c"
grep -Fq 'smp_store_release(&ctx->vm, vm)' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_drv.c"
grep -A30 -F 'static void a6xx_set_pagetable' \
    "$work/linux-$version/drivers/gpu/drm/msm/adreno/a6xx_gpu.c" \
    | grep -Fq 'CP_EVENT_WRITE_0_EVENT(PC_CCU_INVALIDATE_DEPTH)'
grep -A36 -F 'static void a6xx_set_pagetable' \
    "$work/linux-$version/drivers/gpu/drm/msm/adreno/a6xx_gpu.c" \
    | grep -Fq 'CP_EVENT_WRITE_0_EVENT(PC_CCU_INVALIDATE_COLOR)'
grep -A18 -F 'static int nabu_keyboard_suspend' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c" \
    | grep -Fq '!device_may_wakeup(dev) || !connected'
grep -Fq 'keyboard->computer_mode = connected;' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
grep -Fq 'controller IRQ presence inference disabled' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
grep -Fq 'nabu_keyboard_publish_state(keyboard, false, true);' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
! grep -Fq 'gpiod_get_value_cansleep(keyboard->detect);' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
! grep -Fq 'mod_delayed_work(system_percpu_wq, &keyboard->detect_work,' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
! grep -Fq 'connected = !keyboard->connected;' \
    "$work/linux-$version/drivers/input/misc/xiaomi-nabu-keyboard.c"
grep -Fq 'static __poll_t iris_poll' \
    "$work/linux-$version/drivers/media/platform/qcom/iris/iris_vidc.c"
grep -A45 -F 'static __poll_t iris_poll' \
    "$work/linux-$version/drivers/media/platform/qcom/iris/iris_vidc.c" \
    | grep -Fq 'IRIS_INST_INPUT_STREAMING'
grep -Fq '.poll                           = iris_poll,' \
    "$work/linux-$version/drivers/media/platform/qcom/iris/iris_vidc.c"
slim_ngd="$work/linux-$version/drivers/slimbus/qcom-ngd-ctrl.c"
grep -Fq 'struct delayed_work ngd_up_work;' "$slim_ngd"
grep -Fq 'mod_delayed_work(system_dfl_wq, &ctrl->ngd_up_work,' "$slim_ngd"
! grep -Fq 'mod_delayed_work(system_wq, &ctrl->ngd_up_work,' "$slim_ngd"
grep -Fq 'cancel_delayed_work_sync(&ctrl->ngd_up_work);' "$slim_ngd"
test "$(grep -c 'mod_delayed_work(system_percpu_wq, &.*status_changed_work' \
    "$work/linux-$version/drivers/power/supply/ln8000_charger.c")" -eq 4
grep -Fq 'queue_delayed_work(system_percpu_wq, &info->charge_work,' \
    "$work/linux-$version/drivers/power/supply/ln8000_charger.c"
test "$(grep -c 'CLK_SET_RATE_PARENT | CLK_IGNORE_UNUSED' \
    "$work/linux-$version/drivers/clk/qcom/dispcc-sm8250.c")" -eq 6
grep -Fq 'return dev_err_probe(&pdev->dev, -EPROBE_DEFER,' \
    "$work/linux-$version/drivers/gpu/drm/msm/dsi/dsi.c"
grep -Fq 'alloc_ordered_workqueue("nvt_esd_check_wq", WQ_MEM_RECLAIM);' \
    "$work/linux-$version/drivers/input/touchscreen/nt36523/nt36xxx.c"
# Trigger STOP must preserve the active ASM setup state so the next prepare
# closes it, but it must not wait for the optional rendered-EOS event. Nabu's
# ADSP does not reliably emit that event and the extra wait stalls stream close.
q6asm_dai="$work/linux-$version/sound/soc/qcom/qdsp6/q6asm-dai.c"
test "$(grep -c 'prtd->state = Q6ASM_STREAM_STOPPED;' "$q6asm_dai")" -eq 1
! grep -Fq 'eos_done' "$q6asm_dai"
grep -A4 -F 'case SNDRV_PCM_TRIGGER_STOP:' "$q6asm_dai" \
    | grep -Fq 'CMD_EOS'
resv_line=$(grep -n -F 'obj->resv = r_obj->resv;' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gem.c" | cut -d: -f1)
gem_init_line=$(grep -n -F 'ret = drm_gem_object_init(dev, obj, size);' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gem.c" | cut -d: -f1)
bookkeeping_line=$(grep -n -F 'ret = msm_gem_init_bookkeeping(obj);' \
    "$work/linux-$version/drivers/gpu/drm/msm/msm_gem.c" | head -n1 | cut -d: -f1)
test "$resv_line" -lt "$gem_init_line"
test "$gem_init_line" -lt "$bookkeeping_line"
! grep -Fxq 'CONFIG_DEBUG_INFO=y' "$config_dir/.config"
! grep -Eq '^CONFIG_DEBUG_INFO_BTF(=y|=m)$' "$config_dir/.config"
module_count=$(grep -c '=m$' "$config_dir/.config")
test "$module_count" -lt 450

printf 'PASS: %s checksum-locked Nabu patches apply to Linux %s; %s modules enabled\n' \
    "$patch_count" "$version" "$module_count"
