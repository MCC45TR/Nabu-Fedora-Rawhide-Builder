Name:           nabu-desktop-integration
Version:        1.0.0
Release:        1%{?dist}
Summary:        Unified desktop integration source family for Xiaomi Pad 5
License:        MIT AND GPL-2.0-or-later AND GPL-3.0-or-later
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        convergence-shell.zip
Source1:        touchup.zip
Source2:        touchshell.zip
Source3:        nabu-tablet-controls.zip
Source4:        README.packaging.md
Source5:        senemos-fastfetch-config-1.3.0.tar.gz
BuildArch:      noarch
BuildRequires:  glib2-devel
BuildRequires:  gettext
BuildRequires:  jq
BuildRequires:  nodejs
BuildRequires:  python3
BuildRequires:  unzip

%description
One source family for independently installable Nabu desktop helpers. It uses
stock Fedora desktop packages and does not fork KDE Plasma or its applications.

%package -n gnome-extension-group
Version:        1.0.0
Release:        10%{?dist}
Summary:        Catalog for independently installable GNOME touch extensions

%description -n gnome-extension-group
Documentation for the independently installable GNOME touch extensions.

%package -n gnome-shell-extension-nabu-tablet-controls
Version:        1.0.0
Release:        10%{?dist}
Summary:        Native Xiaomi Pad 5 hardware controls for GNOME Shell
License:        GPL-3.0-or-later
Requires:       gnome-shell >= 51~alpha
Requires:       gnome-extensions-app
Requires:       nabu-core-meta >= 3.0.0-35
Obsoletes:      nabu-flashlight-integration-gnome < 1.0.0-16
Provides:       nabu-flashlight-integration-gnome = 1.0.0-16

%description -n gnome-shell-extension-nabu-tablet-controls
Native GNOME Quick Settings controls for Xiaomi Pad 5 flashlight, ambient
brightness, USB roles, accessories and grip-aware sleep.

%package -n gnome-shell-extension-convergence
Version:        1.0.0
Release:        10%{?dist}
Summary:        Convergence Shell for GNOME 51
License:        GPL-3.0-or-later
Requires:       gnome-shell >= 51~alpha
Requires:       gnome-extensions-app

%description -n gnome-shell-extension-convergence
A touch-first convergent shell layer with mobile navigation and helpers.

%package -n gnome-shell-extension-touchup
Version:        1.0.0
Release:        10%{?dist}
Summary:        TouchUp tablet interaction enhancements for GNOME Shell
License:        GPL-3.0-or-later
Requires:       gnome-shell >= 49
Requires:       gnome-extensions-app

%description -n gnome-shell-extension-touchup
Touch navigation, keyboard, rotation, notification and overview enhancements.

%package -n gnome-shell-extension-touchshell
Version:        1.0.0
Release:        10%{?dist}
Summary:        Touchshell touchscreen helpers for GNOME Shell
License:        GPL-2.0-or-later
Requires:       gnome-shell >= 49
Requires:       gnome-extensions-app

%description -n gnome-shell-extension-touchshell
Touch gestures, text actions, tiling and fullscreen helpers for GNOME Shell.

%package -n senemos-fastfetch-config
Version:        1.3.0
Release:        2%{?dist}
Summary:        Locale-aware Fastfetch configuration for SENEMOS
License:        MIT
Requires:       bash
Requires:       fastfetch
Requires:       python3
Conflicts:      nabu-core-meta < 3.0.0-56

%description -n senemos-fastfetch-config
Locale-aware SENEMOS Fastfetch configuration without replacing Fedora's
Fastfetch executable.

%prep
%setup -q -c -T
mkdir convergence touchup touchshell nabu
unzip -q %{SOURCE0} -d convergence
unzip -q %{SOURCE1} -d touchup
unzip -q %{SOURCE2} -d touchshell
unzip -q %{SOURCE3} -d nabu
tar -xzf %{SOURCE5}

%build
for extension in convergence touchup touchshell nabu; do
    glib-compile-schemas --strict "$extension/schemas"
done
for po in nabu/translations/*.po; do
    lang="$(basename "$po" .po)"
    mkdir -p "nabu/locale/$lang/LC_MESSAGES"
    msgfmt --check --check-format -o \
        "nabu/locale/$lang/LC_MESSAGES/nabu_tablet_control.mo" "$po"
done
python3 -m py_compile senemos-fastfetch-config-1.3.0/bin/senemos-fastfetch-value

%install
install -d %{buildroot}%{_datadir}/gnome-shell/extensions
cp -a convergence %{buildroot}%{_datadir}/gnome-shell/extensions/convergence@daniel-blandford.github.io
cp -a touchup %{buildroot}%{_datadir}/gnome-shell/extensions/touchup@mityax
cp -a touchshell %{buildroot}%{_datadir}/gnome-shell/extensions/touchshell@touchshell.com
rm -f \
    %{buildroot}%{_datadir}/gnome-shell/extensions/convergence@daniel-blandford.github.io/LICENSE \
    %{buildroot}%{_datadir}/gnome-shell/extensions/touchup@mityax/LICENSE.md \
    %{buildroot}%{_datadir}/gnome-shell/extensions/touchshell@touchshell.com/LICENSE
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/nabulinuxproject@mcc45tr
install -Dm0644 nabu/extension.js nabu/metadata.json nabu/prefs.js \
    %{buildroot}%{_datadir}/gnome-shell/extensions/nabulinuxproject@mcc45tr/
cp -a nabu/schemas nabu/locale \
    %{buildroot}%{_datadir}/gnome-shell/extensions/nabulinuxproject@mcc45tr/
install -Dm0755 nabu/integration/nabu-gnome-extension-enable \
    %{buildroot}%{_libexecdir}/nabu-gnome-extension-enable
install -Dm0644 nabu/integration/nabu-gnome-extension-enable.service \
    %{buildroot}%{_prefix}/lib/systemd/user/nabu-gnome-extension-enable.service
install -d %{buildroot}%{_prefix}/lib/systemd/user/graphical-session.target.wants
ln -s ../nabu-gnome-extension-enable.service \
    %{buildroot}%{_prefix}/lib/systemd/user/graphical-session.target.wants/nabu-gnome-extension-enable.service
install -Dpm0644 %{SOURCE4} %{buildroot}%{_docdir}/gnome-extension-group/README.md

fastfetch=senemos-fastfetch-config-1.3.0
install -Dm0755 "$fastfetch/bin/senemos-fastfetch" %{buildroot}%{_bindir}/senemos-fastfetch
install -Dm0755 "$fastfetch/bin/senemos-fastfetch-value" %{buildroot}%{_libexecdir}/senemos-fastfetch-value
install -Dm0644 "$fastfetch/profile.d/senemos-fastfetch.sh" %{buildroot}%{_sysconfdir}/profile.d/senemos-fastfetch.sh
install -d %{buildroot}%{_sysconfdir}/xdg/fastfetch
ln -s ../../../usr/share/senemos-fastfetch-config/i18n/en.jsonc \
    %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc
install -Dm0644 "$fastfetch/man/senemos-fastfetch.1" %{buildroot}%{_mandir}/man1/senemos-fastfetch.1
install -d %{buildroot}%{_datadir}/senemos-fastfetch-config/i18n
install -m0644 "$fastfetch"/i18n/*.jsonc %{buildroot}%{_datadir}/senemos-fastfetch-config/i18n/

%check
for pair in \
    'convergence:convergence@daniel-blandford.github.io' \
    'touchup:touchup@mityax' \
    'touchshell:touchshell@touchshell.com' \
    'nabu:nabulinuxproject@mcc45tr'; do
    extension=${pair%%:*}
    uuid=${pair#*:}
    test "$(jq -r .uuid "$extension/metadata.json")" = "$uuid"
    jq -e '."shell-version" | index("51")' "$extension/metadata.json" >/dev/null
    find "$extension" -type f -name '*.js' -print0 | xargs -0 -n1 node --check
done
test "$(find nabu/translations -name '*.po' | wc -l)" = 27
bash -n senemos-fastfetch-config-1.3.0/bin/senemos-fastfetch
bash -n senemos-fastfetch-config-1.3.0/profile.d/senemos-fastfetch.sh
test "$(find senemos-fastfetch-config-1.3.0/i18n -name '*.jsonc' | wc -l)" = 27
test "$(readlink %{buildroot}%{_sysconfdir}/xdg/fastfetch/config.jsonc)" = \
    "../../../usr/share/senemos-fastfetch-config/i18n/en.jsonc"

%files -n gnome-extension-group
%doc %{_docdir}/gnome-extension-group/README.md

%files -n gnome-shell-extension-convergence
%license convergence/LICENSE
%dir %{_datadir}/gnome-shell/extensions/convergence@daniel-blandford.github.io
%{_datadir}/gnome-shell/extensions/convergence@daniel-blandford.github.io/*

%files -n gnome-shell-extension-touchup
%license touchup/LICENSE.md
%dir %{_datadir}/gnome-shell/extensions/touchup@mityax
%{_datadir}/gnome-shell/extensions/touchup@mityax/*

%files -n gnome-shell-extension-touchshell
%license touchshell/LICENSE
%dir %{_datadir}/gnome-shell/extensions/touchshell@touchshell.com
%{_datadir}/gnome-shell/extensions/touchshell@touchshell.com/*

%files -n gnome-shell-extension-nabu-tablet-controls
%license nabu/LICENSE
%{_datadir}/gnome-shell/extensions/nabulinuxproject@mcc45tr
%{_libexecdir}/nabu-gnome-extension-enable
%{_prefix}/lib/systemd/user/nabu-gnome-extension-enable.service
%{_prefix}/lib/systemd/user/graphical-session.target.wants/nabu-gnome-extension-enable.service

%files -n senemos-fastfetch-config
%license senemos-fastfetch-config-1.3.0/LICENSE
%doc senemos-fastfetch-config-1.3.0/README.md
%{_bindir}/senemos-fastfetch
%{_libexecdir}/senemos-fastfetch-value
%{_sysconfdir}/profile.d/senemos-fastfetch.sh
%{_sysconfdir}/xdg/fastfetch/config.jsonc
%{_mandir}/man1/senemos-fastfetch.1*
%{_datadir}/senemos-fastfetch-config/

%changelog
* Sun Sep 06 2026 mcc45tr <mcc45tr@gmail.com> - 1.0.0-1
- Consolidate GNOME extensions and Fastfetch into one COPR source family.
- Preserve all existing binary RPM names and use stock desktop packages.
