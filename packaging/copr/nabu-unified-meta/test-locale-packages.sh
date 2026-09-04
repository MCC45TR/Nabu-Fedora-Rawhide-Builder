#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper="$root/nabu-locale-packages"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

mkdir -p "$work/bin" "$work/state"
cat >"$work/bin/dnf5" <<'EOF'
#!/usr/bin/bash
set -u
last=${!#}
if [[ " $* " == *' repoquery '* ]]; then
    [ "$last" = "${MOCK_AVAILABLE:-}" ] && printf '%s\n' "$last"
    exit 0
fi
if [[ " $* " == *' install '* ]]; then
    printf '%s\n' "$last" >>"$MOCK_LOG"
    exit 0
fi
exit 1
EOF
chmod 0755 "$work/bin/dnf5"
printf 'LANG=zz_ZZ.UTF-8\n' >"$work/locale.conf"

run_helper() {
    MOCK_AVAILABLE=$1 MOCK_LOG="$work/install.log" \
    NABU_LOCALE_FILE="$work/locale.conf" \
    NABU_SETUP_MARKER="$work/setup-done" \
    NABU_LOCALE_STATE_DIR="$work/state" \
    NABU_LOCALE_LOCK="$work/locale.lock" \
    NABU_DNF5="$work/bin/dnf5" \
        /usr/bin/bash "$helper"
}

run_helper langpacks-zz_ZZ
[ ! -e "$work/install.log" ]

touch "$work/setup-done"
run_helper langpacks-zz_ZZ
grep -Fxq 'langpacks-zz_ZZ' "$work/install.log"
grep -Fxq 'zz_ZZ' "$work/state/locale-packages.stamp"

before=$(wc -l <"$work/install.log")
run_helper langpacks-zz_ZZ
[ "$(wc -l <"$work/install.log")" -eq "$before" ]

printf 'LANG=yy_AA.UTF-8\n' >"$work/locale.conf"
run_helper langpacks-yy
grep -Fxq 'langpacks-yy' "$work/install.log"
grep -Fxq 'yy_AA' "$work/state/locale-packages.stamp"

printf 'PASS: locale-selected Fedora language packages\n'
