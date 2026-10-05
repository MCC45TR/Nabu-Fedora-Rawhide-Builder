# SENEMOS Nabu EL2/KVM experiment

**Archived candidate, 2026-09-13.** Consolidation into `main` preserves this
experiment without promoting it to a current production kernel. Its Linux
7.2.4 base is pinned to commit
`303f636c40f769b59cc156bbfd94bf9c04350d27`, where the matching mainline source,
patch manifests and optional KVM test gate remain available in Git history.
The build and test scripts reject the newer adjacent production sources before
downloading or assembling an SRPM. To reproduce the archived candidate, export
`packaging/copr/senemos-nabu-kernel-mainline` from that commit to a separate
directory and pass its path through `NABU_EL2_BASE_SOURCE_DIR`.

This package is deliberately separate from the production Linux 7.2.4 Nabu
kernel. Its RPM name, kernel ABI and files do not overlap, and it requires the
production package to remain installed as a known-good fallback.

The experiment adds only the kernel-side prerequisites `CONFIG_VIRTUALIZATION`
and `CONFIG_KVM`; it retains the production security/device configuration and
keeps EL2 debug interfaces disabled. No install script writes the EFI System
Partition, changes the boot default, or queues automatic UKI generation.

`CurrentEL.efi` is built from `nabu-currentel.c`. It reads the AArch64
`CurrentEL` register, displays the value, waits for a key and returns. It does
not access EFI variables or storage. The RPM installs it under
`/usr/lib/senemos-nabu/el2/` for an explicitly reviewed, later staging step.

After an explicitly selected experimental boot, `nabu-el2-status` separates
three gates: kernel configuration, firmware EL2 handoff evidence and the
presence of `/dev/kvm`. A configured kernel without `/dev/kvm` is not success.

The remaining firmware gate cannot be solved by this package. If the UEFI probe
reports EL1, the trusted firmware/HYP chain retained EL2 and an ESP application
cannot promote Linux. Do not write `hyp_a`, `hyp_b`, boot, XBL, ABL or other
firmware partitions to work around that result.
