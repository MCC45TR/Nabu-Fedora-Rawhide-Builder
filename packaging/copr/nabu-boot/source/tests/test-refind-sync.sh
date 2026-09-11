#!/usr/bin/bash
set -Eeuo pipefail

root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
pending=$root/refind-sync.pending
marker=$root/refind.selected
esp=$root/esp
refind=$root/nabu-refind
mkdir -p "$esp"
touch "$pending" "$marker"
cat >"$refind" <<EOF
#!/usr/bin/bash
printf '%s\n' "\$*" >"$root/refind-called"
EOF
chmod 0755 "$refind"

export NABU_REFIND_SYNC_PENDING=$pending
export NABU_REFIND_MANAGER_MARKER=$marker
export NABU_REFIND_ESP=$esp
export NABU_REFIND_COMMAND=$refind

# An unavailable ESP is a deferred, successful boot-time condition. The marker
# must remain so the enabled oneshot retries once on the next boot.
bash manager/nabu-refind-sync
test -e "$pending"
test ! -e "$root/refind-called"

# A mounted ESP consumes the marker only after the synchronizer succeeds.
findmnt() { [[ $1 == --mountpoint && $2 == "$esp" ]]; }
export -f findmnt
bash manager/nabu-refind-sync
grep -Fxq update "$root/refind-called"
test ! -e "$pending"

# Selecting a different boot manager retires an obsolete request.
touch "$pending"
rm -f "$marker"
bash manager/nabu-refind-sync
test ! -e "$pending"
