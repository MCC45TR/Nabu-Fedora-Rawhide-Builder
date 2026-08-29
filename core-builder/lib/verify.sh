#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

core_verify_no_overflow_ownership() {
    local root="${1:?root is required}" report="${2:?report is required}"
    find "$root" -xdev \( -uid 65534 -o -gid 65534 \) -printf '%u:%g %m %p\n' >"$report"
    [[ ! -s "$report" ]] || {
        sed -n '1,80p' "$report" >&2
        core_die "Target root contains nobody/nobody overflow ownership"
    }
}

core_verify_initramfs_listing() {
    local listing="${1:?listing is required}"
    ! grep -Eiq '(^|[[:space:]])(nobody|65534)([[:space:]]|$)' "$listing" || \
        core_die "Initramfs contains nobody/65534 ownership"
    if awk 'length($1) == 10 && $1 ~ /^[-dlcbps]/ &&
            (substr($1,4,1) ~ /[sS]/ || substr($1,7,1) ~ /[sS]/) {bad=1}
            END {exit !bad}' "$listing"; then
        core_die "Initramfs contains setuid/setgid paths"
    fi
    awk '$NF == "usr/bin/mount" && $1 == "-rwxr-xr-x" && $3 == "root" && $4 == "root" {ok=1}
         END {exit !ok}' "$listing" || core_die "initramfs mount ownership/mode is unsafe"
    awk '$NF == "usr/bin/umount" && $1 == "-rwxr-xr-x" && $3 == "root" && $4 == "root" {ok=1}
         END {exit !ok}' "$listing" || core_die "initramfs umount ownership/mode is unsafe"
}

core_verify_ext4_root_identity() {
    local image="${1:?image is required}" report="${2:?report is required}"
    e2fsck -fn "$image" >"$report" 2>&1
    debugfs -R 'stat /usr/bin/bash' "$image" >>"$report" 2>&1
    grep -Eq 'User:[[:space:]]+0[[:space:]]+Group:[[:space:]]+0' "$report" || \
        core_die "EXT4 serialized /usr/bin/bash with non-root ownership"
}

core_verify_esp() {
    local image="${1:?image is required}" android_hash="${2:?hash is required}" report="${3:?report is required}"
    local sector_size extracted_android
    fsck.vfat -vn "$image" >"$report" 2>&1
    sector_size="$(od -An -t u2 -j 11 -N 2 "$image" | tr -d ' ')"
    [[ "$sector_size" == "$CORE_ESP_LOGICAL_SECTOR_SIZE" ]] || \
        core_die "ESP logical sector size is $sector_size, expected $CORE_ESP_LOGICAL_SECTOR_SIZE"
    mdir -i "$image" ::/EFI/BOOT/BOOTAA64.EFI >>"$report"
    mdir -i "$image" ::/EFI/BOOT/refind.conf >>"$report"
    mdir -i "$image" ::/EFI/android/Reboot2Android.efi >>"$report"
    mdir -i "$image" ::/EFI/SENEMOS >>"$report"
    extracted_android="$(mktemp /var/tmp/core-android.XXXXXXXX.efi)"
    mcopy -i "$image" ::/EFI/android/Reboot2Android.efi "$extracted_android"
    printf '%s  %s\n' "$android_hash" "$extracted_android" | sha256sum -c - >>"$report"
    rm -f -- "$extracted_android"
}
