# GNOME Extension Group

One Fedora source package produces a small catalog package and three fully
independent extension RPMs:

- `gnome-shell-extension-convergence`
- `gnome-shell-extension-touchup`
- `gnome-shell-extension-touchshell`

The packages do not depend on one another. Installing `gnome-extension-group`
only installs this catalog document; it deliberately does not select all three
extensions. Use DNF to install any desired extension package by name.

The extension files are installed system-wide. Enable each extension from the
GNOME Extensions application after logging into a compatible GNOME session.

The packaged downstream source forks are:

- https://github.com/MCC45TR/convergence-shell
- https://github.com/MCC45TR/gnome-extension-touchup
- https://github.com/MCC45TR/touchshell

The fourth archive contains the native Nabu hardware-control extension; the
Fastfetch archive contains only SENEMOS configuration and does not replace the
Fedora executable.  COPR SCM builds verify the committed source set through Git
and the following SHA-256 identities:

```
6ce5455c68202eba5378456d62e13de09e6aa74add093a229def3f1cae5ce76a  convergence-shell.zip
5521ef2b23a95678d11961d0096f97ca9af9cf276df09be547ef4511e7463bf0  nabu-tablet-controls.zip
07e036ed6dac3c0a749106362c42da2a333e7179b1cbff929f4f47d87c0e3571  touchshell.zip
be8b1c2cceed36834974f2006004d5bfa374c9e3578badd80dd319b47685ab56  touchup.zip
75812eeaf5118f3201763f48259a835cea8d97f07f4136a5ee2b2fd2e1fff8c2  senemos-fastfetch-config-1.3.0.tar.gz
```
