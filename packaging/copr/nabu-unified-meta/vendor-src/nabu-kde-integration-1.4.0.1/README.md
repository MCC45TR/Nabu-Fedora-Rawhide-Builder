# SENEMOS Nabu KDE packages

COPR-ready Fedora Rawhide packages for the Xiaomi Mi Pad 5 (nabu).

The source package produces native-architecture RPMs because the runtime
helpers are C++/QtCore binaries:

- `nabu-kde-color-profiles`: checksum-validating, explicit KScreen ICC
  selection tooling;
- `nabu-kde-config`: Fedora stock KWin, safe display policy and stable
  audio integration;
- `nabu-kde-integration`: the single-install KDE metapackage.

The kernel, libssc, iio-sensor-proxy and hexagonrpc packages remain separate
AArch64 packages in the same COPR. The corrected alsa-ucm-conf-sm8150 and
widget packages preserve clean RPM file ownership and upgrade paths.

Create the source archive, build an SRPM with `rpmbuild -bs`, and submit that
SRPM to the Nabu Linux COPR. The project targets Fedora 43, 44, 45 and Rawhide
on AArch64.

Installing the metapackage is intended to be the public entry point:

    sudo dnf install nabu-kde-integration

Run senemos-nabu-status after boot to verify the device integration. This
package does not claim to solve deep sleep beyond s2idle, DT2W, UFS boot
determinism, four-speaker amplifier tuning, or EL2/KVM firmware handoff.

The internal panel has a fixed native 2560x1600 landscape timing. Select a
safe logical workspace size without sending an unverified non-native timing
to the DSI panel:

    senemos-nabu-display-profile native
    senemos-nabu-display-profile fhd   # 1920x1200 landscape
    senemos-nabu-display-profile hd    # 1280x800 landscape

The FHD-class and HD-class profiles retain the native 16:10 aspect ratio;
exact 1920x1080 and 1280x720 modes would require cropping or stretching.

## Android factory color modes on Linux

Android's QDCM XML is proprietary Qualcomm calibration data, not an ICC
profile. It must not be renamed to `.icc`. The package installs the four
converted, panel-specific ICC v4 outputs in
`/usr/share/color/icc/senemos/nabu/`; the proprietary source XML itself is
not included. Fedora's KScreen and KWin packages remain completely stock. The
four ICC files are installed in the system color-profile catalog, but no
profile is selected at login and no user-session service changes KScreen
state. This intentionally leaves the active profile under user control. The
runtime exposes no automatic-application command.
The application menu exposes **Nabu Color Profiles / Nabu Renk Profilleri**;
it lists all four packaged profiles and applies the selection through the
public `kscreen-doctor` interface. Stock Display Configuration then reports
the standard `ICC profile` source and the selected system path.

KWin's `Built-in` label is specifically its EDID colorimetry source. Nabu's
internal DSI panel has no EDID, and that path does not execute the Qualcomm
IGC/3D-LUT/GC calibration stored in these ICC files. The package therefore
does not fake an EDID or relabel ICC as `Built-in`: doing so would visibly
claim calibration while bypassing it.

`senemos-nabu-color-profile` is a native C++ utility that validates and
explicitly applies the packaged profiles:

    senemos-nabu-color-profile catalog
    senemos-nabu-color-profile validate /usr/share/color/icc/senemos/nabu/xiaomi-nabu-36-02-0b-srgb.icc
    senemos-nabu-color-profile apply srgb --panel 36-02-0b --dry-run
    senemos-nabu-color-profile apply srgb --panel 36-02-0b

The build-time conversion recognizes the `36_02_0b` and `42_02_0a` panel
variants and keeps their output files separate. It converts only Android's static SDR
`hal_srgb` (ModeID 3) and `hal_dci_p3` (ModeID 36) pipelines. The resulting
ICC files are RGB display-class profiles with an XYZ PCS and KWin-compatible
`B2A0`/`B2A1` 33x33x33 LUTs.

`native` cannot be described because the XML does not contain measured panel
primaries. `smart_MC` is content-aware, the `GM_*` and `video*` modes use
Qualcomm PA-v2 operations, and `hal_hdr` includes Android HDR metadata and
tone mapping. Those modes are deliberately not mislabeled as ordinary SDR
ICC profiles.

The conversion reproduces the documented IGC, fine 3D LUT and GC stages. It
does not constitute colorimeter validation or prove pixel-for-pixel equality
with Android's complete proprietary display HAL. Select only the entry that
matches the panel revision; the profiles remain explicitly experimental until
physical color accuracy is verified.
