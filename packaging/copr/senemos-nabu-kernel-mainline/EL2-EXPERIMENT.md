# Nabu EL2/KVM — kernel and DT first

The `nabu_el2` RPM build condition shares the current mainline sources, all
device patches, EVDI sources, module signing and regression tests. It replaces
the old independently maintained 7.2.4 experimental spec; no patches are copied
to a second series that could silently miss a display or touch fix.

Build on the development machine:

```sh
NABU_EL2_EXPERIMENTAL=1 bash build-srpm.sh /absolute/scratch/rpmbuild
```

This persists `%bcond nabu_el2 1` in the generated SRPM so an unconfigured COPR
worker also builds the experimental variant. The source/default spec remains
production/KVM-disabled. Current experiment: `senemos-nabu-kernel-el2-experimental`
7.2.7-1; ABI `7.2.7-nabu-senemos-el2-experimental`. No package scripts, automatic
UKI generation, boot menu edits, daemon, firmware writes or runtime Python.
The normal mainline kernel remains a dependency; no `Obsoletes` or normal
kernel-provider capability is exported by the experiment.
COPR candidate [11026757](https://copr.fedorainfracloud.org/coprs/build/11026757)
completed successfully in the isolated
`mcc45tr/nabu-linux:custom:el2727r1` project. Install resolution also needs a
source for the verified normal 7.2.7 kernel; this candidate is not promoted.

## Work kept in the kernel/DT layer

- Upstream ARM64 KVM builds both VHE and nVHE paths and chooses the applicable
  mode based on actual firmware entry and CPU capabilities. No forced protected
  mode, nested mode or EL2 debug/panic bypass is enabled.
- Eight CPUs retain PSCI and `method = "smc"`; the GICv3 virtual-maintenance
  PPI and all four architected timer PPIs are already correctly described.
- HYP remains `0x85700000 + 0x00600000`, and the Nabu TZ/removed region remains
  `0x86200000 + 0x05500000`, both `no-map`. The latter is the board/OEM value,
  not the smaller generic SM8150 value. These regions are NOT free KVM RAM.
- Existing SMMU default-bypass prevention and kernel hardening stay enabled.
  No guessed `iommus` stream IDs or permissive DMA workaround is installed.
- `test-el2-dtb.py` checks the **compiled** DTB and exercises 16 malformed or
  incorrect cases, not just strings in source DTS. `test-el2-compile.sh` checks
  real AArch64 KVM objects. `test-el2-packaging.py` checks both RPM branches.
  `test-el2-guest.cpp` and `test-el2-qemu.sh` are development-machine tests:
  disposable QEMU `virt` boots at EL1, nVHE EL2 and VHE EL2, then executes an
  actual KVM guest on eight emulated host CPUs. The guest init refuses to run
  unless it detects QEMU's `linux,dummy-virt` Device Tree compatible string.

The published AArch64 RPM passed OpenPGP and 540 module signature checks.
The QEMU tests used the **Image extracted from that signed RPM**: EL1 rejected
KVM, while both nVHE and VHE produced the expected guest MMIO exit on all eight
CPUs. Build the disposable initramfs in an AArch64 build environment with
`g++`, `file`, `cpio`, and `gzip` using
`build-el2-qemu-initramfs.sh test-el2-guest.cpp OUTPUT_DIRECTORY`; run
`test-el2-qemu.sh EXTRACTED_IMAGE OUTPUT_DIRECTORY/initramfs.cpio.gz LOG_DIRECTORY`
on a machine with `qemu-system-aarch64`. This tests upstream ARM64 KVM behavior
under emulation, not Nabu's firmware transition or peripheral ownership.

No DTS hardware values needed changing based on the evidence obtained so far.
DT validation is a prerequisite check, **not proof that the firmware exposes
EL2 or that peripheral DMA works after leaving Qualcomm's hypervisor**.

## Firmware boundary and remaining peripherals

Linux 7.2.7 already rejects unavailable HYP access before KVM initialization and
logs whether all CPUs entered at EL1/EL2 or at inconsistent levels. Replacing
those checks, inventing a DT `hypervisor` node or changing PSCI to HVC would not
create the privilege transition. Use the standard kernel logs and `/dev/kvm`.

The current Qualcomm PAS remoteproc driver already supports explicit IOMMU
carveout mapping and shared TZ metadata when a valid `iommus` property exists.
The existing SM8150/Nabu DSP nodes do not describe that EL2-specific contract.
OEM FastRPC context-bank IDs are **not** proof of the DSP firmware-fetch stream
IDs; they must not simply be attached to remoteproc nodes. DSP, Wi-Fi, GPU/ZAP,
camera and resume ownership all remain physical qualification gates.

Qualcomm's 2026 U-Boot proposal places the EL2 handoff **before** normal register
and MMU setup, not in a userspace service or an already-running kernel. Its
Gunyah service is not proven to exist with the same semantics on Nabu's QHEE
firmware. `NabuEl2Preflight.efi` therefore queries the service only and never
invokes it. The older qhypstub implementation explicitly lists MSM8916/MSM8939,
not SM8150, and requires firmware conditions not established on this tablet.
HYP/TZ/XBL/ABL replacements and guessed secure calls are not part of this build.

## Acceptance order

1. Compile/RPM/DTB/modpost/signature checks, separate experimental repository.
2. Read-only EFI service discovery on the tablet, with Android and known-good
   Linux fallback preserved. An advertised service alone is not permission to
   assume safe GIC/SMMU/PSCI handoff.
3. Verified firmware contract, then a separately selected early-boot experiment.
4. Eight CPUs entering coherently, KVM API and actual guest execution, then all
   Nabu peripherals and suspend/resume. Only then review production promotion.

Sources:

- https://docs.kernel.org/arch/arm64/booting.html
- https://lists.u-boot-project.org/pipermail/u-boot/2026-May/618646.html
- https://github.com/tianocore/edk2-platforms/blob/master/Silicon/Qualcomm/KodiakPkg/Library/KodiakLib/KodiakHelper.S
- https://github.com/msm8916-mainline/qhypstub/blob/main/README.md
- Xiaomi `nabu-r-oss` commit `71b6effd2dfa8f703dd1ea17acd1323b2fd3cf6c`,
  `arch/arm64/boot/dts/qcom/sm8150.dtsi`, HYP and removed_regions definitions.
