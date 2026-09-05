#!/usr/bin/bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
state_dir=${test_root}/state
active_file=${test_root}/active
log_file=${test_root}/systemctl.log
mock=${test_root}/systemctl

printf '%s\n' iio-sensor-proxy.service hexagonrpcd-sdsp.service >"${active_file}"

cat >"${mock}" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
case $1 in
	is-active)
		grep -Fxq "${3}" "${ACTIVE_FILE}"
		;;
	stop)
		grep -Fxv "${2}" "${ACTIVE_FILE}" >"${ACTIVE_FILE}.new" || :
		mv "${ACTIVE_FILE}.new" "${ACTIVE_FILE}"
		printf 'stop %s\n' "${2}" >>"${LOG_FILE}"
		[[ ${2} != iio-sensor-proxy.service ]]
		;;
	reset-failed)
		printf 'reset-failed %s\n' "${2}" >>"${LOG_FILE}"
		;;
	start)
		printf '%s\n' "${2}" >>"${ACTIVE_FILE}"
		printf 'start %s\n' "${2}" >>"${LOG_FILE}"
		;;
	*) exit 64 ;;
esac
EOF
chmod 0755 "${mock}"

export ACTIVE_FILE=${active_file} LOG_FILE=${log_file}
NABU_SLPI_STATE_DIR=${state_dir} SYSTEMCTL_BIN=${mock} \
	runtime/nabu-slpi-suspend prepare

test ! -s "${active_file}"
grep -Fxq 'stop iio-sensor-proxy.service' "${log_file}"
grep -Fxq 'reset-failed iio-sensor-proxy.service' "${log_file}"
grep -Fxq 'stop hexagonrpcd-sdsp.service' "${log_file}"

NABU_SLPI_STATE_DIR=${state_dir} SYSTEMCTL_BIN=${mock} \
	runtime/nabu-slpi-suspend resume

grep -Fxq 'start hexagonrpcd-sdsp.service' "${log_file}"
grep -Fxq 'start iio-sensor-proxy.service' "${log_file}"
