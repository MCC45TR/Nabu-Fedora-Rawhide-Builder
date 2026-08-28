%global debug_package %{nil}
Name:           nabu-meta
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Compatibility bridge to the split Nabu CORE packages
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-abi >= 1
Requires:       nabu-core-branch

%description
Compatibility package for installations created before CORE base and kernel
branch selection were separated. Existing branch selections are retained;
fresh dependency solving deterministically prefers the stable provider.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Stop forcing Rawhide installations onto the unstable branch.
- Preserve an installed branch through the shared virtual capability.
