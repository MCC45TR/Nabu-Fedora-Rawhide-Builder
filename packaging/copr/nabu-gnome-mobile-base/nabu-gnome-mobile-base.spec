%global debug_package %{nil}
Name: nabu-gnome-mobile-base
Version: 1.0.0
Release: 33.test%{?dist}
Summary: Touch-oriented stock GNOME session foundation for Nabu
License: MIT
URL: https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch: noarch
Requires: nabu-core-abi >= 1
Requires: nabu-core-branch
Requires: glibc-all-langpacks
Recommends: nabu-language-support >= 1.1.0-1.test
Requires: gnome-shell
Requires: gnome-session
Requires: gdm
Requires: gnome-control-center
Requires: gnome-initial-setup
Requires: gnome-settings-daemon
Requires: mutter
Provides: nabu-desktop-session = %{version}-%{release}
Conflicts: nabu-desktop-session

%description
Touch-oriented profile built only on stock Fedora GNOME packages.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Publish the GNOME Mobile session base as an independent source package.

