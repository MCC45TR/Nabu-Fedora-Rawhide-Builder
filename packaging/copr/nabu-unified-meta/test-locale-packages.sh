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
    printf 'install:%s\n' "$last" >>"$MOCK_LOG"
    exit 0
fi
if [[ " $* " == *' reinstall '* ]]; then
    shift 2
    printf 'reinstall:%s\n' "$*" >>"$MOCK_LOG"
    exit 0
fi
exit 1
EOF
chmod 0755 "$work/bin/dnf5"
cat >"$work/bin/rpm" <<'EOF'
#!/usr/bin/bash
if [[ " $* " == *' -qa '* ]]; then
    printf 'PKG:kde-example\n/usr/share/locale/zz/LC_MESSAGES/kde-example.mo\n'
    printf 'PKG:unrelated\n/usr/share/locale/yy/LC_MESSAGES/unrelated.mo\n'
    exit 0
fi
exit 1
EOF
chmod 0755 "$work/bin/rpm"
printf 'LANG=zz_ZZ.UTF-8\n' >"$work/locale.conf"

run_helper() {
    MOCK_AVAILABLE=$1 MOCK_LOG="$work/install.log" \
    NABU_LOCALE_FILE="$work/locale.conf" \
    NABU_SETUP_MARKER="$work/setup-done" \
    NABU_LOCALE_STATE_DIR="$work/state" \
    NABU_LOCALE_LOCK="$work/locale.lock" \
    NABU_DNF5="$work/bin/dnf5" \
    NABU_RPM="$work/bin/rpm" \
    NABU_ROOT_PREFIX="$work/root" \
        /usr/bin/bash "$helper"
}

mkdir -p "$work/root/usr/share/locale/zz/LC_MESSAGES"
run_helper langpacks-zz_ZZ
[ ! -e "$work/install.log" ]

touch "$work/setup-done"
run_helper langpacks-zz_ZZ
grep -Fxq 'install:langpacks-zz_ZZ' "$work/install.log"
grep -Fxq 'reinstall:kde-example' "$work/install.log"
grep -Fxq 'v2:zz_ZZ' "$work/state/locale-packages.stamp"

before=$(wc -l <"$work/install.log")
run_helper langpacks-zz_ZZ
[ "$(wc -l <"$work/install.log")" -eq "$before" ]

printf 'LANG=yy_AA.UTF-8\n' >"$work/locale.conf"
run_helper langpacks-yy
grep -Fxq 'install:langpacks-yy' "$work/install.log"
grep -Fxq 'v2:yy_AA' "$work/state/locale-packages.stamp"

printf 'PASS: locale-selected Fedora language packages\n'
