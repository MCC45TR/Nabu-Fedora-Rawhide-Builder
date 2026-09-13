#!/usr/bin/bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
source_root=$test_root/source
persist_root=$test_root/persist/registry
runtime_root=$test_root/runtime/hexagonfs
helper=$project_dir/runtime/nabu-copy-calibration-tree

install -d "$source_root/sensors/registry" "$persist_root/registry"
printf 'static\n' >"$source_root/sensors/sns_reg.conf"
printf 'base\n' >"$source_root/sensors/registry/base"
printf 'calibration\n' >"$persist_root/registry/calibration"
printf 'factory-override\n' >"$persist_root/registry/base"
printf 'version-1\n' >"$persist_root/sns_reg_version"

TMPDIR=$test_root \
NABU_SENSOR_SOURCE_ROOT=$source_root \
NABU_SENSOR_PERSIST_REGISTRY=$persist_root/registry \
NABU_SENSOR_RUNTIME_ROOT=$runtime_root \
NABU_SENSOR_RUNTIME_USER=$(id -un) \
NABU_SENSOR_RUNTIME_GROUP=$(id -gn) \
PATH="$(dirname -- "$helper"):$PATH" \
    sed "s#/usr/libexec/senemos-nabu/nabu-copy-calibration-tree#$helper#g" \
        "$project_dir/runtime/nabu-sensor-registry-runtime" >"$test_root/runtime-copy"
chmod 0755 "$test_root/runtime-copy"
TMPDIR=$test_root \
NABU_SENSOR_SOURCE_ROOT=$source_root \
NABU_SENSOR_PERSIST_REGISTRY=$persist_root/registry \
NABU_SENSOR_RUNTIME_ROOT=$runtime_root \
NABU_SENSOR_RUNTIME_USER=$(id -un) \
NABU_SENSOR_RUNTIME_GROUP=$(id -gn) \
    "$test_root/runtime-copy"

grep -Fxq static "$runtime_root/sensors/sns_reg.conf"
grep -Fxq factory-override "$runtime_root/sensors/registry/base"
grep -Fxq calibration "$runtime_root/sensors/registry/calibration"
grep -Fxq version-1 "$runtime_root/sensors/sns_reg_version"
grep -Fxq calibration "$persist_root/registry/calibration"
grep -Fxq version-1 "$persist_root/sns_reg_version"
test "$(stat -c '%U:%G' "$runtime_root/sensors/registry/calibration")" = \
    "$(id -un):$(id -gn)"

# Android-owned symlinks and special files must never cross into the runtime
# tree, even when their numeric owner matches the local desktop user.
attack_source=$test_root/attack-source
attack_destination=$test_root/attack-destination
install -d "$attack_source" "$attack_destination"
ln -s /etc/passwd "$attack_source/escape"
if "$helper" "$attack_source" "$attack_destination"; then
    printf 'Symlink source was unexpectedly accepted\n' >&2
    exit 1
fi
test ! -e "$attack_destination/escape"

special_source=$test_root/special-source
special_destination=$test_root/special-destination
install -d "$special_source" "$special_destination"
mkfifo "$special_source/fifo"
if "$helper" "$special_source" "$special_destination"; then
    printf 'Special source was unexpectedly accepted\n' >&2
    exit 1
fi

large_source=$test_root/large-source
large_destination=$test_root/large-destination
install -d "$large_source" "$large_destination"
truncate -s 1048577 "$large_source/too-large"
if "$helper" "$large_source" "$large_destination"; then
    printf 'Oversized source was unexpectedly accepted\n' >&2
    exit 1
fi
