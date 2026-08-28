%global debug_package %{nil}
Name:           nabu-plasma-optimal-meta
Version:        1.1.0
Release:        1%{?dist}
Summary:        Optimal KDE Plasma desktop profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-plasma-base-abi = 1
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       PackageKit
Requires:       konsole
Requires:       dolphin
Requires:       kde-connect
Requires:       ark
Requires:       gwenview
Requires:       okular
Requires:       system-config-printer
Requires:       kwalletmanager5
Requires:       plasma-milou
Requires:       kwrite
Requires:       spectacle
Requires:       nano
Requires:       fastfetch
Requires:       plasma-systemmonitor
Provides:       nabu-desktop-profile-meta = %{version}-%{release}
Conflicts:      nabu-desktop-profile-meta
Obsoletes:      nabu-kde-plasma-optimal < %{version}-%{release}
Obsoletes:      nabu-kde-plasma-full < %{version}-%{release}
Provides:       nabu-kde-plasma-optimal = %{version}-%{release}
Provides:       nabu-kde-plasma-full = %{version}-%{release}

%description
Recommended stock KDE Plasma tablet application set previously qualified for
Nabu. No Fedora or KDE application is forked or modified.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Adopt independent profile-manifest versioning and base ABI dependencies.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-24.test
- Use KWrite without the separate Kate application.
- Add Spectacle and Discover offline-update integration.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Publish the Plasma optimal profile as an independent COPR source package.
