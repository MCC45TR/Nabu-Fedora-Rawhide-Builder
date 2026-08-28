%global debug_package %{nil}
Name:           nabu-repository-config
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Signed COPR repository definition for Nabu Linux
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-linux-copr.repo
Source1:        90-nabu-disable-cisco-openh264.repo
BuildArch:      noarch

%description
Installs the single signed Nabu Linux COPR definition and selects the matching
Fedora release automatically. Desktop, branch and migration policy live in
independent source packages so repository updates cannot force unrelated
desktop replacement transactions.

%prep
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
%config(noreplace) %{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Split repository configuration from desktop and CORE policy packages.

