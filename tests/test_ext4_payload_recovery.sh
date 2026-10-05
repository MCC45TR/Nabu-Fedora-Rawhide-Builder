#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
BUILDER="$ROOT_DIR/Nabu-Fedora-Rawhide-Builder.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nabu-ext4-payload-test.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/root/usr/share/locale/tr/LC_MESSAGES" "$WORK_DIR/bin" "$WORK_DIR/meta" "$WORK_DIR/logs"
printf 'Fedora-owned Turkish catalog fixture\n' >"$WORK_DIR/root/usr/share/locale/tr/LC_MESSAGES/example.mo"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    '[[ " $* " == *" -qal "* ]] || exit 64' \
    "printf '%s\\n' /usr/share/locale/tr/LC_MESSAGES/example.mo" >"$WORK_DIR/bin/rpm"
chmod 0755 "$WORK_DIR/bin/rpm"

truncate -s 16M "$WORK_DIR/test.img"
mkfs.ext4 -q -F -d "$WORK_DIR/root" "$WORK_DIR/test.img"
debugfs -w -R 'rm /usr/share/locale/tr/LC_MESSAGES/example.mo' "$WORK_DIR/test.img" >/dev/null

source "$BUILDER"
PATH="$WORK_DIR/bin:$PATH"
METADATA_DIR="$WORK_DIR/meta"
LOG_DIR="$WORK_DIR/logs"

restore_all_missing_regular_rpm_payload_in_ext4 "$WORK_DIR/root" "$WORK_DIR/test.img"
verify_all_regular_rpm_payload_in_ext4 "$WORK_DIR/root" "$WORK_DIR/test.img"
debugfs -R 'dump -p /usr/share/locale/tr/LC_MESSAGES/example.mo /dev/stdout' "$WORK_DIR/test.img" 2>/dev/null |
    cmp -s "$WORK_DIR/root/usr/share/locale/tr/LC_MESSAGES/example.mo" -
[[ ! -s "$WORK_DIR/meta/ext4-rpm-payload-missing-after-restore.txt" ]]
printf 'generic ext4 RPM payload recovery: PASS\n'
