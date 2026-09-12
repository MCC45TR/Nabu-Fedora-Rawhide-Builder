# SENEMOS Nabu mainline kernel

This COPR source follows kernel.org's newest `stable` release and publishes it as
`senemos-nabu-kernel-mainline` with a conventional Fedora release number. The source
contains its own checksum-locked device patch series, distinct ABI and SENEMOS7
maintenance family. `update-upstream.sh` accepts a new stable version only after
the complete Nabu patch and configuration gate passes. The accepted commit then
triggers the COPR SCM package's automatic rebuild; a failed port leaves the last
working repository result untouched.

Release 7.2.4-8 lets the clock framework quiesce firmware-owned dual-DSI byte
and pixel branches before the first Linux modeset. Nabu performs a full panel
and bonded-PHY initialization rather than a continuous-splash handoff, so this
prevents stale firmware phase state from surviving into the first scanout.
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
