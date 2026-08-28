%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           phosh-nabu-meta
Version:        2.0.0
Release:        1%{?dist}
Summary:        Complete Phosh release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-meta >= 2.0.0
Requires:       glibc-all-langpacks
Requires:       nabu-language-support >= 1.1.0-1.test
Requires:       phosh
Requires:       phosh-mobile-settings
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-settings-daemon
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
Conflicts:      nabu-desktop-profile-meta
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-posh-base-abi = 2
Obsoletes:      nabu-posh-base < %{legacy_meta_max}
Obsoletes:      nabu-posh-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-posh-optimal-meta < %{legacy_meta_max}

%description
The single Phosh desktop manifest for Nabu. It retains compatibility with the
former "posh" package names while installing Fedora's stock Phosh packages,
the complete application set and mandatory locale data.

%files
%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace Posh/Phosh minimal, optimal and base packages with one manifest.

