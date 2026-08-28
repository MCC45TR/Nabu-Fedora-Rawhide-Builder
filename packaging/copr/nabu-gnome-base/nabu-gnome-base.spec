%global debug_package %{nil}
Name: nabu-gnome-base
Version: 1.1.0
Release: 1%{?dist}
Summary: Stock GNOME session foundation for Nabu
License: MIT
URL: https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch: noarch
Requires: nabu-core-abi = 1
Requires: nabu-core-branch
Requires: glibc-all-langpacks
Recommends: nabu-language-support >= 1.1.0-1.test
Requires: gnome-shell
Requires: gnome-session
Requires: gdm
Requires: gnome-control-center
Requires: gnome-initial-setup
Requires: mutter
Requires: gnome-settings-daemon
Provides: nabu-desktop-session = %{version}-%{release}
Provides: nabu-gnome-base-abi = 1
Conflicts: nabu-desktop-session

%description
Stock Fedora GNOME session and settings foundation for Nabu.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt the independent session-manifest version and ABI.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Publish the GNOME session base as an independent source package.
