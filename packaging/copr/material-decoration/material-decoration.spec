%global upstream_commit 495ebb322f977238eb21d27abc3d9db5751e57b8

Name:           material-decoration
Version:        20261029.113034
Release:        1.git495ebb3%{?dist}
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
* Thu Oct 29 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261029.113034-1.git495ebb3
- Update pinned upstream master to 495ebb322f977238eb21d27abc3d9db5751e57b8.

* Tue Oct 27 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261027.092512-1.gitc7cff8f
- Update pinned upstream master to c7cff8f674a1d29b4f6a232461a2dfe83457b1dc.

* Sun Oct 25 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261024.183512-1.gita8cf123
- Update pinned upstream master to a8cf1238ddb1f7d8a7602d2b4c84c0febddf7016.

* Sat Oct 24 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261023.170806-1.git1a067b9
- Update pinned upstream master to 1a067b9c0fc92454de16287cc761db91b8d6026f.

* Fri Oct 23 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261022.191501-1.gite01f94c
- Update pinned upstream master to e01f94c5c01bbfa066e4c2a6351c36f2feec0b8c.

* Thu Oct 22 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261021.191247-1.git21b6067
- Update pinned upstream master to 21b6067ea6b92cf1d8fea0cc828e613203203117.

* Wed Oct 21 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261020.204322-1.gitf18fea7
- Update pinned upstream master to f18fea7006a6ee683b6cf1873d93514752775a97.

* Mon Oct 19 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261018.161903-1.git641de1a
- Update pinned upstream master to 641de1ac0ee8b36ac38577d463c77b9ae6966dd8.

* Sun Oct 18 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261017.124933-1.git5999272
- Update pinned upstream master to 599927277eca222edfad2f319d0bc07937befd8c.

* Sat Oct 17 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261016.153351-1.gitd9c4db5
- Update pinned upstream master to d9c4db544164677758e0ff885ee681f30577cead.

* Thu Oct 15 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261014.155650-1.git98b9a30
- Update pinned upstream master to 98b9a30e45d486f0c81caf263507de794ea7346d.

* Tue Oct 13 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261012.133806-1.git7379d70
- Update pinned upstream master to 7379d70f3af62039a4fca922d8af1c2077c6330d.

* Mon Oct 12 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261012.123438-1.git874b9ad
- Update pinned upstream master to 874b9adccf128691eedf06e1bb38740a0a3f0cc4.

* Sun Oct 04 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261003.212204-1.git0b77825
- Update pinned upstream master to 0b778253ad6c8eb7fc227bd9d486515c00cdf377.

* Sat Oct 03 2026 SENEMOS Project <mcc45tr@gmail.com> - 20261002.194123-1.git972044b
- Update pinned upstream master to 972044b8148d73d444a0b0baafb32fd786daab88.

* Tue Sep 29 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260928.131945-1.gita5e3ca6
- Update pinned upstream master to a5e3ca6756e9e548cd28ab38416038d2b07d3d69.

* Mon Sep 28 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260928.113020-1.giteb96fde
- Update pinned upstream master to eb96fde952fa84396bb29fcf3681984cfc7f1f35.

* Sat Sep 26 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260918.150131-2.git7bf62f1
- Use KWin's derived plugin ID to avoid repeated metadata warnings.

* Sat Sep 26 2026 SENEMOS Project <mcc45tr@gmail.com> - 20260918.150131-1.git7bf62f1
- Package upstream KWin 6 Material Decoration without changing KDE defaults.
