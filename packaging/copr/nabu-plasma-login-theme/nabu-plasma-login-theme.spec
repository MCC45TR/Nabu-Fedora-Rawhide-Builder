%global debug_package %{nil}
Name:           nabu-plasma-login-theme
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Nabu branding for Plasma Login Manager
License:        GPL-2.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        80-nabu-plasma-login-theme.conf
Source1:        nabu-plasma-login.svg
BuildArch:      noarch
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Provides:       nabu-plasma-login-theme-abi = 1

%description
Device-specific managed defaults and scalable background for Fedora's stock
Plasma Login Manager. No Fedora or KDE package is modified or replaced.

%prep
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
install -Dm0644 %{SOURCE1} %{buildroot}%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg

%files
%dir %{_datadir}/backgrounds/nabu
%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Publish the login theme as an independent source package with ABI metadata.

