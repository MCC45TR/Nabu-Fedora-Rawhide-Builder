%global debug_package %{nil}
%global legacy_meta_max 9999999999-99

Name:           nabu-core-meta
Version:        3.0.0
Release:        4%{?dist}
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
Source11:       nabu-sar-service-0.1.1.tar.zst
Source12:       nabu-ssc-probe.c
BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  pkgconfig(gio-2.0)
BuildRequires:  pkgconfig(libssc)
BuildRequires:  systemd-rpm-macros
BuildRequires:  systemd-udev

# One kernel family is mandatory.  Alpha is listed first and recommended for
# fresh installations, while installed stable/mainline kernels continue to
# satisfy the hard requirement and multiple families may coexist.
Requires:       (senemos-nabu-kernel-alpha or senemos-nabu-kernel or senemos-nabu-kernel-mainline-alpha or senemos-nabu-kernel-lts)
Recommends:     senemos-nabu-kernel-alpha

# Hardware, boot, firmware and service payloads remain independently built
# where architecture, ABI, licensing or physical validation lifecycles differ.
Requires:       nabu-boot-integration >= 2.0.0
Requires:       nabu-boot-manager
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu
Requires:       python3-ssc-nabu
Requires:       iio-sensor-proxy-nabu
Requires:       xiaomi-nabu-firmware
Requires:       senemos-nabu-plymouth >= 1.0.0-5.test
Requires:       NetworkManager-wifi
Requires:       alsa-ucm
Requires:       atheros-firmware
Requires:       bash
Requires:       coreutils
Requires:       dnf5
Requires:       dracut
Requires:       feedbackd
%if 0%{?fedora} >= 45
Requires:       libcanberra-backend-pulse
%else
Requires:       libcanberra
%endif
Requires:       policycoreutils
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
Provides:       nabu-kernel-maintenance-api = 2
Provides:       nabu-meta = %{version}-%{release}
Provides:       nabu-system-integration = %{version}-%{release}
Provides:       nabu-runtime-integration = %{version}-%{release}
Provides:       nabu-core-config = %{version}-%{release}
Provides:       nabu-device-config = %{version}-%{release}
Provides:       nabu-audio-config = %{version}-%{release}
Provides:       nabu-flashlight-integration = %{version}-%{release}
Provides:       nabu-sar-service = %{version}-%{release}
Provides:       nabu-ssc-probe = %{version}-%{release}

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
%{__cc} %{build_cflags} %{build_ldflags} -o nabu-flashlight flashlight-integration/src/nabu-flashlight.c
%{__cc} %{build_cflags} %{build_ldflags} -o nabu-usb-role flashlight-integration/src/nabu-usb-role.c
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
install -Dm0644 %{SOURCE5} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.service
install -Dm0644 %{SOURCE6} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.timer
install -Dm0644 %{SOURCE7} %{buildroot}%{_presetdir}/90-nabu-kernel-maintenance.preset
install -Dm0644 %{SOURCE8} %{buildroot}%{_sysconfdir}/nabu/kernel.conf
install -d %{buildroot}%{_sysconfdir}/systemd/system
ln -s /dev/null %{buildroot}%{_sysconfdir}/systemd/system/nabu-kernel-update.timer

cp -a system-integration/payload/etc system-integration/payload/usr %{buildroot}/
install -d -m0755 %{buildroot}%{_sysconfdir}/modules-load.d
ln -s /dev/null %{buildroot}%{_sysconfdir}/modules-load.d/scsi_dh.conf
install -Dm0755 system-integration/runtime/nabu-pmic-rtc-sync %{buildroot}%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
install -Dm0755 system-integration/runtime/nabu-slpi-suspend %{buildroot}%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
install -Dm0755 system-integration/runtime/nabu-sensor-session-gate %{buildroot}%{_libexecdir}/senemos-nabu/nabu-sensor-session-gate
install -Dm0755 system-integration/runtime/nabu-prepare-selinux-labels %{buildroot}%{_libexecdir}/senemos-nabu/nabu-prepare-selinux-labels
install -Dm0755 system-integration/runtime/senemos-nabu-status %{buildroot}%{_bindir}/senemos-nabu-status
install -Dm0644 system-integration/runtime/nabu-pmic-rtc-sync.service %{buildroot}%{_unitdir}/nabu-pmic-rtc-sync.service
install -Dm0644 system-integration/runtime/nabu-slpi-suspend.service %{buildroot}%{_unitdir}/nabu-slpi-suspend.service
install -Dm0644 system-integration/runtime/nabu-sensor-session-gate.service %{buildroot}%{_unitdir}/nabu-sensor-session-gate.service
install -Dm0644 system-integration/runtime/mnt-vendor-persist.mount %{buildroot}%{_unitdir}/mnt-vendor-persist.mount
install -Dm0644 system-integration/runtime/90-senemos-nabu.preset %{buildroot}%{_presetdir}/90-senemos-nabu.preset
install -Dm0644 system-integration/runtime/10-nabu-sensor-stack.conf %{buildroot}%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
install -Dm0644 system-integration/runtime/10-nabu-wlan-firmware-order.conf %{buildroot}%{_unitdir}/rmtfs.service.d/10-nabu-wlan-firmware-order.conf
install -Dm0644 system-integration/runtime/90-nabu-user-slice-freeze.conf %{buildroot}%{_unitdir}/systemd-suspend.service.d/90-nabu-user-slice-freeze.conf
install -Dm0644 system-integration/runtime/20-nabu-wifi-wowlan.conf %{buildroot}%{_sysconfdir}/NetworkManager/conf.d/20-nabu-wifi-wowlan.conf
install -Dm0644 system-integration/runtime/80-nabu-disable-efi-rtc-wakeup.rules %{buildroot}%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
install -Dm0644 system-integration/runtime/81-nabu-suspend-wake.rules %{buildroot}%{_udevrulesdir}/81-nabu-suspend-wake.rules
install -Dm0644 system-integration/runtime/90-nabu-unneeded-storage.conf %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
install -Dm0644 system-integration/runtime/90-nabu-mcc45tr.hwdb %{buildroot}%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
install -Dm0644 system-integration/runtime/fastfetch-config.jsonc %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc
install -Dm0644 system-integration/sm8150.conf %{buildroot}%{_datadir}/alsa/ucm2/conf.d/sm8150/sm8150.conf
install -Dm0644 system-integration/HiFi.conf %{buildroot}%{_datadir}/alsa/ucm2/Xiaomi/nabu/HiFi.conf
install -Dm0644 system-integration/89-xiaomi_nabu.conf %{buildroot}%{_sysconfdir}/pulse/daemon.conf.d/89-xiaomi_nabu.conf
install -Dm0644 system-integration/nabu.pa %{buildroot}%{_sysconfdir}/pulse/default.pa.d/nabu.pa

install -Dpm2755 nabu-flashlight %{buildroot}%{_libexecdir}/nabu-flashlight
install -Dpm0755 nabu-usb-role %{buildroot}%{_libexecdir}/nabu-usb-role
ln -s %{_libexecdir}/nabu-flashlight %{buildroot}%{_bindir}/nabu-flashlightctl
ln -s %{_libexecdir}/nabu-usb-role %{buildroot}%{_bindir}/nabu-usb-role
install -Dpm0644 flashlight-integration/polkit/org.senemos.nabu.tablet-control.policy %{buildroot}%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy
DESTDIR=%{buildroot} meson install -C sar-build
install -Dm0755 nabu-ssc-probe %{buildroot}%{_bindir}/nabu-ssc-probe

%check
bash -n system-integration/runtime/nabu-pmic-rtc-sync
bash -n system-integration/runtime/nabu-slpi-suspend
bash -n system-integration/runtime/nabu-sensor-session-gate
bash -n system-integration/runtime/nabu-prepare-selinux-labels
(cd system-integration && bash tests/test-sensor-session-gate.sh)
(cd system-integration && bash tests/test-selinux-label-preparation.sh)
(cd system-integration && bash tests/test-suspend-user-slice-policy.sh)
bash -n system-integration/runtime/senemos-nabu-status
udevadm verify %{buildroot}%{_udevrulesdir}/99-libinput-calibration-matrix.rules
meson test -C sar-build --print-errorlogs
test "$(stat -c '%%a' %{buildroot}%{_libexecdir}/nabu-flashlight)" = 2755
grep -Fq '/usr/libexec/nabu-usb-role' %{buildroot}%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy

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
%{_unitdir}/nabu-kernel-maintenance.service
%{_unitdir}/nabu-kernel-maintenance.timer
%{_presetdir}/90-nabu-kernel-maintenance.preset
%license system-integration/licenses/*
%doc system-integration/FIRMWARE-PROVENANCE.md flashlight-integration/API.md
%config(noreplace) %{_sysconfdir}/dracut.conf.d/99-nabu-generic.conf
%config(noreplace) %{_sysconfdir}/systemd/zram-generator.conf
%config(noreplace) %{_sysconfdir}/modules-load.d/scsi_dh.conf
%config(noreplace) %{_sysconfdir}/pulse/daemon.conf.d/89-xiaomi_nabu.conf
%config(noreplace) %{_sysconfdir}/pulse/default.pa.d/nabu.pa
%config(noreplace) %{_sysconfdir}/xdg/fastfetch/config.jsonc
%config(noreplace) %{_sysconfdir}/NetworkManager/conf.d/20-nabu-wifi-wowlan.conf
%config(noreplace) %{_sysconfdir}/nabu-sar.conf
%{_datadir}/alsa/ucm2/conf.d/sm8150/sm8150.conf
%{_datadir}/alsa/ucm2/Xiaomi/nabu/HiFi.conf
%{_bindir}/senemos-nabu-status
%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
%{_libexecdir}/senemos-nabu/nabu-sensor-session-gate
%{_libexecdir}/senemos-nabu/nabu-prepare-selinux-labels
%{_unitdir}/ath10k-shutdown.service
%{_unitdir}/nabu-pmic-rtc-sync.service
%{_unitdir}/nabu-slpi-suspend.service
%{_unitdir}/nabu-sensor-session-gate.service
%{_unitdir}/mnt-vendor-persist.mount
%{_presetdir}/80-nabu-core.preset
%{_presetdir}/90-senemos-nabu.preset
%dir %{_unitdir}/iio-sensor-proxy.service.d
%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
%dir %{_unitdir}/rmtfs.service.d
%{_unitdir}/rmtfs.service.d/10-nabu-wlan-firmware-order.conf
%dir %{_unitdir}/systemd-suspend.service.d
%{_unitdir}/systemd-suspend.service.d/90-nabu-user-slice-freeze.conf
%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
%{_udevrulesdir}/81-nabu-suspend-wake.rules
%{_udevrulesdir}/99-libinput-calibration-matrix.rules
%{_udevrulesdir}/99-nabu-rtc.rules
%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
%attr(2755,root,feedbackd) %{_libexecdir}/nabu-flashlight
%{_libexecdir}/nabu-usb-role
%{_bindir}/nabu-flashlightctl
%{_bindir}/nabu-usb-role
%{_datadir}/polkit-1/actions/org.senemos.nabu.tablet-control.policy
%{_libexecdir}/nabu-sar-service
%{_unitdir}/nabu-sar-service.service
%{_datadir}/dbus-1/system.d/org.senemos.Nabu.Sar.conf
%{_bindir}/nabu-ssc-probe

%post
%systemd_post nabu-kernel-maintenance.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service mnt-vendor-persist.mount nabu-sar-service.service
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%posttrans
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable --now nabu-kernel-maintenance.timer >/dev/null 2>&1 || :
    /usr/bin/systemctl reset-failed nabu-kernel-maintenance.service >/dev/null 2>&1 || :
fi
/usr/libexec/senemos-nabu/nabu-prepare-selinux-labels || printf 'Warning: Nabu SELinux labels are not ready.\n' >&2
if [ -x /usr/bin/udevadm ]; then
    /usr/bin/udevadm control --reload >/dev/null 2>&1 || :
    /usr/bin/udevadm trigger --action=change --subsystem-match=misc --sysname-match='fastrpc-*' >/dev/null 2>&1 || :
fi
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
    /usr/bin/systemctl disable --now hexagonrpcd-adsp-sensorspd.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable rmtfs.service tqftpserv.service mnt-vendor-persist.mount hexagonrpcd-sdsp.service hexagonrpcd-adsp-rootpd.service iio-sensor-proxy.service nabu-sensor-session-gate.service nabu-sar-service.service >/dev/null 2>&1 || :
    case "$(/usr/bin/systemctl is-system-running 2>/dev/null || :)" in
        running|degraded)
            /usr/bin/systemctl start mnt-vendor-persist.mount hexagonrpcd-sdsp.service hexagonrpcd-adsp-rootpd.service nabu-sar-service.service >/dev/null 2>&1 || :
            /usr/bin/systemctl restart iio-sensor-proxy.service >/dev/null 2>&1 || :
            ;;
    esac
fi

%preun
%systemd_preun nabu-kernel-maintenance.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service mnt-vendor-persist.mount nabu-sar-service.service

%postun
%systemd_postun_with_restart nabu-kernel-maintenance.timer ath10k-shutdown.service nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-session-gate.service mnt-vendor-persist.mount nabu-sar-service.service
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%changelog
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
