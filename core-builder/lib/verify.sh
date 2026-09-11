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
    ! grep -Eiq 'nabu-esp32|cdc-initrd-log|cdc-journal-log' "$listing" || \
        core_die "ESP32/CDC logging entered the release initramfs"
    grep -E 'etc/systemd/system/debug-shell[.]service.*->[[:space:]].*dev/null' "$listing" >/dev/null || \
        core_die "debug-shell is not masked in initramfs"
    grep -E 'etc/systemd/system-generators/systemd-debug-generator.*->[[:space:]].*dev/null' "$listing" >/dev/null || \
        core_die "systemd debug generator is not masked in initramfs"
    ! grep -Eq 'kernel/drivers/scsi/scsi_debug[.]ko' "$listing" || \
        core_die "scsi_debug entered the release initramfs"
}

core_verify_release_cmdline() {
    local cmdline_file="${1:?cmdline file is required}" cmdline
    cmdline="$(tr -d '\000\n' <"$cmdline_file")"
    [[ "$cmdline" == "$CORE_KERNEL_CMDLINE" ]] || core_die "UKI cmdline differs from the release contract"
    [[ " $cmdline " == *' rw '* && " $cmdline " != *' ro '* ]] || \
        core_die "Release UKI does not request a writable root"
    ! grep -Eiq '(^|[[:space:]])(rd[.]debug|debug|systemd[.]log_level=debug|systemd[.]debug_shell|ignore_loglevel|plymouth[.]enable=0)([[:space:]]|$)' \
        <<<"$cmdline" || core_die "Debug option entered release UKI cmdline"
}

core_verify_ext4_root_identity() {
    local image="${1:?image is required}" report="${2:?report is required}"
    e2fsck -fn "$image" >"$report" 2>&1
    debugfs -R 'stat /usr/bin/bash' "$image" >>"$report" 2>&1
    debugfs -R 'ea_get /usr/lib/systemd/systemd security.selinux' "$image" >>"$report" 2>&1
    debugfs -R 'stat /etc/systemd/system/debug-shell.service' "$image" >>"$report" 2>&1
    debugfs -R 'cat /etc/fstab' "$image" >>"$report" 2>&1
    debugfs -R 'cat /etc/systemd/system/initial-setup.service.d/10-nabu-writable-root.conf' "$image" >>"$report" 2>&1
    grep -Eq 'User:[[:space:]]+0[[:space:]]+Group:[[:space:]]+0' "$report" || \
        core_die "EXT4 serialized /usr/bin/bash with non-root ownership"
    grep -Fq 'system_u:object_r:init_exec_t:s0' "$report" || \
        core_die "EXT4 serialized systemd without init_exec_t"
    grep -Fq 'Fast link dest: "/dev/null"' "$report" || \
        core_die "EXT4 did not serialize the debug-shell mask"
    grep -Eq '^PARTLABEL=linux[[:space:]]+/[[:space:]]+ext4[[:space:]]+rw,' "$report" || \
        core_die "EXT4 did not serialize the writable root mount"
    grep -Eq '^LABEL=ESPNABU[[:space:]]+/boot/efi[[:space:]]+vfat[[:space:]]+rw,' "$report" || \
        core_die "EXT4 did not serialize the ESP mount"
    grep -Fq 'Requires=systemd-remount-fs.service systemd-logind.service' "$report" || \
        core_die "EXT4 did not serialize Initial Setup ordering"
    grep -Fq 'ConditionPathIsReadWrite=/' "$report" || \
        core_die "EXT4 did not serialize the Initial Setup writable-root condition"
    ! grep -Fq 'mountpoint -q -w' "$report" || \
        core_die "EXT4 serialized an unsupported Initial Setup mountpoint option"
}

core_verify_esp() {
    local image="${1:?image is required}" android_hash="${2:?Android hash is required}"
    local report="${3:?report is required}" kernel_hash="${4:?kernel hash is required}"
    local dtb_hash="${5:?DTB hash is required}" expected_uname="${6:?uname is required}"
    local sector_size extracted_android extracted_uki extracted_linux extracted_dtb extracted_uname loader_path
    fsck.vfat -vn "$image" >"$report" 2>&1
    sector_size="$(od -An -t u2 -j 11 -N 2 "$image" | tr -d ' ')"
    [[ "$sector_size" == "$CORE_ESP_LOGICAL_SECTOR_SIZE" ]] || \
        core_die "ESP logical sector size is $sector_size, expected $CORE_ESP_LOGICAL_SECTOR_SIZE"
    mdir -i "$image" ::/EFI/BOOT/BOOTAA64.EFI >>"$report"
    mdir -i "$image" ::/EFI/BOOT/refind.conf >>"$report"
    mdir -i "$image" ::/EFI/android/Reboot2Android.efi >>"$report"
    mdir -i "$image" ::/EFI/fedora >>"$report"
    local refind_config
    refind_config="$(mktemp /var/tmp/core-refind.XXXXXXXX.conf)"
    mcopy -i "$image" ::/EFI/BOOT/refind.conf "$refind_config"
    grep -Fxq 'scanfor manual' "$refind_config" || \
        core_die "rEFInd production menu is not restricted to manual entries"
    ! grep -Eq '^scanfor .*\b(internal|external|optical)\b' "$refind_config" || \
        core_die "rEFInd production menu enables duplicate auto-discovery"
    [[ "$(grep -c '^menuentry ' "$refind_config")" == 2 ]] || \
        core_die "rEFInd does not contain exactly Fedora and Android entries"
    [[ "$(grep -c '^[[:space:]]*loader /EFI/fedora/' "$refind_config")" == 1 ]] || \
        core_die "rEFInd does not contain exactly one Fedora kernel entry"
    [[ "$(mdir -b -i "$image" '::/EFI/fedora/*.efi' | wc -l)" == 1 ]] || \
        core_die "ESP does not contain exactly one Fedora UKI"
    while IFS= read -r loader_path; do
        mdir -i "$image" "::$loader_path" >/dev/null || \
            core_die "rEFInd loader target is absent: $loader_path"
    done < <(sed -n 's/^[[:space:]]*loader \(\/EFI\/fedora\/[^[:space:]]*\)$/\1/p' "$refind_config")
    grep -Fxq 'default_selection "SENEMOS Nabu Mainline 7.2.x"' "$refind_config" || \
        core_die "rEFInd stable mainline 7.2.x default is missing"
    ! grep -Eiq 'unstable|SENEMOS7U' "$refind_config" || \
        core_die "rEFInd contains an unstable entry"
    grep -Fq 'loader /EFI/android/Reboot2Android.efi' "$refind_config" || \
        core_die "rEFInd Android loader is missing"
    loader_path=$(sed -n 's/^[[:space:]]*loader \(\/EFI\/fedora\/[^[:space:]]*\)$/\1/p' \
        "$refind_config" | head -n1)
    [[ -n $loader_path ]] || core_die "Could not resolve the sole Fedora UKI"
    extracted_android="$(mktemp /var/tmp/core-android.XXXXXXXX.efi)"
    mcopy -o -i "$image" ::/EFI/android/Reboot2Android.efi "$extracted_android"
    printf '%s  %s\n' "$android_hash" "$extracted_android" | sha256sum -c - >>"$report"
    extracted_uki="$(mktemp /var/tmp/core-mainline.XXXXXXXX.efi)"
    extracted_linux="$(mktemp /var/tmp/core-linux.XXXXXXXX.bin)"
    extracted_dtb="$(mktemp /var/tmp/core-dtb.XXXXXXXX.dtb)"
    extracted_uname="$(mktemp /var/tmp/core-uname.XXXXXXXX.txt)"
    mcopy -o -i "$image" "::$loader_path" "$extracted_uki"
    objcopy --dump-section .linux="$extracted_linux" "$extracted_uki"
    objcopy --dump-section .dtb="$extracted_dtb" "$extracted_uki"
    objcopy --dump-section .uname="$extracted_uname" "$extracted_uki"
    printf '%s  %s\n' "$kernel_hash" "$extracted_linux" | sha256sum -c - >>"$report"
    printf '%s  %s\n' "$dtb_hash" "$extracted_dtb" | sha256sum -c - >>"$report"
    [[ $(tr -d '\000\n' <"$extracted_uname") == "$expected_uname" ]] || \
        core_die "Serialized ESP UKI uname differs from the selected kernel"
    rm -f -- "$refind_config" "$extracted_android" "$extracted_uki" \
        "$extracted_linux" "$extracted_dtb" "$extracted_uname"
}
