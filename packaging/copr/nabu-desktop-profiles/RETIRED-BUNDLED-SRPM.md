# Retired bundled source package

`nabu-desktop-profiles.spec` was retired on 2026-08-28. It previously emitted
repository, CORE, desktop, login transition, and session packages from one
source build with one shared release counter. Rebuilding it would reintroduce
cross-component EVR coupling and obsolete Fedora/KDE packages.

The replacements are the independently visible source packages in sibling
directories. Package retirement metadata belongs only in
`nabu-obsolete-packages`; explicit optional cleanup belongs in
`nabu-desktop-migration`.
