#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grow="$root/runtime/nabu-root-growfs.service"
cleanup="$root/runtime/90-nabu-dnf5-offline-cleanup.conf"

grep -Fqx 'ExecStart=/usr/lib/systemd/systemd-growfs /' "$grow"
grep -Fqx 'WantedBy=multi-user.target' "$grow"
grep -Fqx 'ExecStart=-/usr/bin/dnf5 offline clean' "$cleanup"
grep -Fqx 'ExecStart=-/usr/bin/rm -fv /system-update /etc/system-update' "$cleanup"
printf 'PASS: root-grow and failed-offline-update recovery policy\n'
