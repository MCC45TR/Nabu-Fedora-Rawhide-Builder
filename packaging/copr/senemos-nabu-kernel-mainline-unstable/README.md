# SENEMOS Nabu mainline-unstable kernel

This COPR source follows kernel.org's current mainline series. It is pinned to
Torvalds' official `v7.3-rc2` tag through the `linux-7.3-rc2.tar.gz` SHA-256
and applies the ordered, independently checksum-locked Nabu patch queue.

The RPM and kernel identities are deliberately different where RPM ordering
requires it:

- RPM version: `7.3~rc2`
- upstream source: `7.3-rc2`
- ABI: `7.3.0-rc2-nabu-senemos-mainline-unstable`
- maintenance queue: `mainline-unstable`
- EFI/UKI family: `SENEMOS7U`

This package is independent from `senemos-nabu-kernel-mainline`, whose frozen
`7.2.2-2` package and `SENEMOS72` boot entry remain installed as the stable
mainline fallback. It also leaves the validated 6.17 fallback and Android
return entry untouched.

The Linux 7.3 port retains upstream's current Iris encoder/decoder structure
and adapts Nabu's legacy VPU5 firmware queue, buffer, VP9/P010, dual-core load
and suspend behavior semantically. Camera EEPROMs are exposed read-only,
panel revision is exported for per-variant ICC selection, SMB5 charging stays
fail-safe, and the existing display, touch, audio, GPU, USB, storage, sensor,
security and power fixes remain in the series.

`test-patch-series.sh` verifies the upstream archive, all patch checksums,
`git am` semantics, the final Nabu configuration and critical source invariants.
The COPR build separately compiles the kernel Image, modules and the composed
Iris-camera DTB. Neither gate substitutes for physical boot and HIL testing.

`update-upstream.sh` reads the official kernel.org mainline metadata. A newer
tag is committed only if the complete frozen Nabu patch queue still applies and
all static gates pass; otherwise the preceding COPR result remains untouched
for a reviewed rebase.
