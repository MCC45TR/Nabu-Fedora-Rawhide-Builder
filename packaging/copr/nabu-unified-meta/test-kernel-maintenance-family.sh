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
printf 'preferred=mainline-unstable\n' >"$root/etc/nabu/kernel.conf"

declare -A kernel=(
    [senemos-nabu-kernel]=6.16.0-nabu-senemos-stable-2608311409
    [senemos-nabu-kernel-alpha]=6.17.0-senemos-2608301000
    [senemos-nabu-kernel-mainline-alpha]=7.2.0-nabu-senemos-mainline-alpha
    [senemos-nabu-kernel-mainline-unstable]=7.2.2-nabu-senemos-mainline-unstable
    [senemos-nabu-kernel-lts]=6.18.48-nabu-senemos-lts
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
    '-q senemos-nabu-kernel'|'-q senemos-nabu-kernel-alpha'|'-q senemos-nabu-kernel-mainline-alpha'|'-q senemos-nabu-kernel-mainline-unstable'|'-q senemos-nabu-kernel-lts') exit 0 ;;
esac
if [[ $1 == -q && $2 == --qf && $3 == '%{NEVRA}\n' ]]; then
    printf '%s-1.0-2608301100.alpha.fc46.aarch64\n' "$4"
elif [[ $1 == -q && $2 == --qf && $3 == '%{RELEASE}\n' ]]; then
    printf '2608301100.alpha.fc46\n'
elif [[ $1 == -ql ]]; then
    package=${2%-1.0-2608301100.alpha.fc46.aarch64}
    case "$package" in
        senemos-nabu-kernel) kver=6.16.0-nabu-senemos-stable-2608311409 ;;
        senemos-nabu-kernel-alpha) kver=6.17.0-senemos-2608301000 ;;
        senemos-nabu-kernel-mainline-alpha) kver=7.2.0-nabu-senemos-mainline-alpha ;;
        senemos-nabu-kernel-mainline-unstable) kver=7.2.2-nabu-senemos-mainline-unstable ;;
        senemos-nabu-kernel-lts) kver=6.18.48-nabu-senemos-lts ;;
    esac
    printf '%s/vmlinuz-%s\n' "$TEST_BOOT" "$kver"
elif [[ $1 == -qf ]]; then
    case "$4" in
        *6.16.0*) echo senemos-nabu-kernel ;;
        *6.17.0*) echo senemos-nabu-kernel-alpha ;;
        *7.2.0*) echo senemos-nabu-kernel-mainline-alpha ;;
        *7.2.2*) echo senemos-nabu-kernel-mainline-unstable ;;
        *6.18.48*) echo senemos-nabu-kernel-lts ;;
    esac
else
    exit 2
fi
EOF
cat >"$fakebin/kernel-build-identity" <<'EOF'
#!/usr/bin/bash
[[ $1 == --field=stamp && $# -eq 2 ]]
if [[ $2 == 7.2.2-nabu-senemos-mainline-unstable ]]; then
    printf '2608301200\n'
    exit 0
fi
if [[ $2 == 6.18.48-nabu-senemos-lts ]]; then
    printf '2608300900\n'
    exit 0
fi
stamp=${2##*-}
[[ $stamp =~ ^[0-9]{10}$ ]]
printf '%s\n' "$stamp"
EOF
cat >"$fakebin/regenerate" <<'EOF'
#!/usr/bin/bash
[[ $1 == --family && $# -eq 3 ]]
family=$2
stamp=${3##*-}
[[ $3 != 7.2.0-nabu-senemos-mainline-alpha ]] || stamp=2608301100
[[ $3 != 7.2.2-nabu-senemos-mainline-unstable ]] || stamp=2608301200
[[ $3 != 6.18.48-nabu-senemos-lts ]] || stamp=2608300900
printf 'regenerate %s %s\n' "$family" "$3" >>"$TEST_LOG"
printf '%s\n' "$3" >"$TEST_ESP/EFI/fedora/$family-$stamp.efi"
EOF
cat >"$fakebin/configure" <<'EOF'
#!/usr/bin/bash
[[ -s $TEST_ESP/EFI/fedora/SENEMOS6-2608301000.efi ]]
[[ -s $TEST_ESP/EFI/fedora/SENEMOS7U-2608301200.efi ]]
[[ ! -e $TEST_ESP/EFI/fedora/SENEMOS616-2608311409.efi ]]
[[ ! -e $TEST_ESP/EFI/fedora/SENEMOS7-2608301100.efi ]]
[[ ! -e $TEST_ESP/EFI/fedora/SENEMOS6LTS-2608300900.efi ]]
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
[[ $(grep -c '^regenerate ' "$log") -eq 2 ]]
grep -Fxq 'regenerate SENEMOS6 6.17.0-senemos-2608301000' "$log"
grep -Fxq 'regenerate SENEMOS7U 7.2.2-nabu-senemos-mainline-unstable' "$log"
! grep -Eq 'SENEMOS616|SENEMOS7 |SENEMOS6LTS' "$log"
tail -n1 "$log" | grep -Fxq 'configure --sync-only --uki SENEMOS7U-2608301200.efi'

run_maintenance
[[ $(grep -c '^regenerate ' "$log") -eq 2 ]]
[[ $(grep -c '^configure ' "$log") -eq 2 ]]
printf 'PASS: two-family EFI maintenance and idempotence\n'
