%global debug_package %{nil}
Name:           nabu-core-alpha-meta
Version:        1.0.0
Release:        3%{?dist}
Summary:        Alpha Nabu CORE branch
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-abi >= 1
Requires:       senemos-nabu-kernel-alpha >= 1:1.17.0-0.3.alpha.v1.4.0.9
Provides:       nabu-core-branch = 2
Provides:       nabu-core-meta = %{version}-%{release}
Conflicts:      nabu-core-stable-meta
Conflicts:      nabu-core-unstable-meta
Conflicts:      senemos-nabu-kernel < 1:7
Conflicts:      senemos-nabu-kernel-mainline-alpha

%description
Selects the isolated 6.17 alpha/test Nabu kernel while depending on the shared
kernel-independent CORE stack. This channel is not promoted by static build
evidence and still requires physical device acceptance.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-3
- Preserve installed branch selection while making stable the fresh-install default.
- Depend on the independent CORE ABI instead of a lockstep package release.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Introduce the alpha Nabu CORE branch selector.
