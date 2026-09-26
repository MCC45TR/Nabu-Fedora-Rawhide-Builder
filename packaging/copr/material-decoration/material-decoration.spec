%global upstream_commit 7bf62f142c17902f4afe04d0be408b5dfef27982

Name:           material-decoration
Version:        20260918.150131
Release:        2.git7bf62f1%{?dist}
Summary:        Material window decoration and configuration for KWin 6
License:        GPL-2.0-or-later AND LGPL-2.0-or-later
URL:            https://github.com/guiodic/material-decoration
Source0:        https://codeload.github.com/guiodic/material-decoration/tar.gz/%{upstream_commit}#/material-decoration-%{upstream_commit}.tar.gz

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  gcc-c++
BuildRequires:  gettext
BuildRequires:  jq
BuildRequires:  kdecoration-devel >= 6.6
BuildRequires:  kwin-devel >= 6.6
BuildRequires:  libepoxy-devel
BuildRequires:  libdrm-devel
BuildRequires:  vulkan-loader-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qttools-devel
BuildRequires:  kf6-kcmutils-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kconfigwidgets-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kguiaddons-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kiconthemes-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  kf6-kwindowsystem-devel
Requires:       kwin%{?_isa} >= 6.6

%description
An optional Qt 6/C++ window decoration for KWin with an integrated
application menu and search. Installing the package does not select or
activate the decoration, and it does not replace Fedora KDE packages.

%prep
%autosetup -n material-decoration-%{upstream_commit}
# KPlugin derives the decoration ID from materialdecoration.so. Upstream's
# embedded, differently named ID floods System Settings with warnings.
# Keep this conditional on the metadata shape and safe when upstream fixes it.
jq 'del(.KPlugin.Id)' src/material.json > src/material.json.new
mv src/material.json.new src/material.json

%build
%cmake -DFORCE_X11=OFF
%cmake_build

%install
%cmake_install
%find_lang materialdecoration

%check
test "$(jq -r '.KPlugin.Id // empty' src/material.json)" = ""
test -f %{buildroot}%{_libdir}/qt6/plugins/org.kde.kdecoration3/materialdecoration.so
test -f %{buildroot}%{_libdir}/qt6/plugins/org.kde.kdecoration3.kcm/materialdecoration_kcm.so

%files -f materialdecoration.lang
%license LICENSE
%doc README.md
%{_libdir}/qt6/plugins/org.kde.kdecoration3/materialdecoration.so
%{_libdir}/qt6/plugins/org.kde.kdecoration3.kcm/materialdecoration_kcm.so
%{_datadir}/metainfo/materialdecoration_kcm.json
%{_datadir}/applications/*material*desktop

%changelog
* Sat Sep 26 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260918.150131-2.git7bf62f1
- Use KWin's derived plugin ID to avoid repeated metadata warnings.

* Sat Sep 26 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260918.150131-1.git7bf62f1
- Package upstream KWin 6 Material Decoration without changing KDE defaults.
