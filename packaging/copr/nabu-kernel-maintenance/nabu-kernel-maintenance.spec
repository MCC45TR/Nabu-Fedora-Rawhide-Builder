%global debug_package %{nil}
Name:           nabu-kernel-maintenance
Version:        1.0.0
Release:        1%{?dist}
Summary:        Serialized branch-aware kernel and UKI maintenance for Nabu
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-kernel-maintenance
Source1:        nabu-kernel-maintenance.service
Source2:        nabu-kernel-maintenance.timer
Source3:        90-nabu-kernel-maintenance.preset
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       bash
Requires:       coreutils
Requires:       dnf5
Requires:       rpm
Requires:       systemd
Requires:       util-linux-core
Requires:       nabu-boot-integration >= 2.0.0

%description
Selects the kernel package from the installed Nabu CORE branch, serializes
package and UKI work, prepares the RPM-owned kernel atomically, and never
changes the configured fallback boot default. It supersedes the kernel-owned
hard-coded update timer without modifying kernel payloads in place.

%prep
%build
bash -n %{SOURCE0}
%install
install -Dm0755 %{SOURCE0} %{buildroot}%{_libexecdir}/nabu-kernel-maintenance
install -Dm0644 %{SOURCE1} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.service
install -Dm0644 %{SOURCE2} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.timer
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/90-nabu-kernel-maintenance.preset
install -d %{buildroot}%{_sysconfdir}/systemd/system
ln -s /dev/null %{buildroot}%{_sysconfdir}/systemd/system/nabu-kernel-update.timer

%files
%{_libexecdir}/nabu-kernel-maintenance
%{_unitdir}/nabu-kernel-maintenance.service
%{_unitdir}/nabu-kernel-maintenance.timer
%{_presetdir}/90-nabu-kernel-maintenance.preset
%config %{_sysconfdir}/systemd/system/nabu-kernel-update.timer

%post
%systemd_post nabu-kernel-maintenance.timer

%preun
%systemd_preun nabu-kernel-maintenance.timer

%postun
%systemd_postun_with_restart nabu-kernel-maintenance.timer

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Replace the hard-coded kernel timer with branch-aware serialized maintenance.
- Preserve Android, the known-good fallback and the loader default.

