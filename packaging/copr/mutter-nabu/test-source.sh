#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive="$work/mutter-51.rc.tar.xz"

curl --fail --location --retry 3 --silent --show-error \
    --output "$archive" \
    https://download.gnome.org/sources/mutter/51/mutter-51.rc.tar.xz
(cd "$work" && sha512sum -c "$root/sources.sha512")
tar -xf "$archive" -C "$work"
source_file="$work/mutter-51.rc/src/backends/meta-monitor-manager.c"

grep -Fq 'gboolean orientation_unmanaged_inhibited;' "$source_file"
grep -Fq 'sync_orientation_unmanaged_inhibit (MetaMonitorManager *manager)' "$source_file"
grep -A30 -F 'update_panel_orientation_managed (MetaMonitorManager *manager)' "$source_file" \
    | grep -Fq 'sync_orientation_unmanaged_inhibit (manager);'
grep -Fq 'Version:       51~rc' "$root/mutter.spec"
grep -Fq 'Release:       1.nabu1%{?dist}' "$root/mutter.spec"

printf 'PASS: Mutter 51.rc source is checksum-locked and contains the auto-rotation inhibit fix\n'
