# Nabu RPM version and lifecycle policy

## Package roles

| Role | Version source | Dependency rule | Retention |
|---|---|---|---|
| Runtime/content | Upstream or component SemVer | Exact ABI only when required | Latest two validated builds |
| Kernel | Upstream kernel in `Version`; Nabu/channel revision in `Release` | Channel capability and install-only semantics | Current plus known-good fallbacks |
| Integration | Component SemVer | Public `*-api` or `*-abi` capability | Latest two validated builds |
| Meta/profile | Manifest schema in `Version`; manifest revision in `Release` | Package names or stable capabilities | Latest two validated builds |
| Repository | Repository schema | `nabu-repository-config-api` | Latest two validated builds |
| Rename/retirement | Independent manifest revision | Nabu-owned names only | Current plus one predecessor |
| Migration tool | Tool SemVer | Explicit invocation; never automatic cleanup | Latest two validated builds |

## Required invariants

- Unrelated packages never share a release counter.
- `.test` and `.alpha` are reserved for genuinely non-stable payloads.
- `Epoch` is never introduced to express a product release and is never reset.
- Minimum EVRs are used only for a demonstrated file or API requirement.
- Cross-component contracts use equality on a versioned virtual ABI.
- Fedora and KDE packages are never listed in `nabu-obsolete-packages`.
- A rename is owned by the replacement package with a bounded `Provides` and
  `Obsoletes`; a retired Nabu-only name may be listed centrally.
- A COPR release keeps one validated predecessor. Kernel retention follows the
  separately recorded boot/fallback policy rather than the generic limit.

## Legacy kernel normalization

Existing epochs are compatibility history. The next real 6.17 release uses
`Epoch: 1`, `Version: 6.17.0`; the next real mainline release uses `Epoch: 2`,
`Version: 7.2.0`. Channel and Nabu revision belong in `Release`. No no-op kernel
is published solely to make the displayed EVR prettier.
