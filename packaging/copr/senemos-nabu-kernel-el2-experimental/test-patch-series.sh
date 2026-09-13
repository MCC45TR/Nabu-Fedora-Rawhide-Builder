#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
base=$root/../senemos-nabu-kernel-mainline
spec=$root/senemos-nabu-kernel-el2-experimental.spec

grep -Fxq 'Name:           senemos-nabu-kernel-el2-experimental' "$spec"
grep -Fxq '%global uname_r %{version}-nabu-senemos-el2-experimental' "$spec"
grep -Fxq 'Requires:       senemos-nabu-kernel-mainline >= 7.2.4-12' "$spec"
grep -Fxq 'Provides:       kernel-nabu-el2-experimental-uname-r' "$spec"
! grep -Eq '^Provides:[[:space:]]+(kernel-uname-r|kernel-nabu-core-uname-r)' "$spec"
! grep -Eq '^%(post|posttrans|preun)$' "$spec"
grep -Fq 'CONFIG_VIRTUALIZATION=y' "$root/nabu-el2-experimental.config"
grep -Fq 'CONFIG_KVM=y' "$root/nabu-el2-experimental.config"

bash -n "$root/build-srpm.sh" "$root/nabu-el2-status"

toolroot=${NABU_LLVM_TOOLROOT:-/home/mcc45tr/Projeler/.local-llvm22/usr}
clang=${NABU_CLANG:-$toolroot/bin/clang}
lld_link=${NABU_LLD_LINK:-$toolroot/bin/lld-link}
llvm_readobj=${NABU_LLVM_READOBJ:-$toolroot/bin/llvm-readobj}
[[ -x $clang && -x $lld_link && -x $llvm_readobj ]]
work=$(mktemp -d)
cleanup() { find "$work" -depth -delete 2>/dev/null || :; }
trap cleanup EXIT
export LD_LIBRARY_PATH="$toolroot/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$clang" --target=aarch64-unknown-windows -ffreestanding -fshort-wchar \
    -fno-stack-protector -fno-builtin -Wall -Wextra -Werror -Os \
    -c "$root/nabu-currentel.c" -o "$work/nabu-currentel.obj"
"$lld_link" /subsystem:efi_application /entry:efi_main /machine:arm64 \
    /nodefaultlib /opt:ref /opt:icf /timestamp:0 \
    /out:"$work/CurrentEL.efi" \
    "$work/nabu-currentel.obj"
"$llvm_readobj" --file-headers "$work/CurrentEL.efi" \
    | grep -Fq 'Format: COFF-ARM64'
"$llvm_readobj" --file-headers "$work/CurrentEL.efi" \
    | grep -Fq 'TimeDateStamp: 1970-01-01 00:00:00 (0x0)'
! grep -Eq 'SetVariable|Write|Delete|LoadImage|StartImage|EFI_FILE_MODE_WRITE' \
    "$root/nabu-currentel.c"

printf '# CONFIG_KVM is not set\n' >"$work/config-disabled"
: >"$work/log-empty"
NABU_EL2_UNAME=test NABU_EL2_CONFIG="$work/config-disabled" \
    NABU_EL2_DEV_KVM="$work/missing-kvm" NABU_EL2_KERNEL_LOG="$work/log-empty" \
    "$root/nabu-el2-status" | grep -Fxq 'verdict=kernel-kvm-disabled'

printf 'CONFIG_KVM=y\n' >"$work/config-enabled"
printf 'kvm [1]: HYP mode not available\n' >"$work/log-el1"
NABU_EL2_UNAME=test NABU_EL2_CONFIG="$work/config-enabled" \
    NABU_EL2_DEV_KVM="$work/missing-kvm" NABU_EL2_KERNEL_LOG="$work/log-el1" \
    "$root/nabu-el2-status" | grep -Fxq 'verdict=firmware-el2-blocked'

NABU_EXTRA_CONFIG="$root/nabu-el2-experimental.config" \
NABU_EXPECTED_KERNEL_RELEASE=7.2.4-nabu-senemos-el2-experimental \
NABU_EXPECT_KVM=1 \
    "$base/test-patch-series.sh"

printf 'PASS: isolated Nabu EL2/KVM source, config and UEFI gates\n'
