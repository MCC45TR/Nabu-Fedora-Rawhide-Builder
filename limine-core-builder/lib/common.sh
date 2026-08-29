#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

limine_core_log() {
    printf '[LIMINE-CORE] %s\n' "$*" >&2
}

limine_core_die() {
    limine_core_log "ERROR: $*"
    exit 1
}

limine_core_require_command() {
    command -v "$1" >/dev/null 2>&1 || limine_core_die "Required command is missing: $1"
}

limine_core_load_profile() {
    local profile_path="${1:?profile path is required}"
    [[ -r "$profile_path" ]] || limine_core_die "Profile is not readable: $profile_path"
    # shellcheck disable=SC1090
    source "$profile_path"
    : "${LIMINE_CORE_PROFILE_VERSION:?}"
    : "${LIMINE_CORE_TARGET_ARCH:?}"
    : "${LIMINE_CORE_RELEASEVER:?}"
    : "${LIMINE_CORE_CONTAINER_IMAGE:?}"
    : "${LIMINE_CORE_COPR_BASEURL:?}"
    : "${LIMINE_CORE_COPR_GPGKEY:?}"
    : "${LIMINE_CORE_FILESYSTEM:?}"
    : "${LIMINE_CORE_FILESYSTEM_LABEL:?}"
    : "${LIMINE_CORE_IMAGE_SIZE:?}"
    : "${LIMINE_CORE_COMPRESSION_LEVEL:?}"
    : "${LIMINE_CORE_ESP_SIZE_BYTES:?}"
    : "${LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE:?}"
    : "${LIMINE_CORE_ESP_LABEL:?}"
    : "${LIMINE_CORE_BOOTLOADER:?}"
    : "${LIMINE_CORE_DEFAULT_KERNEL_PACKAGE:?}"
    : "${LIMINE_CORE_META_PACKAGE:?}"
    : "${LIMINE_CORE_BOOT_PACKAGE:?}"
    : "${LIMINE_CORE_PLYMOUTH_PACKAGE:?}"
    : "${LIMINE_CORE_PLYMOUTH_THEME:?}"
    : "${LIMINE_CORE_LOCALE:?}"
    : "${LIMINE_CORE_TIMEZONE:?}"
    : "${LIMINE_CORE_REBOOT2ANDROID_URL:?}"
    : "${LIMINE_CORE_REBOOT2ANDROID_SHA256:?}"
    : "${LIMINE_CORE_SLPI_FIRMWARE_URL:?}"
    : "${LIMINE_CORE_SLPI_FIRMWARE_SHA256:?}"
}

limine_core_assert_profile() {
    [[ "$LIMINE_CORE_PROFILE_VERSION" == 1 ]] || limine_core_die "Unsupported profile version"
    [[ "$LIMINE_CORE_TARGET_ARCH" == aarch64 ]] || limine_core_die "Target must be aarch64"
    [[ "$LIMINE_CORE_RELEASEVER" == rawhide ]] || limine_core_die "Release must be Fedora Rawhide"
    [[ "$LIMINE_CORE_FILESYSTEM" == ext4 ]] || limine_core_die "Filesystem must be ext4"
    [[ "$LIMINE_CORE_BOOTLOADER" == limine ]] || limine_core_die "Boot manager must be Limine"
    [[ "$LIMINE_CORE_DEFAULT_KERNEL_PACKAGE" == senemos-nabu-kernel-alpha ]] || \
        limine_core_die "Default kernel must be alpha"
    [[ "$LIMINE_CORE_BOOT_PACKAGE" == nabu-boot-limine ]] || limine_core_die "Wrong Limine selector"
    [[ "$LIMINE_CORE_PLYMOUTH_THEME" == senemos-nabu ]] || limine_core_die "Wrong Plymouth theme"
    [[ "$LIMINE_CORE_IMAGE_SIZE" =~ ^[1-9][0-9]*[GM]$ ]] || limine_core_die "Invalid image size"
    [[ "$LIMINE_CORE_COMPRESSION_LEVEL" =~ ^([1-9]|1[0-9])$ ]] || limine_core_die "Invalid zstd level"
    [[ "$LIMINE_CORE_ESP_SIZE_BYTES" =~ ^[0-9]+$ ]] || limine_core_die "Invalid ESP size"
    [[ "$LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE" == 4096 ]] || \
        limine_core_die "Nabu ESP sector size must be 4096"
    [[ "$LIMINE_CORE_REBOOT2ANDROID_SHA256" =~ ^[0-9a-f]{64}$ ]] || \
        limine_core_die "Invalid Reboot2Android digest"
    [[ "$LIMINE_CORE_SLPI_FIRMWARE_URL" =~ /raw/[0-9a-f]{40}/slpi_nb[.]mbn$ ]] || \
        limine_core_die "SLPI firmware URL is not commit pinned"
    [[ "$LIMINE_CORE_SLPI_FIRMWARE_SHA256" =~ ^[0-9a-f]{64}$ ]] || \
        limine_core_die "Invalid SLPI firmware digest"
}
