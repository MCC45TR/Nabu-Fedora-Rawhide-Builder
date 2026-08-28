%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           kde-plasma-mobile-nabu-meta
Version:        2.0.0
Release:        3%{?dist}
Summary:        Complete KDE Plasma Mobile release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        plasma-mobile.desktop
Source1:        20-nabu-mobile-session.conf
Source2:        90-nabu-mobile-login.conf
Source3:        95-nabu-plasma-mobile.preset
Source4:        80-nabu-plasma-login-theme.conf
Source5:        nabu-plasma-login.svg
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-meta >= 2.0.0
Requires:       nabu-system-integration >= 2.0.0-5.test
Requires:       nabu-kde-config >= 1.4.0.1-12.test
Requires:       nabu-kde-widgets >= 1.0.1-3.test
Requires:       nabu-kde-color-profiles
Requires:       nabu-flashlight-integration-plasma
Requires:       glibc-all-langpacks
Requires:       nabu-language-support >= 1.1.0-1.test
Requires:       nabu-kde-l10n >= 1.1.0-1.test
Requires:       plasma-workspace
Requires:       plasma-mobile
Requires:       plasma-mobile-sounds
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       plasma-settings
Requires:       kwin
Requires:       kscreen
Requires:       kscreenlocker
Requires:       powerdevil
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       bluedevil
Requires:       NetworkManager
Requires:       mesa-dri-drivers
Requires:       mesa-vulkan-drivers
Requires:       mesa-libEGL
Requires:       libglvnd-egl
Requires:       libglvnd-gles
Requires:       libglvnd-glx
Requires:       xorg-x11-server-Xwayland
Requires:       openssh-clients
Requires:       openssh-server
Requires:       plasma-discover
Requires:       plasma-discover-notifier
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       qmlkonsole
Requires:       dolphin
Requires:       angelfish
Requires:       koko
Requires:       kweather
Requires:       kclock
Requires:       kalk
Requires:       elisa-player
Requires:       kde-connect
Requires:       okular-mobile
Requires:       chromium
Requires:       nano
Requires:       fastfetch
Conflicts:      nabu-desktop-profile-meta
Conflicts:      nabu-plasma-mobile-setup
Conflicts:      plasma-desktop
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       plasmashell
Provides:       nabu-kde-mobile-base-abi = 2
Provides:       nabu-plasma-login-theme-abi = 2
Provides:       nabu-kde-plasma-mobile = %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-optimal = %{version}-%{release}
Obsoletes:      nabu-kde-mobile-base < %{legacy_meta_max}
Obsoletes:      nabu-kde-mobile-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-kde-mobile-optimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-plasma-login-theme < %{legacy_meta_max}
Obsoletes:      nabu-desktop-migration < %{legacy_meta_max}
Obsoletes:      nabu-plasma-mobile-setup < %{legacy_meta_max}

%description
The only KDE Plasma Mobile manifest for Nabu. It combines the mobile session,
former optimal application set, Nabu integration, login branding and hard
locale dependencies. It uses unmodified Fedora and KDE packages and never
claims to replace plasma-desktop.

%prep
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE1} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE2} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset
install -Dm0644 %{SOURCE4} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
install -Dm0644 %{SOURCE5} %{buildroot}%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
install -d %{buildroot}%{_datadir}/nabu-plasma-mobile/xsessions

%files
%dir %{_datadir}/nabu-plasma-mobile
%dir %{_datadir}/nabu-plasma-mobile/wayland-sessions
%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
%dir %{_datadir}/nabu-plasma-mobile/xsessions
%dir %{_unitdir}/plasmalogin.service.d
%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
%dir %{_prefix}/lib/plasmalogin
%dir %{_prefix}/lib/plasmalogin/plasmalogin.conf.d
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
%{_presetdir}/95-nabu-plasma-mobile.preset
%dir %{_datadir}/backgrounds/nabu
%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg

%post
%systemd_post plasmalogin.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable plasma-setup.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sshd.service >/dev/null 2>&1 || :
fi
%preun
%systemd_preun plasmalogin.service
%postun
%systemd_postun_with_restart plasmalogin.service

%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Keep Plasma Mobile on the independent Nabu KDE configuration payload; the
  desktop integration meta requires plasma-setup and plasma-desktop.
- Provide the plasmashell capability directly for the mobile shell.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Match the KDE integration/configuration EVRs retained in the live COPR.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Merge Plasma Mobile base, optimal profile, session and login branding.
- Require complete locale support and stop obsoleting Fedora/KDE packages.
