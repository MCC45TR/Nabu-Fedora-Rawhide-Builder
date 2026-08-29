%global debug_package %{nil}
%global legacy_meta_max 9999999999-99
Name:           phosh-nabu-meta
Version:        3.0.0
Release:        3%{?dist}
Summary:        Complete Phosh release profile for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-kde-l10n-1.1.0.tar.gz
BuildArch:      noarch
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

%description
The single Phosh desktop manifest for Nabu. It retains compatibility with the
former "posh" package names while installing Fedora's stock Phosh packages,
the complete application set and mandatory locale data.

%prep
%setup -q -c -T
mkdir l10n
tar -xzf %{SOURCE0} -C l10n --strip-components=1

%install
install -Dm0755 l10n/nabu-restore-kde-locales %{buildroot}%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
install -Dm0644 l10n/macros.nabu-languages %{buildroot}%{_sysconfdir}/rpm/macros.nabu-languages

%posttrans
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales || :

%files
%license l10n/LICENSES/common/LICENSE-MIT
%dir %{_libexecdir}/senemos-nabu
%{_libexecdir}/senemos-nabu/nabu-restore-kde-locales
%{_sysconfdir}/rpm/macros.nabu-languages
%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-3
- Make DE exclusivity explicit by package name so this manifest updates itself.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-2
- Leave retirement of the shared locale policy name to CORE.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 3.0.0-1
- Merge the complete locale policy into the single Phosh release RPM.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace Posh/Phosh minimal, optimal and base packages with one manifest.
