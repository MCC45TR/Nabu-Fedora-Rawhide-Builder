# SENEMOS Nabu LTS kernel

This package builds the official `linux-6.18.y` source in COPR and applies the
ordered Nabu patch series from `patches/`. The upstream archive and every patch
are checksum-locked. A stable point update is accepted only when the complete
series applies without conflict and the package gates pass.

The package is intentionally separate from `senemos-nabu-kernel-mainline-alpha`:

- RPM: `senemos-nabu-kernel-lts`
- ABI: `6.18.x-nabu-senemos-lts`
- maintenance queue: `lts`
- EFI/UKI family: `SENEMOS6LTS`

It does not obsolete or conflict with the 6.17 fallback, Android return entry,
or the existing 7.2 alpha family.

The daily updater checks the official Linux 6.18.y checksum list. It commits a
new point release only after all 25 checksum-locked Nabu patches apply cleanly;
a conflict stops publication and leaves the preceding COPR build untouched.

The updater follows the selected `6.18.y` LTS series. Moving to a future LTS
series is deliberately not automatic because that changes the kernel ABI and
requires a fresh Nabu patch-port and hardware acceptance cycle.
