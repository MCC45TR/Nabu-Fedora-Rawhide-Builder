#!/usr/bin/bash
set -Eeuo pipefail

source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/source/usr/bin" "$test_root/unpack"
printf '#!/usr/bin/bash\nexit 0\n' >"$test_root/source/usr/bin/mount"
cp "$test_root/source/usr/bin/mount" "$test_root/source/usr/bin/umount"
chmod 4755 "$test_root/source/usr/bin/mount" "$test_root/source/usr/bin/umount"
(
    cd "$test_root/source"
    find . -print0 | cpio --null --quiet -o -H newc --owner=65534:65534 | \
        zstd -q -o "$test_root/broken.img"
)
bash "$source_root/payload/usr/libexec/senemos-nabu/sanitize-initramfs" \
    "$test_root/broken.img" "$test_root/unpack" "$test_root/listing.txt"
grep -Eq '^-rwxr-xr-x[[:space:]]+1[[:space:]]+root[[:space:]]+root.*usr/bin/mount$' \
    "$test_root/listing.txt"
grep -Eq '^-rwxr-xr-x[[:space:]]+1[[:space:]]+root[[:space:]]+root.*usr/bin/umount$' \
    "$test_root/listing.txt"
! awk 'length($1) == 10 && $1 ~ /^[-dlcbps]/ &&
       (substr($1,4,1) ~ /[sS]/ || substr($1,7,1) ~ /[sS]/) { bad=1 }
       END { exit !bad }' "$test_root/listing.txt"
