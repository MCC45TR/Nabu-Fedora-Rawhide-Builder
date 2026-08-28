%global debug_package %{nil}
Name:           nabu-desktop-migration
Version:        1.0.0
Release:        1%{?dist}
Summary:        Explicit and conservative Nabu desktop migration helper
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-desktop-migrate
BuildArch:      noarch
Requires:       bash
Requires:       coreutils
Requires:       dnf5
Requires:       nabu-branch-manager >= 1.1.0-1

%description
Provides explicitly invoked desktop migrations. Candidates must be both on a
maintained allowlist and reported unneeded by DNF, which preserves user-owned
Qt5 applications and dependencies still required by installed software.

%prep
%build
bash -n %{SOURCE0}
%install
install -Dm0755 %{SOURCE0} %{buildroot}%{_libexecdir}/nabu-desktop-migrate

%files
%{_libexecdir}/nabu-desktop-migrate

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Add opt-in, allowlisted and dependency-aware Plasma Qt6 cleanup.

