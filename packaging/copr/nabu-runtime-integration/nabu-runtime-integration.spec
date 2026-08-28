%global debug_package %{nil}
Name:           nabu-runtime-integration
Version:        1.4.0.2
Release:        1.test%{?dist}
Summary:        SENEMOS Nabu system and suspend integration
License:        MIT
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        LICENSE
Source1:        README.md
Source2:        nabu-pmic-rtc-sync
Source3:        nabu-slpi-suspend
Source4:        senemos-nabu-status
Source5:        nabu-pmic-rtc-sync.service
Source6:        nabu-slpi-suspend.service
Source7:        mnt-vendor-persist.mount
Source8:        90-senemos-nabu.preset
Source9:        10-nabu-sensor-stack.conf
Source10:       80-nabu-disable-efi-rtc-wakeup.rules
Source11:       81-nabu-suspend-wake.rules
Source12:       90-nabu-unneeded-storage.conf
Source13:       90-nabu-mcc45tr.hwdb
Source14:       fastfetch-config.jsonc

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       bash
Requires:       coreutils
Requires:       util-linux-core
Requires:       systemd
Requires:       systemd-udev
Requires:       tuned
Requires:       tuned-ppd
Requires:       upower
Requires:       hexagonrpc-nabu >= 0.4.0-100.nabu1
Requires:       iio-sensor-proxy-nabu >= 3.9-104.nabu5.test
Requires:       libssc-nabu >= 0.4.1-101.nabu4
Requires:       nabu-audio-config >= 1-3.nabu1
Requires:       kernel-nabu-core-uname-r

%description
Device-level userspace integration for Nabu: PMIC RTC synchronization, orderly
DSP client quiescing across sleep, display recovery, wake-source policy,
boot-noise cleanup, hardware identity and shared diagnostics. The sleep hook
stops active ADSP and SDSP FastRPC clients before suspend and restores only the
clients that were active before that sleep cycle.

%prep

%build
bash -n %{SOURCE2}
bash -n %{SOURCE3}
bash -n %{SOURCE4}

%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dm0644 %{SOURCE1} %{buildroot}%{_docdir}/%{name}/README.md
install -Dm0755 %{SOURCE2} %{buildroot}%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
install -Dm0755 %{SOURCE3} %{buildroot}%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
install -Dm0755 %{SOURCE4} %{buildroot}%{_bindir}/senemos-nabu-status
install -Dm0644 %{SOURCE5} %{buildroot}%{_unitdir}/nabu-pmic-rtc-sync.service
install -Dm0644 %{SOURCE6} %{buildroot}%{_unitdir}/nabu-slpi-suspend.service
install -Dm0644 %{SOURCE7} %{buildroot}%{_unitdir}/mnt-vendor-persist.mount
install -Dm0644 %{SOURCE8} %{buildroot}%{_presetdir}/90-senemos-nabu.preset
install -Dm0644 %{SOURCE9} %{buildroot}%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
install -Dm0644 %{SOURCE10} %{buildroot}%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
install -Dm0644 %{SOURCE11} %{buildroot}%{_udevrulesdir}/81-nabu-suspend-wake.rules
install -Dm0644 %{SOURCE12} %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
install -Dm0644 %{SOURCE13} %{buildroot}%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
install -Dm0644 %{SOURCE14} %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc

%pretrans
/usr/bin/mkdir -p /mnt/vendor/persist || :

%post
%systemd_post nabu-pmic-rtc-sync.service nabu-slpi-suspend.service mnt-vendor-persist.mount
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%preun
%systemd_preun nabu-pmic-rtc-sync.service nabu-slpi-suspend.service mnt-vendor-persist.mount

%postun
%systemd_postun nabu-pmic-rtc-sync.service nabu-slpi-suspend.service mnt-vendor-persist.mount
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%posttrans
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
    /usr/bin/systemctl disable --now \
        hexagonrpcd-adsp-sensorspd.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable \
        mnt-vendor-persist.mount \
        hexagonrpcd-sdsp.service \
        hexagonrpcd-adsp-rootpd.service \
        iio-sensor-proxy.service >/dev/null 2>&1 || :
    case "$(/usr/bin/systemctl is-system-running 2>/dev/null || :)" in
        running|degraded)
            /usr/bin/systemctl start mnt-vendor-persist.mount >/dev/null 2>&1 || :
            /usr/bin/systemctl start \
                hexagonrpcd-sdsp.service \
                hexagonrpcd-adsp-rootpd.service >/dev/null 2>&1 || :
            /usr/bin/udevadm control --reload >/dev/null 2>&1 || :
            /usr/bin/udevadm trigger --action=change \
                --subsystem-match=misc --sysname-match='fastrpc-*' >/dev/null 2>&1 || :
            /usr/bin/systemctl restart iio-sensor-proxy.service >/dev/null 2>&1 || :
            ;;
    esac
fi

%files
%license %{_licensedir}/%{name}/LICENSE
%doc %{_docdir}/%{name}/README.md
%{_bindir}/senemos-nabu-status
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
%{_unitdir}/nabu-pmic-rtc-sync.service
%{_unitdir}/nabu-slpi-suspend.service
%{_unitdir}/mnt-vendor-persist.mount
%{_presetdir}/90-senemos-nabu.preset
%dir %{_unitdir}/iio-sensor-proxy.service.d
%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
%{_udevrulesdir}/81-nabu-suspend-wake.rules
%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
%config(noreplace) %{_sysconfdir}/xdg/fastfetch/config.jsonc

%changelog
* Fri Aug 28 2026 SENEMOS Project <senemos@localhost> - 1.4.0.2-1.test
- Split the device runtime payload from the desktop metapackage source.
- Quiesce the ADSP FastRPC root process together with SLPI sensor clients
  before sleep and restore only services that were previously active.
- Run the DSP sleep hook even when the SDSP FastRPC node is temporarily absent.
