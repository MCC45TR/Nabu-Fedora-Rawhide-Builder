%global debug_package %{nil}
%global __strip /bin/true
%global nabu_build_stamp 0000000000
%global uname_r %{version}-nabu-senemos-mainline-unstable

Name:           senemos-nabu-kernel-mainline-unstable
Version:        7.2.2
Release:        %{nabu_build_stamp}.unstable%{?dist}
Summary:        Patch-layered Linux 7.2.y SENEMOS kernel for Xiaomi Pad 5
License:        GPL-2.0-only AND MIT
URL:            https://github.com/MCC45TR/nabu-linux-kernel
ExclusiveArch:  aarch64
Source0:        https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-%{version}.tar.xz
Source1:        upstream.sha256
Source2:        patches.sha256
Source3:        91-nabu-mainline-unstable-omit-early-xhci.conf
Source4:        nabu-mainline-unstable-late-xhci.service
Source5:        nabu-build-stamp
Source6:        90-nabu-mainline-unstable.preset
Patch0001:      0001-arm64-dts-qcom-add-Xiaomi-Pad-5-Nabu.patch
Patch0002:      0002-drm-panel-nt36523-add-Xiaomi-Nabu-CSOT-panel.patch
Patch0003:      0003-senemos-add-Fedora-Rawhide-arm64-build-profile.patch
Patch0004:      0004-drm-panel-port-Nabu-touch-synchronization-to-Linux-7.patch
Patch0005:      0005-qcom-nabu-port-platform-services-and-seamless-DFPS-c.patch
Patch0006:      0006-input-power-restore-Nabu-touch-and-fuel-gauge-driver.patch
Patch0007:      0007-drm-nabu-fix-seamless-refresh-and-live-touch-sync-on.patch
Patch0008:      0008-input-report-permanent-tablet-mode-on-Xiaomi-Nabu.patch
Patch0009:      0009-nabu-carry-90-Hz-touch-policy-and-defer-optional-XHC.patch
Patch0010:      0010-nabu-port-DT2W-stable-refresh-switching-and-charging.patch
Patch0011:      0011-nabu-quarantine-90-Hz-and-preserve-Night-Light-modes.patch
Patch0012:      0012-ASoC-qcom-port-Nabu-speaker-routing-and-stream-fixes.patch
Patch0013:      0013-power-supply-port-PM8150B-SMB5-charging-support-to-7.patch
Patch0014:      0014-arm64-dts-qcom-restore-SM8150-legacy-audio-topology.patch
Patch0015:      0015-input-drm-adapt-Nabu-touch-lifecycle-to-Linux-7.2.patch
Patch0016:      0016-senemos-align-Linux-7.2-ABI-and-build-identity.patch
Patch0017:      0017-senemos-complete-Linux-7.2-Nabu-hardware-port.patch
Patch0018:      0018-qcom-nabu-stabilize-Linux-7.2-hardware-bring-up.patch
Patch0019:      0019-usb-qcom-stabilize-Nabu-host-CDC-reconnects.patch
Patch0020:      0020-config-remove-release-kernel-self-tests.patch
Patch0021:      0021-config-drop-runtime-test-drivers-from-release-builds.patch
Patch0022:      0022-senemos-isolate-mainline-unstable-kernel-identity.patch
Patch0023:      0023-media-qcom-add-Xiaomi-Nabu-camera-support.patch
Patch0024:      0024-media-qcom-port-Nabu-Iris-VA-API-support-to-6.17.patch
Patch0025:      0025-kernel-overlay-speed-up-VP9-capture-for-FFmpeg.patch
Patch0026:      0026-kernel-overlay-harden-P010-and-external-module-build.patch
Patch0027:      0027-kernel-overlay-preserve-usable-legacy-VP9-output.patch
Patch0028:      0028-kernel-overlay-filter-hidden-VP9-superframes.patch
Patch0029:      0029-kernel-overlay-make-Nabu-Iris-device-tree-append-onl.patch
Patch0030:      0030-media-qcom-adapt-current-Nabu-Iris-overlay-to-Linux-.patch
Patch0031:      0031-arm64-nabu-enable-RTC-and-persistent-suspend-diagnos.patch
Patch0032:      0032-spi-geni-qcom-bound-timeout-recovery-state.patch
Patch0033:      0033-Input-nt36523-bound-retries-while-SPI-recovers.patch
Patch0034:      0034-Input-nt36523-bound-SPI-fault-recovery.patch
Patch0035:      0035-input-gate-NVT-gestures-during-suspend-preparation.patch
Patch0036:      0036-misc-fastrpc-harden-Nabu-SDSP-ownership-recovery.patch
Patch0037:      0037-wifi-ath10k-keep-crash-teardown-local-after-transpor.patch
Patch0038:      0038-wifi-ath10k-ignore-channel-less-survey-events.patch
Patch0039:      0039-Bluetooth-hci_qca-demote-setup-only-framing-discard.patch
Patch0040:      0040-arm64-dts-qcom-nabu-complete-WCN3990-supplies.patch
Patch0041:      0041-dt-bindings-sound-cs35l41-allow-verified-missing-PDN.patch
Patch0042:      0042-ASoC-cs35l41-bound-Nabu-power-down-recovery.patch
Patch0043:      0043-ASoC-cs35l41-defer-accepted-Nabu-PDN-timeout-logging.patch
Patch0044:      0044-ASoC-cs35l41-demote-accepted-Nabu-PDN-timeout.patch
Patch0045:      0045-arm64-dts-qcom-nabu-describe-CS35L41-supplies.patch
Patch0046:      0046-slimbus-qcom-ngd-make-duplicate-UP-work-idempotent.patch
Patch0047:      0047-input-add-explicit-mode-Nabu-keyboard-cover-support.patch
Patch0048:      0048-nabu-keep-keyboard-and-legacy-Iris-from-blocking-sus.patch
Patch0049:      0049-power-supply-integrate-protected-LN8000-charging-on-.patch
Patch0050:      0050-dt-bindings-power-ln8000-describe-unwired-input-NTC.patch
Patch0051:      0051-power-supply-ln8000-disable-unwired-Nabu-input-NTC.patch
Patch0052:      0052-power-supply-add-fail-safe-Nabu-thermal-charging-pol.patch
Patch0053:      0053-dt-bindings-power-supply-add-SMB5-thermal-policy-dat.patch
Patch0054:      0054-power-supply-align-Nabu-charging-policy-with-OEM-lim.patch
Patch0055:      0055-arm64-dts-qcom-nabu-add-OEM-derived-charging-policy.patch
Patch0056:      0056-dt-bindings-power-supply-describe-SMB5-connector-the.patch
Patch0057:      0057-power-supply-stop-Nabu-charging-on-connector-overhea.patch
Patch0058:      0058-power-supply-make-Nabu-charging-policy-fail-safe.patch
Patch0059:      0059-media-venus-restore-coexistence-with-Iris-on-Linux-7.patch
Patch0060:      0060-power-supply-adapt-Nabu-charging-to-Linux-7.2-APIs.patch
Patch0061:      0061-ASoC-cs35l41-include-property-API-for-PDN-policy.patch
Patch0062:      0062-dt-bindings-power-validate-SMB5-Nabu-policy-arrays.patch
Patch0063:      0063-usb-nabu-restore-dual-role-VBUS-operation-on-7.2.patch
Patch0064:      0064-senemos-add-staged-7.2.2-HIL-validation-plan.patch
Patch0065:      0065-senemos-prune-7.2.2-to-Nabu-hardware.patch
Patch0066:      0066-senemos-retain-module-signing-helper-in-Nabu-config.patch
Patch0067:      0067-arm64-dts-qcom-restore-Nabu-display-and-RTC-persiste.patch
Patch0068:      0068-senemos-retain-nftables-for-Fedora-firewalld.patch
Patch0069:      0069-senemos-restore-Fedora-zram-and-persistent-diagnosti.patch
Patch0070:      0070-misc-fastrpc-restore-SM8150-SDSP-IOVA-windows.patch
Patch0071:      0071-arm64-dts-qcom-fix-Nabu-charging-and-DRP-preference.patch
Patch0072:      0072-Input-nt36523-drop-obsolete-MediaTek-SPI-setup.patch
Patch0073:      0073-media-qcom-expose-CAMSS-sensors-as-each-one-binds.patch
Patch0074:      0074-remoteproc-qcom-q6v5-Make-handover-IRQ-one-shot.patch
Patch0075:      0075-senemos-keep-shared-GPIO-proxy-built-in-for-Nabu-aud.patch
Patch0076:      0076-arm64-dts-qcom-persist-Nabu-RTC-time-in-SDAM.patch
Patch0077:      0077-senemos-activate-SELinux-in-Nabu-LSM-stack.patch
Patch0078:      0078-senemos-classify-Nabu-SAR-separately-from-proximity.patch
Patch0079:      0079-iio-light-add-Qualcomm-SSC-color-temperature-endpoin.patch
Patch0080:      0080-senemos-enable-SSC-CCT-IIO-bridge-in-Nabu-profile.patch
Patch0081:      0081-iio-light-invalidate-stale-SSC-color-temperature.patch
Patch0082:      0082-media-qcom-stabilize-Nabu-camera-enumeration.patch
Patch0083:      0083-ASoC-qcom-restore-Nabu-TDM-framing-and-CAMSS-DMA-wi.patch
Patch0084:      0084-media-qcom-initialize-SM8150-CSI-PHY-lane-registers.patch
Patch0085:      0085-senemos-keep-SM8150-video-clock-built-in.patch
Patch0086:      0086-senemos-restore-Fedora-PSI-and-ALSA-sequencer.patch
Patch0087:      0087-senemos-retain-SM8150-OSM-L3-interconnect.patch
Patch0088:      0088-Bluetooth-restore-Fedora-RFCOMM-and-BNEP-protocols.patch
Patch0089:      0089-drm-msm-Recover-HW-before-retire-hung-submit.patch
Patch0090:      0090-drm-msm-remove-objects-from-evict-list-after-pinning.patch
Patch0091:      0091-drm-msm-backport-context-VM-and-GEM-lifetime-fixes.patch
Patch0092:      0092-drm-msm-a6xx-drain-CCU-before-TTBR0-switch.patch
Patch0093:      0093-senemos-enable-multigenerational-LRU.patch
Patch0094:      0094-drm-msm-align-A640-private-VMAs-to-64K.patch
Patch0095:      0095-ASoC-qcom-keep-q6asm-setup-state-through-trigger-stop.patch
Patch0096:      0096-HID-enable-UHID-for-Bluetooth-LE-input-devices.patch

BuildRequires:  bc
BuildRequires:  bison
BuildRequires:  clang
BuildRequires:  elfutils-libelf-devel
BuildRequires:  findutils
BuildRequires:  flex
BuildRequires:  git-core
BuildRequires:  kmod
BuildRequires:  lld
BuildRequires:  llvm
BuildRequires:  make
BuildRequires:  openssl
BuildRequires:  openssl-devel
BuildRequires:  perl
BuildRequires:  python3
BuildRequires:  rsync
BuildRequires:  systemd-rpm-macros
BuildRequires:  xz
BuildRequires:  zstd
Requires:       nabu-kernel-maintenance-api >= 5
Requires:       nabu-boot-integration >= 2.0.0-29.test
Requires(posttrans): coreutils
Requires(postun): kmod

%description
Official Linux 7.2.y plus a checksum-locked, ordered Xiaomi Pad 5 (nabu)
patch series. This is a separate unstable family with its own kernel ABI,
RPM ownership, maintenance queue and SENEMOS7U UKI namespace. It neither
obsoletes nor conflicts with the validated 6.17 or existing 7.2 alpha kernels.

%prep
[[ '%{nabu_build_stamp}' =~ ^[0-9]{10}$ ]]
grep -Fxq '%{nabu_build_stamp}' %{SOURCE5}
grep -Fq "linux-%{version}.tar.xz" %{SOURCE1}
(cd %{_sourcedir} && sha256sum -c %{SOURCE1})
(cd %{_sourcedir} && sha256sum -c %{SOURCE2})
%autosetup -n linux-%{version} -S git_am

%build
export KBUILD_BUILD_USER=mcc45tr
export KBUILD_BUILD_HOST=copr
export KBUILD_BUILD_TIMESTAMP='@0'
export KBUILD_BUILD_VERSION=1
export LOCALVERSION=
make ARCH=arm64 LLVM=1 defconfig
KCONFIG_CONFIG=.config scripts/kconfig/merge_config.sh -m -r \
    .config senemos/configs/nabu-minimal.config
# This package targets one SM8150 device. Avoid the Fedora general-purpose
# module set and the legacy Venus driver; Nabu uses Iris for video acceleration.
# Debug information and BTF are not part of the runtime-only unstable payload.
senemos/configs/prune-nabu-config.sh .config
make ARCH=arm64 LLVM=1 olddefconfig
# Refresh auto.conf after merging the Nabu identity fragment. Otherwise the
# immediately following release gate can retain defconfig's SCM suffix.
make -s ARCH=arm64 LLVM=1 syncconfig
rm -f include/config/kernel.release
test "$(make -s ARCH=arm64 LLVM=1 kernelrelease)" = '%{uname_r}'
make ARCH=arm64 LLVM=1 KALLSYMS_EXTRA_PASS=1 %{?_smp_mflags} Image \
    qcom/sm8150-xiaomi-nabu-iris-camera.dtb modules

%install
install -Dm0644 arch/arm64/boot/Image \
    %{buildroot}/boot/vmlinuz-%{uname_r}
install -Dm0644 System.map %{buildroot}/boot/System.map-%{uname_r}
install -Dm0644 .config %{buildroot}/boot/config-%{uname_r}
make ARCH=arm64 LLVM=1 modules_install \
    MODLIB=%{buildroot}%{_prefix}/lib/modules/%{uname_r} DEPMOD=/bin/true
rm -f %{buildroot}%{_prefix}/lib/modules/%{uname_r}/{build,source}
install -Dm0644 arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris-camera.dtb \
    %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
install -Dm0644 arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris-camera.dtb \
    %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu-iris-camera.dtb

while IFS= read -r -d '' module; do
    llvm-strip --strip-debug "$module"
    scripts/sign-file sha512 certs/signing_key.pem certs/signing_key.x509 "$module"
    zstd -q -T1 -10 --rm "$module"
done < <(find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
    -type f -name '*.ko' -print0)
/usr/sbin/depmod -b %{buildroot} -m %{_prefix}/lib/modules %{uname_r}

install -Dm0644 %{SOURCE3} \
    %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/91-nabu-mainline-unstable-omit-early-xhci.conf
install -Dm0644 %{SOURCE4} \
    %{buildroot}%{_unitdir}/nabu-mainline-unstable-late-xhci.service
install -Dm0644 %{SOURCE6} \
    %{buildroot}%{_presetdir}/90-nabu-mainline-unstable.preset
install -d -m0755 %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d
printf '%%s\n' '%{nabu_build_stamp}' > \
    %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%check
test -s %{buildroot}/boot/vmlinuz-%{uname_r}
test -s %{buildroot}/boot/System.map-%{uname_r}
test -s %{buildroot}/boot/config-%{uname_r}
test -s %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
test -s %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu-iris-camera.dtb
cmp -s \
    %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb \
    %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu-iris-camera.dtb
test -d %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel
test ! -e %{buildroot}%{_prefix}/lib/modules/%{uname_r}/build
test ! -e %{buildroot}%{_prefix}/lib/modules/%{uname_r}/source
find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
    -type f -name '*.ko.zst' -print -quit | grep -q .
! find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
    -type f -name '*.ko' -print -quit | grep -q .
grep -Fxq '%{nabu_build_stamp}' \
    %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}
grep -Fxq 'ConditionPathExists=!/etc/initrd-release' \
    %{buildroot}%{_unitdir}/nabu-mainline-unstable-late-xhci.service
grep -Fxq 'ExecStart=/usr/sbin/modprobe xhci_plat_hcd' \
    %{buildroot}%{_unitdir}/nabu-mainline-unstable-late-xhci.service
grep -Fxq 'enable nabu-mainline-unstable-late-xhci.service' \
    %{buildroot}%{_presetdir}/90-nabu-mainline-unstable.preset
grep -Fxq 'CONFIG_VIDEO_QCOM_IRIS=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_VIDEO_QCOM_VENUS is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_VIDEO_QCOM_CAMSS=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_I2C_QCOM_CCI=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_SM_CAMCC_8150=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_SM_VIDEOCC_8150=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_DMABUF_HEAPS_SYSTEM=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_DMABUF_HEAPS_CMA=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_VIDEO_CN3927=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_USB_DWC3_DUAL_ROLE=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_USB_GADGET=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_REGULATOR_QCOM_USB_VBUS=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_REGULATOR_QCOM_REFGEN=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_NF_TABLES=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_NFT_CT=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_NFT_REJECT_INET=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_ZRAM=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_ZRAM_DEF_COMP_ZSTD=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_RPMB is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_PHY_QCOM_USB_SNPS_FEMTO_V2=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_USB_ACM=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_MODULE_SIG=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_GPIO_SHARED_PROXY=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_SECURITY_SELINUX=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_DEFAULT_SECURITY_SELINUX=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_QCOM_SSC_CCT=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_PSI=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_SND_SEQUENCER=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_INTERCONNECT_QCOM_OSM_L3=y' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_BT_RFCOMM=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_BT_BNEP=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_UHID=y' %{buildroot}/boot/config-%{uname_r}
recover_line=$(grep -n -F 'gpu->funcs->recover(gpu);' \
    drivers/gpu/drm/msm/msm_gpu.c | cut -d: -f1)
retire_line=$(grep -n -F 'retire_submits(gpu);' \
    drivers/gpu/drm/msm/msm_gpu.c | head -n1 | cut -d: -f1)
test "$recover_line" -lt "$retire_line"
grep -A18 -F 'msm_gem_vm_bo_validate' drivers/gpu/drm/msm/msm_gem_vma.c \
    | grep -Fq 'drm_gpuvm_bo_evict(vm_bo, false);'
grep -Fxq 'CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,selinux,ipe,bpf"' \
    %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_ACPI is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_PCI is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_ARCH_MEDIATEK is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_ARCH_ROCKCHIP is not set' %{buildroot}/boot/config-%{uname_r}
grep -Fq 'vbus-supply = <&pm8150b_vbus>;' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts
grep -Fq 'nvmem-cells = <&rtc_offset>;' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts
! grep -Fq 'allow-set-time;' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts
grep -Fq 'IRQF_NO_AUTOEN' drivers/remoteproc/qcom_q6v5.c
grep -Fq 'console-size = <0x200000>;' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris.dtsi
grep -Fq 'ftrace-size = <0x200000>;' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts
grep -Fq '#define FASTRPC_SDSP_IOVA_BASE' drivers/misc/fastrpc.c
grep -Fq 'dev->bus_dma_limit = iova_start + FASTRPC_SDSP_IOVA_SIZE - 1;' \
    drivers/misc/fastrpc.c
! grep -Fq 'lionsemi,allow-direct-charging' \
    arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts
! grep -Eq '^CONFIG_DEBUG_INFO_BTF(=y|=m)$' %{buildroot}/boot/config-%{uname_r}
test "$(grep -c '=m$' %{buildroot}/boot/config-%{uname_r})" -lt 450
# Built-in platform prerequisites (I2C_QCOM_CCI, SM_CAMCC_8150 and DMA-BUF
# heaps) are validated through the config checks above.  Only loadable camera
# and sensor drivers have module payloads to verify here.
for module in qcom-iris qcom-camss cn3927 ov13b10 ov8856 qcom-ssc-cct; do
    find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
        -type f -name "$module.ko.zst" -print -quit | grep -q .
done

%post
%systemd_post nabu-mainline-unstable-late-xhci.service
marker=/var/lib/nabu-kernel-maintenance/late-xhci-service-migrated
if [ ! -e "$marker" ]; then
    /usr/bin/systemctl preset nabu-mainline-unstable-late-xhci.service >/dev/null 2>&1 || :
    install -d -m0755 /var/lib/nabu-kernel-maintenance
    : > "$marker"
fi

%posttrans
install -d -m0755 /var/lib/nabu-kernel-maintenance/pending.d
temporary=$(mktemp /var/lib/nabu-kernel-maintenance/pending.d/.mainline-unstable.XXXXXX)
printf '%%s\n' '%{uname_r}' > "$temporary"
chmod 0644 "$temporary"
mv -f "$temporary" /var/lib/nabu-kernel-maintenance/pending.d/mainline-unstable

%preun
%systemd_preun nabu-mainline-unstable-late-xhci.service

%postun
%systemd_postun_with_restart nabu-mainline-unstable-late-xhci.service
if [ "$1" -eq 0 ]; then
    /usr/sbin/depmod -a || :
fi

%files
%{_prefix}/lib/dracut/dracut.conf.d/91-nabu-mainline-unstable-omit-early-xhci.conf
%{_unitdir}/nabu-mainline-unstable-late-xhci.service
%{_presetdir}/90-nabu-mainline-unstable.preset
/boot/vmlinuz-%{uname_r}
/boot/System.map-%{uname_r}
/boot/config-%{uname_r}
%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu-iris-camera.dtb
%{_prefix}/lib/modules/%{uname_r}/modules.*
%{_prefix}/lib/modules/%{uname_r}/kernel/
%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%changelog
* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Enable UHID so BlueZ can expose Bluetooth LE HID/HOGP mice and keyboards.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Align A640 kernel-managed GPU VMAs to 64K after a decoded CCU resolve fault
  showed hardware access to the aligned page below a 4K-aligned UBWC buffer.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Backport the complete upstream DRM/MSM context VM synchronization series.
- Publish GEM objects only after reservation and VM bookkeeping are valid.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Stop repeatedly validating pinned DRM/MSM objects on a growing evict list.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Recover Adreno hardware before retiring hung submits and releasing their BOs.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Restore the RFCOMM and BNEP protocols expected by standard BlueZ profiles.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Restore the OSM L3 interconnect provider required by SM8150 CPU frequency.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Restore Fedora PSI and the ALSA sequencer module removed by Nabu pruning.
- Load optional XHCI only after switch-root so initrd modules-load stays clean.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Keep the SM8150 video clock controller built in for Iris and camera probe.
- Restore Nabu's proven Quaternary TDM framing so speaker PCM writes reach ADSP.
- Preserve full CAMSS DMA addresses until each VFE backend programs hardware.
- Program the SM8150 CSI PHY lane table so Nabu cameras can deliver frames.
- Lock Nabu's static FastRPC accelerometer matrix into the release validation gate.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Make Nabu CCI, CAMCC and DMA heaps available before userspace and probe timeout.
- Add the missing OV13B10 Device Tree match so the rear camera can autoload.

* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Publish validated SSC color temperature through the standard IIO ABI.

* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Replace Fedora's general-purpose ARM64 module set with an Nabu-focused profile.
- Disable legacy Venus in favor of Iris and omit runtime-unneeded debug information.
- Use a faster module compression level for COPR test publications.
- Carry the reviewed 6.17 RTC, SPI, input, FastRPC, wireless, audio and charging fixes.
- Restore dual-role USB-C and PM8150B VBUS ownership for OTG HIL.
- Restore the built-in DSI REFGEN supply and permit PM8150 RTC time persistence.
- Let DNF replace this same-name kernel package instead of treating it as install-only.
- Retain the nftables surface required by Fedora firewalld.
- Restore Fedora zram, fix the ramoops console/ftrace split and omit unused RPMB.
- Restore Nabu's proven 34-bit SM8150 SDSP IOVA allocation windows.
- Enable the real PM8150B connector thermistor channel so SMB5 can probe.
- Prefer USB-C sink operation while retaining automatic dual-role OTG.
- Drop obsolete MediaTek-only setup from the Nabu NT36523 SPI driver.
- Expose each working CAMSS sensor even if another camera fails to probe.
- Keep direct LN8000 2:1 charging disabled until instrumented qualification.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Port the ChengFangming/CFM880 Nabu camera and Iris/Venus work to Linux 7.2.2.
- Ship the combined Iris-camera DTB as this unstable kernel family's canonical Nabu DTB.
- Disable optional BTF generation to keep Linux 7.2 build tools compatible with Rawhide headers.
- Pin kernel module installation to Fedora's /usr/lib/modules hierarchy.
- Build official Linux 7.2.y in COPR and apply the checksum-locked Nabu series.
- Isolate RPM, ABI, maintenance queue and SENEMOS7U boot-family ownership.
