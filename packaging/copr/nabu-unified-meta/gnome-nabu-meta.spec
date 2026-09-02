%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           gnome-nabu-meta
Version:        3.0.0
Release:        5%{?dist}
Summary:        Complete GNOME release profile for Xiaomi Pad 5
License:        MIT AND GPL-3.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-kde-l10n-1.1.0.tar.gz
Source1:        nabu-flashlight-integration-1.0.0.tar.gz
BuildArch:      noarch
BuildRequires:  python3
BuildRequires:  gettext
BuildRequires:  systemd-rpm-macros
Requires:       nabu-core-meta >= 3.0.0
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
# 51~rc includes upstream MR 4962, which keeps the orientation sensor claim
# balanced when a touchscreen-only device starts directly in touch mode.
Requires:       mutter >= 51~rc-1
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

%description
The single GNOME desktop manifest for Nabu. It installs the formerly optimal
stock Fedora GNOME application set and makes the Nabu locale payload mandatory.

%prep
%setup -q -c -T
mkdir l10n flashlight
tar -xzf %{SOURCE0} -C l10n --strip-components=1
tar -xzf %{SOURCE1} -C flashlight --strip-components=1

%install
install -Dm0755 l10n/nabu-restore-kde-locales %{buildroot}%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
install -Dm0644 l10n/macros.nabu-languages %{buildroot}%{_sysconfdir}/rpm/macros.nabu-languages
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org
install -Dm0644 flashlight/gnome/extension.js %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/extension.js
install -Dm0644 flashlight/gnome/metadata.json %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/metadata.json
for po in flashlight/translations/*.po; do
    lang="$(basename "$po" .po)"
    install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/locale/$lang/LC_MESSAGES
    msgfmt --check --check-format -o %{buildroot}%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/locale/$lang/LC_MESSAGES/nabu_tablet_control.mo "$po"
done
install -Dm0755 flashlight/gnome/integration/nabu-gnome-extension-enable %{buildroot}%{_libexecdir}/nabu-gnome-extension-enable
install -Dm0644 flashlight/gnome/integration/nabu-gnome-extension-enable.service %{buildroot}%{_userunitdir}/nabu-gnome-extension-enable.service
install -d %{buildroot}%{_userunitdir}/graphical-session.target.wants
ln -s ../nabu-gnome-extension-enable.service %{buildroot}%{_userunitdir}/graphical-session.target.wants/nabu-gnome-extension-enable.service

%check
python3 -m json.tool flashlight/gnome/metadata.json >/dev/null
sh -n flashlight/gnome/integration/nabu-gnome-extension-enable
test "$(find flashlight/translations -name '*.po' | wc -l)" = 27

%posttrans
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :

%files
%license l10n/LICENSES/common/LICENSE-MIT
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_sysconfdir}/rpm/macros.nabu-languages
%{_datadir}/gnome-shell/extensions/nabu-flashlight@senemos.org/
%{_libexecdir}/nabu-gnome-extension-enable
%{_userunitdir}/nabu-gnome-extension-enable.service
%{_userunitdir}/graphical-session.target.wants/nabu-gnome-extension-enable.service
%changelog
* Wed Sep 02 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-5
- Require the upstream Mutter auto-rotation lifecycle fix for touch-first devices.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-4
- Expand the independent stock GNOME Quick Settings extension into
  capability-aware Nabu tablet controls and enable it once at first login.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-3
- Make DE exclusivity explicit by package name so this manifest updates itself.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-2
- Leave retirement of shared locale and tablet-control names to CORE.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-1
- Merge the locale policy and GNOME tablet-control extension into this DE RPM.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace minimal/optimal and base packages with one complete GNOME manifest.
