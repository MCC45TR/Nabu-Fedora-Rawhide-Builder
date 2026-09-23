#!/usr/bin/bash
# Run inside a disposable AArch64 userspace build container, on the host.
# Produces only a QEMU test ramdisk. It is not referenced by the RPM spec.
set -Eeuo pipefail
source_file=${1:?usage: build-el2-qemu-initramfs.sh CPP_SOURCE OUTPUT_DIRECTORY}
output=${2:?missing output directory}
mkdir -p "$output/stage"/{lib,lib64,dev,proc,sys}
g++ -std=c++20 -Wall -Wextra -Werror -O2 "$source_file" -o "$output/stage/init"
interpreter=$(readelf -l "$output/stage/init" | sed -n 's/.*Requesting program interpreter: \([^]]*\)].*/\1/p')
test "$interpreter" = /lib/ld-linux-aarch64.so.1
install -m0755 "$interpreter" "$output/stage/$interpreter"
while IFS= read -r library; do
    test -f "$library"
    install -m0755 "$library" "$output/stage/$library"
done < <(ldd "$output/stage/init" | awk '/=> \/lib/ { print $3 }')
file "$output/stage/init" | grep -Fq 'ARM aarch64'
(
    cd "$output/stage"
    find . -print0 | cpio --null -o -H newc 2>"$output/cpio.log" | gzip -n >"$output/initramfs.cpio.gz"
)
gzip -t "$output/initramfs.cpio.gz"
printf 'PASS: disposable AArch64 C++ guest initramfs %s\n' "$output/initramfs.cpio.gz"
