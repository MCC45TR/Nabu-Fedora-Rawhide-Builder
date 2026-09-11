#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
source "$REPO_ROOT/core-builder/lib/common.sh"
source "$REPO_ROOT/core-builder/lib/verify.sh"
source "$REPO_ROOT/gnome-builder/lib/rpm-special-modes.sh"
source "$SCRIPT_DIR/profile.env"

CORE_SYSTEM=
CORE_ESP=
OUTPUT_ROOT="$REPO_ROOT/output/kde"
RUNTIME=${KDE_CONTAINER_RUNTIME:-auto}
usage() { echo 'Usage: kde-builder/build-kde.sh --core-system FILE --core-esp FILE [--output DIR] [--runtime docker|podman]'; }
while (($#)); do
    case "$1" in
        --core-system) CORE_SYSTEM=${2:?}; shift 2 ;;
        --core-esp) CORE_ESP=${2:?}; shift 2 ;;
        --output) OUTPUT_ROOT=${2:?}; shift 2 ;;
        --runtime) RUNTIME=${2:?}; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) core_die "Unknown KDE option: $1" ;;
    esac
done
[[ -s $CORE_SYSTEM ]] || core_die "CORE system image missing: $CORE_SYSTEM"
[[ -s $CORE_ESP ]] || core_die "CORE ESP image missing: $CORE_ESP"
case "$RUNTIME" in
    auto) if command -v podman >/dev/null; then RUNTIME=podman; else RUNTIME=docker; fi ;;
    docker|podman) ;;
    *) core_die "Unsupported runtime: $RUNTIME" ;;
esac
core_require_command "$RUNTIME"
for cmd in cp debugfs e2fsck fsck.vfat fuse2fs fusermount3 mountpoint resize2fs sha256sum truncate zstd; do
    core_require_command "$cmd"
done

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT="$(cd -- "$OUTPUT_ROOT" && pwd -P)"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
artifact="$OUTPUT_ROOT/kde-rawhide-mainline-stable-$stamp"
work="$artifact/.work"; meta="$artifact/metadata"; logs="$artifact/logs"; reports="$artifact/reports"
mkdir -p "$work/mnt" "$meta" "$logs" "$reports"
working="$work/system.img"
system_image="$artifact/fedora-rawhide-mainline-stable-kde-$stamp-system.img"
esp_image="$artifact/fedora-rawhide-mainline-stable-kde-$stamp-esp.img"
cp --reflink=auto -- "$CORE_SYSTEM" "$working"
cp --reflink=auto -- "$CORE_ESP" "$esp_image"
sha256sum "$CORE_SYSTEM" "$CORE_ESP" >"$meta/core-sources.sha256"
e2fsck -f -y "$working" >"$logs/ext4-grow-fsck.log" 2>&1
truncate -s "$KDE_IMAGE_SIZE" "$working"
resize2fs "$working" >"$logs/ext4-grow.log" 2>&1

"$RUNTIME" pull --platform linux/arm64 "$KDE_CONTAINER_IMAGE" >/dev/null
digest=$("$RUNTIME" image inspect "$KDE_CONTAINER_IMAGE" --format '{{.Id}}')
run_args=(run --rm --privileged --platform linux/arm64)
[[ $RUNTIME == podman ]] && run_args+=(--security-opt label=disable)
run_args+=(
    -v "$work:/work:rw" -v "$meta:/meta:rw" -v "$logs:/logs:rw"
    -v "$REPO_ROOT:/builder-source:ro" -v "$SCRIPT_DIR/profile.env:/builder/profile.env:ro"
    -v "$SCRIPT_DIR/container-compose.sh:/builder/container-compose.sh:ro"
    "$KDE_CONTAINER_IMAGE" /usr/bin/bash /builder/container-compose.sh
)
"$RUNTIME" "${run_args[@]}"

ownership_batch="$work/rpm-ownership.debugfs"
while IFS='|' read -r path uid gid; do
    [[ $path == /* && $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || continue
    printf 'set_inode_field "%s" uid %s\nset_inode_field "%s" gid %s\n' "$path" "$uid" "$path" "$gid"
done <"$meta/rpm-file-ownership.tsv" >"$ownership_batch"
debugfs -w -f "$ownership_batch" "$working" >"$logs/rpm-ownership-restore.log" 2>&1
nabu_restore_rpm_special_modes "$working" "$meta/rpm-special-modes.tsv"
nabu_verify_rpm_special_modes "$working" "$meta/rpm-special-modes.tsv"
"$REPO_ROOT/tools/lib/relabel-ext4-selinux.sh" "$working" "$reports/selinux-ext4"
core_verify_ext4_root_identity "$working" "$reports/ext4-validation.log"
mv -- "$working" "$system_image"

mount_dir="$work/mnt"
cleanup() { mountpoint -q "$mount_dir" 2>/dev/null && fusermount3 -u "$mount_dir" || :; }
trap cleanup EXIT
fuse2fs -o fakeroot,ro "$system_image" "$mount_dir" >"$logs/final-fuse-mount.log" 2>&1
mountpoint -q "$mount_dir" || core_die 'Could not mount final KDE image'
core_verify_no_overflow_ownership "$mount_dir" "$reports/final-overflow-ownership.txt"
rpm --root "$mount_dir" -q "$KDE_META_PACKAGE" "$KDE_KERNEL_PACKAGE" nabu-core-meta \
    plasma-login-manager glibc-all-langpacks >"$meta/final-selection.txt"
chroot "$mount_dir" /usr/bin/passwd -S root | grep -Eq '^root[[:space:]]+L[[:space:]]' || core_die 'Final KDE root is not locked'
[[ -L "$mount_dir/etc/systemd/system/nabu-esp32-cdc-log.service" && \
   $(readlink "$mount_dir/etc/systemd/system/nabu-esp32-cdc-log.service") == /dev/null ]] || core_die 'Final KDE CDC logger is not masked'
[[ ! -e "$mount_dir/etc/ssh/sshd_config.d/20-nabu-recovery.conf" ]] || core_die 'CORE root SSH policy remains in KDE'
[[ ! -s "$meta/regular-users.txt" ]] || core_die 'Final KDE contains a pre-created regular user'
sync; cleanup; trap - EXIT

cmp -s "$CORE_ESP" "$esp_image" || core_die 'KDE changed the verified CORE ESP'
fsck.vfat -vn "$esp_image" >"$reports/esp-fsck.log" 2>&1
printf 'core_esp_sha256=%s\nkde_esp_sha256=%s\n' \
    "$(sha256sum "$CORE_ESP" | cut -d' ' -f1)" "$(sha256sum "$esp_image" | cut -d' ' -f1)" \
    >"$meta/esp-preservation.txt"

cat >"$artifact/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide KDE image

- Source: cloned verified CORE image
- Sole Nabu repository: \`mcc45tr/nabu-linux\` (GPG checked)
- Kernel retained: \`$KDE_KERNEL_PACKAGE $KDE_KERNEL_VERSION-$KDE_KERNEL_RELEASE\`
- KDE meta: \`$KDE_META_PACKAGE $KDE_META_VERSION-$KDE_META_RELEASE\`
- Login manager: Plasma Login Manager; Wayland Plasma desktop
- Root: locked; no pre-created regular user; Plasma Setup onboarding retained
- CORE CDC logger: disabled and masked; CORE root SSH recovery policy removed
- Locale gate: all RPM-owned locale files present, with catalog-count thresholds
- Driver/meta gates: camera, Iris VA-API, sensors, audio/desktop dependencies queried from final root
- SELinux: offline relabel applied and inode labels verified after FUSE mutation
- ESP: byte-identical CORE copy; exactly the CORE Android and SENEMOS7 policy is retained
- Physical boot and hardware HIL: not performed by compose
EOF
zstd -T0 -"$KDE_COMPRESSION_LEVEL" -f "$system_image" -o "$system_image.zst"
zstd -T0 -"$KDE_COMPRESSION_LEVEL" -f "$esp_image" -o "$esp_image.zst"
if [[ ${KDE_KEEP_UNCOMPRESSED:-0} != 1 ]]; then rm -f -- "$system_image" "$esp_image"; fi
rm -rf -- "$work"
(
    cd "$artifact"
    find . -type f ! -name SHA256SUMS ! -name sha256-verify.log -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS
    sha256sum -c SHA256SUMS >reports/sha256-verify.log
)
printf 'KDE_ARTIFACT=%s\n' "$artifact"
