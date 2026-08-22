#!/usr/bin/bash
set -Eeuo pipefail

TARGET=/target
WORK=/work
META=/meta
LOGS=/logs
COPR_BASEURL='https://download.copr.fedorainfracloud.org/results/mcc45tr/nabu-linux/fedora-rawhide-aarch64/'
COPR_KEY_URL='https://download.copr.fedorainfracloud.org/results/mcc45tr/nabu-linux/pubkey.gpg'

mkdir -p "$WORK/dnf-cache" "$META" "$LOGS"

dnf5 -y --disable-repo='*openh264*' --setopt=install_weak_deps=False install \
    ca-certificates curl dnf5 findutils python3 rpm systemd util-linux-core \
    >"$LOGS/mobile-container-tools.log" 2>&1

curl --fail --silent --show-error --location "$COPR_KEY_URL" \
    -o "$WORK/nabu-copr-pubkey.gpg"
rpm --root "$TARGET" --import "$WORK/nabu-copr-pubkey.gpg"
rpm --root "$TARGET" -qa --qf '%{NAME}\t%{EVR}\t%{ARCH}\n' | sort \
    >"$META/mobile-packages-before.tsv"

dnf_command=(
    dnf5 -y --refresh --use-host-config --installroot="$TARGET"
    --releasever=rawhide
    --disable-repo='*openh264*'
    --setopt=install_weak_deps=False
    --setopt=keepcache=True
    --setopt=cachedir="$WORK/dnf-cache"
    --setopt=gpgcheck=1
    --repofrompath="nabu-linux,$COPR_BASEURL"
    --setopt=nabu-linux.gpgcheck=1
    --setopt="nabu-linux.gpgkey=$COPR_KEY_URL"
    --exclude=swtpm-selinux
)

mobile_profile_packages=(nabu-kde-plasma-mobile-optimal)
if [[ -d /copr-build ]]; then
    mobile_profile_packages=(
        /copr-build/nabu-repository-config-1.0.0-14.test.fc46.noarch.rpm
        /copr-build/nabu-meta-1.0.0-14.test.fc46.noarch.rpm
        /copr-build/nabu-kde-plasma-mobile-1.0.0-14.test.fc46.noarch.rpm
        /copr-build/nabu-kde-plasma-mobile-optimal-1.0.0-14.test.fc46.noarch.rpm
    )
fi

if [[ ${NABU_SKIP_DNF:-0} != 1 ]]; then
    printf '%q ' "${dnf_command[@]}" install --allowerasing \
        "${mobile_profile_packages[@]}" >"$META/mobile-dnf-command.txt"
    printf '\n' >>"$META/mobile-dnf-command.txt"
    "${dnf_command[@]}" install --allowerasing \
        "${mobile_profile_packages[@]}" \
        >"$LOGS/mobile-dnf-mobile-profile.log" 2>&1
    "${dnf_command[@]}" check >"$LOGS/mobile-dnf-check.log" 2>&1
fi

# This artifact is a fresh-install image. Force the first-run wizard to run
# before the login manager; package upgrades on a live system do not remove
# this marker.
rm -f -- "$TARGET/etc/plasma-setup-done"
systemd-sysusers --root="$TARGET"
systemctl --root="$TARGET" disable sddm.service >/dev/null 2>&1 || :
systemctl --root="$TARGET" enable --force plasmalogin.service
systemctl --root="$TARGET" enable plasma-setup.service

for package in \
    nabu-repository-config nabu-meta nabu-runtime-integration nabu-kde-config \
    nabu-kde-plasma-mobile nabu-kde-plasma-mobile-optimal \
    plasma-mobile plasma-login-manager plasma-setup \
    dolphin angelfish koko kwrite kweather kclock kalk qmlkonsole elisa-player; do
    rpm --root "$TARGET" -q "$package"
done >"$META/mobile-release-package-proof.txt"

rpm --root "$TARGET" -q --qf '%{EVR}\n' nabu-repository-config \
    | grep -Fx '1.0.0-14.test.fc46'
rpm --root "$TARGET" -q --qf '%{EVR}\n' nabu-kde-plasma-mobile \
    | grep -Fx '1.0.0-14.test.fc46'
rpm --root "$TARGET" -q --qf '%{EVR}\n' nabu-kde-plasma-mobile-optimal \
    | grep -Fx '1.0.0-14.test.fc46'
rpm --root "$TARGET" -q --qf '%{EVR}\n' nabu-runtime-integration \
    | grep -Fx '1.4.0.1-6.test.fc46'
rpm --root "$TARGET" -q --qf '%{EVR}\n' nabu-kde-config \
    | grep -Fx '1.4.0.1-6.test.fc46'

for excluded in \
    nabu-kde-meta nabu-kde-integration nabu-kde-plasma-minimal \
    nabu-kde-plasma-optimal nabu-kde-plasma-full \
    sddm sddm-wayland-plasma gwenview kate konsole; do
    if rpm --root "$TARGET" -q "$excluded" >/dev/null 2>&1; then
        printf 'Desktop package must not remain in Mobile: %s\n' "$excluded" >&2
        exit 1
    fi
done

for executable in \
    dolphin angelfish koko kwrite kweather kclock kalk qmlkonsole elisa; do
    test -x "$TARGET/usr/bin/$executable"
done
for excluded_binary in gwenview kate konsole; do
    test ! -e "$TARGET/usr/bin/$excluded_binary"
done

test -s "$TARGET/usr/share/nabu-plasma-mobile/wayland-sessions/plasma-mobile.desktop"
test "$(find "$TARGET/usr/share/nabu-plasma-mobile/wayland-sessions" \
    -maxdepth 1 -type f -name '*.desktop' | wc -l)" -eq 1
grep -Fq 'BindReadOnlyPaths=/usr/share/nabu-plasma-mobile/wayland-sessions:/usr/share/wayland-sessions' \
    "$TARGET/usr/lib/systemd/system/plasmalogin.service.d/20-nabu-mobile-session.conf"
grep -Fq 'PreselectedSession=plasma-mobile.desktop' \
    "$TARGET/usr/lib/plasmalogin/plasmalogin.conf.d/90-nabu-mobile-login.conf"
test "$(readlink "$TARGET/etc/systemd/system/display-manager.service")" \
    = '/usr/lib/systemd/system/plasmalogin.service'
test -L "$TARGET/etc/systemd/system/multi-user.target.wants/plasma-setup.service"
test ! -e "$TARGET/etc/plasma-setup-done"

setup_catalogs="$(find "$TARGET/usr/share/locale" \
    -path '*/LC_MESSAGES/org.kde.plasmasetup.mo' | wc -l)"
shell_catalogs="$(find "$TARGET/usr/share/locale" \
    -path '*/LC_MESSAGES/plasmashell.mo' | wc -l)"
printf 'plasma_setup_catalog_count=%s\nplasmashell_catalog_count=%s\n' \
    "$setup_catalogs" "$shell_catalogs" >"$META/mobile-l10n-proof.txt"
test "$setup_catalogs" -ge 36
test "$shell_catalogs" -ge 65
test -s "$TARGET/usr/share/locale/tr/LC_MESSAGES/org.kde.plasmasetup.mo"
test -s "$TARGET/usr/share/locale/tr/LC_MESSAGES/plasmashell.mo"

rm -rf -- "$TARGET/var/cache/dnf"/* "$TARGET/var/cache/libdnf5"/* 2>/dev/null || :
rpm --root "$TARGET" -qa --qf '%{NAME}\t%{EVR}\t%{ARCH}\n' | sort \
    >"$META/mobile-packages-final.tsv"

python3 - "$TARGET" "$META/mobile-rpm-file-ownership.tsv" <<'PY'
import os
import subprocess
import sys

root, output = sys.argv[1:]

def names(path):
    result = {}
    with open(path, encoding="utf-8", errors="surrogateescape") as stream:
        for line in stream:
            fields = line.rstrip("\n").split(":")
            if len(fields) >= 4 and fields[2].isdigit():
                result[fields[0]] = int(fields[2])
    return result

uids = names(os.path.join(root, "etc/passwd"))
gids = names(os.path.join(root, "etc/group"))
query = subprocess.check_output([
    "rpm", "--root", root, "-qa", "--qf",
    "[%{FILENAMES}|%{FILEUSERNAME}|%{FILEGROUPNAME}\\n]",
], text=True, errors="surrogateescape")
owners = {}
for line in query.splitlines():
    try:
        path, owner, group = line.rsplit("|", 2)
    except ValueError:
        continue
    if not path.startswith("/") or not os.path.lexists(root + path):
        continue
    if owner not in uids or group not in gids:
        raise SystemExit(f"Cannot resolve RPM ownership for {path}: {owner}:{group}")
    owners[path] = (uids[owner], gids[group])

with open(output, "w", encoding="utf-8", errors="surrogateescape") as stream:
    for path, (uid, gid) in sorted(owners.items()):
        stream.write(f"{path}|{uid}|{gid}\n")
PY

source /builder-source/tools/lib/rpm-special-modes.sh
nabu_capture_rpm_special_modes \
    "$TARGET" "$META/mobile-rpm-special-modes.tsv"
sync
