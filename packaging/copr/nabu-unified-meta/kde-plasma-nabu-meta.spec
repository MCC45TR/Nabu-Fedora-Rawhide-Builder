%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           kde-plasma-nabu-meta
Version:        3.0.0
Release:        11%{?dist}
Summary:        Complete KDE Plasma release profile for Xiaomi Pad 5
License:        MIT AND GPL-2.0-or-later AND GPL-3.0-only AND LicenseRef-Proprietary AND BSD-2-Clause AND CC0-1.0
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        95-nabu-plasma-login.preset
Source1:        nabu-kde-integration-1.4.0.1.tar.gz
Source2:        nabu-kde-l10n-1.1.0.tar.gz
Source3:        nabu-kde-widgets-debug-1.0.1.tar.zst
Source4:        nabu-flashlight-integration-1.0.0.tar.gz
Source5:        80-nabu-plasma-login-theme.conf
Source6:        nabu-plasma-login.svg
BuildArch:      noarch
BuildRequires:  desktop-file-utils
BuildRequires:  firewalld-filesystem
BuildRequires:  lcms2
BuildRequires:  python3
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-meta >= 3.0.0-34
# Plasma and setup translations are a hard release contract. Fedora language
# packs are selected later from the locale chosen in Plasma Setup.
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
Requires:       plasma-desktop
Requires:       kdeplasma-addons
Requires:       kwin
Requires:       kscreen
Requires:       plasma-login-manager
Requires:       kde-settings-plasmalogin
Requires:       kcm-plasmalogin
Requires:       plasma-systemsettings
Requires:       kde-gtk-config
Requires:       xsettingsd
Requires:       breeze-gtk-gtk3
Requires:       breeze-gtk-gtk4
Requires:       plasma-nm
Requires:       plasma-pa
Requires:       plasma-keyboard
Requires:       plasma5support
Requires:       bluedevil
Requires:       plasma-setup(aarch-64)
Requires:       plasma-discover
Requires:       plasma-discover-packagekit
Requires:       plasma-discover-notifier
Requires:       plasma-discover-offline-updates
Requires:       PackageKit
Requires:       konsole
Requires:       dolphin
Requires:       udisks2
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
Requires:       plasma-welcome
Requires:       kinfocenter
Requires:       libcanberra-backend-pulse
Requires:       mesa-vulkan-drivers
Requires:       vulkan-tools
Conflicts:      kde-plasma-mobile-nabu-meta
Conflicts:      gnome-nabu-meta
Conflicts:      gnome-mobile-nabu-meta
Conflicts:      phosh-nabu-meta
Provides:       nabu-desktop-profile-meta = 3
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-plasma-base-abi = 2
Provides:       nabu-kde-meta = %{version}-%{release}
Provides:       nabu-kde-plasma-optimal = %{version}-%{release}
Provides:       nabu-kde-plasma-full = %{version}-%{release}
Provides:       nabu-kde-integration = %{version}-%{release}
Provides:       nabu-kde-config = %{version}-%{release}
Provides:       nabu-kde-config = 1.4.0.1-13.test.fc46
Provides:       nabu-kde-color-profiles = %{version}-%{release}
Provides:       nabu-kde-color-profiles = 1.4.0.1-13.test.fc46
Provides:       nabu-kde-widgets = %{version}-%{release}
Provides:       nabu-language-support = %{version}-%{release}
Provides:       nabu-language-support = 1.1.0-1.test.fc46
Provides:       nabu-kde-l10n = %{version}-%{release}
Provides:       nabu-plasma-setup-l10n = %{version}-%{release}
Provides:       nabu-plasma-login-theme-abi = 1
Provides:       nabu-flashlight-integration-plasma = %{version}-%{release}
Obsoletes:      nabu-plasma-base < %{legacy_meta_max}
Obsoletes:      nabu-plasma-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-plasma-optimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-kde-integration < %{legacy_meta_max}
Obsoletes:      nabu-kde-config < %{legacy_meta_max}
Obsoletes:      nabu-kde-color-profiles < %{legacy_meta_max}
Obsoletes:      nabu-kde-widgets < %{legacy_meta_max}
Obsoletes:      nabu-language-support < %{legacy_meta_max}
Obsoletes:      nabu-kde-l10n < %{legacy_meta_max}
Obsoletes:      nabu-plasma-setup-l10n < %{legacy_meta_max}
Obsoletes:      nabu-plasma-login-theme < %{legacy_meta_max}
Obsoletes:      nabu-flashlight-integration-plasma < %{legacy_meta_max}

%description
The only KDE Plasma desktop manifest for Nabu. It contains the formerly
optimal application set, stock Fedora/KDE session packages, Nabu integration,
login branding and complete Plasma translation payloads. Fedora language and
spell-checking packages follow the locale selected in Plasma Setup. No KDE
or Fedora package is forked, replaced or obsoleted.

%prep
%setup -q -c -T
mkdir kde-integration l10n widgets flashlight
tar -xzf %{SOURCE1} -C kde-integration --strip-components=1
tar -xzf %{SOURCE2} -C l10n --strip-components=1
tar --zstd -xf %{SOURCE3} -C widgets --strip-components=1
tar -xzf %{SOURCE4} -C flashlight --strip-components=1
chmod +x kde-integration/kde/senemos-nabu-color-profile kde-integration/tests/mock-kscreen-doctor
%build
%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_presetdir}/95-nabu-plasma-login.preset
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
install -Dm0644 l10n/plasma-setup-locales.tar.gz %{buildroot}%{_datadir}/senemos-nabu/l10n/plasma-setup-locales.tar.gz
install -Dm0644 l10n/macros.nabu-languages %{buildroot}%{_sysconfdir}/rpm/macros.nabu-languages
install -d %{buildroot}%{_datadir}/plasma/plasmoids
cp -a widgets/com.mcc45tr.filesearch widgets/com.mcc45tr.mweather widgets/com.mcc45tr.analogclock %{buildroot}%{_datadir}/plasma/plasmoids/
install -Dm0644 %{SOURCE5} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
install -Dm0644 %{SOURCE6} %{buildroot}%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
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
%{_presetdir}/95-nabu-plasma-login.preset
%license kde-integration/LICENSE l10n/LICENSES/common/LICENSE-MIT l10n/LICENSES/plasma-workspace/* l10n/LICENSES/plasma-setup/*
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
%{_datadir}/senemos-nabu/l10n/plasma-setup-locales.tar.gz
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
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
fi

%posttrans
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :
# KDE Connect's Fedora service definition covers TCP and UDP 1714-1764. Add
# it to the administrator-selected default zone without replacing zone files.
if [ -x /usr/bin/firewall-offline-cmd ]; then
    /usr/bin/firewall-offline-cmd --add-service=kdeconnect >/dev/null 2>&1 || :
fi
%firewalld_reload
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
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
* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-11
- Install UDisks2 so Plasma and Solid can enumerate storage devices without
  repeatedly waiting for a missing D-Bus service during session startup.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-10
- Allow KDE Connect in firewalld's default zone so LAN discovery and pairing
  work after installation without weakening unrelated firewall policy.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-9
- Stop forcing Turkish packages on global installations; use the locale chosen
  in Plasma Setup through the shared CORE language-pack installer.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-8
- Install KDE Plasma Addons so PowerDevil can load its Kameleon module.
- Include the current Fedora Turkish language and spell-checking payloads.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-7
- Read KWin's output transform directly instead of spawning kscreen-doctor
  every second, and reduce idle PipeWire graph scans.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-6
- Add grip-aware keep-awake state and control to the existing Plasma widget.
- Keep the control disabled until real ADUX1050 calibration is available.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-5
- Make DE exclusivity explicit by package name; do not conflict with the
  preceding version of this same updateable KDE manifest.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-4
- Provide the final split KDE and locale EVRs during migration so normal DNF
  updates can retire the internally version-locked legacy packages.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-3
- Own the bounded KDE desktop compatibility transition together with its
  version-locked integration payloads.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-2
- Leave retirement of shared integration names to CORE; this DE owns only its
  replacement payload and profile-specific legacy names.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-1
- Merge KDE configuration, ICC profiles, widgets, locale restoration, Plasma
  login branding and flashlight UI into the single desktop release package.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-6
- Stop applying ownership lifecycle macros to service units supplied by Plasma.
- Recover only an inactive login manager after legacy scriptlets, terminating a
  stale greeter user session before one clean start; leave active sessions alone.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-5
- Start Plasma Login Manager after the legacy base package has finished its
  removal scriptlet, but only on systems already in graphical.target.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-4
- Reassert Plasma Login Manager and Setup enablement after the complete RPM
  transaction, including removal of the superseded Plasma base package.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Keep the shared login theme as an implementation RPM so desktop and mobile
  manifests never compete to obsolete the same installed package.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Match the newest KDE integration and configuration EVRs actually retained in
  the COPR so clean AArch64 installations remain solvable.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Merge Plasma base, optimal profile, login theme and migration ownership.
- Make all Nabu locale packages hard dependencies.
