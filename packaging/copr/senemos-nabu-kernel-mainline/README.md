# SENEMOS Nabu mainline kernel

This COPR source follows kernel.org's newest `stable` release and publishes it as
`senemos-nabu-kernel-mainline` with a conventional Fedora release number. The source
contains its own checksum-locked device patch series, distinct ABI and SENEMOS7
maintenance family. `update-upstream.sh` accepts a new stable version only after
the complete Nabu patch and configuration gate passes. The accepted commit then
triggers the COPR SCM package's automatic rebuild; a failed port leaves the last
working repository result untouched.

Release 7.2.4-3 adds a 7.2.x-only production security layer merged after Nabu
device pruning. It pins SELinux/audit and the low-overhead arm64 hardening
baseline, describes SM8150's PRNG-EE block without treating it as trusted
entropy, and enables the fail-closed SMCCC firmware TRNG provider. The package
gate checks the applied source, final kernel configuration and compiled DTB.
