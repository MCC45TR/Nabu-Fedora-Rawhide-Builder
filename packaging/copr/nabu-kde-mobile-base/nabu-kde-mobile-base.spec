%global debug_package %{nil}
Name: nabu-kde-mobile-base
Version: 1.1.0
Release: 1%{?dist}
Summary: KDE Plasma Mobile session foundation for Nabu
License: MIT
URL: https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0: plasma-mobile.desktop
Source1: 20-nabu-mobile-session.conf
Source2: 90-nabu-mobile-login.conf
Source3: 95-nabu-plasma-mobile.preset
BuildArch: noarch
BuildRequires: systemd-rpm-macros
Requires: nabu-core-abi = 1
Requires: nabu-core-branch
Requires: nabu-system-integration >= 2.0.0-5.test
Requires: nabu-kde-config >= 1.4.0.1-6.test
Requires: nabu-plasma-login-theme-abi = 1
Requires: glibc-all-langpacks
Recommends: nabu-language-support >= 1.1.0-1.test
Recommends: nabu-kde-l10n >= 1.1.0-1.test
Requires: plasma-workspace
Requires: plasma-mobile
Requires: plasma-mobile-sounds
Requires: plasma-login-manager
Requires: kde-settings-plasmalogin
Requires: plasma-settings
Requires: kwin
Requires: kscreen
Requires: kscreenlocker
Requires: powerdevil
Requires: plasma-nm
Requires: plasma-pa
Requires: plasma-keyboard
Requires: bluedevil
Requires: NetworkManager
Requires: mesa-dri-drivers
Requires: mesa-vulkan-drivers
Requires: mesa-libEGL
Requires: libglvnd-egl
Requires: libglvnd-gles
Requires: libglvnd-glx
Requires: xorg-x11-server-Xwayland
Requires: openssh-clients
Requires: openssh-server
Conflicts: nabu-plasma-mobile-setup
Conflicts: plasma-setup
Conflicts: plasma-desktop
Provides: plasmashell
Obsoletes: plasma-desktop < 7
Obsoletes: nabu-plasma-mobile-setup < 1:6.7.4-1.nabu3
Obsoletes: nabu-kde-plasma-mobile-base < %{version}-%{release}
Provides: nabu-kde-plasma-mobile-base = %{version}-%{release}
Provides: nabu-desktop-session = %{version}-%{release}
Provides: nabu-kde-mobile-base-abi = 1
Conflicts: nabu-desktop-session

%description
Nabu Plasma Mobile shell and stock Plasma Login Manager stack. Automatic Qt5
or KF5 removal is not part of normal upgrades.

%prep
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE1} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE2} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset
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
%{_presetdir}/95-nabu-plasma-mobile.preset

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
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt the independent session-manifest version and ABI.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Publish the Plasma Mobile base independently without broad transition metadata.
