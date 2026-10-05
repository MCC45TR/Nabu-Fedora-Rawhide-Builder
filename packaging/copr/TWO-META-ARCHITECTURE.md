# Nabu two-meta release architecture

## Release contract

Every installable Nabu release is represented by exactly two top-level RPMs:

1. `nabu-core-meta` owns the hardware dependency manifest, repository
   configuration and kernel/UKI control plane.
2. Exactly one DE manifest is installed: `kde-plasma-nabu-meta`,
   `kde-plasma-mobile-nabu-meta`, `gnome-nabu-meta`,
   `gnome-mobile-nabu-meta` or `phosh-nabu-meta`.

The two release RPMs now carry Nabu-owned system policy, local services,
desktop configuration, widgets, branding and locale payloads directly. Only
true ABI/alternative boundaries remain independent: kernels, firmware,
HexagonRPC/libssc/IIO native libraries and the selectable boot-manager family.
Users and image builders still install only the two release manifests.

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

All DE manifests require `glibc-all-langpacks` and directly own the Nabu locale
policy. KDE manifests additionally carry the Plasma Shell catalogs; Plasma
Desktop also carries Plasma Setup catalogs. Locale correctness is not delegated
to weak dependencies, image history or a separately versioned helper RPM.

## Migration map

| New package | Replaces |
|---|---|
| `nabu-core-meta` | Old CORE/control metas plus system/runtime integration, flashlight/USB tools, SAR service, SSC probe and retired suspend diagnostics |
| `kde-plasma-nabu-meta` | Plasma profiles plus KDE config/ICC, widgets, locale catalogs, login branding and Plasma tablet-control UI |
| `kde-plasma-mobile-nabu-meta` | KDE Mobile profiles plus shared KDE config/ICC, widgets, locale catalogs, login branding and Plasma tablet-control UI |
| `gnome-nabu-meta` | GNOME profiles, locale policy and GNOME tablet-control UI |
| `gnome-mobile-nabu-meta` | GNOME Mobile profiles, locale policy and GNOME tablet-control UI |
| `phosh-nabu-meta` | Posh/Phosh profiles and locale policy |

The first `dnf update` performs the name transition through RPM obsoletes. The
installed kernel payloads, Android entry and known-good fallback are outside
the transition and remain protected.

The CORE package performs the unambiguous retirement of the old shared Plasma
login-theme RPM. The mutually exclusive KDE DE manifests own the replacement
files and provide the compatibility ABI, so no independently versioned theme
package remains.
