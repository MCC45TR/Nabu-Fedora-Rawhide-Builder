#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

core_log() {
    printf '[CORE] %s\n' "$*" >&2
}

core_die() {
    core_log "ERROR: $*"
    exit 1
}

core_require_command() {
    command -v "$1" >/dev/null 2>&1 || core_die "Required command is missing: $1"
}

core_load_profile() {
    local profile_path="${1:?profile path is required}"
    [[ -r "$profile_path" ]] || core_die "Profile is not readable: $profile_path"
    # shellcheck disable=SC1090
    source "$profile_path"
    : "${CORE_PROFILE_VERSION:?}"
    : "${CORE_BUILD_FLAVOR:?}"
    : "${CORE_TARGET_ARCH:?}"
    : "${CORE_RELEASEVER:?}"
    : "${CORE_CONTAINER_IMAGE:?}"
    : "${CORE_COPR_STABLE_BASEURL:?}"
    : "${CORE_COPR_STABLE_GPGKEY:?}"
    : "${CORE_COPR_TEST_BASEURL:?}"
    : "${CORE_COPR_TEST_GPGKEY:?}"
    : "${CORE_FILESYSTEM:?}"
    : "${CORE_FILESYSTEM_LABEL:?}"
    : "${CORE_IMAGE_SIZE:?}"
    : "${CORE_COMPRESSION_LEVEL:?}"
    : "${CORE_ESP_SIZE_BYTES:?}"
    : "${CORE_ESP_LOGICAL_SECTOR_SIZE:?}"
    : "${CORE_ESP_LABEL:?}"
    : "${CORE_BOOTLOADER:?}"
    : "${CORE_KERNEL_PACKAGE:?}"
    : "${CORE_KERNEL_VERSION:?}"
    : "${CORE_KERNEL_RELEASE:?}"
    : "${CORE_CAMERA_SUPPORT_PACKAGE:?}"
    : "${CORE_IRIS_VAAPI_PACKAGE:?}"
    : "${CORE_META_PACKAGE:?}"
    : "${CORE_META_VERSION:?}"
    : "${CORE_META_RELEASE:?}"
    : "${CORE_BOOT_PACKAGE:?}"
    : "${CORE_PLYMOUTH_PACKAGE:?}"
    : "${CORE_PLYMOUTH_THEME:?}"
    : "${CORE_REFIND_TIMEOUT:?}"
    : "${CORE_RELEASE_TAG:?}"
    : "${CORE_KERNEL_CMDLINE:?}"
    : "${CORE_LOCALE:?}"
    : "${CORE_TIMEZONE:?}"
    : "${CORE_REBOOT2ANDROID_URL:?}"
    : "${CORE_REBOOT2ANDROID_SHA256:?}"
    : "${CORE_SLPI_FIRMWARE_URL:?}"
    : "${CORE_SLPI_FIRMWARE_SHA256:?}"
}

core_assert_profile() {
    [[ "$CORE_PROFILE_VERSION" == 3 ]] || core_die "Unsupported CORE profile version: $CORE_PROFILE_VERSION"
    [[ "$CORE_BUILD_FLAVOR" == release ]] || core_die "CORE build flavor must be release"
    [[ "$CORE_TARGET_ARCH" == aarch64 ]] || core_die "CORE target must be aarch64"
    [[ "$CORE_RELEASEVER" == rawhide ]] || core_die "CORE release must be Fedora Rawhide"
    [[ "$CORE_FILESYSTEM" == ext4 ]] || core_die "CORE filesystem must be ext4"
    [[ "$CORE_BOOTLOADER" == refind ]] || core_die "CORE bootloader must be rEFInd"
    [[ "$CORE_KERNEL_PACKAGE" == senemos-nabu-kernel-mainline ]] || core_die "CORE kernel must be stable mainline 7.2.x"
    [[ "$CORE_KERNEL_VERSION" =~ ^7[.]2[.][0-9]+$ ]] || core_die "CORE kernel version must remain on 7.2.x"
    [[ "$CORE_KERNEL_RELEASE" =~ ^[1-9][0-9]*$ ]] || core_die "Invalid mainline kernel release"
    [[ "$CORE_META_VERSION" == 3.0.0 ]] || core_die "Unexpected CORE meta version"
    [[ "$CORE_META_RELEASE" =~ ^[1-9][0-9]*$ ]] || core_die "Invalid CORE meta release"
    [[ "$CORE_CAMERA_SUPPORT_PACKAGE" == nabu-camera-support ]] || core_die "CORE camera package mismatch"
    [[ "$CORE_IRIS_VAAPI_PACKAGE" == iris-vaapi-nabu ]] || core_die "CORE Iris VA-API package mismatch"
    [[ "$CORE_REFIND_TIMEOUT" == 1 ]] || core_die "Release rEFInd timeout must be one second"
    [[ "$CORE_RELEASE_TAG" =~ ^[0-9]{10}$ ]] || core_die "Invalid release tag: $CORE_RELEASE_TAG"
    for required_word in quiet splash loglevel=3 selinux=1 enforcing=1; do
        [[ " $CORE_KERNEL_CMDLINE " == *" $required_word "* ]] || core_die "Release cmdline is missing: $required_word"
    done
    for forbidden_word in rd.debug debug systemd.log_level=debug systemd.debug_shell ignore_loglevel plymouth.enable=0 rd.driver.pre=cdc_acm deferred_probe_timeout=0; do
        [[ " $CORE_KERNEL_CMDLINE " != *" $forbidden_word "* ]] || core_die "Debug option entered release cmdline: $forbidden_word"
    done
    [[ "$CORE_IMAGE_SIZE" =~ ^[1-9][0-9]*[GM]$ ]] || core_die "Invalid CORE image size: $CORE_IMAGE_SIZE"
    [[ "$CORE_COMPRESSION_LEVEL" =~ ^([1-9]|1[0-9])$ ]] || core_die "Invalid zstd level: $CORE_COMPRESSION_LEVEL"
    [[ "$CORE_ESP_SIZE_BYTES" =~ ^[0-9]+$ ]] || core_die "Invalid ESP size"
    [[ "$CORE_ESP_LOGICAL_SECTOR_SIZE" == 4096 ]] || core_die "Nabu ESP sector size must be 4096"
    [[ "$CORE_REBOOT2ANDROID_SHA256" =~ ^[0-9a-f]{64}$ ]] || core_die "Invalid Reboot2Android digest"
    [[ "$CORE_SLPI_FIRMWARE_URL" =~ /raw/[0-9a-f]{40}/slpi_nb[.]mbn$ ]] || core_die "SLPI firmware URL is not commit pinned"
    [[ "$CORE_SLPI_FIRMWARE_SHA256" =~ ^[0-9a-f]{64}$ ]] || core_die "Invalid SLPI firmware digest"
}

core_json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}
