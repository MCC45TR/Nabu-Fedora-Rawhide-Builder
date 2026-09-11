#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

image=${1:?usage: relabel-ext4-selinux.sh IMAGE REPORT_DIR}
report_dir=${2:?usage: relabel-ext4-selinux.sh IMAGE REPORT_DIR}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
helper="$script_dir/ext4-selinux-labels.py"
mount_dir="$report_dir/selinux-mount"
work_dir="$report_dir/selinux-work"
dry_run="$report_dir/selinux-setfiles-dry-run.log"
manifest="$report_dir/selinux-inode-manifest.json"
policy="$mount_dir/etc/selinux/targeted/contexts/files/file_contexts"

for command in debugfs e2fsck fuse2fs fusermount3 mountpoint python3 setfiles; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'Required SELinux image command is missing: %s\n' "$command" >&2
        exit 1
    }
done
[[ -s $image ]] || { printf 'EXT4 image is missing: %s\n' "$image" >&2; exit 1; }
[[ -x $helper ]] || { printf 'SELinux inode helper is unavailable: %s\n' "$helper" >&2; exit 1; }
mkdir -p "$report_dir" "$mount_dir" "$work_dir"

cleanup_mount() {
    if mountpoint -q "$mount_dir" 2>/dev/null; then
        fusermount3 -u "$mount_dir" || fusermount3 -uz "$mount_dir" || true
    fi
}
trap cleanup_mount EXIT INT TERM

set +e
e2fsck -f -y "$image" >"$report_dir/selinux-pre-fsck.log" 2>&1
fsck_rc=$?
set -e
(( fsck_rc <= 1 )) || { printf 'Pre-label EXT4 fsck failed: %s\n' "$fsck_rc" >&2; exit 1; }

fuse2fs -o fakeroot,ro,norecovery "$image" "$mount_dir" \
    >"$report_dir/selinux-fuse-mount.log" 2>&1
mountpoint -q "$mount_dir" || { printf 'Could not mount EXT4 label inventory view.\n' >&2; exit 1; }
[[ -s $policy ]] || { printf 'Target SELinux file_contexts is absent from the image.\n' >&2; exit 1; }

setfiles -n -F -v -r "$mount_dir" "$policy" "$mount_dir" >"$dry_run" 2>&1
if ! "$helper" prepare --root "$mount_dir" --policy "$policy" --dry-run "$dry_run" \
    --manifest "$manifest" --report "$report_dir/selinux-inventory-report.json" \
    2>"$report_dir/selinux-policy-lookup-warnings.log"; then
    cat "$report_dir/selinux-policy-lookup-warnings.log" >&2
    exit 1
fi
cleanup_mount
trap - EXIT INT TERM
mountpoint -q "$mount_dir" 2>/dev/null && {
    printf 'EXT4 label inventory mount could not be released.\n' >&2
    exit 1
}

set +e
e2fsck -f -y "$image" >"$report_dir/selinux-post-fuse-fsck.log" 2>&1
fsck_rc=$?
set -e
(( fsck_rc <= 1 )) || { printf 'Post-FUSE EXT4 fsck failed: %s\n' "$fsck_rc" >&2; exit 1; }

"$helper" apply --image "$image" --manifest "$manifest" --work-dir "$work_dir" \
    --output "$report_dir/selinux-debugfs-apply.log"

set +e
e2fsck -f -y "$image" >"$report_dir/selinux-post-apply-fsck.log" 2>&1
fsck_rc=$?
set -e
(( fsck_rc <= 1 )) || { printf 'Post-label EXT4 fsck failed: %s\n' "$fsck_rc" >&2; exit 1; }
e2fsck -f -n "$image" >"$report_dir/selinux-final-fsck.log" 2>&1

"$helper" verify --image "$image" --manifest "$manifest" --work-dir "$work_dir" \
    --output "$report_dir/selinux-debugfs-verify.log" \
    --report "$report_dir/selinux-verification-report.json"

printf 'SELinux ext4 inode relabel and full verification passed: %s\n' "$image"
