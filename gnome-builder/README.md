# GNOME image builder

`build-gnome.sh` applies a stock Fedora Rawhide GNOME layer to a copy of a
verified CORE image. It does not rebuild or replace the CORE alpha kernel,
`nabu-core-meta`, rEFInd UKI or Android-return entry.

The default profile is `minimal`; `optimal` adds the GNOME application set
maintained in `profile.env`. GNOME meta packages are intentionally not a hard
dependency until their independent COPR builds exist. The image still keeps
the Nabu COPR repository and verifies GPG-signed DNF transactions.

Example:

```console
gnome-builder/build-gnome.sh \
  --core-system /path/to/core-system.img \
  --core-esp /path/to/core-esp.img \
  --profile minimal \
  --runtime podman \
  --output /tmp/nabu-gnome
```

The builder clones both input images before mounting anything, restores RPM
ownership after the FUSE mutation, checks the future Rawhide DNF solver, and
fails if the final EXT4 root contains UID/GID 65534 (`nobody`).
