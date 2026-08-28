%global debug_package %{nil}

Name:           nabu-repository-config
Version:        1.0.0
Release:        32.test%{?dist}
Summary:        COPR repository definition and desktop session bases for Nabu Linux
License:        MIT AND GPL-2.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-linux-copr.repo
Source1:        90-nabu-disable-cisco-openh264.repo
Source2:        plasma-mobile.desktop
Source3:        20-nabu-mobile-session.conf
Source4:        90-nabu-mobile-login.conf
Source5:        95-nabu-plasma-mobile.preset
Source6:        DESKTOP-PROFILE-MIGRATION.md
Source7:        80-nabu-plasma-login-theme.conf
Source8:        nabu-plasma-login.svg
Source9:        95-nabu-plasma-login.preset
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

%description
Installs the signed Nabu Linux COPR definition and selects the matching Fedora
release automatically. The repository publishes the Nabu hardware stack and
desktop session bases for Fedora 43, 44, 45 and Rawhide on AArch64. User-facing
minimal and optimal meta packages are published as independent COPR sources.

%package -n nabu-core-base
Summary:        Kernel-independent operating-system and hardware stack for Nabu
Requires:       nabu-repository-config = %{version}-%{release}
Requires:       nabu-branch-manager >= 1.0.0-1
Requires:       nabu-boot-integration >= 2.0.0
Requires:       nabu-boot-manager
Requires:       nabu-system-integration >= 2.0.0-5.test
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu
Requires:       python3-ssc-nabu
Requires:       iio-sensor-proxy-nabu
Requires:       senemos-nabu-plymouth >= 1.0.0-5.test
Provides:       nabu-core = %{version}-%{release}

%description -n nabu-core-base
Kernel-independent CORE foundation for Fedora on Xiaomi Pad 5 (nabu). It
brings together boot integration, device policy, audio, sensors and the Nabu
branch-management command. Exactly one separately packaged CORE branch meta
selects the stable, alpha or unstable kernel family. Proprietary device
firmware is never redistributed and must be supplied from an authorized
source.

%package -n nabu-meta
Summary:        Compatibility bridge to the split Nabu CORE channel packages
Requires:       nabu-core-base = %{version}-%{release}
%if 0%{?fedora} >= 46
Requires:       nabu-core-unstable-meta >= 1.0.0-2
%else
Requires:       nabu-core-stable-meta >= 1.0.0-1
%endif

%description -n nabu-meta
Upgrade compatibility package for installations created before the Nabu CORE
base and kernel channel selectors were split.  It keeps the selected compatible
kernel branch while moving the hardware stack to nabu-core-base.

%package -n nabu-plasma-base
Summary:        KDE Plasma desktop session foundation for Nabu
Requires:       nabu-core-base >= 1.0.0-26.test
Requires:       nabu-core-branch
Requires:       nabu-kde-config >= 1.4.0.1-11.test
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Recommends:     nabu-kde-l10n >= 1.1.0-1.test
Recommends:     nabu-plasma-setup-l10n >= 1.1.0-1.test
Requires:       nabu-kde-widgets
Requires:       plasma-workspace
Requires:       plasma-desktop
Requires:       kwin
Requires:       kscreen
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       kcm-plasmalogin
Requires:       nabu-plasma-login-theme = %{version}-%{release}
Requires:       nabu-plasma-login-transition = %{version}-%{release}
Requires:       nabu-plasma-qt6-transition = %{version}-%{release}
Requires:       plasma-systemsettings
Requires:       kde-gtk-config
Requires:       xsettingsd
Requires:       breeze-gtk-gtk3
Requires:       breeze-gtk-gtk4
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       bluedevil
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       plasma-setup(aarch-64)
Conflicts:      nabu-plasma-mobile-setup
Conflicts:      kcm_wacomtablet
Provides:       nabu-desktop-session = %{version}-%{release}
Conflicts:      nabu-desktop-session
Obsoletes:      nabu-kde-meta < %{version}-%{release}
Provides:       nabu-kde-meta = %{version}-%{release}

%description -n nabu-plasma-base
Stock Fedora KDE Plasma desktop, Plasma Login Manager and Nabu integration
foundation. No KDE or Fedora application is forked or replaced.

%package -n nabu-plasma-login-theme
Summary:        Nabu branding for Plasma Login Manager
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
BuildArch:      noarch

%description -n nabu-plasma-login-theme
Device-specific Plasma Login Manager wallpaper and managed default settings
for Xiaomi Pad 5. It uses Plasma's stock image wallpaper plugin and does not
replace or patch the Fedora or KDE login-manager packages.

%package -n nabu-plasma-login-transition
Summary:        One-time transition from SDDM to Plasma Login Manager
Requires:       plasma-login-manager
Obsoletes:      sddm < 1
Obsoletes:      sddm-wayland-plasma < 7
BuildArch:      noarch

%description -n nabu-plasma-login-transition
Single-owner RPM transaction bridge that replaces the legacy SDDM packages
with Fedora's stock Plasma Login Manager without modifying either project.

%package -n nabu-plasma-qt6-transition
Summary:        One-time transition from Maliit and KDE Frameworks 5 to Plasma 6
Obsoletes:      maliit-framework < 3
Obsoletes:      maliit-framework-qt5 < 3
Obsoletes:      maliit-keyboard < 3
Obsoletes:      plasma-integration-qt5 < 7
Obsoletes:      plasma-breeze-qt5 < 7
Obsoletes:      kf5-attica < 6
Obsoletes:      kf5-filesystem < 6
Obsoletes:      kf5-frameworkintegration < 6
Obsoletes:      kf5-frameworkintegration-libs < 6
Obsoletes:      kf5-karchive < 6
Obsoletes:      kf5-kauth < 6
Obsoletes:      kf5-kbookmarks < 6
Obsoletes:      kf5-kcodecs < 6
Obsoletes:      kf5-kcompletion < 6
Obsoletes:      kf5-kconfig-core < 6
Obsoletes:      kf5-kconfig-gui < 6
Obsoletes:      kf5-kconfigwidgets < 6
Obsoletes:      kf5-kcoreaddons < 6
Obsoletes:      kf5-kcrash < 6
Obsoletes:      kf5-kdbusaddons < 6
Obsoletes:      kf5-kdoctools < 6
Obsoletes:      kf5-kglobalaccel < 6
Obsoletes:      kf5-kglobalaccel-libs < 6
Obsoletes:      kf5-kguiaddons < 6
Obsoletes:      kf5-ki18n < 6
Obsoletes:      kf5-kiconthemes < 6
Obsoletes:      kf5-kinit < 6
Obsoletes:      kf5-kio-core < 6
Obsoletes:      kf5-kio-core-libs < 6
Obsoletes:      kf5-kio-doc < 6
Obsoletes:      kf5-kio-file-widgets < 6
Obsoletes:      kf5-kio-gui < 6
Obsoletes:      kf5-kio-ntlm < 6
Obsoletes:      kf5-kio-widgets < 6
Obsoletes:      kf5-kio-widgets-libs < 6
Obsoletes:      kf5-kirigami2 < 6
Obsoletes:      kf5-kitemviews < 6
Obsoletes:      kf5-kjobwidgets < 6
Obsoletes:      kf5-knewstuff < 6
Obsoletes:      kf5-knotifications < 6
Obsoletes:      kf5-kpackage < 6
Obsoletes:      kf5-kservice < 6
Obsoletes:      kf5-ktextwidgets < 6
Obsoletes:      kf5-kwallet < 6
Obsoletes:      kf5-kwallet-libs < 6
Obsoletes:      kf5-kwayland < 6
Obsoletes:      kf5-kwidgetsaddons < 6
Obsoletes:      kf5-kwindowsystem < 6
Obsoletes:      kf5-kxmlgui < 6
Obsoletes:      kf5-qqc2-desktop-style < 6
Obsoletes:      kf5-solid < 6
Obsoletes:      kf5-sonnet < 6
Obsoletes:      kf5-sonnet-core < 6
Obsoletes:      kf5-sonnet-ui < 6
Obsoletes:      kf5-syndication < 6
BuildArch:      noarch

%description -n nabu-plasma-qt6-transition
Transaction-only compatibility bridge. It removes the former Maliit, Qt 5
Plasma integration and KDE Frameworks 5 dependency chain when a Nabu Plasma
profile is upgraded. The runtime replacement is Fedora's stock Qt 6
plasma-keyboard package; no KDE package is patched or replaced downstream.

%package -n nabu-gnome-base
Summary:        GNOME session foundation for Nabu
Requires:       nabu-core-base >= 1.0.0-26.test
Requires:       nabu-core-branch
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       mutter
Requires:       gnome-settings-daemon
Provides:       nabu-desktop-session = %{version}-%{release}
Conflicts:      nabu-desktop-session

%description -n nabu-gnome-base
Stock Fedora GNOME session, display manager and settings foundation for Nabu.

%package -n nabu-gnome-mobile-base
Summary:        Touch-oriented GNOME session foundation for Nabu
Requires:       nabu-core-base >= 1.0.0-26.test
Requires:       nabu-core-branch
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       gnome-settings-daemon
Requires:       mutter
Provides:       nabu-desktop-session = %{version}-%{release}
Conflicts:      nabu-desktop-session

%description -n nabu-gnome-mobile-base
Touch-oriented profile built on stock Fedora GNOME. Fedora does not ship a
separate GNOME Shell Mobile session, so no downstream shell patches are used.

%package -n nabu-posh-base
Summary:        Phosh mobile session foundation for Nabu
Requires:       nabu-core-base >= 1.0.0-26.test
Requires:       nabu-core-branch
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Requires:       phosh
Requires:       phosh-mobile-settings
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-settings-daemon
Provides:       nabu-desktop-session = %{version}-%{release}
Conflicts:      nabu-desktop-session

%description -n nabu-posh-base
Fedora Phosh session and GNOME settings foundation. The package uses the
requested "posh" spelling while the installed shell is Phosh.

%package -n nabu-kde-mobile-base
Summary:        KDE Plasma Mobile session foundation for Nabu
Requires:       nabu-core-base >= 1.0.0-26.test
Requires:       nabu-core-branch
Requires:       nabu-system-integration >= 2.0.0-5.test
Requires:       nabu-kde-config >= 1.4.0.1-6.test
Requires:       glibc-all-langpacks
Recommends:     nabu-language-support >= 1.1.0-1.test
Recommends:     nabu-kde-l10n >= 1.1.0-1.test
Requires:       plasma-workspace
Requires:       plasma-mobile
Requires:       plasma-mobile-sounds
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       nabu-plasma-login-theme = %{version}-%{release}
Requires:       nabu-plasma-login-transition = %{version}-%{release}
Requires:       nabu-plasma-qt6-transition = %{version}-%{release}
Requires:       plasma-settings
Requires:       kwin
Requires:       kscreen
Requires:       kscreenlocker
Requires:       powerdevil
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       bluedevil
Requires:       NetworkManager
Requires:       mesa-dri-drivers
Requires:       mesa-vulkan-drivers
Requires:       mesa-libEGL
Requires:       libglvnd-egl
Requires:       libglvnd-gles
Requires:       libglvnd-glx
Requires:       xorg-x11-server-Xwayland
Requires:       openssh-clients
Requires:       openssh-server
Conflicts:      nabu-plasma-mobile-setup
Conflicts:      plasma-setup
Conflicts:      plasma-desktop
Provides:       plasmashell
Obsoletes:      plasma-desktop < 7
Obsoletes:      nabu-plasma-mobile-setup < 1:6.7.4-1.nabu3
Obsoletes:      nabu-kde-plasma-mobile-base < %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-base = %{version}-%{release}
Provides:       nabu-desktop-session = %{version}-%{release}
Conflicts:      nabu-desktop-session

%description -n nabu-kde-mobile-base
Nabu's Plasma Mobile shell and Plasma Login Manager stack, exposing only the
packaged Plasma Mobile Wayland session.

%prep

%build

%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
install -Dm0644 %{SOURCE2} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE3} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE4} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE5} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset
install -Dm0644 %{SOURCE6} %{buildroot}%{_docdir}/nabu-repository-config/DESKTOP-PROFILE-MIGRATION.md
install -Dm0644 %{SOURCE7} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
install -Dm0644 %{SOURCE8} %{buildroot}%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
install -Dm0644 %{SOURCE9} %{buildroot}%{_presetdir}/95-nabu-plasma-login.preset
install -d %{buildroot}%{_datadir}/nabu-plasma-mobile/xsessions

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
%config(noreplace) %{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
%doc %{_docdir}/nabu-repository-config/DESKTOP-PROFILE-MIGRATION.md

%files -n nabu-core-base
%files -n nabu-meta
%files -n nabu-gnome-base
%files -n nabu-gnome-mobile-base
%files -n nabu-posh-base
%files -n nabu-plasma-base
%{_presetdir}/95-nabu-plasma-login.preset

%files -n nabu-plasma-login-theme
%dir %{_datadir}/backgrounds/nabu
%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf

%files -n nabu-plasma-login-transition
%files -n nabu-plasma-qt6-transition

%post -n nabu-plasma-base
%systemd_post plasmalogin.service plasma-setup.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
fi

%preun -n nabu-plasma-base
%systemd_preun plasmalogin.service plasma-setup.service

%postun -n nabu-plasma-base
%systemd_postun_with_restart plasmalogin.service plasma-setup.service

%files -n nabu-kde-mobile-base
%dir %{_datadir}/nabu-plasma-mobile
%dir %{_datadir}/nabu-plasma-mobile/wayland-sessions
%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
%dir %{_datadir}/nabu-plasma-mobile/xsessions
%dir %{_unitdir}/plasmalogin.service.d
%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
%dir %{_prefix}/lib/plasmalogin
%dir %{_prefix}/lib/plasmalogin/plasmalogin.conf.d
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
%{_presetdir}/95-nabu-plasma-mobile.preset

%post -n nabu-kde-mobile-base
%systemd_post plasmalogin.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable plasma-setup.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sshd.service >/dev/null 2>&1 || :
fi

%preun -n nabu-kde-mobile-base
%systemd_preun plasmalogin.service

%postun -n nabu-kde-mobile-base
%systemd_postun_with_restart plasmalogin.service

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-32.test
- Restore Fedora KDE's stock GTK appearance bridge and Breeze GTK themes.
- Synchronize KWin's minimize, maximize and close button layout to GTK 3,
  GTK 4 and XSettings clients without patching KDE or GTK packages.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-31.test
- Replace Maliit with Fedora's stock Plasma Keyboard in both Plasma profiles.
- Remove the legacy Qt 5 and KDE Frameworks 5 chain through a scoped upgrade
  transition package.
- Require Discover's notifier and offline-update frontend in Plasma Desktop.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-30.test
- Let versioned Obsoletes perform the SDDM replacement without preempting the
  DNF transaction through redundant Conflicts metadata.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-29.test
- Leave SDDM conflict and replacement ownership exclusively to the shared
  Plasma Login Manager transition package.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-28.test
- Preserve the legacy Rawhide mainline selection by migrating nabu-meta to the
  unstable CORE channel explicitly.
- Move SDDM obsoletes into one shared Plasma Login Manager transition package
  so DNF sees a single package-replacement owner.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-27.test
- Restore nabu-meta as an upgrade bridge to nabu-core-base and the compatible
  split kernel branch selector.
- Encode the existing SDDM to Plasma Login Manager transition as versioned
  obsoletes so a normal DNF upgrade can perform the package replacement.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-26.test
- Split the kernel-independent Nabu CORE into nabu-core-base.
- Require one external nabu-core-branch provider from every desktop session.
- Move stable, alpha and unstable kernel selection to independent meta RPMs.
- Install the nabu branch-management command through the shared CORE base.

* Thu Aug 27 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-25.test
- Replace SDDM in the Plasma desktop session base with Plasma Login Manager.
- Add an independent Nabu Plasma Login theme package using the stock image
  wallpaper plugin and a device-specific scalable background.
- Keep Plasma Setup ordered before the new display manager on first boot.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1.0.0-24.test
- Select the Linux 7.2 mainline-alpha successor on Fedora Rawhide.
- Keep Fedora 43, 44 and 45 on the stable 6.17 selector until promoted.
- Preserve versioned 6.17 core and modules packages as rollback fallbacks.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-23.test
- Move all ten user-facing desktop meta packages to independent source RPMs so
  every package has its own row on the COPR Packages page.
- Retain only the shared Nabu core and mutually exclusive session bases here.

* Wed Aug 26 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-22.test
- Publish minimal and optimal -meta packages for GNOME, touch-oriented GNOME,
  Posh/Phosh, Plasma and KDE Mobile.
- Enforce exactly one desktop session and one user-facing profile with shared
  mutually conflicting virtual capabilities.
- Limit minimal profiles to the matching software store and terminal and map
  legacy GNOME, Plasma and Plasma Mobile names to their new equivalents.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-14.test
- Keep Fedora's plasma-desktop package as the plasmashell provider required by
  plasma-workspace; the Plasma Login Manager mount namespace still exposes
  only the packaged Plasma Mobile session.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-13.test
- Require the integrated v1.4.0.3 kernel meta package by its published name.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-12.test
- Add integrated Plasma Mobile common, minimal and optimal profiles.
- Replace SDDM with Plasma Login Manager and isolate its session directory so
  the greeter exposes only Plasma Mobile while Plasma Setup remains a separate
  first-boot service.
- Use Index, KDE Photos, KWrite and QMLKonsole in the minimal profile.
- Retain Dolphin in the optimal profile and add Angelfish, KDE Photos,
  KWeather, KClock, Kalk, QMLKonsole and Elisa.
- Require the v1.4.0.3 Nabu kernel family.

* Sun Aug 23 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-11.test
- Select the matching Fedora COPR repository path for Fedora 43, 44, 45 and
  Rawhide instead of hard-coding Rawhide.
- Clarify the Nabu hardware, desktop-profile and firmware boundaries.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-10.test
- Disable Fedora's Cisco OpenH264 repository through the supported DNF5 repo
  override mechanism because its Rawhide metadata currently serves an fc45
  package that cannot be verified with the Fedora 46 signing key.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-9.test
- Keep the native Nabu Plymouth theme in every supported desktop profile.
- Require the localization payload that restores the Plasma Shell catalogs
  used by Plasma Setup's language selector.

* Sat Aug 22 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-8.test
- Require the current v1.4.0.2 Nabu kernel family instead of the obsolete
  v1.21 package names.
- Keep KDE profiles on Fedora's stock KWin through the integration package.

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-7.test
- Require complete Plasma Setup language catalogs and the sensor-start FOTA

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-6.test
- Add the shared Nabu core hardware meta package and link desktop profiles to it

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-5.test
- Keep Plasma's required libwacom runtime while omitting the Wacom settings KCM

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-4.test
- Decouple the KDE integration EVR from this repository/meta source package.

* Sat Aug 15 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-2
- Publish one test repository definition and desktop-neutral profile names.
