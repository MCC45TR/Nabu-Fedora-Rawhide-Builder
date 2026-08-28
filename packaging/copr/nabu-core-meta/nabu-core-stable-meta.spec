%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-core-stable-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Stable Nabu CORE branch
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-core-abi = 1
Requires:       senemos-nabu-kernel
# Highest branch capability EVR makes stable the deterministic default when a
# desktop profile is installed without an explicit branch selection.
Provides:       nabu-core-branch = 3
Provides:       nabu-core-meta = %{version}-%{release}
Conflicts:      nabu-core-alpha-meta
Conflicts:      nabu-core-unstable-meta
Conflicts:      senemos-nabu-kernel-alpha
Conflicts:      senemos-nabu-kernel-mainline-alpha

%description
Selects the currently supported stable 6.17 Nabu kernel while depending on the
shared kernel-independent CORE stack. Previous install-only kernel payloads
may remain available as boot fallbacks.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Treat the package as a branch manifest and remove cosmetic kernel minimums.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-3
- Preserve installed branch selection while making stable the fresh-install default.
- Depend on the independent CORE ABI instead of a lockstep package release.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-1
- Introduce the stable Nabu CORE branch selector.
