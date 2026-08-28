%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           kde-plasma-nabu-meta
Version:        2.0.0
Release:        3%{?dist}
Summary:        Complete KDE Plasma release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        95-nabu-plasma-login.preset
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-meta >= 2.0.0
Requires:       nabu-kde-integration >= 1.4.0.1-12.test
Requires:       nabu-kde-config >= 1.4.0.1-12.test
Requires:       nabu-kde-widgets >= 1.0.1-3.test
Requires:       nabu-kde-color-profiles
Requires:       nabu-flashlight-integration-plasma
Requires:       nabu-plasma-login-theme-abi = 1
# Locale is a hard release contract, never a weak recommendation.
Requires:       glibc-all-langpacks
Requires:       nabu-language-support >= 1.1.0-1.test
Requires:       nabu-kde-l10n >= 1.1.0-1.test
Requires:       nabu-plasma-setup-l10n >= 1.1.0-1.test
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
Requires:       plasma-setup(aarch-64)
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       PackageKit
Requires:       konsole
Requires:       dolphin
Requires:       kde-connect
Requires:       ark
Requires:       gwenview
Requires:       okular
Requires:       system-config-printer
Requires:       kwalletmanager5
Requires:       plasma-milou
Requires:       kwrite
Requires:       spectacle
Requires:       nano
Requires:       fastfetch
Requires:       plasma-systemmonitor
Conflicts:      nabu-desktop-profile-meta
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-plasma-base-abi = 2
Provides:       nabu-kde-meta = %{version}-%{release}
Provides:       nabu-kde-plasma-optimal = %{version}-%{release}
Provides:       nabu-kde-plasma-full = %{version}-%{release}
Obsoletes:      nabu-plasma-base < %{legacy_meta_max}
Obsoletes:      nabu-plasma-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-plasma-optimal-meta < %{legacy_meta_max}

%description
The only KDE Plasma desktop manifest for Nabu. It contains the formerly
optimal application set, stock Fedora/KDE session packages, Nabu integration,
login branding and mandatory Turkish/English-capable locale payloads. No KDE
or Fedora package is forked, replaced or obsoleted.

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
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Keep the shared login theme as an implementation RPM so desktop and mobile
  manifests never compete to obsolete the same installed package.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Match the newest KDE integration and configuration EVRs actually retained in
  the COPR so clean AArch64 installations remain solvable.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Merge Plasma base, optimal profile, login theme and migration ownership.
- Make all Nabu locale packages hard dependencies.
