%global debug_package %{nil}

Name:           nabu-repository-config
Version:        1.0.0
Release:        15.test%{?dist}
Summary:        COPR repository definition and profiles for Nabu Linux
License:        MIT AND GPL-2.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-linux-copr.repo
Source1:        90-nabu-disable-cisco-openh264.repo
Source2:        plasma-mobile.desktop
Source3:        20-nabu-mobile-session.conf
Source4:        90-nabu-mobile-login.conf
Source5:        95-nabu-plasma-mobile.preset
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

%description
Installs the signed Nabu Linux COPR definition and selects the matching Fedora
release automatically. The repository publishes the Nabu hardware stack and
desktop profiles for Fedora 44, 45 and Rawhide on AArch64; Fedora remains
the source for general-purpose distribution dependencies.

%package -n nabu-meta
Summary:        Core operating-system and hardware stack for Nabu
Requires:       nabu-repository-config = %{version}-%{release}
Requires:       senemos-nabu-kernel >= 1.4.0.3
Requires:       nabu-uki-config
Requires:       nabu-systemd-boot-config
Requires:       nabu-core-config
Requires:       nabu-device-config
Requires:       nabu-zram-compat
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu
Requires:       python3-ssc-nabu
Requires:       iio-sensor-proxy-nabu
Requires:       nabu-audio-config
Requires:       nabu-runtime-integration
Requires:       senemos-nabu-plymouth >= 1.0.0-3.test

%description -n nabu-meta
Coherent base profile for a Fedora installation on Xiaomi Pad 5 (nabu). It
brings together the Nabu kernel, boot integration, device policy, audio and
sensor userspace. Proprietary device firmware is never redistributed and must
be supplied from an authorized source.

%package -n nabu-kde-meta
Summary:        KDE desktop foundation for Nabu
Requires:       nabu-meta = %{version}-%{release}
Requires:       nabu-kde-integration >= 1.0.0-3.test
Requires:       nabu-kde-l10n >= 1.0.0-4.test
Requires:       nabu-kde-widgets
Requires:       glibc-all-langpacks
Requires:       plasma-workspace
Requires:       kwin
Requires:       kscreen
Requires:       sddm
Requires:       sddm-wayland-plasma
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       maliit-framework
Requires:       maliit-keyboard
Requires:       plasma-setup
Requires:       plasma-welcome
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       kinfocenter

%description -n nabu-kde-meta
KDE Plasma desktop foundation for Xiaomi Pad 5 (nabu), including first-run,
software-management and accessibility components appropriate for a tablet.
Profile names describe their contents rather than an internal test state.

%package -n nabu-gnome-meta
Summary:        GNOME desktop foundation for Nabu
Requires:       nabu-meta = %{version}-%{release}
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       gnome-software
Requires:       gnome-terminal
Requires:       nautilus
Requires:       mutter
Requires:       gnome-settings-daemon

%description -n nabu-gnome-meta
GNOME desktop foundation for Xiaomi Pad 5 (nabu). Device firmware remains
separate from this package and must be installed from an authorized source
before sensor hardware is considered complete.

%package -n nabu-kde-plasma-minimal
Summary:        Minimal Plasma tablet profile for Nabu
Requires:       nabu-kde-meta = %{version}-%{release}
Requires:       dolphin
Requires:       konsole

%description -n nabu-kde-plasma-minimal
Focused Plasma tablet profile with the essential shell, first-run, file and
terminal tools required for a practical Nabu installation.

%package -n nabu-kde-plasma-optimal
Summary:        Supported debloated Plasma tablet profile for Nabu
Requires:       nabu-kde-plasma-minimal = %{version}-%{release}
Requires:       kde-connect
Requires:       ark
Requires:       gwenview
Requires:       okular
Requires:       system-config-printer
Requires:       kwalletmanager5
Requires:       plasma-milou
Requires:       kate
Requires:       kwrite
Requires:       nano
Requires:       fastfetch
Requires:       plasma-systemmonitor
Conflicts:      kcm_wacomtablet

%description -n nabu-kde-plasma-optimal
Recommended Plasma tablet profile for Nabu. It adds daily desktop, diagnostics
and productivity tools while deliberately omitting the unsupported Wacom KCM.

%package -n nabu-kde-plasma-full
Summary:        Full Plasma desktop profile for Nabu
Requires:       nabu-kde-plasma-optimal = %{version}-%{release}
Requires:       spectacle
Requires:       filelight
Requires:       khelpcenter
Requires:       kio-admin
Requires:       kio-extras
Requires:       krdc
Requires:       krfb
Requires:       plasma-browser-integration
Requires:       plasma-disks
Requires:       plasma-vault
Requires:       kdeplasma-addons

%description -n nabu-kde-plasma-full
Expanded Plasma desktop profile for users who prefer the wider KDE toolset,
including remote-desktop, storage, browser integration and desktop add-ons.

%package -n nabu-kde-plasma-mobile
Summary:        Plasma Mobile foundation and single-session login policy for Nabu
Requires:       nabu-meta = %{version}-%{release}
Requires:       nabu-runtime-integration >= 1.4.0.1-6.test
Requires:       nabu-kde-config >= 1.4.0.1-6.test
Requires:       nabu-kde-l10n >= 1.0.0-4.test
Requires:       nabu-kde-widgets
Requires:       glibc-all-langpacks
Requires:       plasma-workspace
Requires:       plasma-mobile
Requires:       plasma-login-manager
Requires:       kcm-plasmalogin
Requires:       plasma-setup
Requires:       plasma-systemsettings
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       kinfocenter
Requires:       kwin
Requires:       kscreen
Requires:       powerdevil
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       maliit-framework
Requires:       maliit-keyboard
Conflicts:      nabu-kde-meta
Conflicts:      nabu-kde-integration
Conflicts:      nabu-kde-plasma-minimal
Conflicts:      nabu-kde-plasma-optimal
Conflicts:      nabu-kde-plasma-full
Conflicts:      sddm
Conflicts:      sddm-wayland-plasma
Conflicts:      gwenview
Conflicts:      kate
Conflicts:      konsole
Obsoletes:      nabu-kde-meta < %{version}-%{release}
Obsoletes:      nabu-kde-integration < 1.4.0.1-6.test
Obsoletes:      nabu-kde-plasma-minimal < %{version}-%{release}
Obsoletes:      nabu-kde-plasma-optimal < %{version}-%{release}
Obsoletes:      nabu-kde-plasma-full < %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-shell = %{version}-%{release}

%description -n nabu-kde-plasma-mobile
Nabu's shared Plasma Mobile shell, first-run setup and login stack. Plasma
Setup runs before the display manager, Plasma Login Manager replaces SDDM,
and its private mount namespace exposes only the Plasma Mobile session.

%package -n nabu-kde-plasma-mobile-minimal
Summary:        Lightweight Plasma Mobile application profile for Nabu
Requires:       nabu-kde-plasma-mobile = %{version}-%{release}
Requires:       maui-mauikit-index-fm
Requires:       koko
Requires:       kwrite
Requires:       qmlkonsole
Conflicts:      nabu-kde-plasma-mobile-optimal
Provides:       nabu-kde-plasma-mobile-profile = %{version}-%{release}

%description -n nabu-kde-plasma-mobile-minimal
Lightweight touch-first Nabu profile with Index, KDE Photos, KWrite and
QMLKonsole.

%package -n nabu-kde-plasma-mobile-optimal
Summary:        Optimal Plasma Mobile application profile for Nabu tablets
Requires:       nabu-kde-plasma-mobile = %{version}-%{release}
Requires:       dolphin
Requires:       angelfish
Requires:       koko
Requires:       kwrite
Requires:       kweather
Requires:       kclock
Requires:       kalk
Requires:       qmlkonsole
Requires:       elisa-player
Requires:       kde-connect
Requires:       ark
Requires:       okular
Requires:       system-config-printer
Requires:       kwalletmanager5
Requires:       plasma-milou
Requires:       nano
Requires:       fastfetch
Requires:       plasma-systemmonitor
Conflicts:      nabu-kde-plasma-mobile-minimal
Provides:       nabu-kde-plasma-mobile-profile = %{version}-%{release}

%description -n nabu-kde-plasma-mobile-optimal
The supported touch-first Nabu tablet profile. It retains Dolphin and the
optimal utility set while using Angelfish, KDE Photos, KWrite, KWeather,
KClock, Kalk, QMLKonsole and Elisa instead of desktop-oriented alternatives.

%prep

%build

%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
install -Dm0644 %{SOURCE2} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE3} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE4} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE5} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
%config(noreplace) %{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo

%files -n nabu-meta
%files -n nabu-kde-meta
%files -n nabu-gnome-meta
%files -n nabu-kde-plasma-minimal
%files -n nabu-kde-plasma-optimal
%files -n nabu-kde-plasma-full

%files -n nabu-kde-plasma-mobile
%dir %{_datadir}/nabu-plasma-mobile
%dir %{_datadir}/nabu-plasma-mobile/wayland-sessions
%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
%dir %{_unitdir}/plasmalogin.service.d
%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
%dir %{_prefix}/lib/plasmalogin
%dir %{_prefix}/lib/plasmalogin/plasmalogin.conf.d
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
%{_presetdir}/95-nabu-plasma-mobile.preset

%post -n nabu-kde-plasma-mobile
%systemd_post plasmalogin.service plasma-setup.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
fi

%preun -n nabu-kde-plasma-mobile
%systemd_preun plasmalogin.service plasma-setup.service

%postun -n nabu-kde-plasma-mobile
%systemd_postun_with_restart plasmalogin.service plasma-setup.service

%files -n nabu-kde-plasma-mobile-minimal

%files -n nabu-kde-plasma-mobile-optimal

%changelog
* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 1.0.0-15.test
- Retire Fedora 43 and retain Fedora 44, Fedora 45 and Rawhide AArch64.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-14.test
- Keep Fedora's plasma-desktop package as the plasmashell provider required by
  plasma-workspace; the Plasma Login Manager mount namespace still exposes
  only the packaged Plasma Mobile session.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-13.test
- Require the integrated v1.4.0.3 kernel meta package by its published name.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-12.test
- Add integrated Plasma Mobile common, minimal and optimal profiles.
- Replace SDDM with Plasma Login Manager and isolate its session directory so
  the greeter exposes only Plasma Mobile while Plasma Setup remains a separate
  first-boot service.
- Use Index, KDE Photos, KWrite and QMLKonsole in the minimal profile.
- Retain Dolphin in the optimal profile and add Angelfish, KDE Photos,
  KWeather, KClock, Kalk, QMLKonsole and Elisa.
- Require the v1.4.0.3 Nabu kernel family.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-11.test
- Select the matching Fedora COPR repository path for Fedora 43, 44, 45 and
  Rawhide instead of hard-coding Rawhide.
- Clarify the Nabu hardware, desktop-profile and firmware boundaries.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-10.test
- Disable Fedora's Cisco OpenH264 repository through the supported DNF5 repo
  override mechanism because its Rawhide metadata currently serves an fc45
  package that cannot be verified with the Fedora 46 signing key.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-9.test
- Keep the native Nabu Plymouth theme in every supported desktop profile.
- Require the localization payload that restores the Plasma Shell catalogs
  used by Plasma Setup's language selector.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-8.test
- Require the current v1.4.0.2 Nabu kernel family instead of the obsolete
  v1.21 package names.
- Keep KDE profiles on Fedora's stock KWin through the integration package.

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-7.test
- Require complete Plasma Setup language catalogs and the sensor-start FOTA

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-6.test
- Add the shared Nabu core hardware meta package and link desktop profiles to it

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-5.test
- Keep Plasma's required libwacom runtime while omitting the Wacom settings KCM

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-4.test
- Decouple the KDE integration EVR from this repository/meta source package.

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-2
- Publish one test repository definition and desktop-neutral profile names.
