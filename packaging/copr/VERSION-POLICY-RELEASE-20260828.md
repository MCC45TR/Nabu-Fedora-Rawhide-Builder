# Nabu version-policy release — 2026-08-28

## Published control plane

The normalized 1.1 control plane was published as COPR builds 10914834–10914838,
10914865, 10914868–10914875, 10914880–10914887, and 10914889–10914891.
Every requested Fedora 43, 44, 45, and Rawhide AArch64 chroot succeeded.

The release contains 25 independently visible source packages. The downloaded
Rawhide result set contained 50 source/binary RPMs; all 50 passed isolated
COPR-key digest and signature verification.

## Upgrade result

The live Rawhide N-1 transaction upgraded nine independently versioned control
packages and installed `nabu-obsolete-packages`. It retired only the two
temporary Nabu transition marker packages. It removed no Fedora or KDE package,
did not update a kernel, and required no reboot.

DNF completed with `dnf check` clean and no remaining updates. PackageKit's
dnf5 backend refreshed the same COPR, resolved the new installed manifests, and
reported no updates, providing the Plasma Discover backend acceptance gate.

## Retention result

Twenty-seven legacy bundled `nabu-repository-config` builds and thirty-eight
superseded stable non-kernel builds were deleted after live acceptance. The two
retired transition source-package rows were deleted. Stable non-kernel source
packages now retain no more than two successful builds. Kernel, UEFI, alpha
diagnostic, Android, and known-good fallback histories were excluded.

Fresh repository metadata exposes the independent 1.1 package family and none
of the retired bundled names. `nabu-repository-config-1.0.0-33.test` remains as
the validated predecessor to `1.1.0-1`.
