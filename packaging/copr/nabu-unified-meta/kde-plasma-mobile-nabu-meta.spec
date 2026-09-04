%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           kde-plasma-mobile-nabu-meta
Version:        3.0.0
Release:        11%{?dist}
Summary:        Complete KDE Plasma Mobile release profile for Xiaomi Pad 5
License:        MIT AND GPL-2.0-or-later AND GPL-3.0-only AND LicenseRef-Proprietary AND BSD-2-Clause AND CC0-1.0
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        plasma-mobile.desktop
Source1:        20-nabu-mobile-session.conf
Source2:        90-nabu-mobile-login.conf
Source3:        95-nabu-plasma-mobile.preset
Source4:        nabu-kde-integration-1.4.0.1.tar.gz
Source5:        nabu-kde-l10n-1.1.0.tar.gz
Source6:        nabu-kde-widgets-debug-1.0.1.tar.zst
Source7:        nabu-flashlight-integration-1.0.0.tar.gz
Source8:        80-nabu-plasma-login-theme.conf
Source9:        nabu-plasma-login.svg
BuildArch:      noarch
BuildRequires:  desktop-file-utils
BuildRequires:  firewalld-filesystem
BuildRequires:  lcms2
BuildRequires:  python3
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-meta >= 3.0.0-34
Requires:       glibc-all-langpacks
Requires:       bash
Requires:       color-filesystem
Requires:       coreutils
Requires:       curl
Requires:       filesystem
Requires:       firewalld
Requires:       gzip
Requires:       kdialog
Requires:       lcms2
Requires:       pipewire-utils
Requires:       python3
Requires:       tar
Requires:       wireplumber
Requires:       plasma-workspace
Requires:       plasma-mobile
Requires:       kdeplasma-addons
Requires:       plasma-mobile-sounds
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       plasma-settings
Requires:       kwin
Requires:       kscreen
Requires:       kscreenlocker
Requires:       powerdevil
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       plasma5support
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
Requires:       plasma-discover
Requires:       plasma-discover-notifier
Requires:       plasma-discover-packagekit
Requires:       PackageKit
Requires:       qmlkonsole
Requires:       dolphin
Requires:       udisks2
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
Conflicts:      kde-plasma-nabu-meta
Conflicts:      gnome-nabu-meta
Conflicts:      gnome-mobile-nabu-meta
Conflicts:      phosh-nabu-meta
Conflicts:      nabu-plasma-mobile-setup
Conflicts:      plasma-desktop
Provides:       nabu-desktop-profile-meta = 3
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       plasmashell
Provides:       nabu-kde-mobile-base-abi = 2
Provides:       nabu-kde-plasma-mobile = %{version}-%{release}
Provides:       nabu-kde-plasma-mobile-optimal = %{version}-%{release}
Provides:       nabu-kde-config = %{version}-%{release}
Provides:       nabu-kde-color-profiles = %{version}-%{release}
Provides:       nabu-kde-widgets = %{version}-%{release}
Provides:       nabu-language-support = %{version}-%{release}
Provides:       nabu-kde-l10n = %{version}-%{release}
Provides:       nabu-plasma-login-theme-abi = 1
Provides:       nabu-flashlight-integration-plasma = %{version}-%{release}
Obsoletes:      nabu-kde-mobile-base < %{legacy_meta_max}
Obsoletes:      nabu-kde-mobile-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-kde-mobile-optimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-plasma-mobile-setup < %{legacy_meta_max}

%description
The only KDE Plasma Mobile manifest for Nabu. It combines the mobile session,
former optimal application set, Nabu integration, login branding and complete
Plasma translations. Fedora language packages follow the locale selected in
initial setup. It uses unmodified Fedora and KDE packages and never
claims to replace plasma-desktop.

%prep
%setup -q -c -T
mkdir kde-integration l10n widgets flashlight
tar -xzf %{SOURCE4} -C kde-integration --strip-components=1
tar -xzf %{SOURCE5} -C l10n --strip-components=1
tar --zstd -xf %{SOURCE6} -C widgets --strip-components=1
tar -xzf %{SOURCE7} -C flashlight --strip-components=1
chmod +x kde-integration/kde/senemos-nabu-color-profile kde-integration/tests/mock-kscreen-doctor
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE1} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE2} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset
install -d %{buildroot}%{_datadir}/nabu-plasma-mobile/xsessions
install -Dm0755 kde-integration/kde/nabu-audio-orientation %{buildroot}%{_libexecdir}/senemos-nabu/nabu-audio-orientation
install -Dm0755 kde-integration/kde/senemos-nabu-display-profile %{buildroot}%{_bindir}/senemos-nabu-display-profile
install -Dm0755 kde-integration/kde/senemos-nabu-color-profile %{buildroot}%{_bindir}/senemos-nabu-color-profile
install -Dm0755 kde-integration/kde/senemos-nabu-color-settings %{buildroot}%{_bindir}/senemos-nabu-color-settings
install -Dm0644 kde-integration/kde/org.senemos.nabu.colorprofiles.desktop %{buildroot}%{_datadir}/applications/org.senemos.nabu.colorprofiles.desktop
install -Dm0644 kde-integration/man/senemos-nabu-color-profile.1 %{buildroot}%{_mandir}/man1/senemos-nabu-color-profile.1
install -d %{buildroot}%{_datadir}/color/icc/senemos/nabu
install -m0644 kde-integration/kde/color/icc/senemos/nabu/*.icc %{buildroot}%{_datadir}/color/icc/senemos/nabu/
install -Dm0644 kde-integration/kde/nabu-audio-orientation.service %{buildroot}%{_userunitdir}/nabu-audio-orientation.service
install -Dm0644 kde-integration/kde/90-nabu-kde.preset %{buildroot}%{_userpresetdir}/90-nabu-kde.preset
install -Dm0644 kde-integration/kde/90-senemos-nabu-startupsound.conf %{buildroot}%{_userunitdir}/plasma-startupsound.service.d/90-senemos-nabu.conf
install -Dm0644 kde-integration/kde/kwinoutputconfig.json %{buildroot}%{_sysconfdir}/xdg/kwinoutputconfig.json
install -Dm0644 kde-integration/kde/powerdevilrc %{buildroot}%{_sysconfdir}/xdg/powerdevilrc
install -Dm0755 l10n/nabu-restore-kde-locales %{buildroot}%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
install -Dm0644 l10n/plasma-shell-locales.tar.gz %{buildroot}%{_datadir}/senemos-nabu/l10n/plasma-shell-locales.tar.gz
install -Dm0644 l10n/macros.nabu-languages %{buildroot}%{_sysconfdir}/rpm/macros.nabu-languages
install -d %{buildroot}%{_datadir}/plasma/plasmoids
cp -a widgets/com.mcc45tr.filesearch widgets/com.mcc45tr.mweather widgets/com.mcc45tr.analogclock %{buildroot}%{_datadir}/plasma/plasmoids/
install -Dm0644 %{SOURCE8} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
install -Dm0644 %{SOURCE9} %{buildroot}%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
install -d %{buildroot}%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight
cp -a flashlight/plasma/. %{buildroot}%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight/
install -Dm0644 flashlight/plasma-update/org.senemos.nabu.flashlight.js %{buildroot}%{_datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/org.senemos.nabu.flashlight.js

%check
python3 -m py_compile kde-integration/kde/nabu-audio-orientation kde-integration/kde/senemos-nabu-display-profile kde-integration/kde/senemos-nabu-color-profile
python3 kde-integration/kde/senemos-nabu-color-profile catalog
python3 -m unittest -v kde-integration/tests/test_color_profile.py
python3 -m unittest -v kde-integration/tests/test_audio_orientation.py
bash -n kde-integration/kde/senemos-nabu-color-settings
desktop-file-validate kde-integration/kde/org.senemos.nabu.colorprofiles.desktop
python3 -c 'import json, pathlib; root=pathlib.Path("widgets"); expected={"com.mcc45tr.filesearch","com.mcc45tr.mweather","com.mcc45tr.analogclock"}; assert {json.loads((root/x/"metadata.json").read_text())["KPlugin"]["Id"] for x in expected} == expected'
python3 -m json.tool flashlight/plasma/metadata.json >/dev/null
grep -Fq '/usr/libexec/nabu-sar-control' flashlight/plasma/contents/ui/main.qml
grep -Fq 'Keep awake while held' flashlight/plasma/contents/ui/main.qml

%files
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
%license kde-integration/LICENSE l10n/LICENSES/common/LICENSE-MIT l10n/LICENSES/plasma-workspace/*
%doc kde-integration/README.md kde-integration/COLOR-PROFILE-PROVENANCE.md
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-audio-orientation
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_bindir}/senemos-nabu-display-profile
%{_bindir}/senemos-nabu-color-profile
%{_bindir}/senemos-nabu-color-settings
%{_mandir}/man1/senemos-nabu-color-profile.1*
%{_datadir}/applications/org.senemos.nabu.colorprofiles.desktop
%dir %{_datadir}/color/icc/senemos
%dir %{_datadir}/color/icc/senemos/nabu
%{_datadir}/color/icc/senemos/nabu/*.icc
%{_userunitdir}/nabu-audio-orientation.service
%{_userpresetdir}/90-nabu-kde.preset
%dir %{_userunitdir}/plasma-startupsound.service.d
%{_userunitdir}/plasma-startupsound.service.d/90-senemos-nabu.conf
%config(noreplace) %{_sysconfdir}/xdg/kwinoutputconfig.json
%config(noreplace) %{_sysconfdir}/xdg/powerdevilrc
%{_sysconfdir}/rpm/macros.nabu-languages
%dir %{_datadir}/senemos-nabu
%dir %{_datadir}/senemos-nabu/l10n
%{_datadir}/senemos-nabu/l10n/plasma-shell-locales.tar.gz
%{_datadir}/plasma/plasmoids/com.mcc45tr.filesearch/
%{_datadir}/plasma/plasmoids/com.mcc45tr.mweather/
%{_datadir}/plasma/plasmoids/com.mcc45tr.analogclock/
%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight/
%{_datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/org.senemos.nabu.flashlight.js

%post
%systemd_user_post nabu-audio-orientation.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable plasma-setup.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sshd.service >/dev/null 2>&1 || :
fi
%posttrans
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :
if [ -x /usr/bin/firewall-offline-cmd ]; then
    /usr/bin/firewall-offline-cmd --add-service=kdeconnect >/dev/null 2>&1 || :
fi
%firewalld_reload
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sshd.service >/dev/null 2>&1 || :
    if /usr/bin/systemctl is-active --quiet graphical.target &&
       ! /usr/bin/systemctl is-active --quiet plasmalogin.service; then
        /usr/bin/loginctl terminate-user plasmalogin >/dev/null 2>&1 || :
        /usr/bin/systemctl reset-failed plasmalogin.service >/dev/null 2>&1 || :
        /usr/bin/systemctl start plasmalogin.service >/dev/null 2>&1 || :
    fi
fi
%preun
%systemd_user_preun nabu-audio-orientation.service
%postun
%systemd_user_postun_with_restart nabu-audio-orientation.service

%changelog
* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-11
- Schedule MFile Finder RSS and weather maintenance at their actual deadlines
  instead of waking every minute when no work is due.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-10
- Release completed MFile Finder weather requests and accept Plasma's generic
  applet-layout keys to reduce long-session memory growth and QML log noise.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-9
- Install UDisks2 so Plasma and Solid can enumerate storage devices without
  repeatedly waiting for a missing D-Bus service during session startup.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-8
- Allow KDE Connect in firewalld's default zone so LAN discovery and pairing
  work after installation without weakening unrelated firewall policy.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-7
- Stop forcing Turkish packages on global installations; use the locale chosen
  in initial setup through the shared CORE language-pack installer.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-6
- Install KDE Plasma Addons so PowerDevil can load its Kameleon module.
- Include the current Fedora Turkish language and spell-checking payloads.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-5
- Read KWin's output transform directly instead of spawning kscreen-doctor
  every second, and reduce idle PipeWire graph scans.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-4
- Add grip-aware keep-awake state and control to the existing Plasma Mobile widget.
- Keep the control disabled until real ADUX1050 calibration is available.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-3
- Make DE exclusivity explicit by package name so this manifest updates itself.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-2
- Leave retirement of shared integration names to CORE; this DE owns only its
  replacement payload and profile-specific legacy names.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-1
- Merge mobile KDE configuration, ICC profiles, widgets, locale restoration,
  login branding and the Plasma tablet-control UI into this release package.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-6
- Do not run owner lifecycle macros for the Plasma-owned login service.
- Repair only an inactive manager left by legacy removal scriptlets, while
  preserving an already active graphical login session on normal upgrades.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-5
- Reassert and start Plasma Login Manager after legacy mobile removal scriptlets
  when the machine is already running the graphical target.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-4
- Keep the shared login theme as an implementation dependency and let CORE own
  retirement of the common migration helper, eliminating DE-selection ambiguity.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Keep Plasma Mobile on the independent Nabu KDE configuration payload; the
  desktop integration meta requires plasma-setup and plasma-desktop.
- Provide the plasmashell capability directly for the mobile shell.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Match the KDE integration/configuration EVRs retained in the live COPR.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Merge Plasma Mobile base, optimal profile, session and login branding.
- Require complete locale support and stop obsoleting Fedora/KDE packages.
