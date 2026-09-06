%global debug_package %{nil}

Name:           senemos-nabu-plymouth
Version:        1.0.0
Release:        11.test%{?dist}
Summary:        Pixel-stable Plymouth theme for Xiaomi Pad 5
License:        MIT
URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder
Source0:        %{name}-%{version}.tar.zst
BuildArch:      noarch
BuildRequires:  ImageMagick
Requires:       plymouth
Requires:       plymouth-plugin-script
Requires:       abattis-cantarell-fonts
Requires:       dracut
Requires(post): coreutils
Requires(post): gawk
Requires(posttrans): coreutils
Requires(posttrans): rpm

%description
SENEMOS boot, shutdown, reboot and offline-update visuals for Xiaomi Pad 5.
The supplied Xiaomi and Fedora vector artwork is rasterized at exact physical
pixel dimensions. Plymouth device scaling is pinned to one so desktop HiDPI
settings cannot double the theme geometry.

%prep
%autosetup

%build
magick -background none Fedora_logo.svg fedora-logo.png
magick -background none Xiaomi_logo.svg xiaomi-logo.png

%install
theme_dir=%{buildroot}%{_datadir}/plymouth/themes/senemos-nabu
install -d -m0755 "$theme_dir"
install -m0644 \
    senemos-nabu.plymouth senemos-nabu.script \
    Fedora_logo.svg Xiaomi_logo.svg fedora-logo.png xiaomi-logo.png \
    progress-track.png progress-cap.png progress-center.png \
    "$theme_dir"/

%check
test "$(identify -format '%%wx%%h' %{buildroot}%{_datadir}/plymouth/themes/senemos-nabu/fedora-logo.png)" = 427x120
test "$(identify -format '%%wx%%h' %{buildroot}%{_datadir}/plymouth/themes/senemos-nabu/xiaomi-logo.png)" = 312x312
grep -Fq 'screen_height - fedora.image.GetHeight() - 40' \
    %{buildroot}%{_datadir}/plymouth/themes/senemos-nabu/senemos-nabu.script
! grep -Eq '(layout_scale|short_edge|fedora[.]image.*Scale|xiaomi[.]image.*Scale)' \
    %{buildroot}%{_datadir}/plymouth/themes/senemos-nabu/senemos-nabu.script
grep -Fq 'DeviceScale=1' %{_specdir}/senemos-nabu-plymouth.spec

%post
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme senemos-nabu || :
fi

# Plymouth's DRM renderer independently infers a scale of two from the Nabu
# panel DPI. Store an explicit daemon setting while preserving other local
# administrator keys in the Plymouth-owned configuration file.
config=/etc/plymouth/plymouthd.conf
temporary=$(mktemp /etc/plymouth/.plymouthd.conf.XXXXXX)
awk '
    BEGIN { in_daemon=0; saw_daemon=0; wrote=0 }
    /^\[Daemon\][[:space:]]*$/ {
        if (in_daemon && !wrote) print "DeviceScale=1"
        in_daemon=1; saw_daemon=1; print; next
    }
    /^\[/ {
        if (in_daemon && !wrote) { print "DeviceScale=1"; wrote=1 }
        in_daemon=0
    }
    in_daemon && /^[[:space:]]*DeviceScale[[:space:]]*=/ {
        if (!wrote) { print "DeviceScale=1"; wrote=1 }
        next
    }
    { print }
    END {
        if (in_daemon && !wrote) print "DeviceScale=1"
        else if (!saw_daemon) print "[Daemon]\nDeviceScale=1"
    }
' "$config" >"$temporary"
chmod --reference="$config" "$temporary"
chown --reference="$config" "$temporary"
mv -f "$temporary" "$config"

%posttrans -p /usr/bin/bash
install -d -m0755 /var/lib/nabu-kernel-maintenance/pending.d
for item in \
    kernel:senemos-nabu-kernel \
    mainline:senemos-nabu-kernel-mainline \
    mainline-unstable:senemos-nabu-kernel-mainline-unstable; do
    channel=${item%%:*}
    package=${item#*:}
    rpm -q "$package" >/dev/null 2>&1 || continue
    temporary=$(mktemp "/var/lib/nabu-kernel-maintenance/pending.d/.${channel}.XXXXXX")
    printf 'plymouth-theme-update\n' >"$temporary"
    chmod 0644 "$temporary"
    mv -f "$temporary" "/var/lib/nabu-kernel-maintenance/pending.d/$channel"
done

%files
%{_datadir}/plymouth/themes/senemos-nabu/

%changelog
* Sun Sep 06 2026 mcc45tr <mcc45tr@gmail.com> - 1.0.0-11.test
- Force Plymouth DeviceScale=1 on the Nabu framebuffer so Plasma's 200 percent
  desktop scale cannot double the boot-theme logos, progress bar or text.
- Queue only the three supported kernel families for refreshed UKIs.

* Sun Sep 06 2026 mcc45tr <mcc45tr@gmail.com> - 1.0.0-10.test
- Restore supplied artwork with native dimensions and orientation-aware layout.
- Place the 427x120 Fedora logo exactly 40 pixels above the lower edge.
