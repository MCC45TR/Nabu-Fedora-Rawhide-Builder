#!/usr/bin/bash
set -Eeuo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
rpm_file="$(find "$project_dir/out/rpm" -maxdepth 1 -type f -name 'nabu-runtime-integration-*.rpm' -print -quit)"
[[ -n ${rpm_file} ]]
[[ "$(rpm -qp --qf '%{NAME}' "$rpm_file")" == nabu-runtime-integration ]]
[[ "$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$rpm_file")" == 1.4.0.2-1.test.fc46 ]]
rpm -qp --requires "$rpm_file" | grep -Fx kernel-nabu-core-uname-r
rpm -qpl "$rpm_file" | grep -Fx /usr/libexec/senemos-nabu/nabu-slpi-suspend
rpm -qpl "$rpm_file" | grep -Fx /usr/lib/systemd/system/nabu-slpi-suspend.service
bash -n "$project_dir/../nabu-kde-integration/files/nabu-slpi-suspend"
grep -Fq hexagonrpcd-adsp-rootpd.service \
    "$project_dir/../nabu-kde-integration/files/nabu-slpi-suspend"
! grep -Fq ConditionPathExists \
    "$project_dir/../nabu-kde-integration/files/nabu-slpi-suspend.service"
