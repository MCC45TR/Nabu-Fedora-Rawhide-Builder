# Material Decoration for Nabu COPR

This package builds [guiodic/material-decoration](https://github.com/guiodic/material-decoration)
as an optional Qt 6/C++ KWin decoration. It does not patch KDE packages or
change the user's selected decoration. The source archive is pinned to a Git
commit and verified against `upstream.sha256` before producing the SRPM.

The daily `material-decoration-update.yml` workflow checks upstream `master`,
updates the pinned commit/version/hash, and pushes the source-lock change to
`main`. The COPR SCM package uses `make_srpm` and auto-rebuild on the project's
GitHub webhook. COPR is limited to `fedora-rawhide-aarch64` for this package.
If the upstream source stops compiling against Rawhide KWin, the prior
successful RPM remains available; the updater never installs anything on a
tablet.

Local source test:

```sh
./build-srpm.sh /tmp/material-decoration-rpmbuild
```

Tablet installation, once the COPR build succeeds:

```sh
sudo dnf copr enable mcc45tr/nabu-linux
sudo dnf install material-decoration
```

Selecting the decoration remains an explicit user choice in System Settings.
