# Nabu 6.17 to Linux 6.18 LTS port

The hardware layer was derived from the maintained Nabu 6.17 test line at
commit `de40809f199111e0dfd0160872953f1f715128b4`. Its imported 6.17 SM8150
baseline is `af19964c32a04345d1d00c05eea1d801d0aa4349`.

The 6.18 patch series preserves the Nabu DTS and panel, touch/DT2W, seamless
DFPS, tablet mode and keyboard, FastRPC/SLPI, Wi-Fi, USB CDC, legacy audio,
speaker tuning, PM8150B/SMB5, fuel gauge and release configuration changes.
API conflicts were resolved against official Linux 6.18.48 rather than copying
whole 6.17 files over newer upstream implementations.

Every 6.18.y point update is fail-closed: the archive checksum and all patch
checksums must verify, all patches must apply, and the package build gates must
pass before GitHub can commit the new version and trigger COPR.
