%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           gnome-mobile-nabu-meta
Version:        3.0.0
Release:        9%{?dist}
Summary:        Complete touch-oriented GNOME release profile for Xiaomi Pad 5
License:        MIT AND GPL-3.0-or-later
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-kde-l10n-1.1.0.tar.gz
Source1:        nabu-flashlight-integration-1.0.0.tar.gz
Source2:        gnome-mobile-copr.repo
Source3:        nabu-gnome-mobile-sync
Source4:        nabu-gnome-mobile-sync.service
Source5:        nabu-gnome-mobile-sync.timer
Source6:        90-nabu-gnome-mobile-sync.preset
Source7:        test-gnome-mobile-repo-sync.sh
Source8:        20-nabu-mobile-user-mode.conf
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

%description
The single touch-oriented GNOME Mobile manifest for Nabu. It enables the
signed @mobility/gnome-mobile COPR and defers synchronization of its mobile
GNOME Shell, Mutter and settings-daemon builds until the RPM transaction has
closed. The complete application and mandatory locale payload remains explicit.

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
install -Dm0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/yum.repos.d/gnome-mobile-copr.repo
install -Dm0755 %{SOURCE3} %{buildroot}%{_libexecdir}/nabu-gnome-mobile-sync
install -Dm0644 %{SOURCE4} %{buildroot}%{_unitdir}/nabu-gnome-mobile-sync.service
install -Dm0644 %{SOURCE5} %{buildroot}%{_unitdir}/nabu-gnome-mobile-sync.timer
install -Dm0644 %{SOURCE6} %{buildroot}%{_presetdir}/90-nabu-gnome-mobile-sync.preset
install -Dm0644 %{SOURCE8} %{buildroot}%{_userunitdir}/org.gnome.Shell@initial-setup.service.d/20-nabu-mobile-user-mode.conf

%check
python3 -m json.tool flashlight/gnome/metadata.json >/dev/null
sh -n flashlight/gnome/integration/nabu-gnome-extension-enable
test "$(find flashlight/translations -name '*.po' | wc -l)" = 27
bash %{SOURCE7}
grep -Fqx 'gpgcheck=1' %{SOURCE2}
grep -Fqx 'skip_if_unavailable=False' %{SOURCE2}
grep -Fq '@mobility/gnome-mobile/fedora-$releasever-$basearch/' %{SOURCE2}
grep -Fqx 'ExecStart=/usr/bin/gnome-shell --mode=user' %{SOURCE8}
grep -Fqx 'ExecStartPre=/usr/bin/gsettings set org.gnome.desktop.interface enable-animations false' %{SOURCE8}
grep -Fqx 'ProtectSystem=false' %{SOURCE4}
! grep -Fq '/var/lib/rpm' %{SOURCE4}

%posttrans
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :
install -d -m0755 /var/lib/nabu-gnome-mobile-sync
touch /var/lib/nabu-gnome-mobile-sync/pending

%post
%systemd_post nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%preun
%systemd_preun nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%postun
%systemd_postun_with_restart nabu-gnome-mobile-sync.service nabu-gnome-mobile-sync.timer

%files
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
%changelog
* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-9
- Never start the deferred DNF synchronizer from inside an active RPM
  transaction; leave the pending marker for the enabled boot/retry units.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-8
- Disable animations only in GNOME Initial Setup to avoid the Mobile Shell
  overview grab crash while preserving animations in normal user sessions.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-7
- Present GNOME account creation through the working normal Mobile Shell mode.
- Allow the deferred DNF transaction to use Fedora's current RPM database path.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-6
- Install GNOME input-method integration and Avahi for first-boot services.
- Keep the Nabu extension enable helper out of GDM and Initial Setup greeter sessions.

* Sun Aug 30 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-5
- Enable the signed @mobility/gnome-mobile COPR from the mobile meta package.
- Defer installation of mobile GNOME Shell, Mutter and settings-daemon until
  the package transaction closes, with a persistent retry timer and fail-closed checks.

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
- Replace the touch GNOME minimal/optimal and base packages with one manifest.
