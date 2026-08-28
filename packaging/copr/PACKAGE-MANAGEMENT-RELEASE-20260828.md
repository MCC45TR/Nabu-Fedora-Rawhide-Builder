# Nabu package-management release — 2026-08-28

This release separates repository configuration, core ABI, branch selection,
desktop integration, migrations, and deferred kernel maintenance into distinct
source packages in `mcc45tr/nabu-linux`.

## Invariants

- Fedora and KDE packages are not forked, patched, or broadly obsoleted.
- `nabu-plasma-qt6-transition` is a compatibility marker only.
- Destructive desktop cleanup is explicit through `nabu desktop migrate`.
- Stable, alpha, and unstable branch packages expose ordered capabilities and
  require the same `nabu-core-abi`.
- Kernel RPM transactions only mark maintenance as pending. UKI generation is
  serialized and deferred to `nabu-kernel-maintenance.service`.
- Android EFI and the known-good Linux fallback remain outside package cleanup.

## Published builds

Repository config 10913305; kernel maintenance 10913306; branch manager
10913307; core base 10913308; root meta 10913309; branch metas 10913310–10913312;
desktop packages 10913314–10913322; mainline kernel 10913351.

All builds reached `succeeded` in Fedora 43, 44, 45, and Rawhide chroots. The
live Rawhide N-1 transaction solved and completed without `--allowerasing` and
without package removals. PackageKit's dnf5 backend refreshed the COPR and
reported the installed release packages, which is the backend used by Plasma
Discover.

Physical boot of the newly prepared kernel is intentionally a separate gate.
