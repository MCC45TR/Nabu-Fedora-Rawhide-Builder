#!/usr/bin/bash
set -Eeuo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
pending=$root/pending.d
log=$root/calls.log
install -d "$pending"

cat >"$root/maintenance" <<'EOF'
#!/usr/bin/bash
printf 'maintenance\n' >>"$TEST_LOG"
rm -f -- "$TEST_PENDING"/*
EOF
cat >"$root/plymouth" <<'EOF'
#!/usr/bin/bash
printf 'plymouth %s\n' "$*" >>"$TEST_LOG"
[[ $1 != --ping ]] || exit 0
EOF
chmod +x "$root/maintenance" "$root/plymouth"

printf '7.2.3-nabu-senemos-mainline\n' >"$pending/mainline"
TEST_LOG=$log TEST_PENDING=$pending \
NABU_OFFLINE_PENDING_DIR=$pending \
NABU_OFFLINE_MAINTENANCE=$root/maintenance \
NABU_OFFLINE_PLYMOUTH=$root/plymouth \
    bash "$source_dir/nabu-kernel-offline-finalize"

[[ $(grep -c '^maintenance$' "$log") -eq 1 ]]
grep -Fq 'plymouth display-message --text=Preparing the updated kernel boot files...' "$log"
[[ -z $(find "$pending" -mindepth 1 -maxdepth 1 -type f -print -quit) ]]

# Idempotent no-op: with no pending job, neither maintenance nor Plymouth is
# invoked a second time.
TEST_LOG=$log TEST_PENDING=$pending \
NABU_OFFLINE_PENDING_DIR=$pending \
NABU_OFFLINE_MAINTENANCE=$root/maintenance \
NABU_OFFLINE_PLYMOUTH=$root/plymouth \
    bash "$source_dir/nabu-kernel-offline-finalize"
[[ $(grep -c '^maintenance$' "$log") -eq 1 ]]
printf 'PASS: offline kernel finalization and idempotence\n'
