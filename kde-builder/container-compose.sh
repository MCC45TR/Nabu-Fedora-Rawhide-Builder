#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

source /builder/profile.env
TARGET=/target
META=/meta
LOGS=/logs

log() { printf '[KDE] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

[[ $(uname -m) == aarch64 ]] || die "KDE compose is not AArch64: $(uname -m)"
mkdir -p "$META" "$LOGS" /work/dnf-cache "$TARGET"

dnf5 -y --disablerepo='*openh264*' --setopt=install_weak_deps=False install \
    ca-certificates curl dnf5 e2fsprogs findutils fuse3 python3 rpm systemd util-linux \
    >"$LOGS/container-tools.log" 2>&1

# --use-host-config makes RPM evaluate the compose container's macro. Set it
# here so KDE translations are unpacked during compose, not repaired at login.
install -d -m0755 /etc/rpm
printf '%%_install_langs all\n' >/etc/rpm/macros.zz-nabu-languages
rpm --showrc | grep -Eq '^[^:]*:[[:space:]]+_install_langs[[:space:]]+all$' || \
    die 'Compose RPM language policy is not all'

fuse2fs -o fakeroot /work/system.img "$TARGET" >"$LOGS/fuse-mount.log" 2>&1
mountpoint -q "$TARGET" || die 'Could not mount cloned CORE image'
cleanup_target() {
    if mountpoint -q "$TARGET" 2>/dev/null; then
        sync || :
        fusermount3 -u "$TARGET" || fusermount3 -uz "$TARGET" || :
    fi
}
trap cleanup_target EXIT

rpm --root "$TARGET" -q nabu-core-meta "$KDE_KERNEL_PACKAGE" nabu-boot-refind \
    >"$META/core-selection-before.txt"
core_evr=$(rpm --root "$TARGET" -q --qf '%{VERSION}-%{RELEASE}\n' nabu-core-meta)
kernel_evr=$(rpm --root "$TARGET" -q --qf '%{VERSION}-%{RELEASE}\n' "$KDE_KERNEL_PACKAGE")
[[ $core_evr =~ ^3[.]0[.]0-${KDE_CORE_META_RELEASE}[.]fc[0-9]+$ ]] || die "Unexpected CORE meta: $core_evr"
[[ $kernel_evr =~ ^${KDE_KERNEL_VERSION}-${KDE_KERNEL_RELEASE}[.]fc[0-9]+$ ]] || die "Unexpected kernel: $kernel_evr"

curl -fL --retry 5 "$KDE_COPR_GPGKEY" -o /work/nabu-copr-pubkey.gpg
rpm --root "$TARGET" --import /work/nabu-copr-pubkey.gpg
dnf_command=(
    dnf5 -y --refresh --use-host-config --installroot="$TARGET"
    --releasever="$KDE_RELEASEVER" --forcearch="$KDE_TARGET_ARCH"
    --disablerepo='*openh264*' --setopt=install_weak_deps=False
    --setopt=keepcache=False --setopt=cachedir=/work/dnf-cache
    --setopt=retries=10 --setopt=timeout=120 --setopt=gpgcheck=1
    --repofrompath="nabu-linux,$KDE_COPR_BASEURL"
    --setopt=nabu-linux.gpgcheck=1 --setopt="nabu-linux.gpgkey=$KDE_COPR_GPGKEY"
    --exclude=senemos-nabu-kernel --exclude=senemos-nabu-kernel-alpha
    --exclude=senemos-nabu-kernel-mainline-alpha --exclude=senemos-nabu-kernel-mainline-unstable
    --exclude=senemos-nabu-kernel-legacy-stable --exclude=senemos-nabu-kernel-lts
)
IFS=' ' read -r -a extras <<<"$KDE_EXTRA_PACKAGES"
packages=("$KDE_META_PACKAGE" "${extras[@]}")

set +e
"${dnf_command[@]}" install "${packages[@]}" --assumeno >"$LOGS/dnf-solve.log" 2>&1
solve_rc=$?
set -e
[[ $solve_rc -eq 1 ]] && grep -Fq 'Operation aborted by the user' "$LOGS/dnf-solve.log" || {
    tail -160 "$LOGS/dnf-solve.log" >&2; die 'KDE DNF solve failed';
}
! grep -Eiq 'conflicting requests|problem [0-9]+:|failed to resolve|nothing provides' "$LOGS/dnf-solve.log" || \
    die 'KDE solve contains dependency problems'
"${dnf_command[@]}" install "${packages[@]}" >"$LOGS/dnf-install.log" 2>&1
"${dnf_command[@]}" check >"$LOGS/dnf-check.log" 2>&1

meta_evr=$(rpm --root "$TARGET" -q --qf '%{VERSION}-%{RELEASE}\n' "$KDE_META_PACKAGE")
[[ $meta_evr =~ ^${KDE_META_VERSION}-${KDE_META_RELEASE}[.]fc[0-9]+$ ]] || die "Unexpected KDE meta: $meta_evr"
powerdevil_release=$(rpm --root "$TARGET" -q --qf '%{RELEASE}\n' powerdevil)
[[ $powerdevil_release == 3.nabu1.fc* ]] || die "Nabu PowerDevil keyboard-backlight fix is absent: $powerdevil_release"
[[ $(find "$TARGET/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]] || die 'KDE changed kernel module cardinality'
for forbidden in senemos-nabu-kernel senemos-nabu-kernel-alpha senemos-nabu-kernel-mainline-alpha \
    senemos-nabu-kernel-mainline-unstable senemos-nabu-kernel-legacy-stable senemos-nabu-kernel-lts; do
    ! rpm --root "$TARGET" -q "$forbidden" >/dev/null 2>&1 || die "Forbidden kernel entered KDE: $forbidden"
done
! grep -Rqs 'nabu-linux-test' "$TARGET/etc/yum.repos.d" || die 'Test COPR entered KDE'

# DE security contract: no usable root password, no CORE CDC logger, no root SSH recovery.
chroot "$TARGET" /usr/sbin/usermod -L root
chroot "$TARGET" /usr/bin/passwd -S root | tee "$META/root-password-status.txt" | \
    grep -Eq '^root[[:space:]]+L[[:space:]]' || die 'Root is not locked in KDE'
systemctl --root="$TARGET" disable nabu-esp32-cdc-log.service sshd.service >/dev/null 2>&1 || :
systemctl --root="$TARGET" mask nabu-esp32-cdc-log.service >/dev/null
rm -f -- "$TARGET/etc/ssh/sshd_config.d/20-nabu-recovery.conf"
chroot "$TARGET" /usr/bin/firewall-offline-cmd --remove-service=ssh >"$LOGS/firewalld-ssh-remove.log" 2>&1 || :

systemctl --root="$TARGET" enable NetworkManager.service firewalld.service bluetooth.service \
    plasmalogin.service >/dev/null
ln -sfn /usr/lib/systemd/system/graphical.target "$TARGET/etc/systemd/system/default.target"
ln -sfn /usr/lib/systemd/system/plasmalogin.service \
    "$TARGET/etc/systemd/system/display-manager.service"
mkdir -p "$TARGET/etc/nabu-image"
cat >"$TARGET/etc/nabu-image/desktop-profile" <<'EOF'
desktop=kde-plasma
session=plasma-wayland
display-manager=plasma-login-manager
source=verified-CORE-copy
root=locked
cdc-logger=masked
copr=mcc45tr/nabu-linux
EOF

# No pre-created human account. Plasma Setup creates the first user on-device.
awk -F: '$3 >= 1000 && $3 < 65534 {print $1 ":" $3}' "$TARGET/etc/passwd" >"$META/regular-users.txt"
[[ ! -s "$META/regular-users.txt" ]] || die 'A regular user exists before KDE onboarding'
touch "$TARGET/.unconfigured"

rpm --root "$TARGET" -q "$KDE_META_PACKAGE" glibc-all-langpacks plasma-login-manager \
    plasma-desktop plasma-workspace kwin plasma-discover plasma-discover-offline-updates \
    dolphin konsole spectacle kwrite plasma-camera kde-gtk-config xsettingsd breeze-gtk-gtk3 breeze-gtk-gtk4 \
    nabu-camera-support iris-vaapi-nabu iio-sensor-proxy-nabu libssc-nabu python3-ssc-nabu \
    xiaomi-nabu-firmware \
    >"$META/kde-selection.txt"

locale_dirs=$(find "$TARGET/usr/share/locale" -mindepth 1 -maxdepth 1 -type d | wc -l)
plasma_catalogs=$(find "$TARGET/usr/share/locale" -path '*/LC_MESSAGES/plasmashell.mo' -type f | wc -l)
(( locale_dirs >= KDE_LOCALE_MIN_DIRS )) || die "Locale directory count too low: $locale_dirs"
(( plasma_catalogs >= KDE_PLASMASHELL_LOCALE_MIN )) || die "Plasmashell locale count too low: $plasma_catalogs"
printf 'locale_dirs=%s\nplasmashell_catalogs=%s\n' "$locale_dirs" "$plasma_catalogs" >"$META/locale-counts.txt"

python3 /builder-source/tools/lib/find-missing-rpm-locales.py "$TARGET" "$META/locale-rpm-files-before.txt" \
    "$META/locale-repair-packages.txt"
if [[ -s "$META/locale-repair-packages.txt" ]]; then
    mapfile -t locale_repair_packages <"$META/locale-repair-packages.txt"
    "${dnf_command[@]}" reinstall "${locale_repair_packages[@]}" \
        >"$LOGS/dnf-locale-repair.log" 2>&1
fi
python3 /builder-source/tools/lib/find-missing-rpm-locales.py "$TARGET" "$META/locale-rpm-files.txt" \
    "$META/locale-repair-packages-after.txt"
if [[ -s "$META/locale-repair-packages-after.txt" ]]; then
    sed -n '1,160p' "$META/locale-rpm-files.txt" >&2
    die 'RPM-owned installed locale files remain missing after reinstall repair'
fi

rpm --root "$TARGET" -q plasma-camera >/dev/null || die 'Plasma Camera is absent from KDE'
! rpm --root "$TARGET" -q kamoso >/dev/null 2>&1 || die 'Kamoso entered KDE instead of Plasma Camera'
[[ "$(cat "$TARGET/etc/hostname")" == nabu ]] || die 'KDE did not inherit the nabu hostname'

find "$TARGET/var/cache/dnf" "$TARGET/var/cache/libdnf5" "$TARGET/var/tmp" "$TARGET/tmp" \
    -mindepth 1 -delete 2>/dev/null || :
rpm --root "$TARGET" -qa --qf '%{NAME}|%{EVR}|%{ARCH}\n' | sort >"$META/rpm-manifest.txt"
find "$TARGET" -xdev \( -uid 65534 -o -gid 65534 \) -printf '%u:%g %m %p\n' \
    >"$META/pre-restore-overflow-ownership.txt"

python3 - "$TARGET" "$META/rpm-file-ownership.tsv" <<'PY'
import os, subprocess, sys
root, output = sys.argv[1:]
def ids(name):
    result = {}
    with open(os.path.join(root, "etc", name), encoding="utf-8", errors="surrogateescape") as f:
        for line in f:
            fields = line.rstrip("\n").split(":")
            if len(fields) >= 4 and fields[2].isdigit(): result[fields[0]] = int(fields[2])
    return result
uids, gids = ids("passwd"), ids("group")
query = subprocess.check_output(
    ["rpm", "--root", root, "-qa", "--dump"],
    text=True, errors="surrogateescape")
owners = {}
for line in query.splitlines():
    fields = line.rsplit(maxsplit=10)
    if len(fields) != 11: continue
    path, owner, group = fields[0], fields[5], fields[6]
    if path.startswith("/") and os.path.lexists(root + path):
        if owner not in uids or group not in gids: raise SystemExit(f"Unknown owner: {path} {owner}:{group}")
        owners[path] = (uids[owner], gids[group])
for path in ("/.unconfigured", "/etc/nabu-image/desktop-profile", "/etc/systemd/system/default.target",
             "/etc/systemd/system/display-manager.service", "/etc/systemd/system/nabu-esp32-cdc-log.service"):
    if os.path.lexists(root + path): owners[path] = (0, 0)
with open(output, "w", encoding="utf-8") as f:
    for path, (uid, gid) in sorted(owners.items()): f.write(f"{path}|{uid}|{gid}\\n")
PY
source /builder-source/gnome-builder/lib/rpm-special-modes.sh
nabu_capture_rpm_special_modes "$TARGET" "$META/rpm-special-modes.tsv"
cleanup_target
trap - EXIT
