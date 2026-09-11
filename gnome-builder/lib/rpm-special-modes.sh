#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

# fuse2fs' fakeroot view cannot retain setuid/setgid bits reliably. Capture the
# authoritative RPM metadata while the image is mounted, then restore it to the
# ext4 inode table after unmounting.

nabu_capture_rpm_special_modes() {
    local root=$1 output=$2 path mode owner group uid gid

    : >"$output"
    while IFS='|' read -r path mode owner group; do
        uid=$(awk -F: -v name="$owner" '$1 == name { print $3; exit }' "$root/etc/passwd")
        gid=$(awk -F: -v name="$group" '$1 == name { print $3; exit }' "$root/etc/group")
        [[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || {
            echo "Cannot resolve RPM owner for $path: $owner:$group" >&2
            return 65
        }
        printf '%s|%s|%s|%s\n' "$path" "${mode: -4}" "$uid" "$gid" >>"$output"
    done < <(
        rpm --root="$root" -qa --dump | awk '
            NF >= 11 {
                mode = $(NF - 6)
                special = substr(mode, length(mode) - 3, 1)
                if (special !~ /^[246]$/) next
                path = $1
                for (i = 2; i <= NF - 10; i++) path = path " " $i
                print path "|" mode "|" $(NF - 5) "|" $(NF - 4)
            }
        '
    )

    [[ -s $output ]] || {
        echo 'RPM metadata did not expose any setuid/setgid files' >&2
        return 65
    }
}

nabu_restore_rpm_special_modes() {
    local image=$1 metadata=$2 path mode uid gid

    while IFS='|' read -r path mode uid gid; do
        debugfs -w -R "set_inode_field $path uid $uid" "$image" >/dev/null 2>&1
        debugfs -w -R "set_inode_field $path gid $gid" "$image" >/dev/null 2>&1
        # Include the regular-file type bits. A typeless 04755 inode is
        # rejected and repaired destructively by e2fsck.
        debugfs -w -R "set_inode_field $path mode 010$mode" "$image" >/dev/null 2>&1
    done <"$metadata"
}

nabu_verify_rpm_special_modes() {
    local image=$1 metadata=$2 path mode uid gid inode

    while IFS='|' read -r path mode uid gid; do
        inode=$(debugfs -R "stat $path" "$image" 2>/dev/null)
        grep -Eq "Mode:[[:space:]]+0?$mode([[:space:]]|$)" <<<"$inode" || {
            echo "Special mode verification failed for $path (expected 0$mode)" >&2
            return 65
        }
        grep -Eq "User:[[:space:]]+$uid[[:space:]]+Group:[[:space:]]+$gid" <<<"$inode" || {
            echo "Special owner verification failed for $path (expected $uid:$gid)" >&2
            return 65
        }
    done <"$metadata"
}
