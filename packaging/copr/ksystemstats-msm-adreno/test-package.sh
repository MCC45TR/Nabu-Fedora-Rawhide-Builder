#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
patch="$root/patches/0001-gpu-add-Linux-MSM-Adreno-sensors.patch"

grep -Fq 'add_match_subsystem(enumerate, "devfreq")' "$patch"
grep -Fq 'strcmp(driver, "adreno")' "$patch"
grep -Fq 'drm-engine-gpu' "$patch"
grep -Fq 'm_usageProperty->isSubscribed()' "$patch"
grep -Fq '/cur_freq' "$patch"
if grep -Fq '/sys/kernel/debug' "$patch"; then
    echo 'MSM telemetry must not depend on debugfs' >&2
    exit 1
fi

bash -n "$root/build-srpm.sh"
grep -Fq '.PHONY: srpm' "$root/Makefile"
grep -Fq '$(MAKE) -f Makefile srpm' "$root/../../../.copr/Makefile"
rpmspec -P "$root/ksystemstats.spec" >/dev/null
echo 'PASS: ksystemstats MSM/Adreno package invariants'
