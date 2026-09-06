# SENEMOS Nabu mainline unstable kernel

This package builds the official `linux-7.2.y` source in COPR and applies the
ordered Nabu patch series from `patches/`. The upstream archive and every patch
are checksum-locked. A stable point update is accepted only when the complete
series applies without conflict and the package gates pass.

Camera support is a Linux 7.2.2 port of ChengFangming/CFM880's original
[`nabu-camera`](https://github.com/CFM880/nabu-camera) work. Iris/Venus support
tracks ChengFangming/CFM880's [`nabu-iris`](https://github.com/CFM880/nabu-iris)
overlay. The corresponding experimental VA-API userspace driver is maintained
upstream in [`iris-vaapi`](https://github.com/CFM880/iris-vaapi). Patch commit
messages retain the exact source revisions and original author credit.

The package is intentionally separate from `senemos-nabu-kernel-mainline-alpha`:

- RPM: `senemos-nabu-kernel-mainline-unstable`
- ABI: `7.2.x-nabu-senemos-mainline-unstable`
- maintenance queue: `mainline-unstable`
- EFI/UKI family: `SENEMOS7U`

It does not obsolete or conflict with the 6.17 fallback, Android return entry,
or the existing 7.2 alpha family.

The daily updater checks the official Linux 7.2.y checksum list. It commits a
new point release only after all checksum-locked Nabu patches apply cleanly;
a conflict stops publication and leaves the preceding COPR build untouched.

The 7.2.2-test extension carries the reviewed RTC/diagnostic, bounded SPI and
NT36523 recovery, FastRPC ownership, wireless, keyboard, CS35L41 and charging
work. USB-C is forced back to a built-in dual-role stack with explicit PM8150B
VBUS ownership. The DSI REFGEN regulator and writable PM8150 RTC are kept in
the minimal profile. The connector thermistor ADC is explicitly enabled so the
fail-closed SMB5 policy can probe, and DRP prefers sink while remaining able to
source VBUS for OTG accessories. Direct LN8000 2:1 charging remains disabled in
the normal DTB. The package deliberately omits the generic `kernel-uname-r` capability so
DNF replaces this same-name kernel package instead of retaining it as an
install-only family; the separate 6.17 fallback remains independently owned.
The compact nftables set used by the validated 6.17 kernel is retained so
Fedora firewalld remains functional. Fedora's zram swap backend is retained,
while unused UFS RPMB support is disabled. The fixed 4 MiB ramoops area is
split evenly between the persistent console and ftrace instead of overcommitted.
The modern FastRPC lifetime and VMID hardening remains in place, while SM8150
SDSP allocations use Nabu's physically proven 34-bit, SID-specific IOVA windows.
CAMSS links and exposes each sensor as it binds, so one failed camera no longer
keeps another working camera out of the media graph.
When explicitly selected with `qcom_ice.use_wrapped_keys=1`, pre-HWKM Qualcomm
ICE can consume the ephemeral `wrappedkey_v0` keys produced by Android
Keymaster. Raw-key and wrapped-key profiles remain mutually exclusive, and
legacy mode rejects the modern generate/import/prepare operations it cannot
provide.
The A6xx context-switch path drains and invalidates the previous context's CCU
state before replacing TTBR0, preventing stale render-backend accesses from
being translated through the next process page table on Adreno 640.
The compact kernel profile also enables mainline MGLRU by default, retaining
Fedora-compatible PSI and zram while improving reclaim behavior on the 6 GiB
tablet without a userspace sysctl override.
Idle legacy VPU5 firmware is quiesced before s2idle and initialized lazily on
the next codec open, avoiding stale HFI state after resume while refusing to
silently invalidate an active encode or decode session.
Kernel linking uses an extra kallsyms pass so parallel COPR builds remain
deterministic across the supported Fedora AArch64 chroots.

## COPR build profile

COPR starts from the upstream ARM64 `defconfig` and merges the reviewed Nabu
fragment. It does not compile Fedora's general-purpose ARM64 module inventory.
The profile keeps the Nabu boot, UFS, display, touch, wireless, audio, camera and
Iris paths, while disabling legacy Venus because this device uses Iris. Runtime
debug information and BTF are omitted from this unstable test package, and the
resolved configuration is rejected if it enables 450 or more modules.

This profile is a build-time and package-size optimization. It does not replace
camera, media-graph, captured-frame or VA-API validation on physical hardware.
