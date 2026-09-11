# Nabu KDE image builder

This builder clones a freshly verified CORE system image and its ESP before adding the stable
`kde-plasma-nabu-meta` desktop layer. It never mounts or mutates the source images.

The final KDE contract locks root, contains no pre-created regular user, uses Plasma Login
Manager and Plasma Setup, masks the CORE CDC logger, and removes the CORE root-SSH recovery
policy. It retains exactly the CORE mainline kernel and copies the Android/SENEMOS7 ESP
byte-for-byte.

The build reinstalls owners of missing normal-state RPM locale files and fails if any remain;
it also fails on insufficient Plasma translation catalogs,
missing Nabu camera/Iris/sensor packages, a second kernel, test-COPR configuration, overflow
ownership, lost RPM special modes, invalid SELinux labels, or a changed ESP.

```bash
kde-builder/build-kde.sh \
  --core-system /path/to/core-system.img \
  --core-esp /path/to/core-esp.img
```
