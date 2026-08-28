%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-gnome-optimal-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Optimal GNOME tablet profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-gnome-base-abi = 1
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
Requires:       gnome-session-wayland-session
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
# Intentional Workstation manifest dependency for SVG rendering and previews.
Requires:       librsvg2
Requires:       papers-nautilus
Requires:       sushi
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta
Obsoletes:      nabu-gnome-meta < %{version}-%{release}
Provides:       nabu-gnome-meta = %{version}-%{release}

%description
Recommended stock GNOME tablet application set for Nabu, using GNOME-native or
desktop-neutral applications and the same provisional coverage as Posh.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.2.0-1
- Align terminal and video applications with the Fedora Workstation ISO.
- Add GNOME System Monitor and the selected mandatory session components.
- Add the Workstation file, PackageKit and preview integration set.
- Keep Fastfetch as a Nabu profile utility and drop File Roller.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the GNOME optimal profile as an independent COPR source package.
