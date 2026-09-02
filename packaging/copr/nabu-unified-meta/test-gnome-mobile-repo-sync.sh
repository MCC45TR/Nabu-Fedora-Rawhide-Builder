#!/usr/bin/bash
set -Eeuo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fakebin=$root/bin
state=$root/state
log=$root/calls.log
install -d "$fakebin" "$state"
touch "$state/pending"

cat >"$fakebin/dnf5" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG"
[[ $* == *'--from-repo=copr:copr.fedorainfracloud.org:group_mobility:gnome-mobile'* ]]
[[ $* == *'gnome-shell mutter gnome-settings-daemon'* ]]
EOF
cat >"$fakebin/rpm" <<'EOF'
#!/usr/bin/bash
case "${4:-}" in
    gnome-shell) echo '0:51~beta.mobile.0-1.mobile.fc46' ;;
    mutter) echo '0:51~beta.mobile.0-1.mobile.fc46' ;;
    gnome-settings-daemon) echo '0:51~beta.mobile.0-1.mobile.fc46' ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fakebin"/*

TEST_LOG=$log \
NABU_GNOME_MOBILE_PATH="$fakebin:/usr/bin:/usr/sbin" \
NABU_GNOME_MOBILE_REPO_FILE=$source_dir/gnome-mobile-copr.repo \
NABU_GNOME_MOBILE_STATE_DIR=$state \
NABU_GNOME_MOBILE_LOCK_FILE=$root/sync.lock \
NABU_GNOME_MOBILE_DNF=$fakebin/dnf5 \
NABU_GNOME_MOBILE_RPM=$fakebin/rpm \
bash "$source_dir/nabu-gnome-mobile-sync"

[[ ! -e $state/pending ]]
[[ $(wc -l <"$log") -eq 1 ]]
grep -Fq -- '--assumeyes --refresh distro-sync' "$log"
printf 'PASS: GNOME Mobile repo and deferred package synchronization\n'
