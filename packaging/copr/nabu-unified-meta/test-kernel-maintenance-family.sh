#!/usr/bin/bash
set -Eeuo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
boot=$root/boot
esp=$root/esp
modules=$root/modules
state=$root/state
fakebin=$root/bin
log=$root/calls.log
install -d "$boot" "$esp/EFI/fedora" "$esp/loader/entries" "$modules" "$fakebin" "$root/etc/nabu"
printf 'preferred=mainline\n' >"$root/etc/nabu/kernel.conf"

declare -A kernel=(
    [senemos-nabu-kernel]=6.17.0-nabu-senemos-kernel
    [senemos-nabu-kernel-mainline]=7.2.3-nabu-senemos-mainline
    [senemos-nabu-kernel-mainline-unstable]=7.3.0-nabu-senemos-mainline-unstable
)
for name in "${!kernel[@]}"; do
    kver=${kernel[$name]}
    printf '%s\n' "$name" >"$boot/vmlinuz-$kver"
    install -d "$modules/$kver"
done

cat >"$fakebin/rpm" <<'EOF'
#!/usr/bin/bash
set -eu
case "$*" in
    '-q senemos-nabu-kernel'|'-q senemos-nabu-kernel-mainline'|'-q senemos-nabu-kernel-mainline-unstable') exit 0 ;;
esac
if [[ $1 == -q && $2 == --qf && $3 == '%{NEVRA}\n' ]]; then
    printf '%s-1.0-1.fc46.aarch64\n' "$4"
elif [[ $1 == -q && $2 == --qf && $3 == '%{RELEASE}\n' ]]; then
    printf '1.fc46\n'
elif [[ $1 == -ql ]]; then
    package=${2%-1.0-1.fc46.aarch64}
    case "$package" in
        senemos-nabu-kernel) kver=6.17.0-nabu-senemos-kernel ;;
        senemos-nabu-kernel-mainline) kver=7.2.3-nabu-senemos-mainline ;;
        senemos-nabu-kernel-mainline-unstable) kver=7.3.0-nabu-senemos-mainline-unstable ;;
    esac
    printf '%s/vmlinuz-%s\n' "$TEST_BOOT" "$kver"
elif [[ $1 == -qf ]]; then
    case "$4" in
        *6.17.0*) echo senemos-nabu-kernel ;;
        *7.2.3*) echo senemos-nabu-kernel-mainline ;;
        *7.3.0*) echo senemos-nabu-kernel-mainline-unstable ;;
    esac
else
    exit 2
fi
EOF
cat >"$fakebin/kernel-build-identity" <<'EOF'
#!/usr/bin/bash
[[ $1 == --field=stamp && $# -eq 2 ]]
case $2 in
    6.17.0-*) printf '2609061218\n' ;;
    7.2.3-*) printf '7.2.3\n' ;;
    7.3.0-*) printf '2609061220\n' ;;
    *) exit 1 ;;
esac
EOF
cat >"$fakebin/regenerate" <<'EOF'
#!/usr/bin/bash
[[ $1 == --family && $# -eq 3 ]]
family=$2
case $family in
    SENEMOS6) stamp=2609061218 ;;
    SENEMOS7) stamp=7.2.3 ;;
    SENEMOS7U) stamp=2609061220 ;;
    *) exit 2 ;;
esac
printf 'regenerate %s %s\n' "$family" "$3" >>"$TEST_LOG"
printf '%s\n' "$3" >"$TEST_ESP/EFI/fedora/$family-$stamp.efi"
EOF
cat >"$fakebin/configure" <<'EOF'
#!/usr/bin/bash
[[ -s $TEST_ESP/EFI/fedora/SENEMOS6-2609061218.efi ]]
[[ -s $TEST_ESP/EFI/fedora/SENEMOS7-7.2.3.efi ]]
[[ -s $TEST_ESP/EFI/fedora/SENEMOS7U-2609061220.efi ]]
printf 'configure %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$fakebin"/*

run_maintenance() {
    TEST_BOOT=$boot TEST_ESP=$esp TEST_LOG=$log \
    NABU_MAINT_PATH="$fakebin:/usr/bin:/usr/sbin" \
    NABU_MAINT_STATE_DIR=$state \
    NABU_MAINT_BOOT_DIR=$boot \
    NABU_MAINT_ESP=$esp \
    NABU_MAINT_MODULES_DIR=$modules \
    NABU_MAINT_IDENTITY_TOOL=$fakebin/kernel-build-identity \
    NABU_MAINT_REGENERATE_COMMAND=$fakebin/regenerate \
    NABU_MAINT_CONFIGURE_COMMAND=$fakebin/configure \
    NABU_MAINT_COMPATIBLE_PATH=$root/no-compatible \
    NABU_MAINT_LOCK_FILE=$root/maintenance.lock \
    NABU_MAINT_CONFIG=$root/etc/nabu/kernel.conf \
    bash "$source_dir/nabu-kernel-maintenance"
}

run_maintenance
[[ $(grep -c '^regenerate ' "$log") -eq 3 ]]
grep -Fxq 'regenerate SENEMOS6 6.17.0-nabu-senemos-kernel' "$log"
grep -Fxq 'regenerate SENEMOS7 7.2.3-nabu-senemos-mainline' "$log"
grep -Fxq 'regenerate SENEMOS7U 7.3.0-nabu-senemos-mainline-unstable' "$log"
tail -n1 "$log" | grep -Fxq 'configure --sync-only --uki SENEMOS7-7.2.3.efi'

run_maintenance
[[ $(grep -c '^regenerate ' "$log") -eq 3 ]]
[[ $(grep -c '^configure ' "$log") -eq 2 ]]
printf 'PASS: three-family EFI maintenance and idempotence\n'
