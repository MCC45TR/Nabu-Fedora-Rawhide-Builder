#!/usr/bin/bash
set -euo pipefail

policy=${1:-runtime/90-nabu-user-slice-freeze.conf}

test -f "$policy"
test "$(stat -c '%a' "$policy")" = 644
grep -Fxq '[Service]' "$policy"
grep -Fxq 'Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false' "$policy"
test "$(grep -Fc 'Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=' "$policy")" = 1
