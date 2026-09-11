# Nabu Plymouth runtime backport

This recipe reproduces Fedora's `plymouth-26.134.222` source package from
dist-git commit `790078da1921e40036ee0326bc9a7959111813ff` and adds only upstream
commit `88c8dd8d9e894bcd8343e5ae3b2c8baca4035fa5`.

The backport prevents the script plugin from calling
`ply_console_viewer_hide(NULL)`. It can be retired as soon as Fedora ships a
Plymouth snapshot containing that upstream commit. The SENEMOS theme stays in
its separate `senemos-nabu-plymouth` package.
