# Mutter auto-rotation override for Nabu

This COPR package keeps Fedora's `mutter` package name and upgrades Rawhide's
51.beta build to the checksum-locked GNOME 51.rc source.

Mutter 51.beta can underflow the orientation tracking inhibit counter before the
initial sensor read. GNOME Shell then never claims the accelerometer even though
iio-sensor-proxy reports a valid orientation. GNOME 51.rc contains upstream
commit `25e48d8b3f0905fa38c07340e17b0f59938d44c2`, which tracks the unmanaged
inhibit state explicitly and makes the initial sensor claim possible.

The `51~rc-1.nabu1` EVR is newer than Fedora's current `51~beta-1`, while a
future final GNOME 51 package naturally supersedes this temporary override.

Run `./test-source.sh` before `./build-srpm.sh`.
