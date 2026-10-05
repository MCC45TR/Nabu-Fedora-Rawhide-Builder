#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export NABU_META_VERSION_STATE="$test_root/last-version"
export NABU_META_VERSION_TIMEZONE=Europe/Istanbul

export NABU_META_VERSION_NOW='2026-08-28 14:28:59 +03'
first=$($root/generate-meta-version)
[[ $first == 2608281428 ]]

second=$($root/generate-meta-version)
[[ $second == 2608281429 ]]

export NABU_META_VERSION_NOW='2026-08-28 14:20:00 +03'
third=$($root/generate-meta-version)
[[ $third == 2608281430 ]]

export NABU_META_VERSION_NOW='2026-08-28 11:31:00 UTC'
fourth=$($root/generate-meta-version)
[[ $fourth == 2608281431 ]]

printf 'Meta version policy: PASS (%s %s %s %s)\n' \
    "$first" "$second" "$third" "$fourth"
