#!/usr/bin/bash
# Build-host software regression only, never a Nabu EL2/DMA qualification.
set -Eeuo pipefail
kernel=${1:?usage: test-el2-qemu.sh KERNEL_IMAGE INITRAMFS OUTPUT_DIRECTORY}
initrd=${2:?missing test-only initramfs}
output=${3:?missing output directory}
mkdir -p "$output"
for mode in el1 nvhe vhe; do
    case $mode in
        el1) cpu=cortex-a57; virtualization=off; expected=el1 ;;
        nvhe) cpu=cortex-a57; virtualization=on; expected=el2 ;;
        vhe) cpu=cortex-a76; virtualization=on; expected=el2 ;;
    esac
    logfile="$output/$mode.log"
    if ! timeout --signal=TERM --kill-after=10s 180s qemu-system-aarch64 \
        -machine "virt,virtualization=$virtualization,gic-version=3" \
        -accel tcg,thread=multi -cpu "$cpu" -smp 8 -m 1024 \
        -nodefaults -display none -serial stdio -monitor none -nic none \
        -no-reboot -kernel "$kernel" -initrd "$initrd" \
        -append "console=ttyAMA0 rdinit=/init panic=-1 nabu_test.expect=$expected" \
        >"$logfile" 2>&1; then
        tail -n 80 "$logfile"
        echo "QEMU $mode did not shut down cleanly" >&2
        exit 1
    fi
    grep -E 'All CPU\(s\) started|VHE mode initialized|NABU_EL2_|Kernel panic|BUG:|WARNING:|Oops:' "$logfile" || :
    grep -Fq 'NABU_EL2_TEST_PASS:' "$logfile"
    if grep -Eq 'NABU_EL2_TEST_FAIL:|Kernel panic|BUG:|WARNING:|Oops:' "$logfile"; then
        echo "Unexpected failure in $mode" >&2
        exit 1
    fi
    grep -Fq "All CPU(s) started at EL${expected#el}" "$logfile"
    if [[ $expected == el2 ]]; then
        for index in {0..7}; do
            grep -Fq "NABU_EL2_GUEST: host-cpu=$index guest-wrote=0x4b56" "$logfile"
        done
        if [[ $mode == nvhe ]]; then
            grep -Fq 'Hyp nVHE mode initialized successfully' "$logfile"
        else
            grep -Fq 'VHE mode initialized successfully' "$logfile"
        fi
    fi
    printf 'PASS: %s software-only KVM gate\n' "$mode"
done
