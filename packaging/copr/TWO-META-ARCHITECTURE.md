# Nabu two-meta release architecture

## Release contract

Every installable Nabu release is represented by exactly two top-level RPMs:

1. `nabu-core-meta` owns the hardware dependency manifest, repository
   configuration and kernel/UKI control plane.
2. Exactly one DE manifest is installed: `kde-plasma-nabu-meta`,
   `kde-plasma-mobile-nabu-meta`, `gnome-nabu-meta`,
   `gnome-mobile-nabu-meta` or `phosh-nabu-meta`.

Architecture-specific libraries, firmware, kernels and services remain
independent implementation RPMs. They have different ABI, licensing, build and
physical-validation lifecycles; merging their payloads would make updates less
safe rather than simpler. Users and image builders install only the two release
manifests, which pull every implementation RPM through hard dependencies.

## Kernel policy

`nabu-core-meta` has a rich hard dependency requiring at least one of stable,
alpha, mainline or the reserved future LTS selector. Alpha is a weakly
recommended default, not an exclusive branch. Existing kernel families satisfy
the hard dependency and may coexist. Kernel core/modules keep install-only
semantics and are never obsoleted by control packages.

`nabu kernel use FAMILY` installs and selects a preferred UKI family;
`nabu kernel add FAMILY` adds a fallback. Neither command reboots or removes a
kernel. The old `nabu branch` spelling remains an alias.

## Dependency updates and removals

Adding a hard `Requires` to either manifest distributes a new component through
ordinary `dnf update`. Removing a `Requires` does not safely uninstall a package
on RPM systems. A removed or renamed Nabu-owned package therefore gets a
bounded, versioned `Obsoletes` in its replacement manifest. Fedora, KDE and
third-party package names must never appear in that retirement list.

## Locale contract

All DE manifests require `glibc-all-langpacks` and `nabu-language-support`.
KDE manifests additionally require `nabu-kde-l10n`; Plasma Desktop also
requires `nabu-plasma-setup-l10n`. Locale correctness is not delegated to weak
dependencies, image history or a one-time setup script.

## Migration map

| New package | Replaces |
|---|---|
| `nabu-core-meta` | `nabu-meta`, `nabu-core-base`, three branch metas, repository config, branch manager, kernel maintenance, obsolete-package manifest and desktop migration helper |
| `kde-plasma-nabu-meta` | Plasma base and minimal/optimal metas |
| `kde-plasma-mobile-nabu-meta` | KDE Mobile base, minimal/optimal metas and legacy mobile setup |
| `gnome-nabu-meta` | GNOME base and minimal/optimal metas |
| `gnome-mobile-nabu-meta` | GNOME Mobile base and minimal/optimal metas |
| `phosh-nabu-meta` | Posh base and minimal/optimal metas |

The first `dnf update` performs the name transition through RPM obsoletes. The
installed kernel payloads, Android entry and known-good fallback are outside
the transition and remain protected.

The Plasma login theme stays an independently versioned implementation RPM
required by both KDE manifests. Moving its files into both mutually exclusive
DE packages would give DNF two competing replacements for the same installed
package during migration.
