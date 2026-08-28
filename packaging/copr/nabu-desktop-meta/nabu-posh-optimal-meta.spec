%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-posh-optimal-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Optimal Phosh tablet profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-posh-base-abi = 1
Requires:       gnome-software
Requires:       gnome-console
Requires:       nautilus
Requires:       firefox
Requires:       loupe
Requires:       gnome-weather
Requires:       gnome-clocks
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       totem
Requires:       papers
Requires:       file-roller
Requires:       nano
Requires:       fastfetch
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta

%description
Recommended Fedora Phosh application set for Nabu, matching the provisional
GNOME optimal application coverage.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the Posh optimal profile as an independent COPR source package.
