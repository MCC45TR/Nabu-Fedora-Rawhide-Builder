%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-kde-mobile-optimal-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Optimal KDE Plasma Mobile profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-kde-mobile-base-abi = 1
Requires:       plasma-discover
Requires:       plasma-discover-notifier
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       qmlkonsole
Requires:       dolphin
Requires:       angelfish
Requires:       koko
Requires:       kweather
Requires:       kclock
Requires:       kalk
Requires:       elisa-player
Requires:       kde-connect
Requires:       okular-mobile
Requires:       chromium
Requires:       nano
Requires:       fastfetch
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta
Obsoletes:      nabu-kde-plasma-mobile < %{version}-%{release}
Obsoletes:      nabu-kde-plasma-mobile-optimal < %{version}-%{release}
Provides:       nabu-kde-plasma-mobile = %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-optimal = %{version}-%{release}

%description
Recommended touch-first Plasma Mobile application set for Nabu using stock
Fedora and KDE packages.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the KDE Mobile optimal profile as an independent COPR source.
