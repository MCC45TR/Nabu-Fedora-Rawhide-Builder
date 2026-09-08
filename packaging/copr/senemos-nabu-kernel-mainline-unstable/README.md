# SENEMOS Nabu mainline-unstable kernel

This COPR source follows kernel.org's current `mainline` series. Each accepted
build is pinned to Torvalds' official source archive by SHA-256 and applies the
ordered, independently checksum-locked Nabu patch queue.

The RPM and kernel identities are deliberately different where RPM ordering
requires it:

- RPM prerelease mapping: upstream `X.Y-rcN` becomes `X.Y~rcN`
- ABI: `X.Y.0-rcN-nabu-senemos-mainline-unstable`
- maintenance queue: `mainline-unstable`
- EFI/UKI family: `SENEMOS7U`

This package is independent from `senemos-nabu-kernel-mainline`, which follows
kernel.org's gated stable release stream and keeps its own `SENEMOS7` boot
family as the stable mainline fallback. It also leaves the validated 6.17
fallback and Android return entry untouched.

The current port retains upstream's Iris encoder/decoder structure and adapts
Nabu's legacy VPU5 firmware queue, buffer, VP9/P010, dual-core load
and suspend behavior semantically. Camera EEPROMs are exposed read-only,
panel revision is exported for per-variant ICC selection, SMB5 charging stays
fail-safe, and the existing display, touch, audio, GPU, USB, storage, sensor,
security and power fixes remain in the series.

`test-patch-series.sh` verifies the upstream archive, all patch checksums,
`git am` semantics, the final Nabu configuration and critical source invariants.
The COPR build separately compiles the kernel Image, modules and the composed
Iris-camera DTB. Neither gate substitutes for physical boot and HIL testing.

`update-upstream.sh` reads the official kernel.org `mainline` metadata, so the
channel advances across release-candidate series (for example from 7.3 to
7.4-rc1). A newer tag is committed only if the complete frozen Nabu patch queue
still applies and all static gates pass. The accepted commit triggers COPR's SCM
auto-rebuild; otherwise the preceding result remains untouched for a reviewed
rebase.
