%global debug_package %{nil}
Name:           nabu-gnome-minimal-meta
Version:        1.2.0
Release:        1%{?dist}
Summary:        Minimal GNOME profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-gnome-base-abi = 1
Requires:       gnome-software
Requires:       ptyxis
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta

%description
Minimal stock GNOME session for Nabu. It adds only GNOME Software and Ptyxis
to the required session base.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.2.0-1
- Follow the Fedora Workstation terminal selection by replacing GNOME Console
  with Ptyxis.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the GNOME minimal profile as an independent COPR source package.
