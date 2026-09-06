%global debug_package %{nil}
%global legacy_meta_max 9999999999-99

Name:           nabu-desktop-metas
Version:        3.0.0
Release:        100%{?dist}
Summary:        Unified desktop profile family for Xiaomi Pad 5
License:        MIT AND GPL-2.0-or-later AND GPL-3.0-or-later AND BSD-2-Clause AND CC0-1.0
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        nabu-kde-l10n-1.1.0.tar.gz
Source1:        nabu-flashlight-integration-1.0.0.tar.gz
Source2:        nabu-kde-integration-1.4.0.1.tar.gz
Source3:        nabu-kde-widgets-debug-1.0.1.tar.zst
Source4:        95-nabu-plasma-login.preset
Source5:        80-nabu-plasma-login-theme.conf
Source6:        nabu-plasma-login.svg
Source7:        90-nabu-powerdevil.conf
Source8:        90-nabu-compositor-realtime.conf
Source9:        plasma-mobile.desktop
Source10:       20-nabu-mobile-session.conf
Source11:       90-nabu-mobile-login.conf
Source12:       95-nabu-plasma-mobile.preset
Source13:       gnome-mobile-copr.repo
Source14:       nabu-gnome-mobile-sync
Source15:       nabu-gnome-mobile-sync.service
Source16:       nabu-gnome-mobile-sync.timer
Source17:       90-nabu-gnome-mobile-sync.preset
Source18:       test-gnome-mobile-repo-sync.sh
Source19:       20-nabu-mobile-user-mode.conf
BuildArch:      noarch
BuildRequires:  desktop-file-utils
BuildRequires:  firewalld-filesystem
BuildRequires:  gettext
BuildRequires:  glib2
BuildRequires:  lcms2
BuildRequires:  python3
BuildRequires:  systemd-rpm-macros

%description
One source package for the five supported Nabu desktop manifests. Existing
binary RPM names, dependencies, conflicts, integration payloads and update
semantics are preserved for ordinary DNF upgrades.

%package -n gnome-nabu-meta
Summary:        Complete GNOME release profile for Xiaomi Pad 5
Requires:       nabu-core-meta >= 3.0.0-35
Requires:       glibc-all-langpacks
Requires:       bash
Requires:       coreutils
Requires:       grep
Requires:       filesystem
Requires:       gzip
Requires:       tar
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gnome-session-wayland-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       mutter
Requires:       gnome-settings-daemon
Requires:       gnome-software
Requires:       ptyxis
Requires:       nautilus
Requires:       firefox
Requires:       loupe
Requires:       gnome-weather
Requires:       gnome-clocks
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       showtime
Requires:       papers
Requires:       gnome-system-monitor
Requires:       nano
Requires:       fastfetch
Requires:       dconf
Requires:       polkit
Requires:       PackageKit-command-not-found
Requires:       PackageKit-gtk3-module
Requires:       glycin-thumbnailer
Requires:       gnome-epub-thumbnailer
Requires:       gst-thumbnailers
Requires:       gvfs-afc
Requires:       gvfs-fuse
Requires:       gvfs-goa
Requires:       gvfs-gphoto2
Requires:       gvfs-mtp
Requires:       gvfs-smb
Requires:       librsvg2
Requires:       papers-nautilus
Requires:       sushi
Conflicts:      kde-plasma-nabu-meta
Conflicts:      kde-plasma-mobile-nabu-meta
Conflicts:      gnome-mobile-nabu-meta
Conflicts:      phosh-nabu-meta
Provides:       nabu-desktop-profile-meta = 3
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-gnome-base-abi = 2
Provides:       nabu-gnome-meta = %{version}-%{release}
Provides:       nabu-language-support = %{version}-%{release}
Provides:       nabu-flashlight-integration-gnome = %{version}-%{release}
Obsoletes:      nabu-gnome-base < %{legacy_meta_max}
Obsoletes:      nabu-gnome-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-gnome-optimal-meta < %{legacy_meta_max}

%description -n gnome-nabu-meta
The single GNOME desktop manifest for Nabu. It installs the formerly optimal
stock Fedora GNOME application set and makes the Nabu locale payload mandatory.

%package -n gnome-mobile-nabu-meta
Summary:        Complete touch-oriented GNOME release profile for Xiaomi Pad 5
Requires:       nabu-core-meta >= 3.0.0-35
Requires:       glibc-all-langpacks
Requires:       bash
Requires:       coreutils
Requires:       grep
Requires:       filesystem
Requires:       gzip
Requires:       tar
Requires:       dnf5
Requires:       rpm
Requires:       systemd
Requires:       util-linux-core
Requires:       gnome-shell
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-initial-setup
Requires:       gnome-settings-daemon
Requires:       mutter
Requires:       ibus
Requires:       ibus-gtk3
Requires:       ibus-gtk4
Requires:       avahi
Requires:       gnome-software
Requires:       gnome-console
Requires:       nautilus
Requires:       firefox
Requires:       loupe
Requires:       gnome-weather
Requires:       gnome-clocks
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       totem
Requires:       papers
Requires:       file-roller
Requires:       nano
Requires:       fastfetch
Conflicts:      kde-plasma-nabu-meta
Conflicts:      kde-plasma-mobile-nabu-meta
Conflicts:      gnome-nabu-meta
Conflicts:      phosh-nabu-meta
Provides:       nabu-desktop-profile-meta = 3
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-gnome-mobile-base-abi = 2
Provides:       nabu-language-support = %{version}-%{release}
Provides:       nabu-flashlight-integration-gnome = %{version}-%{release}
Obsoletes:      nabu-gnome-mobile-base < %{legacy_meta_max}
Obsoletes:      nabu-gnome-mobile-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-gnome-mobile-optimal-meta < %{legacy_meta_max}

%description -n gnome-mobile-nabu-meta
The single touch-oriented GNOME Mobile manifest for Nabu. It enables the
signed @mobility/gnome-mobile COPR and defers synchronization of its mobile
GNOME Shell, Mutter and settings-daemon builds until the RPM transaction has
closed. The complete application and mandatory locale payload remains explicit.

%package -n kde-plasma-nabu-meta
Summary:        Complete KDE Plasma release profile for Xiaomi Pad 5
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
Requires:       pulseaudio-utils
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

%description -n kde-plasma-nabu-meta
The only KDE Plasma desktop manifest for Nabu. It contains the formerly
optimal application set, stock Fedora/KDE session packages, Nabu integration,
login branding and complete Plasma translation payloads. Fedora language and
spell-checking packages follow the locale selected in Plasma Setup. No KDE
or Fedora package is forked, replaced or obsoleted.

%package -n kde-plasma-mobile-nabu-meta
Summary:        Complete KDE Plasma Mobile release profile for Xiaomi Pad 5
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

%description -n kde-plasma-mobile-nabu-meta
The only KDE Plasma Mobile manifest for Nabu. It combines the mobile session,
former optimal application set, Nabu integration, login branding and complete
Plasma translations. Fedora language packages follow the locale selected in
initial setup. It uses unmodified Fedora and KDE packages and never
claims to replace plasma-desktop.

%package -n phosh-nabu-meta
Summary:        Complete Phosh release profile for Xiaomi Pad 5
Requires:       nabu-core-meta >= 3.0.0
Requires:       glibc-all-langpacks
Requires:       bash
Requires:       coreutils
Requires:       filesystem
Requires:       gzip
Requires:       tar
Requires:       phosh
Requires:       phosh-mobile-settings
Requires:       gnome-session
Requires:       gdm
Requires:       gnome-control-center
Requires:       gnome-settings-daemon
Requires:       gnome-software
Requires:       gnome-console
Requires:       nautilus
Requires:       firefox
Requires:       loupe
Requires:       gnome-weather
Requires:       gnome-clocks
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       totem
Requires:       papers
Requires:       file-roller
Requires:       nano
Requires:       fastfetch
Conflicts:      kde-plasma-nabu-meta
Conflicts:      kde-plasma-mobile-nabu-meta
Conflicts:      gnome-nabu-meta
Conflicts:      gnome-mobile-nabu-meta
Provides:       nabu-desktop-profile-meta = 3
Provides:       nabu-desktop-session = %{version}-%{release}
Provides:       nabu-posh-base-abi = 2
Provides:       nabu-language-support = %{version}-%{release}
Obsoletes:      nabu-posh-base < %{legacy_meta_max}
Obsoletes:      nabu-posh-minimal-meta < %{legacy_meta_max}
Obsoletes:      nabu-posh-optimal-meta < %{legacy_meta_max}

%description -n phosh-nabu-meta
The single Phosh desktop manifest for Nabu. It retains compatibility with the
former "posh" package names while installing Fedora's stock Phosh packages,
the complete application set and mandatory locale data.

%prep
%setup -q -c -T
mkdir l10n flashlight kde-integration widgets
tar -xzf %{SOURCE0} -C l10n --strip-components=1
tar -xzf %{SOURCE1} -C flashlight --strip-components=1
tar -xzf %{SOURCE2} -C kde-integration --strip-components=1
tar --zstd -xf %{SOURCE3} -C widgets --strip-components=1
chmod +x kde-integration/kde/senemos-nabu-color-profile kde-integration/tests/mock-kscreen-doctor

%build

%install
# Shared GNOME and GNOME Mobile payload
install -Dm0755 l10n/nabu-restore-kde-locales %{buildroot}%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
install -Dm0644 l10n/macros.nabu-languages %{buildroot}%{_sysconfdir}/rpm/macros.nabu-languages
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org
install -Dm0644 flashlight/gnome/extension.js %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/extension.js
install -Dm0644 flashlight/gnome/metadata.json %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/metadata.json
install -Dm0644 flashlight/gnome/prefs.js %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/prefs.js
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/schemas
install -Dm0644 flashlight/gnome/schemas/*.gschema.xml %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/schemas/
glib-compile-schemas --strict %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/schemas
for po in flashlight/translations/*.po; do
    lang="$(basename "$po" .po)"
    install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/locale/$lang/LC_MESSAGES
    msgfmt --check --check-format -o %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/locale/$lang/LC_MESSAGES/nabu_tablet_control.mo "$po"
done
install -Dm0755 flashlight/gnome/integration/nabu-gnome-extension-enable %{buildroot}%{_libexecdir}/nabu-gnome-extension-enable
install -Dm0644 flashlight/gnome/integration/nabu-gnome-extension-enable.service %{buildroot}%{_userunitdir}/nabu-gnome-extension-enable.service
install -d %{buildroot}%{_userunitdir}/graphical-session.target.wants
ln -s ../nabu-gnome-extension-enable.service %{buildroot}%{_userunitdir}/graphical-session.target.wants/nabu-gnome-extension-enable.service
install -Dm0644 %{SOURCE13} %{buildroot}%{_sysconfdir}/yum.repos.d/gnome-mobile-copr.repo
install -Dm0755 %{SOURCE14} %{buildroot}%{_libexecdir}/nabu-gnome-mobile-sync
install -Dm0644 %{SOURCE15} %{buildroot}%{_unitdir}/nabu-gnome-mobile-sync.service
install -Dm0644 %{SOURCE16} %{buildroot}%{_unitdir}/nabu-gnome-mobile-sync.timer
install -Dm0644 %{SOURCE17} %{buildroot}%{_presetdir}/90-nabu-gnome-mobile-sync.preset
install -Dm0644 %{SOURCE19} %{buildroot}%{_userunitdir}/org.gnome.Shell@initial-setup.service.d/20-nabu-mobile-user-mode.conf

# Shared KDE Plasma payload
install -Dm0644 %{SOURCE4} %{buildroot}%{_presetdir}/95-nabu-plasma-login.preset
install -Dm0755 kde-integration/kde/nabu-audio-orientation %{buildroot}%{_libexecdir}/senemos-nabu/nabu-audio-orientation
install -Dm0644 kde-integration/kde/nabu-speaker-filter-chain.conf %{buildroot}%{_datadir}/senemos-nabu/nabu-speaker-filter-chain.conf
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
install -Dm0644 %{SOURCE7} %{buildroot}%{_prefix}/lib/environment.d/90-nabu-powerdevil.conf
install -Dm0644 %{SOURCE8} %{buildroot}%{_unitdir}/user@.service.d/90-nabu-compositor-realtime.conf
install -d %{buildroot}%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight
cp -a flashlight/plasma/. %{buildroot}%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight/
install -Dm0644 flashlight/plasma-update/org.senemos.nabu.flashlight.js %{buildroot}%{_datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/org.senemos.nabu.flashlight.js

# Plasma Mobile session-only payload
install -Dm0644 %{SOURCE9} %{buildroot}%{_datadir}/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop
install -Dm0644 %{SOURCE10} %{buildroot}%{_unitdir}/plasmalogin.service.d/20-nabu-mobile-session.conf
install -Dm0644 %{SOURCE11} %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf
install -Dm0644 %{SOURCE12} %{buildroot}%{_presetdir}/95-nabu-plasma-mobile.preset
install -d %{buildroot}%{_datadir}/nabu-plasma-mobile/xsessions

%check
# gnome-mobile-nabu-meta
python3 -m json.tool flashlight/gnome/metadata.json >/dev/null
glib-compile-schemas --strict --dry-run flashlight/gnome/schemas
sh -n flashlight/gnome/integration/nabu-gnome-extension-enable
test "$(find flashlight/translations -name '*.po' | wc -l)" = 27
grep -Fq '/usr/libexec/nabu-sar-control' flashlight/gnome/extension.js
grep -Fq 'show-hold-awake' flashlight/gnome/schemas/org.gnome.shell.extensions.nabu-tablet-controls.gschema.xml
bash %{SOURCE18}
grep -Fqx 'gpgcheck=1' %{SOURCE13}
grep -Fqx 'skip_if_unavailable=False' %{SOURCE13}
grep -Fq '@mobility/gnome-mobile/fedora-$releasever-$basearch/' %{SOURCE13}
grep -Fqx 'ExecStart=/usr/bin/gnome-shell --mode=user' %{SOURCE19}
grep -Fqx 'ExecStartPre=/usr/bin/gsettings set org.gnome.desktop.interface enable-animations false' %{SOURCE19}
grep -Fqx 'ProtectSystem=false' %{SOURCE15}
! grep -Fq '/var/lib/rpm' %{SOURCE15}

# kde-plasma-nabu-meta
python3 -m py_compile kde-integration/kde/nabu-audio-orientation kde-integration/kde/senemos-nabu-display-profile kde-integration/kde/senemos-nabu-color-profile
grep -Fq 'audio.position = [ FL FR RL RR ]' kde-integration/kde/nabu-speaker-filter-chain.conf
python3 kde-integration/kde/senemos-nabu-color-profile catalog
python3 -m unittest -v kde-integration/tests/test_color_profile.py
python3 -m unittest -v kde-integration/tests/test_audio_orientation.py
bash -n kde-integration/kde/senemos-nabu-color-settings
desktop-file-validate kde-integration/kde/org.senemos.nabu.colorprofiles.desktop
python3 -c 'import json, pathlib; root=pathlib.Path("widgets"); expected={"com.mcc45tr.filesearch","com.mcc45tr.mweather","com.mcc45tr.analogclock"}; assert {json.loads((root/x/"metadata.json").read_text())["KPlugin"]["Id"] for x in expected} == expected'
python3 -m json.tool flashlight/plasma/metadata.json >/dev/null
grep -Fq '/usr/libexec/nabu-sar-control' flashlight/plasma/contents/ui/main.qml
grep -Fq 'Keep awake while held' flashlight/plasma/contents/ui/main.qml

# kde-plasma-mobile-nabu-meta
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

%posttrans -n gnome-nabu-meta
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :

%files -n gnome-nabu-meta
%license l10n/LICENSES/common/LICENSE-MIT
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_sysconfdir}/rpm/macros.nabu-languages
%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/
%{_libexecdir}/nabu-gnome-extension-enable
%{_userunitdir}/nabu-gnome-extension-enable.service
%{_userunitdir}/graphical-session.target.wants/nabu-gnome-extension-enable.service

%posttrans -n gnome-mobile-nabu-meta
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :
install -d -m0755 /var/lib/nabu-gnome-mobile-sync
touch /var/lib/nabu-gnome-mobile-sync/pending

%post -n gnome-mobile-nabu-meta
%systemd_post nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%preun -n gnome-mobile-nabu-meta
%systemd_preun nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%postun -n gnome-mobile-nabu-meta
%systemd_postun_with_restart nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%files -n gnome-mobile-nabu-meta
%license l10n/LICENSES/common/LICENSE-MIT
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_sysconfdir}/rpm/macros.nabu-languages
%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/
%{_libexecdir}/nabu-gnome-extension-enable
%{_userunitdir}/nabu-gnome-extension-enable.service
%{_userunitdir}/graphical-session.target.wants/nabu-gnome-extension-enable.service
%config(noreplace) %{_sysconfdir}/yum.repos.d/gnome-mobile-copr.repo
%{_libexecdir}/nabu-gnome-mobile-sync
%{_unitdir}/nabu-gnome-mobile-sync.service
%{_unitdir}/nabu-gnome-mobile-sync.timer
%{_presetdir}/90-nabu-gnome-mobile-sync.preset
%{_userunitdir}/org.gnome.Shell@initial-setup.service.d/20-nabu-mobile-user-mode.conf

%post -n kde-plasma-nabu-meta
%systemd_user_post nabu-audio-orientation.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable plasma-setup.service >/dev/null 2>&1 || :
fi

%posttrans -n kde-plasma-nabu-meta
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

%preun -n kde-plasma-nabu-meta
%systemd_user_preun nabu-audio-orientation.service

%postun -n kde-plasma-nabu-meta
%systemd_user_postun_with_restart nabu-audio-orientation.service

%files -n kde-plasma-nabu-meta
%{_presetdir}/95-nabu-plasma-login.preset
%license kde-integration/LICENSE l10n/LICENSES/common/LICENSE-MIT l10n/LICENSES/plasma-workspace/*
%doc kde-integration/README.md kde-integration/COLOR-PROFILE-PROVENANCE.md
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-audio-orientation
%dir %{_datadir}/senemos-nabu
%{_datadir}/senemos-nabu/nabu-speaker-filter-chain.conf
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
%dir %{_datadir}/senemos-nabu/l10n
%{_datadir}/senemos-nabu/l10n/plasma-shell-locales.tar.gz
%{_datadir}/senemos-nabu/l10n/plasma-setup-locales.tar.gz
%{_datadir}/plasma/plasmoids/com.mcc45tr.filesearch/
%{_datadir}/plasma/plasmoids/com.mcc45tr.mweather/
%{_datadir}/plasma/plasmoids/com.mcc45tr.analogclock/
%{_datadir}/backgrounds/nabu/nabu-plasma-login.svg
%{_prefix}/lib/environment.d/90-nabu-powerdevil.conf
%dir %{_unitdir}/user@.service.d
%{_unitdir}/user@.service.d/90-nabu-compositor-realtime.conf
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight/
%{_datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/org.senemos.nabu.flashlight.js

%post -n kde-plasma-mobile-nabu-meta
%systemd_user_post nabu-audio-orientation.service
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable sddm.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable plasma-setup.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable --force plasmalogin.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sshd.service >/dev/null 2>&1 || :
fi

%posttrans -n kde-plasma-mobile-nabu-meta
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

%preun -n kde-plasma-mobile-nabu-meta
%systemd_user_preun nabu-audio-orientation.service

%postun -n kde-plasma-mobile-nabu-meta
%systemd_user_postun_with_restart nabu-audio-orientation.service

%files -n kde-plasma-mobile-nabu-meta
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
%{_prefix}/lib/environment.d/90-nabu-powerdevil.conf
%dir %{_unitdir}/user@.service.d
%{_unitdir}/user@.service.d/90-nabu-compositor-realtime.conf
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/80-nabu-plasma-login-theme.conf
%{_datadir}/plasma/plasmoids/org.senemos.nabu.flashlight/
%{_datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/org.senemos.nabu.flashlight.js

%posttrans -n phosh-nabu-meta
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :

%files -n phosh-nabu-meta
%license l10n/LICENSES/common/LICENSE-MIT
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_sysconfdir}/rpm/macros.nabu-languages

%changelog
* Sun Sep 06 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-100
- Build all five desktop manifests from one COPR source family.
- Preserve the existing binary names and stock Fedora/KDE package policy.
