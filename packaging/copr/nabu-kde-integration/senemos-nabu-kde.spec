%global debug_package %{nil}
Name:           nabu-kde-integration
Version:        1.4.0.1
Release:        8.test%{?dist}
Summary:        KDE Plasma integration for Xiaomi Pad 5 (nabu)
License:        MIT
URL:            https://github.com/mcc45tr
Source0:        nabu-kde-debug-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

Requires:       nabu-runtime-integration = %{version}-%{release}
Requires:       nabu-kde-config = %{version}-%{release}
Requires:       nabu-kde-widgets >= 1.0.1
Requires:       nabu-kde-l10n >= 1.0.0-1.test
Requires:       plasma-workspace
Requires:       kwin >= 6.7.4
Requires:       plasma-login-manager
Requires:       plasma-welcome
Requires:       plasma-setup
Requires:       plasma-discover
Requires:       PackageKit
Requires:       kinfocenter
Requires:       kde-connect
Requires:       ark
Requires:       gwenview
Requires:       okular
Requires:       system-config-printer
Requires:       kwalletmanager5
Requires:       plasma-milou
Requires:       plasma-keyboard
Requires:       libcanberra-backend-pulse
Requires:       mesa-vulkan-drivers
Requires:       vulkan-tools
Requires:       fastfetch

%description
Single-install metapackage for the supported KDE Plasma experience on Xiaomi
Pad 5 (nabu). It brings together the desktop integration, configuration and
tablet-oriented applications while keeping hardware-specific binaries separate
and individually auditable.

%package -n nabu-runtime-integration
Summary:        SENEMOS Nabu system and suspend integration
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

%description -n nabu-runtime-integration
Device-level userspace integration for Nabu: PMIC RTC synchronization, orderly
SLPI client quiescing across sleep, display recovery, wake-source policy,
boot-noise cleanup, hardware identity and shared diagnostics.

%package -n nabu-kde-config
Summary:        SENEMOS KDE profile for Xiaomi Mi Pad 5 (nabu)
Requires:       nabu-runtime-integration = %{version}-%{release}
Requires:       bash
Requires:       kscreen
Requires:       kwin
Requires:       pipewire-utils
Requires:       wireplumber
Requires:       python3

%description -n nabu-kde-config
KDE-specific Nabu policy using Fedora's stock KWin, standard sensor interfaces
and a stable screen-relative PipeWire sink that avoids device-added OSD churn
during display rotation.

%prep
%autosetup -n nabu-kde-debug-%{version}

%build

%install
install -Dm0755 runtime/nabu-pmic-rtc-sync \
    %{buildroot}%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
install -Dm0755 runtime/nabu-slpi-suspend \
    %{buildroot}%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
install -Dm0755 runtime/nabu-sensor-registry-runtime \
    %{buildroot}%{_libexecdir}/senemos-nabu/nabu-sensor-registry-runtime
install -Dm0755 runtime/senemos-nabu-status \
    %{buildroot}%{_bindir}/senemos-nabu-status
install -Dm0644 runtime/nabu-pmic-rtc-sync.service \
    %{buildroot}%{_unitdir}/nabu-pmic-rtc-sync.service
install -Dm0644 runtime/nabu-slpi-suspend.service \
    %{buildroot}%{_unitdir}/nabu-slpi-suspend.service
install -Dm0644 runtime/nabu-sensor-registry-runtime.service \
    %{buildroot}%{_unitdir}/nabu-sensor-registry-runtime.service
install -Dm0644 runtime/mnt-vendor-persist.mount \
    %{buildroot}%{_unitdir}/mnt-vendor-persist.mount
install -Dm0644 runtime/90-senemos-nabu.preset \
    %{buildroot}%{_presetdir}/90-senemos-nabu.preset
install -Dm0644 runtime/10-nabu-sensor-stack.conf \
    %{buildroot}%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
install -Dm0644 runtime/20-nabu-runtime-registry.conf \
    %{buildroot}%{_unitdir}/hexagonrpcd-sdsp.service.d/20-nabu-runtime-registry.conf
install -Dm0644 runtime/90-nabu-compositor-realtime.conf \
    %{buildroot}%{_unitdir}/user@.service.d/90-nabu-compositor-realtime.conf
install -Dm0644 runtime/80-nabu-disable-efi-rtc-wakeup.rules \
    %{buildroot}%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
install -Dm0644 runtime/81-nabu-suspend-wake.rules \
    %{buildroot}%{_udevrulesdir}/81-nabu-suspend-wake.rules
install -Dm0644 runtime/90-nabu-unneeded-storage.conf \
    %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
install -Dm0644 runtime/90-nabu-mcc45tr.hwdb \
    %{buildroot}%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
install -Dm0644 runtime/fastfetch-config.jsonc \
    %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc

install -Dm0755 kde/nabu-audio-orientation \
    %{buildroot}%{_libexecdir}/senemos-nabu/nabu-audio-orientation
install -Dm0755 kde/senemos-nabu-display-profile \
    %{buildroot}%{_bindir}/senemos-nabu-display-profile
install -Dm0644 kde/nabu-audio-orientation.service \
    %{buildroot}%{_userunitdir}/nabu-audio-orientation.service
install -Dm0644 kde/90-nabu-kde.preset \
    %{buildroot}%{_userpresetdir}/90-nabu-kde.preset
install -Dm0644 kde/90-senemos-nabu-startupsound.conf \
    %{buildroot}%{_userunitdir}/plasma-startupsound.service.d/90-senemos-nabu.conf
install -Dm0644 kde/kwinoutputconfig.json \
    %{buildroot}%{_sysconfdir}/xdg/kwinoutputconfig.json
install -Dm0644 kde/powerdevilrc \
    %{buildroot}%{_sysconfdir}/xdg/powerdevilrc

%pretrans -n nabu-runtime-integration
/usr/bin/mkdir -p /mnt/vendor/persist || :

%post -n nabu-runtime-integration
%systemd_post nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-registry-runtime.service mnt-vendor-persist.mount
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%preun -n nabu-runtime-integration
%systemd_preun nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-registry-runtime.service mnt-vendor-persist.mount

%postun -n nabu-runtime-integration
%systemd_postun nabu-pmic-rtc-sync.service nabu-slpi-suspend.service nabu-sensor-registry-runtime.service mnt-vendor-persist.mount
if [ -x /usr/bin/systemd-hwdb ]; then
    /usr/bin/systemd-hwdb update || :
fi

%posttrans -n nabu-runtime-integration
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
            /usr/bin/systemctl restart \
                nabu-sensor-registry-runtime.service >/dev/null 2>&1 || :
            /usr/bin/systemctl restart \
                hexagonrpcd-sdsp.service >/dev/null 2>&1 || :
            /usr/bin/systemctl start \
                hexagonrpcd-adsp-rootpd.service >/dev/null 2>&1 || :
            /usr/bin/udevadm control --reload >/dev/null 2>&1 || :
            /usr/bin/udevadm trigger --action=change \
                --subsystem-match=misc --sysname-match='fastrpc-*' >/dev/null 2>&1 || :
            /usr/bin/systemctl restart iio-sensor-proxy.service >/dev/null 2>&1 || :
            ;;
    esac
fi

%post -n nabu-kde-config
%systemd_user_post nabu-audio-orientation.service

%preun -n nabu-kde-config
%systemd_user_preun nabu-audio-orientation.service

%postun -n nabu-kde-config
%systemd_user_postun_with_restart nabu-audio-orientation.service

%files
%license LICENSE
%doc README.md

%files -n nabu-runtime-integration
%license LICENSE
%doc README.md
%{_bindir}/senemos-nabu-status
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-pmic-rtc-sync
%{_libexecdir}/senemos-nabu/nabu-slpi-suspend
%{_libexecdir}/senemos-nabu/nabu-sensor-registry-runtime
%{_unitdir}/nabu-pmic-rtc-sync.service
%{_unitdir}/nabu-slpi-suspend.service
%{_unitdir}/nabu-sensor-registry-runtime.service
%{_unitdir}/mnt-vendor-persist.mount
%{_presetdir}/90-senemos-nabu.preset
%dir %{_unitdir}/iio-sensor-proxy.service.d
%{_unitdir}/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf
%dir %{_unitdir}/hexagonrpcd-sdsp.service.d
%{_unitdir}/hexagonrpcd-sdsp.service.d/20-nabu-runtime-registry.conf
%dir %{_unitdir}/user@.service.d
%{_unitdir}/user@.service.d/90-nabu-compositor-realtime.conf
%{_udevrulesdir}/80-nabu-disable-efi-rtc-wakeup.rules
%{_udevrulesdir}/81-nabu-suspend-wake.rules
%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-unneeded-storage.conf
%{_udevhwdbdir}/90-nabu-mcc45tr.hwdb
%config(noreplace) %{_sysconfdir}/xdg/fastfetch/config.jsonc

%files -n nabu-kde-config
%license LICENSE
%doc README.md
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-audio-orientation
%{_bindir}/senemos-nabu-display-profile
%{_userunitdir}/nabu-audio-orientation.service
%{_userpresetdir}/90-nabu-kde.preset
%dir %{_userunitdir}/plasma-startupsound.service.d
%{_userunitdir}/plasma-startupsound.service.d/90-senemos-nabu.conf
%config(noreplace) %{_sysconfdir}/xdg/kwinoutputconfig.json
%config(noreplace) %{_sysconfdir}/xdg/powerdevilrc

%changelog
* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 1.4.0.1-8.test
- Allow the user service manager only the minimum real-time priority requested
  by stock KWin for compositor, input and DRM commit scheduling.
- Keep KWin's upstream dynamic double/triple-buffering policy unchanged.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 1.4.0.1-7.test
- Serve the downstream SSC registry from a volatile writable copy so the DSP
  can create temporary registry files without modifying Android persist or the
  packaged firmware payload.
- Delay SensorProxy until the Type=simple HexagonRPC listener has had time to
  publish the SSC QRTR service.
- Recreate the volatile registry and restart only the sensor FastRPC listener
  during a live package upgrade so the new root takes effect without rebooting.

* Sun Aug 23 2026 SENEMOS Project <senemos@localhost> - 1.4.0.1-6.test
- Keep the reusable Nabu KDE configuration independent of a particular
  display manager so Plasma Mobile can use Plasma Login Manager without
  pulling SDDM or the Plasma Desktop session.
- Record physically stable automatic rotation and ambient-light brightness
  behavior with the standard SensorProxy, KWin and PowerDevil path.

* Sat Aug 22 2026 SENEMOS Project <senemos@localhost> - 1.4.0.1-4.test
- Require Fedora's stock KWin and reject downstream KWin builds.
- Keep the seeded output state empty and leave rotation, brightness, scale,
  and refresh selection to standard desktop and DRM interfaces.

* Sat Aug 22 2026 SENEMOS Project <senemos@localhost> - 1.4.0.1-3.test
- Treat an available but unclaimed SensorProxy accelerometer as a valid
  headless or display-manager state; retain physical tilt validation for an
  active desktop claim.

* Sat Aug 22 2026 SENEMOS Project <senemos@localhost> - 1.4.0.1-2.test
- Select the installed kernel provider that owns the currently booted image.
- Resolve Nabu hardware RPMs through their generic capabilities.
- Report live SLPI, FastRPC, SensorProxy ALS-in-lux, accelerometer, and mount
  matrix state without desktop-specific helper scripts.

* Sat Aug 22 2026 SENEMOS Project <senemos@localhost> - 1.4.0.1-1.test
- Preserve SLPI client restore markers across interrupted resume attempts.
- Validate the running Nabu kernel through its exact RPM capability instead of
  a stale hard-coded release string.
- Begin the v1.4.0.1 sequential release naming scheme.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-13.test
- Add user-selectable native, FHD-class, and HD-class logical display profiles.
- Keep the fixed-timing 2560 by 1600 panel mode unchanged to avoid unsafe
  non-native DSI timings and preserve the panel's native 16:10 aspect ratio.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-12.test
- Stop seeding a complete KWin output state so KWin can calculate 185 percent
  automatically from the kernel-provided 148 by 236 mm panel dimensions.
- Delegate the initial rotation and ambient-brightness policies to the narrow
  SENEMOS KWin tablet-default patch; preserve subsequent user choices.
- Remove the superseded one-time fixed-scale migration.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-11.test
- Remove the obsolete scsi_dh.conf initramfs request.
- Add a one-time 200 percent scale migration for existing test installations.
- Never override scale again after the migration marker is written.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-10.test
- Seed a 200 percent KWin scale for the first Nabu Plasma session.
- Keep scale user-configurable after the initial profile is created.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-9.test
- Keep the runtime dependency compatible with future SENEMOS Nabu kernels.
- Stop loading absent SCSI device-handler modules during early boot.
- Retain native KWin Always rotation and automatic-brightness XDG defaults.

* Fri Aug 21 2026 SENEMOS Project <senemos@localhost> - 1.0.0-8.test
- Remove duplicate SDDM and session-time kscreen orientation scripts.
- Trust the kernel panel rotation property and KWin automatic rotation.
- Remove the scripted DPMS bounce from the suspend resume path.

* Thu Aug 20 2026 SENEMOS Project <senemos@localhost> - 1.0.0-7.test
- Keep the generic sensor runtime free of KDE/kscreen dependencies; package
  the observed KWin panel recovery only in the KDE profile.

* Thu Aug 20 2026 SENEMOS Project <senemos@localhost> - 1.0.0-6.test
- Use kernel SLPI auto-start instead of a boot-order shell helper.
- Seed KWin auto-rotation and automatic brightness through XDG defaults.
- Seed the safe lid policy through KConfig defaults instead of an autostart script.

* Thu Aug 20 2026 SENEMOS Project <senemos@localhost> - 1.0.0-5.test
- Keep the live persist mount outside the RPM file payload during FOTA updates

* Thu Aug 20 2026 SENEMOS Project <senemos@localhost> - 1.0.0-4.test
- Start SLPI before the libssc sensor stack and expose the SDSP device reliably
- Mount the Android sensor calibration partition read-only before SLPI startup
- Disable the invalid ADSP SensorPD daemon on Nabu

* Sat Aug 15 2026 SENEMOS Project <senemos@localhost> - 1.0.0-3.test
- Start the Qualcomm sensor daemons and SensorProxy deterministically after FOTA
- Pull the complete Plasma Setup language restoration package

* Sat Aug 15 2026 SENEMOS Project <senemos@localhost> - 1.0.0-1
- Initial COPR-ready Rawhide package set for Nabu KDE fixes
