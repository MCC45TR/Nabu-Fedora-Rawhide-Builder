%global debug_package %{nil}
Name:           nabu-core-unstable-meta
Version:        1.0.0
Release:        3%{?dist}
Summary:        Unstable mainline Nabu CORE branch
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-abi >= 1
Requires:       senemos-nabu-kernel-mainline-alpha >= 1:7.2.0-0.4.alpha
Provides:       nabu-core-branch = 1
Provides:       nabu-core-meta = %{version}-%{release}
Conflicts:      nabu-core-stable-meta
Conflicts:      nabu-core-alpha-meta
Conflicts:      senemos-nabu-kernel < 1:7
Conflicts:      senemos-nabu-kernel-alpha

%description
Selects the experimental mainline 7.2 Nabu kernel while depending on the
shared kernel-independent CORE stack. This Rawhide-only branch is WIP and does
not imply successful boot or hardware qualification.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-3
- Preserve installed branch selection while making stable the fresh-install default.
- Depend on the independent CORE ABI instead of a lockstep package release.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Introduce the Rawhide-only unstable 7.2 Nabu CORE branch selector.
