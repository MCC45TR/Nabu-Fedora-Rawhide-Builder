%global debug_package %{nil}
Name:           nabu-kde-mobile-minimal-meta
Version:        1.0.0
Release:        23.test%{?dist}
Summary:        Minimal KDE Plasma Mobile profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-kde-mobile-base >= 1.0.0-23.test
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       qmlkonsole
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta
Obsoletes:      nabu-kde-plasma-mobile-minimal < %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-minimal = %{version}-%{release}

%description
Minimal stock KDE Plasma Mobile profile for Nabu with only Discover, its
PackageKit backend and QMLKonsole added to the required mobile session base.

%files

%changelog
* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the KDE Mobile minimal profile as an independent COPR source.
