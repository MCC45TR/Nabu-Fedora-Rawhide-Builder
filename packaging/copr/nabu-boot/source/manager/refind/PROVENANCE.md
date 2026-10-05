# Nabu rEFInd and GopRotate provenance

The bundled AArch64 binaries were recovered from the established Nabu EFI
overlay and are byte-identical to the public `jhuang6451/nabu_fedora_packages`
tree at commit `7bb9617b0947e8695707feeac3d2dd85b059b327`.

- `refind_aa64.efi`: rEFInd 0.14.2 Nabu build with the `rotation` configuration
  token; SHA-256 `c563b52e4068d2e8a836c43b10465b4ea066ca7f3d1266107b6b11698270ee4c`.
- `drivers_aa64/GopRotate_aa64.efi`: GopRotate 1.0 AArch64 DXE driver;
  SHA-256 `23cde353a5bf5d85c2bf45e8ae6db0074d826643b69c39dd42c4bdf6e2e43a89`.

Both files are PE32+ AArch64 EFI images. The rEFInd source is GPL-3.0-or-later.
GopRotate source is available from `https://github.com/apop2/GopRotate` under
BSD-2-Clause. The unrelated ext2/ext4/Btrfs/HFS/ISO9660/ReiserFS drivers from
the recovered ESP are intentionally excluded.
