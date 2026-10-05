#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/etc" "$work/state"

ssh-keygen -q -t ed25519 -N '' -f "$work/etc/ssh_host_ed25519_key"
expected=$(ssh-keygen -lf "$work/etc/ssh_host_ed25519_key.pub" | awk '{print $2}')
NABU_SSH_ETC_DIR="$work/etc" NABU_SSH_STATE_DIR="$work/state" \
    bash "$root/runtime/nabu-ssh-host-key-guard" save

ssh-keygen -q -t ed25519 -N '' -f "$work/etc/replacement"
mv -f "$work/etc/replacement" "$work/etc/ssh_host_ed25519_key"
mv -f "$work/etc/replacement.pub" "$work/etc/ssh_host_ed25519_key.pub"
NABU_SSH_ETC_DIR="$work/etc" NABU_SSH_STATE_DIR="$work/state" \
    bash "$root/runtime/nabu-ssh-host-key-guard" restore
actual=$(ssh-keygen -lf "$work/etc/ssh_host_ed25519_key.pub" | awk '{print $2}')

[[ $actual == "$expected" ]]
[[ $(stat -c %a "$work/state") == 700 ]]
[[ $(stat -c %a "$work/etc/ssh_host_ed25519_key") == 600 ]]
printf 'PASS: SSH host key survives replacement\n'
