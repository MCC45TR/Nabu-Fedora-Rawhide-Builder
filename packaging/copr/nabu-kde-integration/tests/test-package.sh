#!/usr/bin/bash
set -Eeuo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mapfile -t rpms < <(find "$project_dir/out/rpm" -maxdepth 1 -type f -name '*.rpm' | sort)
[[ ${#rpms[@]} -eq 3 ]]

find_package_rpm() {
    local wanted=$1 candidate
    for candidate in "${rpms[@]}"; do
        if [[ "$(rpm -qp --qf '%{NAME}' "$candidate")" == "$wanted" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

runtime="$(find_package_rpm nabu-runtime-integration)"
profile="$(find_package_rpm nabu-kde-config)"
meta="$(find_package_rpm nabu-kde-integration)"
expected_version=1.4.0.1
for rpm_file in "$runtime" "$profile" "$meta"; do
    [[ "$(rpm -qp --qf '%{ARCH}' "$rpm_file")" == noarch ]]
    [[ "$(rpm -qp --qf '%{VERSION}' "$rpm_file")" == "$expected_version" ]]
done

rpm -qp --requires "$runtime" | grep -Fx 'kernel-nabu-core-uname-r'
rpm -qp --requires "$runtime" | grep -F 'iio-sensor-proxy-nabu >= 3.9-104.nabu5.test'
rpm -qp --requires "$runtime" | grep -Fx tuned
! rpm -qp --requires "$runtime" | grep -Fxq kscreen
rpm -qp --requires "$profile" | grep -F 'nabu-runtime-integration = '
rpm -qp --requires "$meta" | grep -F 'nabu-kde-l10n >= 1.0.0-1.test'
rpm -qp --requires "$meta" | grep -F 'nabu-kde-widgets >= 1.0.1'
rpm -qp --requires "$meta" | grep -Fx 'kwin >= 6.7.4'
! rpm -qp --requires "$meta" | grep -Fq 'senemos_nabu'

rpm -qpl "$runtime" | grep -Fx '/usr/bin/senemos-nabu-status'
rpm -qpl "$runtime" | grep -Fx '/usr/lib/systemd/system/nabu-slpi-suspend.service'
! rpm -qpl "$runtime" | grep -Fq 'nabu-slpi-start'
rpm -qpl "$runtime" | grep -Fx '/usr/lib/systemd/system/mnt-vendor-persist.mount'
! rpm -qpl "$runtime" | grep -Eq '^/mnt(/|$)'
rpm -qpl "$runtime" | grep -Fx '/usr/lib/systemd/system/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf'
! rpm -qpl "$runtime" | grep -Fq '/etc/modules-load.d/scsi_dh.conf'
! rpm -qpl "$profile" | grep -Eq 'nabu-(apply-display-orientation|display-resume|sddm-kwin-wayland)'
! rpm -qpl "$profile" | grep -Eq 'sddm.conf.d/90-senemos-nabu-display-orientation|xdg/autostart/nabu-display-orientation'
rpm -qpl "$profile" | grep -Fx '/etc/xdg/kwinoutputconfig.json'
rpm -qpl "$profile" | grep -Fx '/etc/xdg/powerdevilrc'
rpm -qpl "$profile" | grep -Fx '/usr/bin/senemos-nabu-display-profile'
! rpm -qpl "$profile" | grep -Fq 'nabu-kde-scale-migration'

bash -n "$project_dir/files/nabu-slpi-suspend"
! grep -Fq 'nabu-display-resume' "$project_dir/files/nabu-slpi-suspend"
bash -n "$project_dir/files/senemos-nabu-status"
! grep -Fq 'v1.23-s2idle-native' "$project_dir/files/senemos-nabu-status"
grep -Fq -- '--whatprovides kernel-nabu-core-uname-r' "$project_dir/files/senemos-nabu-status"
grep -Fq 'sensorproxy-als' "$project_dir/files/senemos-nabu-status"
grep -Fq 'sensorproxy-accel' "$project_dir/files/senemos-nabu-status"
grep -Fq 'available; currently unclaimed' "$project_dir/files/senemos-nabu-status"
grep -Fq 'slpi-remoteproc' "$project_dir/files/senemos-nabu-status"
grep -Fx 'enable iio-sensor-proxy.service' "$project_dir/files/90-senemos-nabu.preset"
! grep -Fq 'nabu-slpi-start.service' "$project_dir/files/90-senemos-nabu.preset"
grep -Fx 'disable hexagonrpcd-adsp-sensorspd.service' "$project_dir/files/90-senemos-nabu.preset"
! grep -Fq 'hexagonrpcd-adsp-sensorspd.service' "$project_dir/files/10-nabu-sensor-stack.conf"
grep -Fx 'WantedBy=multi-user.target' "$project_dir/files/10-nabu-sensor-stack.conf"
grep -Fx 'LidAction=32' "$project_dir/files/powerdevilrc"
! grep -Fq 'nabu-kde-scale-migration.service' "$project_dir/files/90-senemos-nabu-user.preset"
jq -e 'length == 0' "$project_dir/files/kwinoutputconfig.json" >/dev/null
python3 -m py_compile \
    "$project_dir/files/nabu-audio-orientation"
python3 -m py_compile "$project_dir/files/senemos-nabu-display-profile"

(
    slpi_mock_dir="$(mktemp -d "${TMPDIR:-/tmp}/senemos-nabu-slpi-mock.XXXXXX")"
    trap 'rm -rf -- "$slpi_mock_dir"' EXIT
    mkdir -p "$slpi_mock_dir/bin" "$slpi_mock_dir/units" "$slpi_mock_dir/runtime"
    mock_log="$slpi_mock_dir/systemctl.log"

    cat >"$slpi_mock_dir/bin/systemctl" <<'EOF'
#!/usr/bin/bash
set -eu
command=${1:-}
case "$command" in
    is-active)
        unit=${3:?missing unit}
        [[ -e "$SLPI_MOCK_UNIT_DIR/${unit}.active" ]]
        ;;
    stop)
        unit=${2:?missing unit}
        printf 'stop %s\n' "$unit" >>"$SLPI_MOCK_LOG"
        rm -f -- "$SLPI_MOCK_UNIT_DIR/${unit}.active"
        ;;
    start)
        unit=${2:?missing unit}
        printf 'start %s\n' "$unit" >>"$SLPI_MOCK_LOG"
        if [[ ${SLPI_MOCK_FAIL_START_UNIT:-} == "$unit" ]]; then
            exit 1
        fi
        : >"$SLPI_MOCK_UNIT_DIR/${unit}.active"
        ;;
    *)
        exit 64
        ;;
esac
EOF
    chmod 0755 "$slpi_mock_dir/bin/systemctl"

    export PATH="$slpi_mock_dir/bin:$PATH"
    export NABU_SLPI_STATE_DIR="$slpi_mock_dir/runtime"
    export SLPI_MOCK_UNIT_DIR="$slpi_mock_dir/units"
    export SLPI_MOCK_LOG="$mock_log"
    helper="$project_dir/files/nabu-slpi-suspend"

    : >"$SLPI_MOCK_UNIT_DIR/iio-sensor-proxy.service.active"
    : >"$SLPI_MOCK_UNIT_DIR/hexagonrpcd-sdsp.service.active"
    : >"$SLPI_MOCK_UNIT_DIR/hexagonrpcd-adsp-rootpd.service.active"
    bash "$helper" prepare
    [[ ! -e "$SLPI_MOCK_UNIT_DIR/iio-sensor-proxy.service.active" ]]
    [[ ! -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-sdsp.service.active" ]]
    [[ ! -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-adsp-rootpd.service.active" ]]
    mapfile -t calls <"$mock_log"
    [[ ${calls[*]} == 'stop iio-sensor-proxy.service stop hexagonrpcd-sdsp.service stop hexagonrpcd-adsp-rootpd.service' ]]

    bash "$helper" resume
    [[ -e "$SLPI_MOCK_UNIT_DIR/iio-sensor-proxy.service.active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-sdsp.service.active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-adsp-rootpd.service.active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/iio-sensor-proxy.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-sdsp.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-adsp-rootpd.was-active" ]]
    mapfile -t calls <"$mock_log"
    [[ ${calls[*]} == 'stop iio-sensor-proxy.service stop hexagonrpcd-sdsp.service stop hexagonrpcd-adsp-rootpd.service start hexagonrpcd-adsp-rootpd.service start hexagonrpcd-sdsp.service start iio-sensor-proxy.service' ]]

    : >"$mock_log"
    bash "$helper" prepare
    if SLPI_MOCK_FAIL_START_UNIT=iio-sensor-proxy.service bash "$helper" resume; then
        echo 'SLPI resume unexpectedly succeeded while SensorProxy start was forced to fail' >&2
        exit 1
    fi
    [[ -e "$NABU_SLPI_STATE_DIR/iio-sensor-proxy.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-sdsp.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-adsp-rootpd.was-active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-sdsp.service.active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-adsp-rootpd.service.active" ]]
    [[ ! -e "$SLPI_MOCK_UNIT_DIR/iio-sensor-proxy.service.active" ]]

    bash "$helper" prepare
    [[ -e "$NABU_SLPI_STATE_DIR/iio-sensor-proxy.was-active" ]]
    [[ -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-sdsp.was-active" ]]
    [[ -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-adsp-rootpd.was-active" ]]
    bash "$helper" resume
    [[ -e "$SLPI_MOCK_UNIT_DIR/iio-sensor-proxy.service.active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-sdsp.service.active" ]]
    [[ -e "$SLPI_MOCK_UNIT_DIR/hexagonrpcd-adsp-rootpd.service.active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/iio-sensor-proxy.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-sdsp.was-active" ]]
    [[ ! -e "$NABU_SLPI_STATE_DIR/hexagonrpcd-adsp-rootpd.was-active" ]]
)

mock_dir="$(mktemp -d "${TMPDIR:-/tmp}/senemos-nabu-kscreen-mock.XXXXXX")"
cat >"$mock_dir/kscreen-doctor" <<'EOF'
#!/usr/bin/bash
set -eu
if [[ "${1:-}" == --json && "${KSCREEN_MOCK_JSON_FAIL:-0}" == 1 ]]; then
    exit 1
elif [[ "${1:-}" == --json ]]; then
    cat <<'JSON'
{"outputs":[{"id":1,"name":"DSI-1","connected":true,"enabled":true,"currentModeId":"native","modes":[{"id":"native","size":{"width":1600,"height":2560}}]}]}
JSON
elif [[ "${1:-}" == -o ]]; then
    cat <<'TEXT'
Output: 1 DSI-1 test-uuid
        enabled
        connected
        Modes: 1:1600x2560@120.00*!
        Geometry: 0,0 1280x800
        Scale: 2
TEXT
else
    printf '%s\n' "$*" >"$KSCREEN_MOCK_RESULT"
fi
EOF
chmod 0755 "$mock_dir/kscreen-doctor"
mock_result="$mock_dir/result"
KSCREEN_DOCTOR="$mock_dir/kscreen-doctor" KSCREEN_MOCK_RESULT="$mock_result" \
    "$project_dir/files/senemos-nabu-display-profile" fhd
grep -Fx 'output.DSI-1.scale.1.33333333333' "$mock_result"
KSCREEN_DOCTOR="$mock_dir/kscreen-doctor" KSCREEN_MOCK_RESULT="$mock_result" \
    "$project_dir/files/senemos-nabu-display-profile" hd
grep -Fx 'output.DSI-1.scale.2' "$mock_result"
KSCREEN_MOCK_JSON_FAIL=1 KSCREEN_DOCTOR="$mock_dir/kscreen-doctor" \
    KSCREEN_MOCK_RESULT="$mock_result" \
    "$project_dir/files/senemos-nabu-display-profile" fhd --dry-run |
    grep -Fx 'profile=fhd connector=DSI-1 scale=1.33333333333'
rm -rf -- "$mock_dir"

payload_root="$(mktemp -d "${TMPDIR:-/tmp}/senemos-nabu-rpm-test.XXXXXX")"
trap 'rm -rf -- "$payload_root"' EXIT
for package in "$runtime" "$profile" "$meta"; do
    (cd "$payload_root" && rpm2cpio "$package" | cpio --quiet -idmu)
done
test -x "$payload_root/usr/bin/senemos-nabu-status"
test -x "$payload_root/usr/bin/senemos-nabu-display-profile"
test ! -e "$payload_root/usr/libexec/senemos-nabu/nabu-apply-display-orientation"
test ! -e "$payload_root/usr/libexec/senemos-nabu/nabu-display-resume"
test ! -e "$payload_root/usr/libexec/senemos-nabu/nabu-sddm-kwin-wayland"
test -s "$payload_root/etc/xdg/kwinoutputconfig.json"
test -s "$payload_root/etc/xdg/powerdevilrc"
test ! -e "$payload_root/usr/libexec/senemos-nabu/nabu-kde-scale-migration"
test ! -e "$payload_root/usr/lib/systemd/user/nabu-kde-scale-migration.service"
test -s "$payload_root/usr/lib/systemd/system/iio-sensor-proxy.service.d/10-nabu-sensor-stack.conf"
test ! -e "$payload_root/usr/libexec/senemos-nabu/nabu-slpi-start"
test ! -e "$payload_root/usr/lib/systemd/system/nabu-slpi-start.service"
test -s "$payload_root/usr/lib/systemd/system/mnt-vendor-persist.mount"

echo 'senemos-nabu-kde package tests passed'
