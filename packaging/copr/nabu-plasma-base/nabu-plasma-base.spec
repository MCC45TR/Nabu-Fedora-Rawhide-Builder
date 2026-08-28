%global debug_package %{nil}
Name:           nabu-plasma-base
Version:        1.1.0
Release:        1%{?dist}
Summary:        Stock KDE Plasma desktop foundation for Nabu
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        95-nabu-plasma-login.preset
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-abi = 1
Requires:       nabu-core-branch
Requires:       nabu-kde-config >= 1.4.0.1-11.test
Requires:       nabu-kde-widgets
Requires:       nabu-plasma-login-theme-abi = 1
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Recommends:     nabu-kde-l10n >= 1.1.0-1.test
Recommends:     nabu-plasma-setup-l10n >= 1.1.0-1.test
Recommends:     nabu-desktop-migration >= 1.0.0-1
Requires:       plasma-workspace
Requires:       plasma-desktop
Requires:       kwin
Requires:       kscreen
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       kcm-plasmalogin
Requires:       plasma-systemsettings
Requires:       kde-gtk-config
Requires:       xsettingsd
Requires:       breeze-gtk-gtk3
Requires:       breeze-gtk-gtk4
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       bluedevil
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       plasma-setup(aarch-64)
Conflicts:      nabu-plasma-mobile-setup
Conflicts:      kcm_wacomtablet
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-plasma-base-abi = 1
Conflicts:      nabu-desktop-session
Obsoletes:      nabu-kde-meta < %{version}-%{release}
Provides:       nabu-kde-meta = %{version}-%{release}

%description
Fedora's stock KDE Plasma desktop and Plasma Login Manager with independent
Nabu integration. Legacy Qt5 cleanup is never part of a normal DNF upgrade.

%prep
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_presetdir}/95-nabu-plasma-login.preset

%files
%{_presetdir}/95-nabu-plasma-login.preset

%post
%systemd_post plasmalogin.service plasma-setup.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
fi

%preun
%systemd_preun plasmalogin.service plasma-setup.service

%postun
%systemd_postun_with_restart plasmalogin.service plasma-setup.service

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Decouple the Plasma manifest from the former repository-wide release counter.
- Require component ABIs instead of unrelated minimum EVRs.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Remove the mandatory broad Qt5 and KF5 obsoletes transition.
- Link independent components through stable virtual ABI capabilities.
