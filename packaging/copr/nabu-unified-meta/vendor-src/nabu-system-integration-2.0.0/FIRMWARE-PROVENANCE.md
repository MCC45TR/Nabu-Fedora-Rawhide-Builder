# Nabu firmware provenance

`nabu-system-integration` contains no firmware blobs. It has explicit runtime
dependencies on Fedora's `qcom-firmware` and `atheros-firmware` packages and on
the separately maintained `xiaomi-nabu-firmware` package.

The Xiaomi package contains device-extracted third-party firmware. Its RPM
metadata identifies `https://gitlab.postmarketos.org/panpanpanpan/nabu-firmware`
as the source and currently records `LicenseRef-Unknown`; it must therefore be
reviewed and distributed independently under the firmware owner's terms. This
integration package neither relicenses nor duplicates those files.

The dependency is intentional: removing `xiaomi-nabu-firmware` also removes the
Nabu hardware profile instead of leaving an apparently installable system with
non-functional WLAN, audio DSP, touch or sensor firmware.
