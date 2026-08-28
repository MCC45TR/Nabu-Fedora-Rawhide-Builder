%global debug_package %{nil}
Name:           nabu-branch-manager
Version:        1.1.0
Release:        2%{?dist}
Summary:        Safe CORE branch manager for Nabu Linux
License:        MIT
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        nabu
Source1:        nabu.8
BuildArch:      noarch
Requires:       bash
Requires:       coreutils
Requires:       dnf5
Requires:       rpm
Requires:       sudo
Requires:       nabu-boot-integration >= 2.0.0
Requires:       nabu-kernel-maintenance >= 1.0.0-1
Provides:       nabu-branch-manager-api = 1

%description
Installs the system-wide nabu command used to inspect and switch between the
stable, alpha and unstable CORE branch meta packages. Privilege elevation is
delegated to the system sudo policy; the package grants no additional rights.

%prep

%build
bash -n %{SOURCE0}

%install
install -Dm0755 %{SOURCE0} %{buildroot}%{_bindir}/nabu
install -Dm0644 %{SOURCE1} %{buildroot}%{_mandir}/man8/nabu.8

%files
%{_bindir}/nabu
%{_mandir}/man8/nabu.8*

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-2
- Export a stable API capability for dependency manifests.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Delegate explicit desktop migrations to the independently packaged helper.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Add status, list and sudo-mediated CORE branch switching.
