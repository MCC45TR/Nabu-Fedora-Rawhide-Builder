# Archived Nabu Linux 7.2.7-13 patch candidates

Preserved on 2026-10-05 from commit
`9a6fbe526cf67a77a7d36990f2276bcb4593806c` during branch consolidation.
This directory retains the additional optimization, stereo I2S
and touch-wake patch candidates, with their matching test sources. The updated
`0006` patch is a historical replacement, not an additional patch to append.
The adjacent checksum manifest covers only the preserved candidate patches.

This directory is outside the production COPR source paths and scheduled
workflows. The production kernel remains in
`packaging/copr/senemos-nabu-kernel-mainline` with its current upstream version
and patch manifests. In particular, the NT36523 wake replay patch is not added
to that production series: physical double-tap wake and suspend acceptance
remain open. Past package versions and test reports are historical evidence.

The complete original branch history is reachable from `main`. Use the source
commit above to recover its base tree when investigating historical results.
The archived files are not a standalone SRPM or a supported build entry point.
Porting and selecting these candidates require independent source checks and
device acceptance. All EL2 package, configuration, build and test entry points
were excluded after the owner reported that the EL2 candidate did not boot.
DisplayLink userspace, diagnostics, module/config sources and tests were also
excluded at the owner's request.
