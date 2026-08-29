# Limine CORE image builder

This is the clean, modular Fedora Rawhide AArch64 image path for Xiaomi Pad 5
(Nabu). It produces two independently flashable files:

- an 8 GiB EXT4 system image with filesystem label `linux`;
- a 320 MiB FAT32 ESP image with 4096-byte logical sectors.

The immutable profile selects Bash, `nabu-core-meta`, the COPR alpha kernel,
Limine and the `senemos-nabu` Plymouth theme. The root account is locked and
`sshd` remains disabled; first-boot provisioning is intentionally separate.

## Local build

The host needs Podman or Docker. The same Fedora Rawhide AArch64 container and
the same compose script are used locally and in GitHub Actions.

```bash
./limine-core-builder/build-core.sh
```

Use `--solve-only` for the live signed-COPR dependency gate. Set
`LIMINE_CORE_KEEP_UNCOMPRESSED=0` to retain only compressed images.

Each run creates `output/limine-core/core-rawhide-alpha-limine-*/` containing
the images, checksums, full package manifest, DNF logs, initramfs listing,
kernel command line, Limine configuration and a timestamped `stages.tsv`.
`systemd-boot-unsigned` is installed only as the Fedora-supplied AArch64 UKI PE
stub; `nabu-boot-limine` remains the sole selected boot-manager package.

## Acceptance boundary

Static acceptance verifies EXT4 integrity and label, 4 KiB-sector FAT32,
AArch64 Limine EFI, the dynamic alpha UKI, Android return payload, Plymouth in
the final initramfs, `quiet splash`, signed COPR solving, future DNF solving and
absence of UID/GID 65534 overflow ownership. Physical boot, display, touch and
Plymouth animation remain hardware-in-the-loop checks and must be recorded
after flashing both partitions.
