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
Source4:        91-nabu-mainline-unstable-late-xhci.conf
Source5:        nabu-build-stamp
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
Patch0031:      0031-media-qcom-update-Venus-close-helper-for-Linux-7.2.patch

BuildRequires:  bc
BuildRequires:  bison
BuildRequires:  clang
BuildRequires:  dwarves
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
Provides:       kernel-uname-r(%{uname_r})

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
cp senemos/configs/fedora-rawhide-aarch64.config .config
KCONFIG_CONFIG=.config scripts/kconfig/merge_config.sh -m -r \
    .config senemos/configs/nabu-minimal.config
# Linux 7.2's host resolve_btfids sources do not build against Rawhide's newer
# AArch64 UAPI headers. BTF is not required by the Nabu runtime payload.
scripts/config --disable DEBUG_INFO_BTF --disable DEBUG_INFO_BTF_MODULES
make ARCH=arm64 LLVM=1 olddefconfig
test "$(make -s ARCH=arm64 LLVM=1 kernelrelease)" = '%{uname_r}'
make ARCH=arm64 LLVM=1 %{?_smp_mflags} Image \
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
    zstd -q -T0 -19 --rm "$module"
done < <(find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
    -type f -name '*.ko' -print0)
/usr/sbin/depmod -b %{buildroot} -m %{_prefix}/lib/modules %{uname_r}

install -Dm0644 %{SOURCE3} \
    %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/91-nabu-mainline-unstable-omit-early-xhci.conf
install -Dm0644 %{SOURCE4} \
    %{buildroot}%{_prefix}/lib/modules-load.d/91-nabu-mainline-unstable-late-xhci.conf
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
grep -Fxq 'xhci_plat_hcd' \
    %{buildroot}%{_prefix}/lib/modules-load.d/91-nabu-mainline-unstable-late-xhci.conf
grep -Fxq 'cdc_acm' \
    %{buildroot}%{_prefix}/lib/modules-load.d/91-nabu-mainline-unstable-late-xhci.conf
grep -Fxq 'CONFIG_VIDEO_QCOM_IRIS=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_VIDEO_QCOM_CAMSS=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq 'CONFIG_VIDEO_CN3927=m' %{buildroot}/boot/config-%{uname_r}
grep -Fxq '# CONFIG_DEBUG_INFO_BTF is not set' %{buildroot}/boot/config-%{uname_r}
for module in qcom-iris qcom-camss i2c-qcom-cci cn3927 ov13b10 ov8856; do
    find %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel \
        -type f -name "$module.ko.zst" -print -quit | grep -q .
done

%posttrans
install -d -m0755 /var/lib/nabu-kernel-maintenance/pending.d
temporary=$(mktemp /var/lib/nabu-kernel-maintenance/pending.d/.mainline-unstable.XXXXXX)
printf '%%s\n' '%{uname_r}' > "$temporary"
chmod 0644 "$temporary"
mv -f "$temporary" /var/lib/nabu-kernel-maintenance/pending.d/mainline-unstable

%postun
if [ "$1" -eq 0 ]; then
    /usr/sbin/depmod -a || :
fi

%files
%{_prefix}/lib/dracut/dracut.conf.d/91-nabu-mainline-unstable-omit-early-xhci.conf
%{_prefix}/lib/modules-load.d/91-nabu-mainline-unstable-late-xhci.conf
/boot/vmlinuz-%{uname_r}
/boot/System.map-%{uname_r}
/boot/config-%{uname_r}
%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu-iris-camera.dtb
%{_prefix}/lib/modules/%{uname_r}/modules.*
%{_prefix}/lib/modules/%{uname_r}/kernel/
%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%changelog
* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 7.2.2-%{nabu_build_stamp}.unstable
- Port the ChengFangming/CFM880 Nabu camera and Iris/Venus work to Linux 7.2.2.
- Ship the combined Iris-camera DTB as this unstable kernel family's canonical Nabu DTB.
- Disable optional BTF generation to keep Linux 7.2 build tools compatible with Rawhide headers.
- Pin kernel module installation to Fedora's /usr/lib/modules hierarchy.
- Build official Linux 7.2.y in COPR and apply the checksum-locked Nabu series.
- Isolate RPM, ABI, maintenance queue and SENEMOS7U boot-family ownership.
