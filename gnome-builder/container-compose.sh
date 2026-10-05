#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

SCRIPT_DIR=/builder
PROFILE="$SCRIPT_DIR/profile.env"
TARGET=/target
META=/meta
LOGS=/logs

# shellcheck disable=SC1091
source "$PROFILE"

log() {
    printf '[GNOME] %s\n' "$*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

[[ "$(uname -m)" == aarch64 ]] || die "GNOME compose is not native AArch64: $(uname -m)"
[[ "$GNOME_PROFILE" == minimal || "$GNOME_PROFILE" == optimal ]] || die "Unsupported GNOME profile: $GNOME_PROFILE"

mkdir -p "$META" "$LOGS" /work/dnf-cache

log "Installing GNOME compose tools in the identical Rawhide AArch64 container"
dnf5 -y --disablerepo='*openh264*' --setopt=install_weak_deps=False install \
    ca-certificates curl dnf5 e2fsprogs findutils fuse3 gcc-c++ rpm systemd util-linux \
    >"$LOGS/container-tools.log" 2>&1
g++ -std=c++20 -O2 -Wall -Wextra -Werror \
    /builder-source/tools/lib/rpm-file-ownership.cpp \
    -o /work/rpm-file-ownership

mkdir -p "$TARGET"
fuse2fs -o fakeroot /work/system.img "$TARGET" >"$LOGS/fuse-mount.log" 2>&1
mountpoint -q "$TARGET" || die 'Could not mount the cloned CORE image inside the container'
[[ -d "$TARGET/etc" && -d "$TARGET/var" ]] || die "CORE target is not mounted at $TARGET"
cleanup_target() {
    if mountpoint -q "$TARGET" 2>/dev/null; then
        sync || true
        fusermount3 -u "$TARGET" || true
    fi
}
trap cleanup_target EXIT

rpm --root "$TARGET" -qa --qf '%{NAME}\t%{EVR}\t%{ARCH}\n' | sort >"$META/packages-before.tsv"

curl --fail --silent --show-error --location "$GNOME_COPR_GPGKEY" -o /work/nabu-copr-pubkey.gpg
rpm --root "$TARGET" --import /work/nabu-copr-pubkey.gpg

dnf_command=(
    dnf5 -y --refresh --use-host-config --installroot="$TARGET"
    --releasever="$GNOME_RELEASEVER" --forcearch="$GNOME_TARGET_ARCH"
    --disablerepo='*openh264*'
    --setopt=install_weak_deps=False
    --setopt=keepcache=False
    --setopt=cachedir=/work/dnf-cache
    --setopt=retries=10
    --setopt=timeout=120
    --setopt=gpgcheck=1
    --repofrompath="nabu-linux,$GNOME_COPR_BASEURL"
    --setopt=nabu-linux.gpgcheck=1
    --setopt="nabu-linux.gpgkey=$GNOME_COPR_GPGKEY"
)

case "$GNOME_PROFILE" in
    minimal)
        IFS=' ' read -r -a profile_packages <<<"$GNOME_MINIMAL_PACKAGES"
        ;;
    optimal)
        IFS=' ' read -r -a profile_packages <<<"$GNOME_MINIMAL_PACKAGES"
        IFS=' ' read -r -a optimal_packages <<<"$GNOME_OPTIMAL_PACKAGES"
        profile_packages+=("${optimal_packages[@]}")
        ;;
esac

printf '%q ' "${dnf_command[@]}" install "${profile_packages[@]}" >"$META/dnf-command.txt"
printf '\n' >>"$META/dnf-command.txt"
printf 'profile=gnome-%s\n' "$GNOME_PROFILE" >"$META/desktop-profile.txt"
printf 'meta-package=not-published-in-copr-at-compose-time\n' >>"$META/desktop-profile.txt"

log "Resolving Fedora GNOME $GNOME_PROFILE package closure"
set +e
"${dnf_command[@]}" install "${profile_packages[@]}" --assumeno \
    >"$LOGS/dnf-solve.log" 2>&1
solve_rc=$?
set -e
if [[ $solve_rc -ne 1 ]] || ! grep -Fq 'Operation aborted by the user' "$LOGS/dnf-solve.log"; then
    tail -160 "$LOGS/dnf-solve.log" >&2
    die 'GNOME DNF solve did not produce an aborted, fully resolved transaction'
fi
! grep -Eiq 'conflicting requests|problem [0-9]+:|failed to resolve|nothing provides' \
    "$LOGS/dnf-solve.log" || die 'GNOME DNF solve contains dependency problems'

log "Installing the GNOME layer without replacing the CORE branch"
"${dnf_command[@]}" install "${profile_packages[@]}" >"$LOGS/dnf-install.log" 2>&1

dnf5 --version >"$META/dnf-version.txt"
rpm --version >"$META/rpm-version.txt"
printf '%s\n' "${GNOME_CONTAINER_IMAGE_ID:-unknown}" >"$META/container-image-id.txt"

log "Running installed-root DNF integrity and future Rawhide solver gates"
"${dnf_command[@]}" check >"$LOGS/dnf-check.log" 2>&1
set +e
"${dnf_command[@]}" distro-sync --assumeno >"$LOGS/dnf-forward-sync.log" 2>&1
sync_rc=$?
set -e
if [[ $sync_rc -ne 0 && $sync_rc -ne 1 ]]; then
    tail -120 "$LOGS/dnf-forward-sync.log" >&2
    die 'GNOME future Rawhide distro-sync solver gate failed'
fi
! grep -Eiq 'conflicting requests|problem [0-9]+:|failed to resolve|nothing provides' \
    "$LOGS/dnf-forward-sync.log" || die 'GNOME future Rawhide distro-sync has dependency problems'

log "Enabling the graphical GNOME boot target"
systemctl --root="$TARGET" enable NetworkManager.service firewalld.service \
    bluetooth.service gdm.service >"$LOGS/systemd-enable.log" 2>&1
mkdir -p "$TARGET/etc/systemd/system" "$TARGET/etc/nabu-image"
ln -sfn /usr/lib/systemd/system/graphical.target "$TARGET/etc/systemd/system/default.target"
ln -sfn /usr/lib/systemd/system/gdm.service "$TARGET/etc/systemd/system/display-manager.service"

cat >"$TARGET/etc/nabu-image/desktop-profile" <<EOF
desktop=gnome
profile=$GNOME_PROFILE
session=gnome-wayland
display-manager=gdm
source=CORE-copy
EOF
cat >"$TARGET/etc/nabu-image/README" <<'EOF'
This image is a GNOME layer applied to a verified Nabu Fedora CORE image.
The alpha kernel, nabu-core-meta, rEFInd and Android return path remain owned
by the CORE selection and were not replaced by the desktop layer.
EOF

# Keep the image deterministic and do not carry the temporary package cache.
find "$TARGET/var/cache/dnf" "$TARGET/var/cache/libdnf5" \
    "$TARGET/var/tmp" "$TARGET/tmp" -mindepth 1 -delete 2>/dev/null || true

rpm --root "$TARGET" -qa --qf '%{NAME}\t%{EVR}\t%{ARCH}\n' | sort >"$META/packages-final.tsv"
rpm --root "$TARGET" -q nabu-core-meta senemos-nabu-kernel-alpha nabu-boot-refind \
    >"$META/core-selection.txt"
rpm --root "$TARGET" -q gdm gnome-shell gnome-session gnome-session-wayland-session \
    gnome-settings-daemon gnome-control-center gnome-software ptyxis nautilus \
    >"$META/gnome-selection.txt"

for path in \
    /usr/sbin/gdm /usr/bin/gnome-shell /usr/bin/gnome-control-center \
    /usr/bin/gnome-software /usr/bin/ptyxis /usr/bin/nautilus; do
    [[ -x "$TARGET$path" ]] || die "GNOME payload is missing: $path"
done
[[ "$(readlink "$TARGET/etc/systemd/system/default.target")" == /usr/lib/systemd/system/graphical.target ]]
[[ "$(readlink "$TARGET/etc/systemd/system/display-manager.service")" == /usr/lib/systemd/system/gdm.service ]]

# FUSE can expose a transient nobody mapping while the image is mounted. The
# authoritative RPM owner map is applied to the ext4 inode table by the host
# after unmounting; retain both reports so that final verification is explicit.
find "$TARGET" -xdev \( -uid 65534 -o -gid 65534 \) \
    -printf '%u:%g %m %p\n' >"$META/pre-restore-overflow-ownership.txt"

/work/rpm-file-ownership capture "$TARGET" "$META/rpm-file-ownership.tsv" \
    /etc/nabu-image/desktop-profile /etc/nabu-image/README \
    /etc/systemd/system/default.target /etc/systemd/system/display-manager.service

[[ -s "$META/rpm-file-ownership.tsv" ]] || die 'RPM ownership metadata is empty'
source /builder-source/gnome-builder/lib/rpm-special-modes.sh
nabu_capture_rpm_special_modes "$TARGET" "$META/rpm-special-modes.tsv"
[[ -s "$META/rpm-special-modes.tsv" ]] || die 'RPM special-mode metadata is empty'

log "GNOME layer completed; host-side ext4 ownership restoration is required"
cleanup_target
trap - EXIT
