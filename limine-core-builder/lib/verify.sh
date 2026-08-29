#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

limine_core_verify_no_overflow_ownership() {
    local root="${1:?root is required}" report="${2:?report is required}"
    find "$root" -xdev \( -uid 65534 -o -gid 65534 \) -printf '%u:%g %m %p\n' >"$report"
    [[ ! -s "$report" ]] || {
        sed -n '1,80p' "$report" >&2
        limine_core_die "Target contains nobody/nobody overflow ownership"
    }
}

limine_core_verify_initramfs() {
    local listing="${1:?listing is required}"
    ! grep -Eiq '(^|[[:space:]])(nobody|65534)([[:space:]]|$)' "$listing" || \
        limine_core_die "Initramfs contains nobody/65534 ownership"
    grep -Fq 'usr/share/plymouth/themes/senemos-nabu/senemos-nabu.plymouth' "$listing" || \
        limine_core_die "Plymouth theme descriptor is absent from initramfs"
    grep -Fq 'usr/share/plymouth/themes/senemos-nabu/senemos-nabu.script' "$listing" || \
        limine_core_die "Plymouth script is absent from initramfs"
    grep -Fq 'usr/lib64/plymouth/script.so' "$listing" || \
        limine_core_die "Plymouth script plugin is absent from initramfs"
    for firmware in slpi_nb.mbn cdsp.mbn adsp.mbn modem.mbn; do
        grep -Fq "$firmware" "$listing" || limine_core_die "Initramfs firmware is missing: $firmware"
    done
}

limine_core_verify_ext4() {
    local image="${1:?image is required}" report="${2:?report is required}"
    e2fsck -fn "$image" >"$report" 2>&1
    dumpe2fs -h "$image" >>"$report" 2>&1
    debugfs -R 'stat /usr/bin/bash' "$image" >>"$report" 2>&1
    grep -Fq "Filesystem volume name:   $LIMINE_CORE_FILESYSTEM_LABEL" "$report" || \
        limine_core_die "EXT4 label does not match the flash contract"
    grep -Eq 'User:[[:space:]]+0[[:space:]]+Group:[[:space:]]+0' "$report" || \
        limine_core_die "EXT4 serialized Bash with non-root ownership"
}

limine_core_verify_uki_cmdline() {
    local cmdline_file="${1:?cmdline file is required}" cmdline
    cmdline="$(tr -d '\000\n' <"$cmdline_file")"
    [[ "$cmdline" == *'root=PARTLABEL=linux'* ]] || limine_core_die "UKI root partition contract is missing"
    [[ " $cmdline " == *' quiet '* ]] || limine_core_die "UKI quiet flag is missing"
    [[ " $cmdline " == *' splash '* ]] || limine_core_die "UKI splash flag is missing"
    [[ "$cmdline" != *'plymouth.enable=0'* ]] || limine_core_die "UKI disables Plymouth"
    [[ "$cmdline" != *'systemd.log_level=debug'* ]] || limine_core_die "UKI unexpectedly enables debug mode"
}

limine_core_verify_esp() {
    local image="${1:?image is required}" android_hash="${2:?hash is required}"
    local uki_name="${3:?UKI name is required}" report="${4:?report is required}"
    local sector_size scratch extracted_android extracted_limine
    fsck.vfat -vn "$image" >"$report" 2>&1
    sector_size="$(od -An -t u2 -j 11 -N 2 "$image" | tr -d ' ')"
    [[ "$sector_size" == "$LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE" ]] || \
        limine_core_die "ESP logical sector is $sector_size, expected $LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE"
    mdir -i "$image" ::/EFI/BOOT/BOOTAA64.EFI >>"$report"
    mdir -i "$image" ::/EFI/limine/BOOTAA64.EFI >>"$report"
    mdir -i "$image" "::/EFI/SENEMOS/$uki_name" >>"$report"
    mdir -i "$image" ::/EFI/android/Reboot2Android.efi >>"$report"
    mtype -i "$image" ::/limine.conf >>"$report"
    mtype -i "$image" ::/limine.conf | grep -Fq "path: boot():/EFI/SENEMOS/$uki_name" || \
        limine_core_die "Limine does not point to the canonical alpha UKI"
    mtype -i "$image" ::/limine.conf | grep -Fq 'path: boot():/EFI/android/Reboot2Android.efi' || \
        limine_core_die "Limine Android return entry is missing"
    scratch="$(mktemp -d /var/tmp/limine-core-esp.XXXXXXXX)"
    extracted_android="$scratch/Reboot2Android.efi"
    extracted_limine="$scratch/BOOTAA64.EFI"
    mcopy -i "$image" ::/EFI/android/Reboot2Android.efi "$extracted_android"
    mcopy -i "$image" ::/EFI/BOOT/BOOTAA64.EFI "$extracted_limine"
    printf '%s  %s\n' "$android_hash" "$extracted_android" | sha256sum -c - >>"$report"
    file "$extracted_limine" >>"$report"
    file "$extracted_limine" | grep -Eiq 'PE32.*(Aarch64|ARM aarch64|ARM64)' || \
        limine_core_die "Limine removable EFI is not an AArch64 PE image"
    rm -rf -- "$scratch"
}
