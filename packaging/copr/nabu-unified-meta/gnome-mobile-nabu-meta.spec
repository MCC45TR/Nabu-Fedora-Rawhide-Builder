%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           gnome-mobile-nabu-meta
Version:        2.0.0
Release:        1%{?dist}
Summary:        Complete touch-oriented GNOME release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-meta >= 2.0.0
Requires:       glibc-all-langpacks
Requires:       nabu-language-support >= 1.1.0-1.test
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       gnome-settings-daemon
Requires:       mutter
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
Provides:       nabu-gnome-mobile-base-abi = 2
Obsoletes:      nabu-gnome-mobile-base < %{legacy_meta_max}
Obsoletes:      nabu-gnome-mobile-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-gnome-mobile-optimal-meta < %{legacy_meta_max}

%description
The single touch-oriented GNOME manifest for Nabu. Fedora does not ship a
separate GNOME Shell Mobile, so this uses the unmodified stock GNOME session
with the complete prior optimal application set and mandatory locale payload.

%files
%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace the touch GNOME minimal/optimal and base packages with one manifest.

