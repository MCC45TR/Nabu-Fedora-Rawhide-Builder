#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper=$root/nabu-maintenance-ready
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

queue=$test_root/queue
pending=$test_root/refind.pending
proc=$test_root/proc
power=$test_root/power
fakebin=$test_root/bin
sessions=$test_root/sessions
install -d "$queue" "$proc/1" "$power/usb" "$power/battery" "$fakebin"
printf '0.10 0.20 0.30 1/1 1\n' >"$proc/loadavg"
printf 'systemd\n' >"$proc/1/comm"
printf '1\n' >"$power/usb/online"
printf '90\n' >"$power/battery/capacity"
: >"$sessions"

cat >"$fakebin/systemctl" <<'EOF'
#!/usr/bin/bash
exit 1
EOF
cat >"$fakebin/loginctl" <<'EOF'
#!/usr/bin/bash
sessions=${NABU_TEST_SESSIONS:?}
if [[ $1 == list-sessions ]]; then
    cat "$sessions"
elif [[ $1 == show-session ]]; then
    case $4 in
        Active) printf 'yes\n' ;;
        IdleHint) printf '%s\n' "${NABU_TEST_IDLE:-yes}" ;;
    esac
fi
EOF
chmod 0755 "$fakebin"/*

run_ready() {
    NABU_KERNEL_QUEUE=$queue \
    NABU_REFIND_PENDING=$pending \
    NABU_PROC_ROOT=$proc \
    NABU_POWER_SUPPLY_ROOT=$power \
    NABU_SYSTEMCTL=$fakebin/systemctl \
    NABU_LOGINCTL=$fakebin/loginctl \
    NABU_TEST_SESSIONS=$sessions \
    NABU_MAINTENANCE_MAX_LOAD=1.00 \
        "$helper"
}

if run_ready; then
    echo 'maintenance was accepted without pending work' >&2
    exit 1
fi

touch "$queue/mainline"
run_ready

printf '2 1000 test seat0 tty2\n' >"$sessions"
if NABU_TEST_IDLE=no run_ready; then
    echo 'maintenance was accepted during an active session' >&2
    exit 1
fi
NABU_TEST_IDLE=yes run_ready

install -d "$proc/2"
printf 'dnf5\n' >"$proc/2/comm"
if run_ready; then
    echo 'maintenance was accepted during a DNF transaction' >&2
    exit 1
fi
rm -rf -- "$proc/2"

printf '0\n' >"$power/usb/online"
printf '20\n' >"$power/battery/capacity"
if run_ready; then
    echo 'maintenance was accepted on a low battery' >&2
    exit 1
fi
printf '1\n' >"$power/usb/online"
run_ready

rm -f -- "$queue/mainline"
touch "$pending"
run_ready

echo 'maintenance readiness tests passed'
