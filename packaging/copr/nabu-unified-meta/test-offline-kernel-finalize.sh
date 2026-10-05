#!/usr/bin/bash
set -Eeuo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
pending=$root/pending.d
refind_pending=$root/refind.pending
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
cat >"$root/refind-sync" <<'EOF'
#!/usr/bin/bash
printf 'refind-sync\n' >>"$TEST_LOG"
rm -f -- "$TEST_REFIND_PENDING"
EOF
chmod +x "$root/maintenance" "$root/plymouth" "$root/refind-sync"

printf '7.2.3-nabu-senemos-mainline\n' >"$pending/mainline"
touch "$refind_pending"
TEST_LOG=$log TEST_PENDING=$pending \
TEST_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_PENDING_DIR=$pending \
NABU_OFFLINE_MAINTENANCE=$root/maintenance \
NABU_OFFLINE_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_REFIND_SYNC=$root/refind-sync \
NABU_OFFLINE_PLYMOUTH=$root/plymouth \
    bash "$source_dir/nabu-kernel-offline-finalize"

[[ $(grep -c '^maintenance$' "$log") -eq 1 ]]
[[ $(grep -c '^refind-sync$' "$log") -eq 1 ]]
grep -Fq 'plymouth display-message --text=Preparing the updated boot files...' "$log"
[[ -z $(find "$pending" -mindepth 1 -maxdepth 1 -type f -print -quit) ]]
[[ ! -e $refind_pending ]]

# Idempotent no-op: with no pending job, neither maintenance nor Plymouth is
# invoked a second time.
TEST_LOG=$log TEST_PENDING=$pending \
TEST_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_PENDING_DIR=$pending \
NABU_OFFLINE_MAINTENANCE=$root/maintenance \
NABU_OFFLINE_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_REFIND_SYNC=$root/refind-sync \
NABU_OFFLINE_PLYMOUTH=$root/plymouth \
    bash "$source_dir/nabu-kernel-offline-finalize"
[[ $(grep -c '^maintenance$' "$log") -eq 1 ]]
[[ $(grep -c '^refind-sync$' "$log") -eq 1 ]]

# A boot-package-only offline update also uses this finalizer, without running
# the expensive kernel worker when its queue is empty.
touch "$refind_pending"
TEST_LOG=$log TEST_PENDING=$pending TEST_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_PENDING_DIR=$pending \
NABU_OFFLINE_MAINTENANCE=$root/maintenance \
NABU_OFFLINE_REFIND_PENDING=$refind_pending \
NABU_OFFLINE_REFIND_SYNC=$root/refind-sync \
NABU_OFFLINE_PLYMOUTH=$root/plymouth \
    bash "$source_dir/nabu-kernel-offline-finalize"
[[ $(grep -c '^maintenance$' "$log") -eq 1 ]]
[[ $(grep -c '^refind-sync$' "$log") -eq 2 ]]
printf 'PASS: offline boot finalization and idempotence\n'
