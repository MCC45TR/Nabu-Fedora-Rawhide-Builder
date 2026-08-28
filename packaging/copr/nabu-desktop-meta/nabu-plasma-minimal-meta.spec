%global debug_package %{nil}
Name:           nabu-plasma-minimal-meta
Version:        1.0.0
Release:        24.test%{?dist}
Summary:        Minimal KDE Plasma desktop profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-plasma-base >= 1.0.0-23.test
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       PackageKit
Requires:       konsole
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta
Obsoletes:      nabu-kde-plasma-minimal < %{version}-%{release}
Provides:       nabu-kde-plasma-minimal = %{version}-%{release}

%description
Minimal stock KDE Plasma desktop for Nabu with only Discover, its PackageKit
backend and Konsole added to the required session base.

%files

%changelog
* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-24.test
- Add Discover notification and offline-update integration.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the Plasma minimal profile as an independent COPR source package.
