#!/usr/bin/bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Exercise the packaged function without loading modules, mounting an ESP,
# executing UKI generation, or adding test overrides to production code.
eval "$(sed -n '/^validate_mainline_modules() {/,/^}/p' "$root/payload/usr/bin/nabu-regenerate-uki")"
declare -F validate_mainline_modules >/dev/null
mode=good
modinfo() {
    [[ $1 == -k && $3 == -F && $4 == vermagic ]]
    case $mode in
        good) printf '%s SMP preempt mod_unload aarch64\n' "$2" ;;
        missing) [[ $5 != nt36523_ts ]] || return 1; printf '%s SMP\n' "$2" ;;
        wrong) printf '7.2.6-nabu-senemos-mainline SMP\n' ;;
        prefix) printf '%s-extra SMP\n' "$2" ;;
        empty) printf '\n' ;;
    esac
}
validate_mainline_modules 7.2.7-nabu-senemos-mainline
for mode in missing wrong prefix empty; do
    if validate_mainline_modules 7.2.7-nabu-senemos-mainline; then
        printf 'FAIL: accepted %s module data\n' "$mode" >&2
        exit 1
    fi
done
validate_mainline_modules 6.17-nabu-senemos
validate_mainline_modules 7.3.0-nabu-senemos-mainline-unstable
printf 'PASS: mainline UKI rejects missing/mismatched modules; other families unchanged\n'
