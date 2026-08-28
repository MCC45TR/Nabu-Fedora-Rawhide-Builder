%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           gnome-nabu-meta
Version:        2.0.0
Release:        1%{?dist}
Summary:        Complete GNOME release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-core-meta >= 2.0.0
Requires:       glibc-all-langpacks
Requires:       nabu-language-support >= 1.1.0-1.test
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gnome-session-wayland-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       mutter
Requires:       gnome-settings-daemon
Requires:       gnome-software
Requires:       ptyxis
Requires:       nautilus
Requires:       firefox
Requires:       loupe
Requires:       gnome-weather
Requires:       gnome-clocks
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       showtime
Requires:       papers
Requires:       gnome-system-monitor
Requires:       nano
Requires:       fastfetch
Requires:       dconf
Requires:       polkit
Requires:       PackageKit-command-not-found
Requires:       PackageKit-gtk3-module
Requires:       glycin-thumbnailer
Requires:       gnome-epub-thumbnailer
Requires:       gst-thumbnailers
Requires:       gvfs-afc
Requires:       gvfs-fuse
Requires:       gvfs-goa
Requires:       gvfs-gphoto2
Requires:       gvfs-mtp
Requires:       gvfs-smb
Requires:       librsvg2
Requires:       papers-nautilus
Requires:       sushi
Conflicts:      nabu-desktop-profile-meta
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-gnome-base-abi = 2
Provides:       nabu-gnome-meta = %{version}-%{release}
Obsoletes:      nabu-gnome-base < %{legacy_meta_max}
Obsoletes:      nabu-gnome-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-gnome-optimal-meta < %{legacy_meta_max}

%description
The single GNOME desktop manifest for Nabu. It installs the formerly optimal
stock Fedora GNOME application set and makes the Nabu locale payload mandatory.

%files
%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace minimal/optimal and base packages with one complete GNOME manifest.

