# SENEMOS Nabu mainline kernel

Release 7.2.7-7 specializes the resolved kernel configuration for SM8150's
eight CPUs and non-NUMA memory topology. It also clears the temporary MSM GPU
boost request when suspend cancels its expiry worker, and removes an unused
NT36523 sysfs-group array. The active GPU boost policy, thermal/frequency limits,
UFS runtime-PM safety quirk, 256 MiB CMA and security policy remain unchanged.
The compiled-DTB/config and extracted-C regression gate is
`test-kernel-optimization.py`; it runs only on build hosts. These changes are
not evidence of a measured battery-life, frame-rate or physical resume gain.
See [OPTIMIZATION-7.2.7.md](OPTIMIZATION-7.2.7.md) for audit and qualification.
Release 7 also uses GCC for build-host tools so Fedora's GCC-specific RPM
hardening specs no longer cause Clang warnings; the AArch64 kernel and EVDI
still compile with Clang. One preexisting whitespace warning in the legacy
fuel-gauge patch is removed without changing its C token stream.

An opt-in EL2/KVM variant now uses this same kernel and DT patch series. Its
isolated build and hardware qualification limits are documented in
[EL2-EXPERIMENT.md](EL2-EXPERIMENT.md). The default build remains unchanged.

Release 7.2.7-4 adds optional USB DisplayLink support: upstream `udl.ko` for
older adapters and checksum-pinned EVDI 1.15.1 for modern DisplayLinkManager.
EVDI is built against the same kernel and signed by the same build key before
compression; every module must pass the vermagic/signature/depmod payload gate.
No DKMS or on-tablet compilation is required. No modules-load entry, virtual
display, compositor override or always-running service is installed.

EVDI alone is NOT a DisplayLink USB driver. Modern docks also need Synaptics'
separately licensed AArch64 DisplayLinkManager and a matching libevdi. Those
proprietary binaries are not included in this kernel's COPR sources. This is
USB graphics, not USB-C DP Alt-Mode. Dock hotplug, KDE Wayland, suspend/resume
and USB bandwidth/CPU/power behavior require physical qualification.

The first release-3 candidate was rejected by COPR: EVDI imported RPM's
userspace GCC `CFLAGS` into the Clang module build. Release 4 clears only that
input; Kbuild hardening and WERROR remain intact. The source gate deliberately
poisons CFLAGS to prevent recurrence. Successful candidate build: 11026630,
in `mcc45tr/nabu-linux:custom:displaylink727r4`, not promoted to production.

After verifying the downloaded RPM's OpenPGP signature and extracting it into
a scratch directory, run these **build-host tests** (never on-device services):

```sh
bash test-runtime-payload.sh EXTRACTED_RPM_ROOT 7.2.7-nabu-senemos-mainline
python3 test-module-signatures.py EXTRACTED_RPM_ROOT 7.2.7-nabu-senemos-mainline
```

The second test checks every module's AArch64 ELF header and PKCS7 signature
against the public certificate embedded in that exact kernel Image. It also
requires a deliberately corrupted temporary payload to fail verification.
It does not load any module or read/change the running kernel. Module-signing
metadata alone is not evidence of a valid signature. See the upstream
[module signing documentation](https://docs.kernel.org/admin-guide/module-signing.html).

This COPR source follows kernel.org's newest `stable` release and publishes it as
`senemos-nabu-kernel-mainline` with a conventional Fedora release number. The source
contains its own checksum-locked device patch series, distinct ABI and SENEMOS7
maintenance family. `update-upstream.sh` accepts a new stable version only after
the complete Nabu patch and configuration gate passes. The accepted commit then
triggers the COPR SCM package's automatic rebuild; a failed port leaves the last
working repository result untouched.

Release 7.2.4-14 carries the documented NT36523 `double_tap_to_wake` sysfs ABI
using Linux 7.2's managed single-group registration API. Release 13 is retained
only as the rejected compile-gate attempt and was never installed. The ABI adds
the built-in uinput capability used by the opt-in Sensor DSP tilt-wake bridge.
The touchscreen attribute is created only when Device Tree declares both the
gesture and wake source, and the userspace bridge can emit only `KEY_WAKEUP`.
Neither mechanism changes Android/vendor calibration data or broadens access
to any firmware partition.

Release 7.2.4-12 adds the charge-full and SOC-derived charge-now attributes
required by UPower's charge-based accounting. UPower can therefore combine
the fuel gauge's measured current and voltage with remaining charge, allowing
KDE to populate battery and power-consumption history instead of displaying
zero energy. The remaining-charge value is an SOC-based estimate; the
instantaneous power source remains the hardware current/voltage telemetry.

Release 7.2.4-11 disables only UFS runtime autosuspend on Nabu after physical
HIL captured a Samsung UniPro TC replay timeout during device-WLUN resume. The
failed recovery exhausted the reserved management request, returned `-ENOMEM`,
aborted the root EXT4 journal and made the tablet appear frozen. Normal system
suspend remains available, as do active-state UFS clock gating and scaling; the
change therefore removes the unsafe device/link sleep transition without
turning every UFS power-saving mechanism off. The release also enables the
low-overhead hung-task and workqueue watchdogs, stores their evidence in the
existing ramoops allocation and reboots 15 seconds after a confirmed
120-second uninterruptible-task panic.

Release 7.2.4-10 restores `CLK_IGNORE_UNUSED` on the six firmware-owned
bonded-DSI byte/pixel branches. Device HIL showed that release 8's generic
disable-unused experiment could not halt any of them, emitted six clock
warnings on every boot, and preceded one early hard lock. The bounded camera
recovery remains intact while the display fault moves to a driver-owned reset
path. Release 7.2.4-9 gives Nabu's front OV8856 one board-opted, bounded recovery
after the observed cold-boot `-EIO`: the driver performs a complete power
cycle and retries only chip identification once. It also removes duplicated
fwnode-control parsing left by the older camera backport now that Linux 7.2
contains that support upstream. Release 7.2.4-8's attempt to quiesce the
firmware-owned clocks is retained in history but explicitly reverted by
release 10 after physical HIL rejected it.
Release 7.2.4-7 adds a one-MiB persistent ramoops dmesg record for diagnosing
otherwise unobservable hard UI freezes. Release 7.2.4-6 keeps the same
production security, entropy and camera payload
while exposing the user-facing Device Tree product name as `Xiaomi Pad 5`.
Release 7.2.4-5 layers the remaining production security and entropy policy on
top of the release-4 hardening, power-profile and stable wireless-address work.
It preserves Fedora's SELinux/BPF/IPE LSM order, adds the remaining low-overhead
arm64 hardening after device pruning, describes SM8150 PRNG-EE without treating
it as trusted entropy, and enables the fail-closed SMCCC firmware TRNG provider.
The package gate checks the applied source, final kernel configuration and
compiled DTB.
