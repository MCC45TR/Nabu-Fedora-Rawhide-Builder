#!/usr/bin/bash
set -Eeuo pipefail

source_root=$PWD
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
test_root="$work/root"
fake_bin="$work/bin"
mkdir -p "$test_root/etc/selinux/targeted/contexts/files" \
    "$test_root/boot" "$test_root/var/lib/senemos-nabu" "$fake_bin"
printf 'test policy\n' >"$test_root/etc/selinux/targeted/contexts/files/file_contexts"
printf 'CONFIG_SECURITY_SELINUX=y\n' >"$test_root/boot/config-7.2.0-nabu-test"
touch "$test_root/.autorelabel"

cat >"$fake_bin/setfiles" <<'EOF'
#!/usr/bin/bash
printf '%q ' "$@" >>"$NABU_SETFILES_LOG"
printf '\n' >>"$NABU_SETFILES_LOG"
exit 0
EOF
chmod 0755 "$fake_bin/setfiles"

NABU_SETFILES_LOG="$work/setfiles.log" \
NABU_SELINUX_ROOT="$test_root" \
PATH="$fake_bin:/usr/bin:/bin" \
    bash runtime/nabu-prepare-selinux-labels

test ! -e "$test_root/.autorelabel"
test -s "$test_root/var/lib/senemos-nabu/selinux-label-ready"
grep -Fq -- '-F' "$work/setfiles.log"
grep -Fq -- '-n -v' "$work/setfiles.log"
grep -Fq -- "-r $test_root" "$work/setfiles.log"

first_run_calls=$(wc -l <"$work/setfiles.log")
NABU_SETFILES_LOG="$work/setfiles.log" \
NABU_SELINUX_ROOT="$test_root" \
PATH="$fake_bin:/usr/bin:/bin" \
    bash runtime/nabu-prepare-selinux-labels
test "$(wc -l <"$work/setfiles.log")" -eq "$first_run_calls"
