#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROFILE="$SCRIPT_DIR/profile.env"
CONTAINER_SCRIPT="$SCRIPT_DIR/container-compose.sh"
SPECIAL_MODES="$SCRIPT_DIR/lib/rpm-special-modes.sh"

CORE_SYSTEM="${NABU_CORE_SYSTEM:-}"
CORE_ESP="${NABU_CORE_ESP:-}"
OUTPUT_ROOT="$REPO_ROOT/output/gnome"
RUNTIME="${GNOME_CONTAINER_RUNTIME:-auto}"
GNOME_PROFILE="${NABU_GNOME_PROFILE:-minimal}"

# shellcheck disable=SC1091
source "$PROFILE"
# shellcheck disable=SC1091
source "$REPO_ROOT/core-builder/lib/common.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/core-builder/lib/verify.sh"
source "$SPECIAL_MODES"
CORE_ESP_LOGICAL_SECTOR_SIZE="$GNOME_ESP_LOGICAL_SECTOR_SIZE"

usage() {
    cat <<'EOF'
Usage: gnome-builder/build-gnome.sh [options]

Apply a stock Fedora Rawhide GNOME layer to a copied Nabu CORE image.

Options:
  --core-system PATH  Uncompressed CORE EXT4 image (required)
  --core-esp PATH     CORE rEFInd ESP image (required)
  --profile NAME      minimal (default) or optimal
  --output PATH       Artifact output root (default: output/gnome)
  --runtime NAME      auto, podman, or docker
  --help              Show this help
EOF
}

while (($#)); do
    case "$1" in
        --core-system) CORE_SYSTEM="${2:?--core-system needs a path}"; shift 2 ;;
        --core-esp) CORE_ESP="${2:?--core-esp needs a path}"; shift 2 ;;
        --profile) GNOME_PROFILE="${2:?--profile needs a value}"; shift 2 ;;
        --output) OUTPUT_ROOT="${2:?--output needs a path}"; shift 2 ;;
        --runtime) RUNTIME="${2:?--runtime needs a value}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) core_die "Unknown option: $1" ;;
    esac
done

case "$GNOME_PROFILE" in
    minimal|optimal) ;;
    *) core_die "Unsupported GNOME profile: $GNOME_PROFILE" ;;
esac
[[ -f "$CORE_SYSTEM" && -s "$CORE_SYSTEM" ]] || core_die "CORE EXT4 image is missing: $CORE_SYSTEM"
[[ -f "$CORE_ESP" && -s "$CORE_ESP" ]] || core_die "CORE ESP image is missing: $CORE_ESP"
[[ -f "$CONTAINER_SCRIPT" ]] || core_die "Container helper is missing: $CONTAINER_SCRIPT"
[[ -f "$SPECIAL_MODES" ]] || core_die "RPM special-mode helper is missing: $SPECIAL_MODES"

for command in cp debugfs dumpe2fs e2fsck file fsck.vfat fuse2fs fusermount3 \
    mcopy mdir mountpoint mtype sha256sum stat zstd; do
    core_require_command "$command"
done

case "$RUNTIME" in
    auto)
        if command -v podman >/dev/null 2>&1; then RUNTIME=podman
        elif command -v docker >/dev/null 2>&1; then RUNTIME=docker
        else core_die 'Neither Podman nor Docker is installed'; fi
        ;;
    podman|docker) core_require_command "$RUNTIME" ;;
    *) core_die "Unsupported container runtime: $RUNTIME" ;;
esac

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT="$(cd -- "$OUTPUT_ROOT" && pwd -P)"
run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_id="gnome-rawhide-${GNOME_PROFILE}-alpha-refind-$run_stamp"
ARTIFACT_DIR="$OUTPUT_ROOT/$run_id"
WORK="$ARTIFACT_DIR/.work"
META="$ARTIFACT_DIR/metadata"
REPORTS="$ARTIFACT_DIR/reports"
LOGS="$ARTIFACT_DIR/logs"
MOUNT_DIR="$WORK/mnt"
WORKING_IMAGE="$WORK/system.img"
SYSTEM_IMAGE="$ARTIFACT_DIR/fedora-rawhide-nabu-gnome-${GNOME_PROFILE}-alpha-${run_stamp}-system.img"
ESP_IMAGE="$ARTIFACT_DIR/fedora-rawhide-nabu-gnome-${GNOME_PROFILE}-alpha-${run_stamp}-esp.img"

[[ ! -e "$ARTIFACT_DIR" ]] || core_die "Output already exists: $ARTIFACT_DIR"
mkdir -p "$WORK" "$META" "$REPORTS" "$LOGS" "$MOUNT_DIR"

cleanup_mount() {
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        sync || true
        fusermount3 -u "$MOUNT_DIR" || true
    fi
}
trap cleanup_mount EXIT INT TERM

core_log "Cloning CORE before any FUSE access"
cp --reflink=auto -- "$CORE_SYSTEM" "$WORKING_IMAGE"
cp --reflink=auto -- "$CORE_ESP" "$ESP_IMAGE"
printf 'core-system=%s\ncore-esp=%s\nprofile=gnome-%s\n' \
    "$CORE_SYSTEM" "$CORE_ESP" "$GNOME_PROFILE" >"$META/sources.txt"
sha256sum "$CORE_SYSTEM" "$CORE_ESP" >"$META/sources.sha256"
stat -c '%n %s bytes' "$CORE_SYSTEM" "$CORE_ESP" >"$META/source-sizes.txt"

core_log "Pulling identical Fedora environment: $GNOME_CONTAINER_IMAGE"
"$RUNTIME" pull --platform linux/arm64 "$GNOME_CONTAINER_IMAGE" >/dev/null
image_digest="$($RUNTIME image inspect "$GNOME_CONTAINER_IMAGE" --format '{{.Id}}')"
printf '%s\n' "$image_digest" >"$META/container-image-id-host.txt"

core_log "Mounting only the cloned EXT4 image"
fuse2fs -o fakeroot "$WORKING_IMAGE" "$MOUNT_DIR" >"$LOGS/fuse-mount.log" 2>&1
mountpoint -q "$MOUNT_DIR" || core_die 'Could not mount the cloned CORE image'

run_args=(run --rm --privileged --platform linux/arm64)
if [[ "$RUNTIME" == podman ]]; then
    run_args+=(--security-opt label=disable)
fi
run_args+=(
    -e "GNOME_PROFILE=$GNOME_PROFILE"
    -e "GNOME_CONTAINER_IMAGE_ID=$image_digest"
    -v "$WORK:/work:rw"
    -v "$MOUNT_DIR:/target:rw"
    -v "$META:/meta:rw"
    -v "$LOGS:/logs:rw"
    -v "$REPO_ROOT:/builder-source:ro"
    -v "$PROFILE:/builder/profile.env:ro"
    -v "$CONTAINER_SCRIPT:/builder/container-compose.sh:ro"
    "$GNOME_CONTAINER_IMAGE"
    /usr/bin/bash /builder/container-compose.sh
)
"$RUNTIME" "${run_args[@]}"

cleanup_mount
trap - EXIT INT TERM

[[ -s "$META/rpm-file-ownership.tsv" ]] || core_die 'RPM ownership metadata is missing'
[[ -s "$META/rpm-special-modes.tsv" ]] || core_die 'RPM special-mode metadata is missing'

core_log "Restoring RPM ownership to the serialized ext4 inode table"
ownership_batch="$WORK/rpm-ownership.debugfs"
while IFS='|' read -r payload_path uid gid; do
    [[ "$payload_path" == /* && "$uid" =~ ^[0-9]+$ && "$gid" =~ ^[0-9]+$ ]] || continue
    escaped_path=${payload_path//"/\\"}
    printf 'set_inode_field "%s" uid %s\n' "$escaped_path" "$uid"
    printf 'set_inode_field "%s" gid %s\n' "$escaped_path" "$gid"
done <"$META/rpm-file-ownership.tsv" >"$ownership_batch"
debugfs -w -f "$ownership_batch" "$WORKING_IMAGE" >"$LOGS/rpm-ownership-restore.log" 2>&1
nabu_restore_rpm_special_modes "$WORKING_IMAGE" "$META/rpm-special-modes.tsv"
nabu_verify_rpm_special_modes "$WORKING_IMAGE" "$META/rpm-special-modes.tsv"

core_log "Checking and serializing the GNOME EXT4 image"
e2fsck -f -y "$WORKING_IMAGE" >"$LOGS/ext4-final-fsck.log" 2>&1
e2fsck -f -n "$WORKING_IMAGE" >>"$LOGS/ext4-final-fsck.log" 2>&1
core_verify_ext4_root_identity "$WORKING_IMAGE" "$REPORTS/ext4-validation.log"
mv -- "$WORKING_IMAGE" "$SYSTEM_IMAGE"

core_log "Verifying the final GNOME root and nobody/nobody ownership gate"
mkdir -p "$MOUNT_DIR"
fuse2fs -o fakeroot "$SYSTEM_IMAGE" "$MOUNT_DIR" >"$LOGS/final-fuse-mount.log" 2>&1
mountpoint -q "$MOUNT_DIR" || core_die 'Could not remount final GNOME EXT4 image'
core_verify_no_overflow_ownership "$MOUNT_DIR" "$REPORTS/root-overflow-ownership.txt"
rpm --root "$MOUNT_DIR" -q nabu-core-meta senemos-nabu-kernel-alpha nabu-boot-refind \
    >"$META/core-selection-readback.txt"
rpm --root "$MOUNT_DIR" -q gdm gnome-shell gnome-session gnome-session-wayland-session \
    gnome-settings-daemon gnome-control-center gnome-software ptyxis nautilus \
    >"$META/gnome-selection-readback.txt"
find "$MOUNT_DIR" -xdev \( -uid 65534 -o -gid 65534 \) \
    -printf '%u:%g %m %p\n' >"$REPORTS/final-overflow-ownership.txt"
[[ ! -s "$REPORTS/final-overflow-ownership.txt" ]] || core_die 'Final GNOME root contains nobody/nobody ownership'
sync
fusermount3 -u "$MOUNT_DIR"

core_log "Updating only the copied rEFInd titles while preserving UKI and Android"
android_before="$WORK/android-before.efi"
android_after="$WORK/android-after.efi"
mcopy -i "$CORE_ESP" ::/EFI/android/Reboot2Android.efi "$android_before"
mcopy -i "$ESP_IMAGE" ::/EFI/android/Reboot2Android.efi "$android_after"
cmp --silent "$android_before" "$android_after" || core_die 'Copied ESP changed Android return payload'

mtype -i "$ESP_IMAGE" ::/EFI/BOOT/refind.conf >"$WORK/refind.conf"
sed -i 's/Fedora Rawhide (SENEMOS6 /Fedora Rawhide GNOME (SENEMOS6 /' "$WORK/refind.conf"
mcopy -o -i "$ESP_IMAGE" "$WORK/refind.conf" ::/EFI/BOOT/refind.conf
if mtype -i "$ESP_IMAGE" ::/loader/entries/senemos.conf >"$WORK/senemos.conf" 2>/dev/null; then
    sed -i 's/title Fedora Rawhide (SENEMOS6 /title Fedora Rawhide GNOME (SENEMOS6 /' "$WORK/senemos.conf"
    mcopy -o -i "$ESP_IMAGE" "$WORK/senemos.conf" ::/loader/entries/senemos.conf
fi

mtype -i "$ESP_IMAGE" ::/EFI/BOOT/refind.conf >"$META/refind.conf"
mtype -i "$ESP_IMAGE" ::/loader/entries/senemos.conf >"$META/senemos.conf"
grep -Fq 'Fedora Rawhide GNOME' "$META/refind.conf" || core_die 'rEFInd GNOME title is missing'
grep -Fq '/EFI/SENEMOS/SENEMOS' "$META/refind.conf" || core_die 'rEFInd alpha UKI loader is missing'
grep -Fq '/EFI/android/Reboot2Android.efi' "$META/refind.conf" || core_die 'Android rEFInd entry is missing'
grep -Fq 'Fedora Rawhide GNOME' "$META/senemos.conf" || core_die 'systemd-boot GNOME title is missing'
mcopy -i "$ESP_IMAGE" ::/EFI/android/Reboot2Android.efi "$android_after"
cmp --silent "$android_before" "$android_after" || core_die 'Final ESP changed Android return payload'

core_verify_esp "$ESP_IMAGE" "$(sha256sum "$android_before" | awk '{print $1}')" \
    "$REPORTS/esp-validation.log"
sha256sum "$android_before" "$android_after" >"$META/android-readback.sha256"
stat -c '%n %s bytes' "$SYSTEM_IMAGE" "$ESP_IMAGE" >"$META/artifact-sizes.txt"
file "$SYSTEM_IMAGE" "$ESP_IMAGE" >"$META/file-types.txt"

zstd -T0 -"$GNOME_COMPRESSION_LEVEL" -f "$SYSTEM_IMAGE" -o "$SYSTEM_IMAGE.zst"
zstd -T0 -"$GNOME_COMPRESSION_LEVEL" -f "$ESP_IMAGE" -o "$ESP_IMAGE.zst"

write_hashes() {
    local hash_file="$ARTIFACT_DIR/SHA256SUMS" path
    local -a inputs=()
    for path in ./*.img ./*.img.zst; do
        [[ -f "$path" ]] && inputs+=("$path")
    done
    for path in metadata/* reports/*; do
        [[ "${path##*/}" == sha256-verify.log ]] || inputs+=("$path")
    done
    sha256sum "${inputs[@]}" >"$hash_file"
    sha256sum -c "$hash_file" >"$REPORTS/sha256-verify.log"
}

(
    cd "$ARTIFACT_DIR"
    write_hashes
)

cat >"$ARTIFACT_DIR/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide GNOME image

- Architecture: AArch64
- Source: copied verified CORE image
- Profile: GNOME $GNOME_PROFILE
- Filesystem: EXT4, label \`$GNOME_CORE_FILESYSTEM_LABEL\`
- Boot manager: rEFInd
- CORE meta retained: \`nabu-core-meta\`
- Alpha kernel retained: \`senemos-nabu-kernel-alpha\`
- Display manager: GDM
- COPR: \`mcc45tr/nabu-linux\`, GPG verification enabled for the Nabu layer
- ESP: copied CORE ESP, $GNOME_ESP_LOGICAL_SECTOR_SIZE-byte logical sectors
- Android return EFI: preserved and hash-verified
- nobody/nobody overflow ownership: absent after ext4 inode restoration
- Future DNF solve: checked with installed-root \`check\` and \`distro-sync --assumeno\`
- Physical Nabu boot/HIL: not performed by the image compose
EOF

if [[ "${GNOME_KEEP_UNCOMPRESSED:-1}" != 1 ]]; then
    rm -f -- "$SYSTEM_IMAGE" "$ESP_IMAGE"
    (
        cd "$ARTIFACT_DIR"
        write_hashes
    )
fi

rm -rf -- "$WORK"
printf 'GNOME_ARTIFACT=%s\n' "$ARTIFACT_DIR"
