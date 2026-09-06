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
