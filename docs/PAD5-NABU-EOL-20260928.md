# Xiaomi Pad 5 (Nabu): EOL engineering handoff

This repository preserves the Xiaomi Pad 5 work as of 28 September 2026.
The tablet's display is broken, so new builds cannot receive a final physical
acceptance test. The sources remain useful as a method reference for a future
device; Nabu DT nodes, firmware, calibration and boot assumptions must not be
copied to Xiaomi Pad 7 without identifying its actual hardware.

## What worked, and what did not

| Area | Last evidence | Boundary |
| --- | --- | --- |
| Fedora KDE image | Clean-install ext4 image composed on 12 September with 7.2.4-6; root locked and no regular account | Offline filesystem, RPM ownership, SELinux, locale and ESP checks passed; the compose itself did not boot on hardware |
| Four speakers | 7.2.7-12 stereo I²S transported two PCM channels to four CS35L41 amplifiers; user reported audible improvement after reboot | Individual positions, sustained load and thermal protection were not fully accepted; remain in the test channel |
| Stable kernel | 7.2.8-1 successfully built in `mcc45tr/nabu-linux` on Fedora AArch64 | COPR success is not a Pad 5 boot result |
| Power and charging | PM8150B step sizes, thermal/JEITA limits and fail-closed behavior were packaged; direct LN8000 path remained opt-in and disabled | Do not infer 67 W charging from the adapter label; final algorithm audit was interrupted by EOL |
| UFS/ext4 | ext4 block bitmap checksum mismatch was diagnosed; offline recovery was performed with Linux unmounted | UFS PA/DL events were not proven to be the cause |
| EL2/KVM | EFI preflight displayed `CurrentEL=1` and no proven SCM transition ABI | KVM cannot be claimed from a kernel config alone |
| Double tap wake | Interface and test patches were built | A physical double tap did not wake the display during testing |
| Btrfs | A personal HIL candidate was prepared | Contains user data and credentials; never a public image or release asset |
| DisplayLink | UDL/EVDI compiled and signed on AArch64 | No physical dock test |
| DRM L1 | No licensed OEMCrypto/CDM or protected video path | Not implemented or claimed |

## Reusable workflow

1. Identify the device, partition labels, SoC, PMIC, panel, codec, sensor
   transport and firmware provenance using read-only evidence.
2. Keep Android EFI and a booted Linux fallback. Use a separately named test
   UKI and rEFInd entry for kernel/DT/firmware experiments.
3. Version the kernel patch series and SHA-256 manifests. Test source apply,
   DTB, module signatures and dependencies before a COPR build.
4. Wait for terminal COPR success, inspect signed RPM payloads and run an
   isolated AArch64 dependency solve before a physical install.
5. After reboot, collect actual display, touch, Wi-Fi, audio, storage, thermal,
   charge and suspend results. Source tests alone do not promote a build.
6. Publish only clean-install images. Inspect accounts, `/etc/shadow`, Wi-Fi
   profiles, SSH host keys, machine ID, device-derived calibration and signing
   private keys before release. Do not distribute personal-device Btrfs images.

The Nabu-specific source branches in this repository document experimental
steps independently. Other source families are referenced through COPR
package metadata; no private Android partitions, device logs or credentials
are part of this EOL documentation.
