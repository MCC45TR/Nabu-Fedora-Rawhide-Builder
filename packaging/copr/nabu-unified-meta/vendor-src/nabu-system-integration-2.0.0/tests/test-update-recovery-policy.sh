#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cleanup="$root/runtime/90-nabu-dnf5-offline-cleanup.conf"

test ! -e "$root/runtime/nabu-root-growfs.service"
test ! -e "$root/runtime/nabu-pmic-rtc-sync.service"
grep -Fqx 'ExecStart=-/usr/bin/dnf5 offline clean' "$cleanup"
grep -Fqx 'ExecStart=-/usr/bin/rm -fv /system-update /etc/system-update' "$cleanup"
printf 'PASS: native root-grow and failed-offline-update recovery policy\n'
