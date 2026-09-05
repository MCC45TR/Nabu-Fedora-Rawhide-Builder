%global debug_package %{nil}
%global legacy_meta_max 9999999999-99

Name:           nabu-core-meta
Version:        3.0.0
Release:        60%{?dist}
Summary:        Complete hardware and kernel policy for Xiaomi Pad 5
License:        MIT AND GPL-3.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-linux-copr.repo
Source1:        90-nabu-disable-cisco-openh264.repo
Source2:        nabu
Source3:        nabu.8
Source4:        nabu-kernel-maintenance
Source5:        nabu-kernel-maintenance.service
Source6:        nabu-kernel-maintenance.timer
Source7:        90-nabu-kernel-maintenance.preset
Source8:        kernel.conf
Source9:        nabu-system-integration-2.0.0.tar.zst
Source10:       nabu-flashlight-integration-1.0.0.tar.gz
Source11:       nabu-sar-service-0.2.1.tar.zst
Source12:       nabu-ssc-probe.c
Source13:       nabu-pen-autopair
Source14:       82-nabu-pen-autopair.rules
Source15:       nabu-pen-autopair@.service
Source16:       nabu-kernel-maintenance.path
Source17:       80-nabu-kernel-retention.conf
Source18:       test-kernel-maintenance-family.sh
Source19:       nabu-kernel-offline-finalize
Source20:       90-nabu-offline-uki-finalize.conf
Source21:       test-offline-kernel-finalize.sh
Source22:       20-nabu-packagekit-qos.conf
Source23:       nabu-locale-packages
Source24:       nabu-locale-packages.service
Source25:       nabu-locale-packages.path
Source26:       nabu-locale-packages.timer
Source27:       91-nabu-locale-packages.preset
Source28:       test-locale-packages.sh
Source29:       91-nabu-microphone-noise-cancel.conf
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  meson
BuildRequires:  openssh
BuildRequires:  pkgconfig(gio-2.0)
BuildRequires:  libssc-nabu-devel >= 0.4.4-8.nabu7.test
BuildRequires:  pkgconfig(Qt6Core)
BuildRequires:  pkgconfig(Qt6DBus)
BuildRequires:  systemd-rpm-macros
BuildRequires:  systemd-udev

# One ESP-supported kernel family is mandatory. Alpha is the normal release
# line and mainline-unstable is the explicit comparison line; the other COPR
# packages may remain installed but do not consume the constrained Nabu ESP.
Requires:       (senemos-nabu-kernel-alpha or senemos-nabu-kernel-mainline-unstable)
Recommends:     senemos-nabu-kernel-alpha
Recommends:     senemos-fastfetch-config >= 1.1.0-1

# Hardware, boot, firmware and service payloads remain independently built
# where architecture, ABI, licensing or physical validation lifecycles differ.
Requires:       nabu-boot-integration >= 2.0.0-31.test
Requires:       nabu-boot-manager
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu >= 0.4.4-8.nabu7.test
Requires:       python3-ssc-nabu >= 0.4.4-8.nabu7.test
Requires:       iio-sensor-proxy-nabu
Requires:       xiaomi-nabu-firmware
Requires:       senemos-nabu-plymouth >= 1.0.0-5.test
# The Nabu camera kernel graph is exercised through the stock Fedora media
# stack.  Keep it in CORE so every supported desktop receives the same V4L2,
# libcamera, PipeWire and GStreamer integration without another Nabu RPM.
Requires:       gstreamer1-plugins-bad-free
Requires:       libcamera
Requires:       libcamera-gstreamer
Requires:       libcamera-qcam
Requires:       libcamera-tools
Requires:       pipewire-plugin-libcamera
Requires:       v4l-utils
Requires:       NetworkManager-wifi
Requires:       NetworkManager-bluetooth
Requires:       openssh-server
Requires:       alsa-ucm
Requires:       atheros-firmware
Requires:       bash
Requires:       bluez
Requires:       bluez-obexd
Requires:       coreutils
Requires:       dnf5
Requires:       dosfstools
Requires:       dracut
Requires:       feedbackd
%if 0%{?fedora} >= 45
Requires:       libcanberra-backend-pulse
%else
Requires:       libcanberra
%endif
Requires:       policycoreutils
Requires:       pipewire-pulseaudio
Requires:       polkit
Requires:       qcom-firmware
Requires:       qrtr
Requires:       rmtfs
Requires:       rpm
Requires:       selinux-policy-targeted
Requires:       sudo
Requires:       systemd >= 256
Requires:       systemd-udev
Requires:       tqftpserv
Requires:       tuned
Requires:       tuned-ppd
Requires:       upower
Requires:       util-linux-core
Requires:       wpa_supplicant
Requires:       webrtc-audio-processing
Requires:       zram-generator

Provides:       nabu-release-manifest = 3
Provides:       nabu-core = %{version}-%{release}
Provides:       nabu-core-abi = 1
Provides:       nabu-core-abi = 2
Provides:       nabu-core-branch = 2
Provides:       nabu-repository-config = %{version}-%{release}
Provides:       nabu-repository-config-api = 2
Provides:       nabu-branch-manager = %{version}-%{release}
Provides:       nabu-branch-manager-api = 2
Provides:       nabu-kernel-maintenance = %{version}-%{release}
Provides:       nabu-kernel-maintenance-api = 5
Provides:       nabu-meta = %{version}-%{release}
Provides:       nabu-system-integration = %{version}-%{release}
Provides:       nabu-runtime-integration = %{version}-%{release}
Provides:       nabu-core-config = %{version}-%{release}
Provides:       nabu-device-config = %{version}-%{release}
Provides:       nabu-audio-config = %{version}-%{release}
Provides:       nabu-flashlight-integration = %{version}-%{release}
Provides:       nabu-flashlight-integration = 1.0.0-10.fc46
Provides:       nabu-flashlight-integration = 1.0.0-14.fc46
Provides:       nabu-flashlight-integration = 1.0.0-15.fc46
Provides:       nabu-sar-service = %{version}-%{release}
Provides:       nabu-ssc-probe = %{version}-%{release}
Provides:       nabu-camera-stack = %{version}-%{release}
Provides:       senemos-nabu-pen-autopair = %{version}-%{release}

# Bounded Nabu-only transition.  No Fedora, KDE or third-party package is
# obsoleted.  Kernel payload packages are deliberately retained.
Obsoletes:      nabu-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-base < %{legacy_meta_max}
Obsoletes:      nabu-core-stable-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-alpha-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-unstable-meta < %{legacy_meta_max}
Obsoletes:      nabu-repository-config < %{legacy_meta_max}
Obsoletes:      nabu-branch-manager < %{legacy_meta_max}
Obsoletes:      nabu-kernel-maintenance < %{legacy_meta_max}
Obsoletes:      nabu-obsolete-packages < %{legacy_meta_max}
Obsoletes:      nabu-desktop-migration < %{legacy_meta_max}
Obsoletes:      nabu-system-integration < %{legacy_meta_max}
Obsoletes:      nabu-runtime-integration < %{legacy_meta_max}
Obsoletes:      nabu-core-config < %{legacy_meta_max}
Obsoletes:      nabu-device-config < %{legacy_meta_max}
Obsoletes:      nabu-audio-config < %{legacy_meta_max}
Obsoletes:      nabu-flashlight-integration < %{legacy_meta_max}
Obsoletes:      nabu-sar-service < %{legacy_meta_max}
Obsoletes:      nabu-ssc-probe < %{legacy_meta_max}
Obsoletes:      nabu-suspend-diagnostics < %{legacy_meta_max}
Obsoletes:      senemos-nabu-pen-autopair < 1:1.17.0-1.v1.4.0.7.1.2
# Legacy split payloads are intentionally not obsoleted in the first unified
# release: one of them may be the running kernel and DNF must preserve it.

%description
The single hardware-side release manifest for Fedora on Xiaomi Pad 5 (nabu).
It installs the required firmware, boot, audio, sensor, power and service
components and guarantees that at least one supported Nabu kernel family is
installed.  Alpha is the recommended family, but stable, mainline and the
reserved future LTS family may be installed together without replacing this
meta package.  The package also owns repository configuration and the safe
kernel/UKI maintenance control plane so their versions cannot drift apart.

%prep
%setup -q -c -T
mkdir system-integration flashlight-integration sar-service
tar --zstd -xf %{SOURCE9} -C system-integration --strip-components=1
tar -xzf %{SOURCE10} -C flashlight-integration --strip-components=1
tar --zstd -xf %{SOURCE11} -C sar-service --strip-components=1
cp -p %{SOURCE12} nabu-ssc-probe.c

%build
bash -n %{SOURCE2}
bash -n %{SOURCE4}
bash -n %{SOURCE23}
bash %{SOURCE28}
%{__cc} %{build_cflags} %{build_ldflags} -o nabu-flashlight flashlight-integration/src/nabu-flashlight.c
%{__cc} %{build_cflags} %{build_ldflags} -o nabu-usb-role flashlight-integration/src/nabu-usb-role.c
%{__cxx} -std=c++17 %{build_cxxflags} $(pkg-config --cflags Qt6Core Qt6DBus) \
    -o nabu-accessory-state flashlight-integration/src/nabu-accessory-state.cpp \
    %{build_ldflags} $(pkg-config --libs Qt6Core Qt6DBus)
%{__cc} %{build_cflags} %{build_ldflags} -o nabu-ssc-probe nabu-ssc-probe.c $(pkg-config --cflags --libs gio-2.0 libssc)
meson setup sar-build sar-service \
    --prefix=%{_prefix} --libexecdir=%{_libexecdir} \
    --sysconfdir=%{_sysconfdir} --datadir=%{_datadir}
meson compile -C sar-build

%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
install -Dm0755 %{SOURCE2} %{buildroot}%{_bindir}/nabu
install -Dm0644 %{SOURCE3} %{buildroot}%{_mandir}/man8/nabu.8
install -Dm0755 %{SOURCE4} %{buildroot}%{_libexecdir}/nabu-kernel-maintenance
install -Dm0755 %{SOURCE19} %{buildroot}%{_libexecdir}/nabu-kernel-offline-finalize
install -Dm0644 %{SOURCE5} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.service
install -Dm0644 %{SOURCE6} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.timer
install -Dm0644 %{SOURCE16} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.path
install -Dm0644 %{SOURCE7} %{buildroot}%{_presetdir}/90-nabu-kernel-maintenance.preset
install -Dm0644 %{SOURCE8} %{buildroot}%{_sysconfdir}/nabu/kernel.conf
install -Dm0755 %{SOURCE13} %{buildroot}%{_libexecdir}/nabu-pen-autopair
install -Dm0644 %{SOURCE14} %{buildroot}%{_udevrulesdir}/82-nabu-pen-autopair.rules
install -Dm0644 %{SOURCE15} %{buildroot}%{_unitdir}/nabu-pen-autopair@.service
install -Dm0644 %{SOURCE17} %{buildroot}%{_datadir}/dnf5/libdnf.conf.d/80-nabu-kernel-retention.conf
install -Dm0644 %{SOURCE20} %{buildroot}%{_unitdir}/dnf5-offline-transaction.service.d/90-nabu-offline-uki-finalize.conf
install -Dm0644 %{SOURCE22} %{buildroot}%{_unitdir}/packagekit.service.d/20-nabu-packagekit-qos.conf
install -Dm0755 %{SOURCE23} %{buildroot}%{_libexecdir}/senemos-nabu/nabu-locale-packages
install -Dm0644 %{SOURCE24} %{buildroot}%{_unitdir}/nabu-locale-packages.service
install -Dm0644 %{SOURCE25} %{buildroot}%{_unitdir}/nabu-locale-packages.path
install -Dm0644 %{SOURCE26} %{buildroot}%{_unitdir}/nabu-locale-packages.timer
install -Dm0644 %{SOURCE27} %{buildroot}%{_presetdir}/91-nabu-locale-packages.preset
install -Dm0644 %{SOURCE29} %{buildroot}%{_datadir}/pipewire/pipewire-pulse.conf.d/91-nabu-microphone-noise-cancel.conf
install -d %{buildroot}%{_sysconfdir}/systemd/system
ln -s /dev/null %{buildroot}%{_sysconfdir}/systemd/system/nabu-kernel-update.timer

cp -a system-integration/payload/etc system-integration/payload/usr %{buildroot}/
install -d -m0755 %{buildroot}%{_sysconfdir}/modules-load.d
ln -s /dev/null %{buildroot}%{_sysconfdir}/modules-load.d/scsi_dh.conf
# The old image recipe forced this codec from the UKI initrd before the full
# ALSA module set was available.  Device modalias loading after switch-root is
# sufficient, so mask the obsolete image-era list for existing installations.
ln -s /dev/null %{buildroot}%{_sysconfdir}/modules-load.d/nabu-audio-codecs.conf
install -Dm0755 system-integration/runtime/nabu-pmic-rtc-sync %{buildroot}%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
install -Dm0755 system-integration/runtime/nabu-slpi-suspend %{buildroot}%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
install -Dm0755 system-integration/runtime/nabu-sensor-session-gate %{buildroot}%{_libexecdir}/senemos-nabu/nabu-sensor-session-gate
install -Dm0755 system-integration/runtime/nabu-sensor-registry-runtime %{buildroot}%{_libexecdir}/senemos-nabu/nabu-sensor-registry-runtime
install -Dm0755 system-integration/runtime/nabu-esp32-cdc-journal-log %{buildroot}%{_libexecdir}/senemos-nabu/nabu-esp32-cdc-journal-log
install -Dm0755 system-integration/runtime/nabu-prepare-selinux-labels %{buildroot}%{_libexecdir}/senemos-nabu/nabu-prepare-selinux-labels
install -Dm0755 system-integration/runtime/nabu-ssh-host-key-guard %{buildroot}%{_libexecdir}/senemos-nabu/nabu-ssh-host-key-guard
install -Dm0755 system-integration/runtime/senemos-nabu-status %{buildroot}%{_bindir}/senemos-nabu-status
install -Dm0644 system-integration/runtime/nabu-pmic-rtc-sync.service %{buildroot}%{_unitdir}/nabu-pmic-rtc-sync.service
install -Dm0644 system-integration/runtime/nabu-slpi-suspend.service %{buildroot}%{_unitdir}/nabu-slpi-suspend.service
install -Dm0644 system-integration/runtime/nabu-sensor-session-gate.service %{buildroot}%{_unitdir}/nabu-sensor-session-gate.service
install -Dm0644 system-integration/runtime/nabu-sensor-registry-runtime.service %{buildroot}%{_unitdir}/nabu-sensor-registry-runtime.service
install -Dm0644 system-integration/runtime/nabu-esp32-cdc-log.service %{buildroot}%{_unitdir}/nabu-esp32-cdc-log.service
install -Dm0644 system-integration/runtime/mnt-vendor-persist.mount %{buildroot}%{_unitdir}/mnt-vendor-persist.mount
install -Dm0644 system-integration/runtime/nabu-root-growfs.service %{buildroot}%{_unitdir}/nabu-root-growfs.service
install -Dm0644 system-integration/runtime/nabu-ssh-host-key-restore.service %{buildroot}%{_unitdir}/nabu-ssh-host-key-restore.service
install -Dm0644 system-integration/runtime/nabu-ssh-host-key-save.service %{buildroot}%{_unitdir}/nabu-ssh-host-key-save.service
install -Dm0644 system-integration/runtime/90-senemos-nabu.preset %{buildroot}%{_presetdir}/90-senemos-nabu.preset
install -Dm0644 system-integration/runtime/10-nabu-sensor-stack.conf %{buildroot}%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
install -Dm0644 system-integration/runtime/20-nabu-sensor-cache.conf %{buildroot}%{_unitdir}/iio-sensor-proxy.service.d/20-nabu-sensor-cache.conf
install -Dm0644 system-integration/runtime/20-nabu-runtime-registry.conf %{buildroot}%{_unitdir}/hexagonrpcd-sdsp.service.d/20-nabu-runtime-registry.conf
install -Dm0644 system-integration/runtime/10-nabu-wlan-firmware-order.conf %{buildroot}%{_unitdir}/rmtfs.service.d/10-nabu-wlan-firmware-order.conf
install -Dm0644 system-integration/runtime/90-nabu-user-slice-freeze.conf %{buildroot}%{_unitdir}/systemd-suspend.service.d/90-nabu-user-slice-freeze.conf
install -Dm0644 system-integration/runtime/20-nabu-host-key-persistence.conf %{buildroot}%{_unitdir}/sshd.service.d/20-nabu-host-key-persistence.conf
install -Dm0644 system-integration/runtime/90-nabu-dnf5-offline-cleanup.conf %{buildroot}%{_unitdir}/system-update-cleanup.service.d/90-nabu-dnf5-offline-cleanup.conf
install -Dm0644 system-integration/runtime/20-nabu-wifi-wowlan.conf %{buildroot}%{_sysconfdir}/NetworkManager/conf.d/20-nabu-wifi-wowlan.conf
install -Dm0644 system-integration/runtime/80-nabu-disable-efi-rtc-wakeup.rules %{buildroot}%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
install -Dm0644 system-integration/runtime/81-nabu-suspend-wake.rules %{buildroot}%{_udevrulesdir}/81-nabu-suspend-wake.rules
install -Dm0644 system-integration/runtime/90-nabu-unneeded-storage.conf %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
install -Dm0644 system-integration/runtime/90-nabu-mcc45tr.hwdb %{buildroot}%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
install -Dm0644 system-integration/sm8150.conf %{buildroot}%{_datadir}/alsa/ucm2/conf.d/sm8150/sm8150.conf
install -Dm0644 system-integration/HiFi.conf %{buildroot}%{_datadir}/alsa/ucm2/Xiaomi/nabu/HiFi.conf
install -Dm0644 system-integration/89-xiaomi_nabu.conf %{buildroot}%{_sysconfdir}/pulse/daemon.conf.d/89-xiaomi_nabu.conf
install -Dm0644 system-integration/nabu.pa %{buildroot}%{_sysconfdir}/pulse/default.pa.d/nabu.pa

install -Dpm2755 nabu-flashlight %{buildroot}%{_libexecdir}/nabu-flashlight
install -Dpm0755 nabu-usb-role %{buildroot}%{_libexecdir}/nabu-usb-role
install -Dpm0755 nabu-accessory-state %{buildroot}%{_libexecdir}/nabu-accessory-state
ln -s %{_libexecdir}/nabu-flashlight %{buildroot}%{_bindir}/nabu-flashlightctl
ln -s %{_libexecdir}/nabu-usb-role %{buildroot}%{_bindir}/nabu-usb-role
ln -s %{_libexecdir}/nabu-accessory-state %{buildroot}%{_bindir}/nabu-accessory-state
install -Dpm0644 flashlight-integration/polkit/org.senemos.nabu.tablet-control.policy %{buildroot}%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy
DESTDIR=%{buildroot} meson install -C sar-build
install -Dm0755 nabu-ssc-probe %{buildroot}%{_bindir}/nabu-ssc-probe

%check
bash %{SOURCE18}
bash %{SOURCE21}
bash -n %{SOURCE19}
grep -Fqx 'ExecStartPost=/usr/libexec/nabu-kernel-offline-finalize' %{SOURCE20}
grep -Fqx 'CPUWeight=20' %{SOURCE22}
grep -Fqx 'IOWeight=20' %{SOURCE22}
grep -Fqx 'Nice=10' %{SOURCE22}
grep -Fqx 'IOSchedulingClass=idle' %{SOURCE22}
bash -n %{SOURCE23}
bash %{SOURCE28}
grep -Fqx 'PathChanged=/etc/plasma-setup-done' %{SOURCE25}
! grep -Fqx 'PathExists=/etc/plasma-setup-done' %{SOURCE25}
grep -Fqx 'OnUnitInactiveSec=6h' %{SOURCE26}
! grep -Eq '^Requires:[[:space:]]+(langpacks|hunspell)-tr$' kde-plasma-nabu-meta.spec kde-plasma-mobile-nabu-meta.spec
bash -n system-integration/runtime/nabu-pmic-rtc-sync
bash -n system-integration/runtime/nabu-slpi-suspend
bash -n system-integration/runtime/nabu-sensor-session-gate
bash -n system-integration/runtime/nabu-sensor-registry-runtime
bash -n system-integration/runtime/nabu-esp32-cdc-journal-log
bash -n system-integration/runtime/nabu-prepare-selinux-labels
bash -n system-integration/runtime/nabu-ssh-host-key-guard
(cd system-integration && bash tests/test-sensor-session-gate.sh)
grep -Fxq 'Before=display-manager.service gdm.service plasmalogin.service' \
    system-integration/runtime/nabu-sensor-session-gate.service
grep -Fq -- '--sensor accelerometer --timeout 1' \
    system-integration/runtime/nabu-sensor-session-gate
(cd system-integration && bash tests/test-sensor-registry-runtime.sh)
(cd system-integration && bash tests/test-selinux-label-preparation.sh)
(cd system-integration && bash tests/test-suspend-user-slice-policy.sh)
(cd system-integration && bash tests/test-slpi-suspend.sh)
(cd system-integration && bash tests/test-ssh-host-key-guard.sh)
(cd system-integration && bash tests/test-update-recovery-policy.sh)
bash -n system-integration/runtime/senemos-nabu-status
udevadm verify %{buildroot}%{_udevrulesdir}/99-libinput-calibration-matrix.rules
test ! -e %{buildroot}%{_udevrulesdir}/81-nabu-sensor-orientation.rules
test ! -e %{buildroot}%{_libexecdir}/nabu-import-mount-matrix
test "$(readlink %{buildroot}%{_sysconfdir}/modules-load.d/nabu-audio-codecs.conf)" = /dev/null
! grep -Eq '(^|,)senemos-nabu-kernel-mainline-unstable(,|$)' %{SOURCE17}
meson test -C sar-build --print-errorlogs
bash -n sar-service/tools/nabu-cct-iio-setup
bash -n sar-service/tools/nabu-sar-capture
test "$(stat -c '%%a' %{buildroot}%{_libexecdir}/nabu-flashlight)" = 2755
test "$(stat -c '%%a' %{buildroot}%{_libexecdir}/nabu-accessory-state)" = 755
grep -Fq '/usr/libexec/nabu-usb-role' %{buildroot}%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy
grep -Fq '/usr/libexec/nabu-sar-control' %{buildroot}%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy

%pretrans -p /usr/bin/bash
/usr/bin/mkdir -p /mnt/vendor/persist || :
legacy_iwd=/etc/NetworkManager/conf.d/10-iwd.conf
if [ -f "$legacy_iwd" ] && printf '[device]\nwifi.backend=iwd\n' | /usr/bin/cmp -s - "$legacy_iwd"; then
    /usr/bin/rm -f -- "$legacy_iwd"
fi

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
%config(noreplace) %{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
%config(noreplace) %{_sysconfdir}/nabu/kernel.conf
%config %{_sysconfdir}/systemd/system/nabu-kernel-update.timer
%{_bindir}/nabu
%{_mandir}/man8/nabu.8*
%{_libexecdir}/nabu-kernel-maintenance
%{_libexecdir}/nabu-kernel-offline-finalize
%{_unitdir}/nabu-kernel-maintenance.service
%{_unitdir}/nabu-kernel-maintenance.timer
%{_unitdir}/nabu-kernel-maintenance.path
%dir %{_unitdir}/dnf5-offline-transaction.service.d
%{_unitdir}/dnf5-offline-transaction.service.d/90-nabu-offline-uki-finalize.conf
%dir %{_unitdir}/packagekit.service.d
%{_unitdir}/packagekit.service.d/20-nabu-packagekit-qos.conf
%{_libexecdir}/senemos-nabu/nabu-locale-packages
%{_unitdir}/nabu-locale-packages.service
%{_unitdir}/nabu-locale-packages.path
%{_unitdir}/nabu-locale-packages.timer
%{_presetdir}/91-nabu-locale-packages.preset
%{_presetdir}/90-nabu-kernel-maintenance.preset
%license system-integration/licenses/*
%doc system-integration/FIRMWARE-PROVENANCE.md flashlight-integration/API.md
%config(noreplace) %{_sysconfdir}/dracut.conf.d/99-nabu-generic.conf
%config(noreplace) %{_sysconfdir}/systemd/zram-generator.conf
%config(noreplace) %{_sysconfdir}/modules-load.d/scsi_dh.conf
%{_sysconfdir}/modules-load.d/nabu-audio-codecs.conf
%config(noreplace) %{_sysconfdir}/pulse/daemon.conf.d/89-xiaomi_nabu.conf
%config(noreplace) %{_sysconfdir}/pulse/default.pa.d/nabu.pa
%{_datadir}/pipewire/pipewire-pulse.conf.d/91-nabu-microphone-noise-cancel.conf
%config(noreplace) %{_sysconfdir}/NetworkManager/conf.d/20-nabu-wifi-wowlan.conf
%config(noreplace) %{_sysconfdir}/nabu-sar.conf
%{_prefix}/lib/modprobe.d/80-nabu-audio.conf
%{_datadir}/alsa/ucm2/conf.d/sm8150/sm8150.conf
%{_datadir}/alsa/ucm2/Xiaomi/nabu/HiFi.conf
%{_bindir}/senemos-nabu-status
%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
%{_libexecdir}/senemos-nabu/nabu-sensor-session-gate
%{_libexecdir}/senemos-nabu/nabu-sensor-registry-runtime
%{_libexecdir}/senemos-nabu/nabu-esp32-cdc-journal-log
%{_libexecdir}/senemos-nabu/nabu-prepare-selinux-labels
%{_libexecdir}/senemos-nabu/nabu-ssh-host-key-guard
%{_unitdir}/ath10k-shutdown.service
%{_unitdir}/nabu-pmic-rtc-sync.service
%{_unitdir}/nabu-slpi-suspend.service
%{_unitdir}/nabu-sensor-session-gate.service
%{_unitdir}/nabu-sensor-registry-runtime.service
%{_unitdir}/nabu-esp32-cdc-log.service
%{_unitdir}/mnt-vendor-persist.mount
%{_unitdir}/nabu-root-growfs.service
%{_unitdir}/nabu-ssh-host-key-restore.service
%{_unitdir}/nabu-ssh-host-key-save.service
%{_presetdir}/80-nabu-core.preset
%{_presetdir}/90-senemos-nabu.preset
%dir %{_unitdir}/iio-sensor-proxy.service.d
%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
%{_unitdir}/iio-sensor-proxy.service.d/20-nabu-sensor-cache.conf
%dir %{_unitdir}/hexagonrpcd-sdsp.service.d
%{_unitdir}/hexagonrpcd-sdsp.service.d/20-nabu-runtime-registry.conf
%dir %{_unitdir}/rmtfs.service.d
%{_unitdir}/rmtfs.service.d/10-nabu-wlan-firmware-order.conf
%dir %{_unitdir}/systemd-suspend.service.d
%{_unitdir}/systemd-suspend.service.d/90-nabu-user-slice-freeze.conf
%dir %{_unitdir}/sshd.service.d
%{_unitdir}/sshd.service.d/20-nabu-host-key-persistence.conf
%dir %{_unitdir}/system-update-cleanup.service.d
%{_unitdir}/system-update-cleanup.service.d/90-nabu-dnf5-offline-cleanup.conf
%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
%{_udevrulesdir}/81-nabu-suspend-wake.rules
%{_udevrulesdir}/99-libinput-calibration-matrix.rules
%{_udevrulesdir}/99-nabu-rtc.rules
%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
%attr(2755,root,feedbackd) %{_libexecdir}/nabu-flashlight
%{_libexecdir}/nabu-usb-role
%{_libexecdir}/nabu-accessory-state
%{_bindir}/nabu-flashlightctl
%{_bindir}/nabu-usb-role
%{_bindir}/nabu-accessory-state
%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy
%{_libexecdir}/nabu-sar-service
%{_libexecdir}/nabu-sar-control
%{_libexecdir}/nabu-cct-iio-setup
%{_libexecdir}/nabu-cct-iio-bridge
%{_unitdir}/nabu-sar-service.service
%{_unitdir}/nabu-cct-iio-bridge.service
%{_prefix}/lib/modules-load.d/nabu-cct-iio.conf
%{_datadir}/dbus-1/system.d/org.senemos.Nabu.Sar.conf
%{_bindir}/nabu-sar-capture
%{_bindir}/nabu-ssc-probe
%{_libexecdir}/nabu-pen-autopair
%{_udevrulesdir}/82-nabu-pen-autopair.rules
%{_unitdir}/nabu-pen-autopair@.service
%{_datadir}/dnf5/libdnf.conf.d/80-nabu-kernel-retention.conf

%post
%systemd_post nabu-kernel-maintenance.timer nabu-kernel-maintenance.path nabu-locale-packages.path nabu-locale-packages.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service nabu-sensor-registry-runtime.service nabu-esp32-cdc-log.service mnt-vendor-persist.mount nabu-root-growfs.service nabu-ssh-host-key-restore.service nabu-ssh-host-key-save.service nabu-sar-service.service nabu-cct-iio-bridge.service
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%posttrans
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable --now nabu-kernel-maintenance.timer >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --now nabu-kernel-maintenance.path >/dev/null 2>&1 || :
    # Presets cover clean installs; explicitly enable without starting here so
    # existing systems gain locale following on their next boot without
    # launching DNF recursively inside this RPM transaction.
    /usr/bin/systemctl enable nabu-locale-packages.path nabu-locale-packages.timer >/dev/null 2>&1 || :
    /usr/bin/systemctl reset-failed nabu-locale-packages.path nabu-locale-packages.service >/dev/null 2>&1 || :
    /usr/bin/systemctl restart nabu-locale-packages.path nabu-locale-packages.timer >/dev/null 2>&1 || :
    /usr/bin/systemctl reset-failed nabu-kernel-maintenance.service >/dev/null 2>&1 || :
fi
/usr/libexec/senemos-nabu/nabu-prepare-selinux-labels || printf 'Warning: Nabu SELinux labels are not ready.\n' >&2
/usr/libexec/senemos-nabu/nabu-ssh-host-key-guard save || printf 'Warning: Nabu SSH host keys could not be persisted.\n' >&2
if [ -x /usr/bin/udevadm ]; then
    /usr/bin/udevadm control --reload >/dev/null 2>&1 || :
    /usr/bin/udevadm trigger --action=change --subsystem-match=misc --sysname-match='fastrpc-*' >/dev/null 2>&1 || :
fi
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --now nabu-root-growfs.service nabu-ssh-host-key-restore.service nabu-ssh-host-key-save.service >/dev/null 2>&1 || :
    /usr/bin/systemctl reenable nabu-sensor-session-gate.service nabu-esp32-cdc-log.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable --now hexagonrpcd-adsp-sensorspd.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable rmtfs.service tqftpserv.service mnt-vendor-persist.mount hexagonrpcd-sdsp.service hexagonrpcd-adsp-rootpd.service iio-sensor-proxy.service nabu-sensor-session-gate.service nabu-sar-service.service nabu-cct-iio-bridge.service >/dev/null 2>&1 || :
fi

%preun
%systemd_preun nabu-kernel-maintenance.timer nabu-kernel-maintenance.path nabu-locale-packages.path nabu-locale-packages.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service nabu-sensor-registry-runtime.service nabu-esp32-cdc-log.service mnt-vendor-persist.mount nabu-root-growfs.service nabu-ssh-host-key-restore.service nabu-ssh-host-key-save.service nabu-sar-service.service nabu-cct-iio-bridge.service

%postun
%systemd_postun nabu-kernel-maintenance.timer nabu-kernel-maintenance.path nabu-locale-packages.path nabu-locale-packages.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service nabu-sensor-registry-runtime.service nabu-esp32-cdc-log.service mnt-vendor-persist.mount nabu-root-growfs.service nabu-ssh-host-key-restore.service nabu-ssh-host-key-save.service nabu-sar-service.service nabu-cct-iio-bridge.service
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%changelog
* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-60
- Require the corrected SSC standard-event decoder before enabling the TCS3701
  colour-temperature bridge.

* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-59
- Install NetworkManager's Bluetooth PAN/DUN plugin and BlueZ OBEX support.
- Expose a WebRTC noise-cancelled microphone source while preserving the raw
  two-channel internal microphone source.

* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-58
- Continue SLPI quiescing after a bounded sensor-service stop timeout.
- Require proof that a timed-out client is inactive before suspending.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-57
- Keep ADUX1050 as an unmapped three-channel SAR/grip stream by default.
- Remove uncalibrated CH0/CH2 selection and synthetic grip thresholds.
- Require an explicit valid calibration before grip classification can run.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-56
- Transfer the system Fastfetch configuration to the optional
  senemos-fastfetch-config package so uninstall removes it cleanly.
- Recommend the ownership-aware locale package at version 1.1.0 or newer.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-55
- Recommend the optional SENEMOS locale-aware Fastfetch configuration so
  normal image and device transactions install it without a hard dependency.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-54
- Align the RPM build gate with the PackageKit idle I/O policy.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-53
- Move PackageKit background metadata work to idle I/O scheduling and nice 10
  so Discover startup does not compete with the first Plasma frames.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-52
- Mask the obsolete forced CS35L41 module list so UKI early boot no longer
  reports a false snd-seq/systemd-modules-load failure.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-51
- Recover systems that briefly received the level-triggered locale watcher by
  clearing its start limit and activating the corrected edge-based units.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-50
- Watch setup completion as an edge instead of a permanently true path state,
  preventing a locale-service start-limit loop after first boot.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-49
- Enable locale selection units for existing installations on package upgrade,
  while deferring their first package transaction until the next boot.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-48
- Install Fedora language support from the locale selected in initial setup
  instead of imposing any maintainer language on global installations.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-47
- Give interactive desktop work priority over background PackageKit CPU and
  I/O activity without disabling Discover or offline updates.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-46
- Stop globally disabling Freedreno UBWC; it did not prevent the observed GPU
  resets and unnecessarily increased graphics memory and bandwidth pressure.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-45
- Disable UBWC for Freedreno GL clients on Nabu to avoid the observed Adreno
  640 CCU translation faults and repeated Plasma graphics resets.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-44
- Converge stable, alpha, mainline, unstable and LTS kernel packages into four
  managed EFI families with exactly one newest UKI retained per family.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-43
- Use the native TCS3701 cct_front protocol for colour temperature instead of
  interpreting the cct_front_strm ambient-light payload as Kelvin.
- Require the libssc release that exposes the complete typed CCT measurement.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-42
- Rate-limit invalid TCS3701 colour-temperature warnings while continuing to
  reject out-of-range firmware samples from the standard IIO endpoint.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-41
- Load the WCD934x ASoC codec before the SM8150 machine driver so the Xiaomi
  Pad 5 sound card cannot remain deferred after boot.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-40
- Refuse package-triggered manual stops of the ath10k shutdown helper so an
  online upgrade cannot unload the active Wi-Fi driver.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-39
- Finish queued kernel UKI work inside the DNF5 offline transaction unit.
- Hold the ordered offline reboot until the new EFI and rEFInd default are ready.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-38
- Recover once when SLPI is running without publishing its SSC QMI service.
- Keep the live sensor stack undisturbed during package upgrades; new unit
  definitions take effect on the next bounded boot instead of restarting
  FastRPC consumers underneath the graphical session.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-37
- Add the openssh build dependency required by the packaged host-key
  persistence test.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-36
- Gate graphical startup on a real SSC accelerometer sample and SensorProxy
  publication instead of treating a running FastRPC filesystem server as ready.
- Order the bounded recovery gate explicitly before GDM and Plasma Login so a
  late SLPI enumeration is repaired before the desktop caches sensor state.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-35
- Grow undersized ext4 root filesystems to the provisioned Linux partition.
- Preserve SSH host identity across boots even if another boot step removes keys.
- Clear failed DNF5 offline-update state instead of repeating a broken update.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-34
- Publish the SSC colour-temperature stream through a standard IIO endpoint.
- Add fail-closed ADUX1050 grip-aware sleep inhibition and calibration tooling.
- Install the shared SAR control interface used by KDE Plasma and GNOME.

* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-33
- Add automatic USB-C power-role policy and correct Xiaomi Keyboard presence.

* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-32
- Skip the expensive full-root SELinux relabel and verification pass when the
  stored policy digest is already current and no autorelabel was requested.

* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-31
- Retire the legacy shell importer and duplicate Nabu orientation rule; the
  sensor package now consumes the kernel-exported Device Tree matrix directly.
- Let the canonical 7.2.2 package self-update normally while preserving the
  independently named 6.17 fallback kernel family.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-30
- Import Nabu's accelerometer matrix from the FastRPC sysfs attribute backed by
  Device Tree instead of duplicating board orientation as a userspace constant.
- Import the trusted matrix with a bounded helper that accepts only a Nabu
  sysfs path and a valid 3x3 signed-unit rotation matrix.
- Keep SDSP as the sole SSC sensor source and prevent duplicate ADSP discovery.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-28
- Make SDSP the sole Nabu SSC sensor owner and prevent duplicate ADSP sensors.
- Export the verified Nabu accelerometer matrix through the udev device property.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-27
- Expose only the supported alpha and mainline-unstable families on the ESP.
- Keep stable, LTS and old mainline packages available without generating UKIs.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-26
- Align kernel maintenance verification with the standard EFI/fedora UKI path.
- Require the dynamic rEFInd-capable boot integration before enabling maintenance.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-25
- Copy the Android SSC registry version marker beside the volatile registry so
  SDSP discovery can validate and open the complete calibration database.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-24
- Stage packaged SSC data and read-only Android calibration in a volatile
  fastrpc-owned registry; give iio-sensor-proxy a system cache under SELinux.
- Remove the sensor health check from the graphical critical path.
- Keep ESP32 CDC journal streaming healthy across cable disconnects.
- Install the FAT checker and include signed regulatory data in release UKIs.
- Retry deferred UKI work once at boot instead of rerunning failed dracut jobs.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-21
- Keep the existing stable package as the independent SENEMOS616 UKI family.
- Preserve exactly five named kernel package families without UKI collisions.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-20
- Require the corrected SENEMOS7U-aware boot integration build.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-19
- Manage the separate mainline-unstable package as the SENEMOS7U UKI family.

* Sun Aug 30 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-18
- Maintain one latest UKI independently for SENEMOS6, SENEMOS7 and SENEMOS6LTS.
- Preserve user-installed kernels and select the preferred family only as the default.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-17
- Verify the exact UKI derived from the shared kernel identity instead of
  treating the manager-neutral manifest as the only success artifact.
- Skip regeneration only when the prepared record's UKI digest still matches
  the exact canonical artifact on the ESP.
- Require boot integration support for the COPR uname form with the preserved
  SENEMOS timestamped EFI name.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-16
- Skip the full-root SELinux relabel and verification pass when the stored
  policy digest is current and no autorelabel request exists.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-15
- Make the ESP an explicit writable path in the hardened UKI maintenance
  service and serialize it after rEFInd synchronization.
- Rate-limit failed path-triggered retries while retaining the pending marker
  for the timer's later retry.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-14
- Add the native BlueZ, stylus-power and pogo-keyboard state helper required
  by the stock GNOME and Plasma tablet-control integrations.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-13
- Classify stable, alpha and mainline package names as install-only after the
  first unified upgrade while retaining exactly two versions per family.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-12
- Retain at most two versions of each installed Nabu kernel family using DNF's
  native install-only policy without disabling running-kernel protection.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-11
- Preserve legacy split payloads during the first unified transaction so DNF's
  running-kernel safety gate remains effective.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-10
- Drain deferred work for installed non-preferred kernel families so the path
  unit cannot retrigger continuously; only the selected family owns a UKI.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-9
- Support one-RPM kernel families and migrate every former core/modules split.
- Merge the Nabu stylus autopair hardware integration into CORE.
- Require scriptlet-free boot integration 2.0.0-17.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-8
- Retire only pre-migration install-only payload EVRs so a normal DNF update
  converges on one version per installed family and removes orphan payloads.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-7
- Consume exact per-family kernel markers without running DNF recursively or
  scanning unrelated installed kernels.
- Manage one canonical Linux entry, never require or inspect a Linux fallback, and
  preserve the Android return artifact when it exists.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-6
- Ship the stock Fedora libcamera, PipeWire, GStreamer and V4L2 camera stack
  from CORE for the Nabu CAMSS/CCI alpha kernel; no KDE or Fedora application
  is forked or replaced.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-5
- Provide the final split flashlight EVR during migration so normal DNF
  updates can remove its version-locked Plasma companion without erasing.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-4
- Keep desktop-owned compatibility transitions in the selected DE manifest so
  version-locked legacy KDE integrations retire in one solvable transaction.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-3
- Make CORE the sole retirement owner for shared integration subpackages so
  mutually exclusive DE manifests are never considered competing replacements.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-2
- Run inherited system-policy tests from their source root in clean build
  chroots.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-1
- Merge the complete noarch system policy, native flashlight/USB helpers, SAR
  service and SSC probe into the CORE release package.
- Retire the standalone runtime, system, flashlight, SAR, SSC and alpha-only
  suspend diagnostic integration packages in one bounded transaction.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-4
- Preserve the device's existing explicit loader default instead of assuming it
  must be fallback.conf, and hash-guard Android/fallback entries and EFI files.
- Clear the obsolete failed-unit state after installing the corrected policy.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Re-enable and start the maintenance timer in post-transaction so removal of
  the superseded standalone package cannot undo the new CORE policy.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Retire the shared one-shot desktop migration helper from the unambiguous CORE
  transition instead of making multiple DE manifests compete for it.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace the split CORE base, branch selectors and control packages with one
  release manifest while retaining all install-only kernel payloads.
- Require at least one kernel family, recommend alpha and permit co-installing
  stable, alpha, mainline and the future LTS family.
- Make firmware, flashlight and SAR hardware support explicit dependencies.
