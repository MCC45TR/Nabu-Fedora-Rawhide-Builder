# SENEMOS Nabu KDE packages

COPR-ready Fedora Rawhide packages for the Xiaomi Mi Pad 5 (nabu).

The source package produces three noarch RPMs:

- `nabu-runtime-integration`: desktop-independent device services and policy;
- `nabu-kde-config`: Fedora stock KWin, KDE, SDDM, safe lid locking and stable
  audio integration;
- `nabu-kde-integration`: the single-install KDE metapackage.

The kernel, libssc, iio-sensor-proxy and hexagonrpc packages contain AArch64
machine code and therefore remain separate aarch64 packages in the same COPR.
The corrected alsa-ucm-conf-sm8150 and widget packages are separate noarch
packages to preserve clean RPM file ownership and upgrade paths.

Build locally with ./build-rpm.sh. Upload the resulting source RPM from
out/srpm to a Fedora Rawhide COPR project. The intended COPR chroot is
fedora-rawhide-aarch64; the resulting packages from this source are noarch.

Installing the metapackage is intended to be the public entry point:

    sudo dnf install nabu-kde-integration

Run senemos-nabu-status after boot to verify the device integration. This
package does not claim to solve deep sleep beyond s2idle, DT2W, UFS boot
determinism, four-speaker amplifier tuning, or EL2/KVM firmware handoff.

The runtime integration grants user sessions only real-time priority 1. This
is the minimum requested by unmodified KWin for compositor, input and DRM
commit threads; KWin's upstream dynamic buffering policy remains untouched.

The sensor runtime keeps Android persist read-only and gives SSC a volatile,
writable registry copy below `/run`. On the physically tested Nabu, SSC
publishes the STMicro LSM6DSO accelerometer and ams AG TCS3701 ambient-light
sensor. The factory registry's ROHM BU27030 entries are named `bu27030_back`
and describe the secondary/rear light sensor; they must not replace TCS3701 as
the primary ALS identity. ADUX1050 proximity calibration is present, but live
proximity publication has not been established.

The internal panel has a fixed native 2560x1600 landscape timing. Select a
safe logical workspace size without sending an unverified non-native timing
to the DSI panel:

    senemos-nabu-display-profile native
    senemos-nabu-display-profile fhd   # 1920x1200 landscape
    senemos-nabu-display-profile hd    # 1280x800 landscape

The FHD-class and HD-class profiles retain the native 16:10 aspect ratio;
exact 1920x1080 and 1280x720 modes would require cropping or stretching.
