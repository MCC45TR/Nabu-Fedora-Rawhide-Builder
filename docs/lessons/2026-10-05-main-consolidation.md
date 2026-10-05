# Consolidate histories into main; exclude EL2 and DisplayLink

- Date: 2026-10-05
- Lesson ID: NABU-20261005-001
- Environment: `MCC45TR/Nabu-Fedora-Rawhide-Builder`, Fedora x86_64 host;
  target sources remain Xiaomi Pad 5 (`nabu`), Fedora Rawhide AArch64.
- Evidence level: Git/source, host fixtures and source RPM assembly only.
- Original main: `a2df7041bbad83aff08e2ac0f35c91c67c43e409`.
- Consolidated merge history before final corrections:
  `13e58b5` (`Preserve superseded Nabu branch histories in main`).

## Finding and exact evidence

The remote contained 34 branches: `main`, 27 `codex/` branches, five `archive/`
branches and `nabu-7.2.2-mainline-unstable`. There were no open pull requests.
A full Git bundle and the original remote-head inventory were saved locally;
`git bundle verify` confirmed a complete, valid history.

The newer `main` had Linux 7.2.9 production sources. Several development
branches carried older versions, duplicate security/PRNG patches and superseded
sensor, audio, power or maintenance implementations. A blanket conflict choice
would have discarded useful changes or revived old policy. Content merges
retained the native audio and desktop helpers, two-meta source family, ext4
payload recovery, rEFInd title selection, historical EOL records, C++ locale
and RPM ownership helpers, and jq release parsing. The COPR dispatcher now
supports both package Makefiles and the imported SRPM scripts.

Older sensor/power/audio branch histories were merged with the current tree
retained where later implementations supersede them. In particular, older
four-channel desktop filter chains do not replace the later native stereo I2S
path. The current production kernel version, upstream checksum, patch checksum
manifest and patch files were retained. Additional 7.2.7-13 optimization,
audio and touch-wake candidates are preserved outside production
paths under `packaging/experiments/nabu-kernel-7.2.7-13`; their source commit is
`9a6fbe526cf67a77a7d36990f2276bcb4593806c`.

### EL2 correction

An initial consolidation trial retained a separately named, archived 7.2.4 EL2
package. The owner then explicitly reported that the EL2 candidate did not
boot and requested its exclusion. This report supersedes that trial's decision
to retain a buildable experiment. No fresh device log or measured failure
cause was supplied during this maintenance task.

The final tree removes both EL2 experiment variants, their package specs,
config fragments, CurrentEL application, optional production-test override,
QEMU guest and EL2 build/test tools. Production checks again reject enabled
`CONFIG_VIRTUALIZATION` or `CONFIG_KVM`. Historical commits remain reachable
for provenance, but no EL2 experiment is included in the current tree.

### Publication and package-policy corrections

The imported unified-meta policy initially rejected the source name `libevdi`.
An intermediate trial renamed it to `libevdi-nabu` with native compatibility
capabilities. The owner subsequently requested DisplayLink removal. That
trial was discarded: the final tree removes the library spec, SRPM scripts,
read-only diagnostic command, EVDI configuration and associated test tools.
Only historical records and Git commits retain this work.

The same imported policy rejected the existing `material-decoration` source on
`main`; the check now allows that exact upstream window-theme package without
allowing arbitrary KDE application replacements.

New merge commits use the account's GitHub no-reply address. Imported textual
package changelogs and touched updater metadata use that address too. Original
patch and Git authorship remains historical provenance; no device logs,
credentials or calibration captures were added by this task.

## Host validation

| Check | Result and boundary |
| --- | --- |
| `make check` | 23 generic builder, 21 CORE, 12 GNOME and 14 KDE assertions passed; Limine contract and Bash syntax passed |
| `tests/test_ext4_payload_recovery.sh` | Missing RPM-owned locale file restored and verified in a disposable ext4 fixture |
| `tests/test_rpm_file_ownership.sh` | Native C++ capture and verification passed, including the expected wrong-owner rejection |
| `nabu-boot/source/tests/test-boot-manager.sh` | Temporary ESP fixture validated systemd-boot, rEFInd displayed-title defaults, Android preservation and fallback retention |
| `nabu-unified-meta/test-unified-meta.sh` | Six-spec policy, native desktop generator, family maintenance, offline boot finalization, deferred GNOME sync and vendor checksum gates passed |
| COPR dispatcher for `nabu-unified-meta/nabu-core-meta.spec` | Six source RPMs assembled; this is not a binary package or image build |
| Experimental candidate `patches.sha256` | All eight preserved candidate patches verified |
| Git ancestry | Every captured non-main branch tip is reachable from the consolidated `main` history |

Before the DisplayLink removal request, a source RPM was assembled. Its initial
native fixture build failed because the host lacked `libdrm-devel`. Extracting
the signed Fedora `libdrm-devel-2.4.134-2.fc45.x86_64` RPM into a temporary
build directory resolved the missing headers without installing a system
package. Native procfs and synthetic sysfs fixture checks then passed. These
trial results neither establish dock support nor retain DisplayLink in the
final tree; the later explicit removal request supersedes that integration.

## Practical consequence

GitHub branch maintenance can use `main` alone while retaining every captured
branch history. Branch deletion must accompany publication of the consolidated
head and use each captured branch SHA as a lease. If any branch changes in the
meantime, reject the transaction and inspect the new commits before deleting
it. Preserve existing release tags and the local Git bundle.

EL2 and DisplayLink are excluded. Kernel updates continue from the existing
production series; archived touch-wake and optimization patches are not automatically
promoted by the branch consolidation.

## Uncertainty and next validation

This maintenance task does not build a complete kernel, binary RPM family or
Fedora image, run QEMU, boot the tablet, or test speakers, sensors, suspend or
a dock. The reported EL2 boot failure has no newly collected diagnosis here.

Before a future release, run the full signed upstream patch gate, AArch64
binary package and dependency checks, clean-install image verification and
an independent physical-device acceptance campaign with a known-good fallback.

## Captured remote branch tips

| Former branch | Original tip |
| --- | --- |
| `archive/nabu-pad5-boot-r46-20260928` | `bc73191fb38e8e1924f6066175a1a53b0bb8a852` |
| `archive/nabu-pad5-dt2w-727r13-20260928` | `9a6fbe526cf67a77a7d36990f2276bcb4593806c` |
| `archive/nabu-pad5-kde-runtime-20260928` | `3c848afafa3f61d01b75ffb720dbdc72adf81b3d` |
| `archive/nabu-pad5-meta-family-20260928` | `e76ab38004f17ceb804511f89f4e9aab7fdbbd25` |
| `archive/nabu-pad5-power-color-20260928` | `b079ced8b6014546678bb317c7cce24d69876414` |
| `codex/nabu-audio-i2s-20260925` | `461081fea20931f9e4b3edcd48198523e64d4ae0` |
| `codex/nabu-boot-727-20260921` | `9371a4bf5d81785bd492d6bdf1572e400fb03916` |
| `codex/nabu-camera-display-r10-20260913` | `14d94a7e2228e5e25ea464d25556739c33a78bc4` |
| `codex/nabu-camera-probe-r9-20260913` | `67b65516ad6517df6bca68998aa52884274e43ed` |
| `codex/nabu-connectivity-audio-rt-20260905` | `3ad8980c4c28bacfa9651cb49c5bb0c7d9188f62` |
| `codex/nabu-core-recovery-image-20260911` | `ed8503f7c46debe858b685a94c30bb8310b3aa87` |
| `codex/nabu-core-recovery-meta-20260911` | `0ac4a77dc9ccee5ac0ccb8cf3e1a7fe65e7b6d6f` |
| `codex/nabu-core-stable-kde-20260911` | `1345fb1a66ee1a9c10f8f916a5720e0c013632b9` |
| `codex/nabu-display-handoff-20260912` | `eb56a0bbdc624ea0885dbe7aca9d7738403e5e30` |
| `codex/nabu-displaylink-727-20260923` | `4be07c8073300712dd0a9f4555acfff90c8e9858` |
| `codex/nabu-el2-gate-20260913` | `303f636c40f769b59cc156bbfd94bf9c04350d27` |
| `codex/nabu-energy-r12-20260913` | `7169873ae0b61a7179bd7369d0f82ac29fbc5cbc` |
| `codex/nabu-hardware-data-sensors-el2-20260913` | `f8ae09c47eec53f1876e9cf1498438d6e01ae667` |
| `codex/nabu-kernel-optimize-20260924` | `d6bd2068c4839518ffbeb5c7c853075d8b974e6d` |
| `codex/nabu-mainline-unstable-20260831` | `9ade68c453b3b57da9905d1f2c3923c787f8011c` |
| `codex/nabu-package-management-20260828` | `6277e94e25d502ce201afa49d2a3b572f667a7f2` |
| `codex/nabu-pad5-eol-20260928` | `0f4e7634b05bae45439d1d7531680e2a0afc290b` |
| `codex/nabu-permanent-wifi-mac-20260912` | `4dd7fb3f8431e98099d5d2503453540629089110` |
| `codex/nabu-power-sleep-refind-20260913` | `399deacd276c05aa00b1e5fc53437eb4e482d08d` |
| `codex/nabu-runtime-compose-20260912` | `eac9d0375ba0ba56e1a9f0adf646f998e56e86aa` |
| `codex/nabu-runtime-firstboot-fixes-20260911` | `110385b85580db5f8e0d7e3feb6a2d5e71f3f942` |
| `codex/nabu-security-rng-7.2.4-release5-20260910` | `9ee3450e0ecf6fa6db938e0aa083a297e7155eb9` |
| `codex/nabu-security-stage1-packaging-20260910` | `ee47b21612e33b585c50776d44fa38f1e1a22a42` |
| `codex/nabu-suspend-resilience-20260828` | `dc7d797d8dff4598c80582246b2463b8efd44616` |
| `codex/nabu-two-meta-20260829` | `98188b595b42ba975f5bc238e596f330d3994ed8` |
| `codex/nabu-ufs-r11-20260913` | `181e4bb5ed2e8e28754662502519d354cc07f139` |
| `codex/nabu-wake-r13-20260913` | `2f2b3ee1ec88a8e03ee286357016a4583f03d9da` |
| `main` | `a2df7041bbad83aff08e2ac0f35c91c67c43e409` |
| `nabu-7.2.2-mainline-unstable` | `e4aa8ab7725b9de2292ed51ae1a3dcc7d1ae4d1d` |
