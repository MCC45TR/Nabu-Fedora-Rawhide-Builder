#!/usr/bin/bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
helper=${project_dir}/runtime/nabu-sensor-session-gate
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

cat >"${test_root}/busctl" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
if [[ -e ${state}/restarted ]]; then
	echo 'b true'
else
	echo 'b false'
fi
EOF
cat >"${test_root}/monitor-sensor" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
printf '%s\n' "$*" >>"${state}/monitor-sensor.log"
echo '=== Has accelerometer (orientation: right-up, tilt: tilted-up)'
EOF
cat >"${test_root}/ssccli" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
printf '%s\n' "$*" >>"${state}/ssccli.log"
echo 'Accelerometer sensor measurement: X=0.0 Y=9.8 Z=0.0 m/s2'
EOF
cat >"${test_root}/timeout" <<'EOF'
#!/usr/bin/bash
shift
exec "$@"
EOF
cat >"${test_root}/systemctl" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
printf '%s\n' "$*" >>"${state}/systemctl.log"
touch "${state}/restarted"
EOF
cat >"${test_root}/sleep" <<'EOF'
#!/usr/bin/bash
:
EOF
chmod +x "${test_root}/busctl" "${test_root}/monitor-sensor" "${test_root}/ssccli" \
    "${test_root}/systemctl" "${test_root}/timeout" "${test_root}/sleep"

NABU_SENSOR_GATE_TEST_STATE=${test_root} \
NABU_SENSOR_GATE_BUSCTL=${test_root}/busctl \
NABU_SENSOR_GATE_MONITOR_SENSOR=${test_root}/monitor-sensor \
NABU_SENSOR_GATE_SSCCLI=${test_root}/ssccli \
NABU_SENSOR_GATE_SYSTEMCTL=${test_root}/systemctl \
NABU_SENSOR_GATE_TIMEOUT=${test_root}/timeout \
NABU_SENSOR_GATE_SLEEP=${test_root}/sleep \
NABU_SENSOR_GATE_SSC_ATTEMPTS=1 \
NABU_SENSOR_GATE_PROXY_ATTEMPTS=1 \
"${helper}" >"${test_root}/success.log" 2>&1

grep -Fxq -- '--sensor accelerometer --timeout 1' "${test_root}/ssccli.log"
grep -Fxq 'restart iio-sensor-proxy.service' "${test_root}/systemctl.log"
grep -Fq 'delivered an accelerometer sample after one bounded restart' "${test_root}/success.log"
grep -Fxq -- '--accel' "${test_root}/monitor-sensor.log"

rm -f "${test_root}/restarted" "${test_root}/systemctl.log"
cat >"${test_root}/systemctl" <<'EOF'
#!/usr/bin/bash
exit 1
EOF
chmod +x "${test_root}/systemctl"

NABU_SENSOR_GATE_TEST_STATE=${test_root} \
NABU_SENSOR_GATE_BUSCTL=${test_root}/busctl \
NABU_SENSOR_GATE_MONITOR_SENSOR=${test_root}/monitor-sensor \
NABU_SENSOR_GATE_SSCCLI=${test_root}/ssccli \
NABU_SENSOR_GATE_SYSTEMCTL=${test_root}/systemctl \
NABU_SENSOR_GATE_TIMEOUT=${test_root}/timeout \
NABU_SENSOR_GATE_SLEEP=${test_root}/sleep \
NABU_SENSOR_GATE_SSC_ATTEMPTS=1 \
NABU_SENSOR_GATE_PROXY_ATTEMPTS=1 \
"${helper}" >"${test_root}/fallback.log" 2>&1

grep -Fq 'allowing the desktop to start for recovery' "${test_root}/fallback.log"

rm -f "${test_root}/restarted" "${test_root}/systemctl.log"
cat >"${test_root}/ssccli" <<'EOF'
#!/usr/bin/bash
exit 1
EOF
cat >"${test_root}/busctl" <<'EOF'
#!/usr/bin/bash
echo 'b true'
EOF
chmod +x "${test_root}/ssccli" "${test_root}/busctl"

NABU_SENSOR_GATE_TEST_STATE=${test_root} \
NABU_SENSOR_GATE_BUSCTL=${test_root}/busctl \
NABU_SENSOR_GATE_MONITOR_SENSOR=${test_root}/monitor-sensor \
NABU_SENSOR_GATE_SSCCLI=${test_root}/ssccli \
NABU_SENSOR_GATE_SYSTEMCTL=${test_root}/systemctl \
NABU_SENSOR_GATE_TIMEOUT=${test_root}/timeout \
NABU_SENSOR_GATE_SLEEP=${test_root}/sleep \
NABU_SENSOR_GATE_SSC_ATTEMPTS=1 \
NABU_SENSOR_GATE_PROXY_ATTEMPTS=1 \
"${helper}" >"${test_root}/no-sample.log" 2>&1

grep -Fq 'SSC produced no accelerometer sample' "${test_root}/no-sample.log"
grep -Fq 'SLPI recovery failed; allowing the desktop to start for recovery' "${test_root}/no-sample.log"
test ! -e "${test_root}/systemctl.log"

cat >"${test_root}/ssccli" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
[[ $(cat "${state}/slpi-state") == start ]] || exit 1
echo 'Accelerometer sensor measurement: X=0.0 Y=9.8 Z=0.0 m/s2'
EOF
cat >"${test_root}/busctl" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
grep -Fxq 'start iio-sensor-proxy.service' "${state}/systemctl.log" 2>/dev/null && echo 'b true' || echo 'b false'
EOF
cat >"${test_root}/systemctl" <<'EOF'
#!/usr/bin/bash
state=${NABU_SENSOR_GATE_TEST_STATE:?}
printf '%s\n' "$*" >>"${state}/systemctl.log"
EOF
chmod +x "${test_root}/ssccli" "${test_root}/busctl" "${test_root}/systemctl"
: >"${test_root}/slpi-state"
: >"${test_root}/systemctl.log"

NABU_SENSOR_GATE_TEST_STATE=${test_root} \
NABU_SENSOR_GATE_BUSCTL=${test_root}/busctl \
NABU_SENSOR_GATE_MONITOR_SENSOR=${test_root}/monitor-sensor \
NABU_SENSOR_GATE_SSCCLI=${test_root}/ssccli \
NABU_SENSOR_GATE_SYSTEMCTL=${test_root}/systemctl \
NABU_SENSOR_GATE_TIMEOUT=${test_root}/timeout \
NABU_SENSOR_GATE_SLEEP=${test_root}/sleep \
NABU_SENSOR_GATE_SLPI_STATE=${test_root}/slpi-state \
NABU_SENSOR_GATE_SSC_ATTEMPTS=1 \
NABU_SENSOR_GATE_RECOVERY_ATTEMPTS=1 \
NABU_SENSOR_GATE_PROXY_ATTEMPTS=1 \
"${helper}" >"${test_root}/slpi-recovery.log" 2>&1

grep -Fxq 'stop nabu-cct-iio-bridge.service iio-sensor-proxy.service hexagonrpcd-sdsp.service' "${test_root}/systemctl.log"
grep -Fxq 'start hexagonrpcd-sdsp.service' "${test_root}/systemctl.log"
grep -Fxq 'start iio-sensor-proxy.service' "${test_root}/systemctl.log"
grep -Fq 'SSC recovered after one bounded SLPI cycle' "${test_root}/slpi-recovery.log"
grep -Fq 'delivered an accelerometer sample before the graphical session' "${test_root}/slpi-recovery.log"
# Exercise real long-running producers: the old command substitution waited
# four seconds even when the very first line was already a valid sample.
source <(sed '/^if ! wait_until ssc_ready/,$d' "${helper}")
started=$EPOCHREALTIME
first_sample 4 '^sample$' bash -c 'echo sample; exec sleep 10'
elapsed=$(awk -v start="$started" -v end="$EPOCHREALTIME" 'BEGIN {print end-start}')
awk -v elapsed="$elapsed" 'BEGIN {exit !(elapsed < 2)}'
if first_sample 0.2 '^sample$' bash -c 'echo undefined; exec sleep 10'; then
    echo 'Accepted an invalid sample' >&2
    exit 1
fi
first_sample 2 '^sample$' bash -c 'echo undefined; sleep 0.1; echo sample; exec sleep 10'
monitor_sensor_bin=${test_root}/monitor-sensor
cat >"${monitor_sensor_bin}" <<'EOF'
#!/usr/bin/bash
echo '=== Has accelerometer (orientation: undefined, tilt: undefined)'
EOF
if proxy_sample_ready; then
    echo 'Accepted sensor presence without valid orientation' >&2
    exit 1
fi
cat >"${monitor_sensor_bin}" <<'EOF'
#!/usr/bin/bash
echo '=== Has accelerometer (orientation: undefined, tilt: face-up)'
exec sleep 10
EOF
proxy_sample_ready
echo 'sensor session gate tests passed'
