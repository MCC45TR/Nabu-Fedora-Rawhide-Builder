# Nabu 7.2.7 regression repair — 2026-09-21

## Scope and evidence boundary

The tablet is powered off. This release repairs identified source/packaging
defects; it is not a claim of successful physical boot or suspend qualification.
The reported symptoms were vertical display lines after 7.2.6, followed by
missing network and touchscreen even when selecting an older 7.2.4 UKI.
Do not flash Android partitions, change firmware calibration, or overwrite the
known-good recovery path to test these changes.

## Findings

| Area | Verified evidence | Change / remaining uncertainty |
| --- | --- | --- |
| DSI display | Nabu uses two `qcom,dsi-phy-7nm-8150` PHYs in bonded mode. 7.2.6 carries upstream revert `44784327815b`, restoring a known bonded PLL initialization defect. 7.2.7 still carries the reverted code. | Patch 0157 restores the earlier reference lifetime and bias refresh only on bonded SM8150. Standalone links and other SoCs retain upstream behavior. Physical display recovery remains unproven. |
| Driver payload | The downloaded 7.2.6-1 Rawhide RPM contains 537 signed, ABI-matching modules; depmod reports no unresolved symbols. Wi-Fi, touchscreen, panel and remoteproc modules are present. | Do not describe this as a wholesale compile-time driver omission. The inaccessible tablet's actual installed filesystem and probe failures could not be inspected. |
| Fallback integrity | Previous mainline RPMs lacked `Provides: installonlypkg(kernel)`. A normal upgrade can replace the old module tree while an old EFI file survives. | Add the standard install-only capability. A fallback must retain the matching kernel RPM/module tree, not only an EFI file. Old versions already removed by an earlier upgrade are not restored by this change. |
| Deferred probing | Boot policy through 2.0.0-45 forced `deferred_probe_timeout=0`. The correction in 46 had only been published for Rawhide under a separate upload package. | Require 2.0.0-47 or newer. Publish the correction consistently for Rawhide/44/45 and reject UKIs with missing or mismatched essential modules. This is a dependency/probe correction, not proof of the individual failed probes. |
| Device tree | The locally compiled 7.2.7 Nabu DTB is byte-identical to the published 7.2.6 DTB (`27e01238ada4f33bdeedfc46866e379d1813d02068a2b9b41b26273ea93321e1`). | No speculative DT voltage, clock, GPIO, reset, or calibration changes. An installed UKI must still be checked for the correct embedded DTB. |
| Iris video | Upstream 7.2.7 changes runtime-PM unwind in `iris_disable_power_domains`; old patch 0030 no longer applied. | Rebase only the OPP call conversion, retaining upstream unconditional PM release and original error propagation. |

Older GPU CCU translation faults/hangcheck observations predate this release.
They are not sufficient evidence that this PLL correction fixes every GPU or
suspend fault. Preserve those diagnostics rather than suppressing warnings.

## Automated checks

- Verify the kernel.org signed SHA-256 manifest before accepting the source.
- Apply the entire checksum-locked series to a clean 7.2.7 source tree.
- Compile the modified DSI and Iris objects plus Nabu DTB for AArch64.
- Execute the extracted C PLL functions with mocked registers: 6,000 balanced
  cycles across SM8150 master/slave/standalone and other-SoC scope controls.
  The unpatched code fails the reference-preservation assertion; patched code
  passes. This is a logic test, not a hardware timing test.
- In every RPM build, check the Image release, every signed module's vermagic,
  essential driver presence, DTB, module indexes and depmod symbol resolution.
- Test UKI refusal for missing, wrong-version, misleading-prefix and empty
  module metadata; leave other kernel families' layouts unchanged.
- Inspect downloaded COPR RPMs and the AArch64 dependency/upgrade solver
  separately from source checks. A running COPR job is not release success.

Python is used only for build-time tests. No Python runtime component is added.
The hardware change is native kernel C; boot integration retains its existing
shell implementation.

## Next image and hardware acceptance

1. Select the final successful 7.2.7-1 COPR RPM and boot integration 47+ from
   the same stable repository. Do not include a test-channel package silently.
2. Retain a complete known-good 7.2.4 fallback (UKI **and matching modules**)
   and the Android EFI path. The failing 7.2.6 image is not a known-good fallback.
3. Before flashing, inspect the UKI's kernel, `.uname`, embedded DTB, command
   line and initramfs; verify all references against the final root filesystem.
4. On-device: cold boot, Wi-Fi discovery/traffic, touchscreen, panel mode
   changes, screen blank/unblank, repeated suspend/resume, charging and DSP
   audio/sensors. Collect timestamped kernel logs and pstore if a boot fails.
5. Keep failed-probe, DSI PLL, DPU underrun, GPU fault and remoteproc messages
   visible. Do not classify the release as hardware-qualified until these tests
   pass on the tablet.

## Primary references

- [kernel.org release metadata](https://www.kernel.org/releases.json)
- [Original bonded-mode PLL fix](https://github.com/torvalds/linux/commit/93c97bc8d85d5742d6f000d8bf3eeeb705bc6082)
- [Revert for standalone-link regression](https://github.com/torvalds/linux/commit/44784327815b2a1ad8bb56b9236770cb538c7c27)
