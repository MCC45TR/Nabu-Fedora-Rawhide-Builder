%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-posh-minimal-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Minimal Phosh profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-posh-base-abi = 1
Requires:       gnome-software
Requires:       gnome-console
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta

%description
Minimal Fedora Phosh session for Nabu with only GNOME Software and GNOME
Console added. The profile name retains the requested Posh spelling.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the Posh minimal profile as an independent COPR source package.
