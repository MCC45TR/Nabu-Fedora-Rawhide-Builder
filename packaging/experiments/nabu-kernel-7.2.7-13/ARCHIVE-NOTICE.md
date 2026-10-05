# Archived Nabu Linux 7.2.7-13 candidate

Preserved on 2026-10-05 from commit
`9a6fbe526cf67a77a7d36990f2276bcb4593806c` during branch consolidation.
The source tree retains the optimization, DisplayLink, isolated EL2, stereo
I2S and touch-wake experiments from the former archive branch.

This directory is an engineering archive. It is outside the production COPR
source paths and scheduled workflows. The production kernel remains in
`packaging/copr/senemos-nabu-kernel-mainline` with its current upstream version
and patch manifests. In particular, the archived NT36523 wake replay patch is
not added to that production series: physical double-tap wake and suspend
acceptance remain open. The archive's package version and past test reports
must not be treated as current hardware validation.

The complete original branch history is reachable from `main`. Use the source
commit above to recover the original tree when investigating historical
results. Rebuilding, packaging or selecting this candidate requires its own
source checks and device acceptance campaign.
