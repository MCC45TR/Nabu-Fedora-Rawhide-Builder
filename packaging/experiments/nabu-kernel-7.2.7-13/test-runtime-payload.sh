#!/usr/bin/bash
# Build-time/extracted-RPM check only. Never loads modules or alters the host.
set -Eeuo pipefail
payload=${1:?usage: test-runtime-payload.sh ROOT UNAME_R}
release=${2:?missing expected kernel release}
modules=$payload/usr/lib/modules/$release
test -s "$payload/boot/vmlinuz-$release"
# Avoid pipefail/SIGPIPE hiding a successful strings match on large Images.
banner=$(strings "$payload/boot/vmlinuz-$release" | sed -n '/^Linux version /p')
[[ $banner == "Linux version $release "* ]]
test -s "$modules/modules.dep.bin"
test -s "$modules/modules.alias.bin"
test -s "$modules/modules.builtin"
test -s "$modules/dtb/qcom/sm8150-xiaomi-nabu.dtb"
for module in \
    drivers/net/wireless/ath/ath10k/ath10k_snoc \
    drivers/net/wireless/ath/ath10k/ath10k_core \
    drivers/input/touchscreen/nt36523/nt36523_ts \
    drivers/gpu/drm/panel/panel-novatek-nt36523 \
    drivers/gpu/drm/udl/udl \
    drivers/gpu/drm/evdi/evdi \
    drivers/remoteproc/qcom_q6v5_pas; do
    test -s "$modules/kernel/$module.ko.zst"
done
count=0
while IFS= read -r -d '' module; do
    vermagic=$(modinfo -F vermagic "$module")
    [[ $vermagic == "$release "* ]]
    test -n "$(modinfo -F signer "$module")"
    count=$((count + 1))
done < <(find "$modules/kernel" -type f -name '*.ko.zst' -print0)
test "$count" -gt 0
# depmod -n is read-only. Treat unresolved symbols as failure even if depmod
# itself exits successfully; otherwise a complete-looking RPM may not load.
diagnostics=$(depmod -n -e -F "$payload/boot/System.map-$release" \
    -b "$payload" -m /usr/lib/modules "$release" 2>&1 >/dev/null)
if [[ -n $diagnostics ]]; then
    printf '%s\n' "$diagnostics" >&2
    exit 1
fi
printf 'PASS: %s signed modules match %s; required drivers, DTB and symbol resolution\n' "$count" "$release"
