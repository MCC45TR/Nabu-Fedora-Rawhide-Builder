# Nabu COPR channel policy

## Channels

- `mcc45tr/nabu-linux` is the stable channel. It must never consume or depend on
  `nabu-linux-test`.
- `mcc45tr/nabu-linux-test` is the candidate channel. Its build chroots may use
  `nabu-linux` as a dependency base, and test images enable it at higher DNF
  priority.

Candidate packages use the next normal NVR in the test channel. A `.test`
suffix is not used as a substitute for isolation. The repository boundary is
the isolation mechanism.

## Promotion gate

The exact candidate source is eligible for a stable rebuild only after all of
these gates pass:

1. source syntax, patch, archive checksum and SRPM tests;
2. terminal COPR success for every supported AArch64 chroot;
3. signed Rawhide AArch64 package download and dependency-solver verification;
4. recovery image checks, including exact UKI kernel, DTB and uname matching;
5. device HIL for boot time, display/touch, Wi-Fi, Bluetooth, built-in audio,
   rotation, brightness sensors, suspend/resume and ESP32-S3 CDC recovery.

Promotion rebuilds the checksum-recorded candidate SRPM in `nabu-linux` and
records both COPR build IDs. Candidate binaries are not copied blindly because
the two projects have independent signing keys and repository metadata.

If HIL fails, increment the NVR in `nabu-linux-test`; never replace or erase a
published stable build.
