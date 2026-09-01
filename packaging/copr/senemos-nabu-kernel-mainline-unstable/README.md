# SENEMOS Nabu mainline unstable kernel

This package builds the official `linux-7.2.y` source in COPR and applies the
ordered Nabu patch series from `patches/`. The upstream archive and every patch
are checksum-locked. A stable point update is accepted only when the complete
series applies without conflict and the package gates pass.

Camera support is a Linux 7.2.2 port of ChengFangming/CFM880's original
[`nabu-camera`](https://github.com/CFM880/nabu-camera) work. Iris/Venus support
tracks ChengFangming/CFM880's [`nabu-iris`](https://github.com/CFM880/nabu-iris)
overlay. The corresponding experimental VA-API userspace driver is maintained
upstream in [`iris-vaapi`](https://github.com/CFM880/iris-vaapi). Patch commit
messages retain the exact source revisions and original author credit.

The package is intentionally separate from `senemos-nabu-kernel-mainline-alpha`:

- RPM: `senemos-nabu-kernel-mainline-unstable`
- ABI: `7.2.x-nabu-senemos-mainline-unstable`
- maintenance queue: `mainline-unstable`
- EFI/UKI family: `SENEMOS7U`

It does not obsolete or conflict with the 6.17 fallback, Android return entry,
or the existing 7.2 alpha family.

The daily updater checks the official Linux 7.2.y checksum list. It commits a
new point release only after all 32 checksum-locked Nabu patches apply cleanly;
a conflict stops publication and leaves the preceding COPR build untouched.
