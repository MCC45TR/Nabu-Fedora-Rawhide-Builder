#!/usr/bin/bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
source_root=$test_root/source
persist_root=$test_root/persist/registry
runtime_root=$test_root/runtime/hexagonfs

install -d "$source_root/sensors/registry" "$persist_root/registry"
printf 'static\n' >"$source_root/sensors/sns_reg.conf"
printf 'base\n' >"$source_root/sensors/registry/base"
printf 'calibration\n' >"$persist_root/registry/calibration"
printf 'version-1\n' >"$persist_root/sns_reg_version"

TMPDIR=$test_root \
NABU_SENSOR_SOURCE_ROOT=$source_root \
NABU_SENSOR_PERSIST_REGISTRY=$persist_root/registry \
NABU_SENSOR_RUNTIME_ROOT=$runtime_root \
NABU_SENSOR_RUNTIME_USER=$(id -un) \
NABU_SENSOR_RUNTIME_GROUP=$(id -gn) \
    "$project_dir/runtime/nabu-sensor-registry-runtime"

grep -Fxq static "$runtime_root/sensors/sns_reg.conf"
grep -Fxq base "$runtime_root/sensors/registry/base"
grep -Fxq calibration "$runtime_root/sensors/registry/calibration"
grep -Fxq version-1 "$runtime_root/sensors/sns_reg_version"
grep -Fxq calibration "$persist_root/registry/calibration"
grep -Fxq version-1 "$persist_root/sns_reg_version"
test "$(stat -c '%U:%G' "$runtime_root/sensors/registry/calibration")" = \
    "$(id -un):$(id -gn)"
