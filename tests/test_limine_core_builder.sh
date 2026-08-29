#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
profile="$repo_root/limine-core-builder/profile.env"
compose="$repo_root/limine-core-builder/container-compose.sh"
verify="$repo_root/limine-core-builder/lib/verify.sh"
workflow="$repo_root/.github/workflows/build-limine-core-manual.yml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_fixed() { grep -Fq "$1" "$2" || fail "$2 lacks: $1"; }
assert_absent() { ! grep -Fq "$1" "$2" || fail "$2 unexpectedly contains: $1"; }

for file in "$profile" "$compose" "$verify" "$workflow"; do [[ -s "$file" ]] || fail "missing $file"; done

assert_fixed 'LIMINE_CORE_BOOTLOADER=limine' "$profile"
assert_fixed 'LIMINE_CORE_FILESYSTEM=ext4' "$profile"
assert_fixed 'LIMINE_CORE_FILESYSTEM_LABEL=linux' "$profile"
assert_fixed 'LIMINE_CORE_DEFAULT_KERNEL_PACKAGE=senemos-nabu-kernel-alpha' "$profile"
assert_fixed 'LIMINE_CORE_META_PACKAGE=nabu-core-meta' "$profile"
assert_fixed 'LIMINE_CORE_BOOT_PACKAGE=nabu-boot-limine' "$profile"
assert_fixed 'LIMINE_CORE_PLYMOUTH_PACKAGE=senemos-nabu-plymouth' "$profile"
assert_fixed 'LIMINE_CORE_ESP_LOGICAL_SECTOR_SIZE=4096' "$profile"

assert_fixed 'NABU_VERBOSE_MARKER_DIR=/etc/kernel/nabu-verbose-disabled.d' "$compose"
assert_fixed 'plymouth-set-default-theme' "$compose"
assert_fixed 'nabu-regenerate-uki' "$compose"
assert_fixed 'systemd-boot-unsigned' "$compose"
assert_fixed 'diffutils' "$compose"
assert_fixed 'limine_core_verify_no_overflow_ownership' "$compose"
assert_fixed 'distro-sync --assumeno' "$compose"
assert_fixed 'stages.tsv' "$compose"
assert_fixed 'limine.conf' "$compose"

assert_fixed "root=PARTLABEL=linux" "$verify"
assert_fixed "quiet" "$verify"
assert_fixed "splash" "$verify"
assert_fixed "plymouth.enable=0" "$verify"
assert_fixed "nobody/65534" "$verify"
assert_fixed "ARM64" "$verify"

assert_fixed 'workflow_dispatch:' "$workflow"
assert_absent 'push:' "$workflow"
assert_absent 'pull_request:' "$workflow"
assert_fixed 'uname -m' "$workflow"
assert_fixed 'limine-core-builder/build-core.sh' "$workflow"

printf 'PASS: Limine CORE builder contract\n'
