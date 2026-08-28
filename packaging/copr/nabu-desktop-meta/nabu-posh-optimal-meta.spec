%global debug_package %{nil}
Name:           nabu-posh-optimal-meta
Version:        1.0.0
Release:        23.test%{?dist}
Summary:        Optimal Phosh tablet profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-posh-base >= 1.0.0-23.test
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
* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the Posh optimal profile as an independent COPR source package.
