# Nabu desktop profile migration

Release 1.0.0-22 provides one minimal and one optimal package for each session:

- `nabu-gnome-minimal-meta` / `nabu-gnome-optimal-meta`
- `nabu-gnome-mobile-minimal-meta` / `nabu-gnome-mobile-optimal-meta`
- `nabu-posh-minimal-meta` / `nabu-posh-optimal-meta` (installs Phosh)
- `nabu-plasma-minimal-meta` / `nabu-plasma-optimal-meta`
- `nabu-kde-mobile-minimal-meta` / `nabu-kde-mobile-optimal-meta`

Exactly one package from this list can be installed. Switch explicitly so DNF
can remove the old profile and incompatible session base in one transaction:

```console
sudo dnf install --allowerasing nabu-plasma-optimal-meta
```

Minimal profiles add only the session's software store and terminal. Optimal
profiles add the selected daily-use application set. GNOME Mobile currently
uses stock Fedora GNOME because Fedora 44 through Rawhide do not ship a
separate GNOME Shell Mobile session package; it contains no downstream shell
patches.

Beginning with release 1.0.0-23, every user-facing meta package is also an
independent source package and therefore appears as its own row on the COPR
Packages page. Shared session bases remain in `nabu-repository-config`.

## CORE branches

Beginning with release 1.0.0-26, a complete installation is composed from two
independent selections:

1. Exactly one CORE branch meta package:
   `nabu-core-stable-meta`, `nabu-core-alpha-meta` or
   `nabu-core-unstable-meta`.
2. Exactly one desktop profile meta package from the list above.

The kernel-independent hardware, boot, audio and sensor dependencies live in
`nabu-core-base`. Desktop session bases depend on the abstract
`nabu-core-branch` capability instead of naming a kernel package.

Use the packaged command to inspect or change the branch:

```console
nabu branch status
nabu branch list
nabu branch stable
nabu branch alpha
nabu branch unstable
```

Switching requires the caller's normal sudo authorization, installs the chosen
branch with DNF, regenerates its UKI and never reboots automatically. Previous
install-only kernel payloads may remain available as boot fallbacks. The
unstable 7.2 branch is published only for Rawhide and remains WIP.
