# Nabu CORE 7.2.x stable builder

This profile composes a fresh Fedora Rawhide AArch64 CORE image for Xiaomi Pad 5 (Nabu).

Release contract:

- EXT4 system image with label `linux`
- rEFInd on a 320 MiB FAT32 ESP with 4096-byte logical sectors
- only `senemos-nabu-kernel-mainline` 7.2.x under `/EFI/fedora`; the unstable package is forbidden
- Reboot2Android as the protected `/EFI/android` entry
- Bash and the SENEMOS Plymouth theme
- quiet release command line; debug shell and debug generator masked
- CORE-only root login enabled with the release installation password; no desktop user
- Fedora Initial Setup disabled; NetworkManager, SSH, late XHCI and ESP32-S3/CDC recovery enabled
- all Nabu packages come only from the GPG-checked stable `mcc45tr/nabu-linux` COPR; the test COPR is forbidden
- exact UKI kernel/DTB/uname matching plus signed COPR, forward DNF solve, ownership, SELinux, initramfs, EXT4, ESP and checksum gates

Build locally with the same Fedora AArch64 container used by CI:

```bash
core-builder/build-core.sh
```

Run only the live dependency closure gate:

```bash
core-builder/build-core.sh --solve-only
```

Only a directory whose `reports/stages.tsv` contains a `PASS` for every begun stage and whose
`SHA256SUMS` verifies is a flash candidate. Compose success remains separate from physical boot,
display, touch, audio, sensors, Wi-Fi and ESP32 recovery validation on the device.
