# SENEMOS Nabu mainline kernel

This COPR source follows kernel.org's newest `stable` release and publishes it as
`senemos-nabu-kernel-mainline` with a conventional Fedora release number. The source
contains its own checksum-locked device patch series, distinct ABI and SENEMOS7
maintenance family. `update-upstream.sh` accepts a new stable version only after
the complete Nabu patch and configuration gate passes. The accepted commit then
triggers the COPR SCM package's automatic rebuild; a failed port leaves the last
working repository result untouched.

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
