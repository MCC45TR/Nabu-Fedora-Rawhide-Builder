# Nabu Fedora Rawhide Builder

`Nabu-Fedora-Rawhide-Builder.sh` composes Fedora Rawhide **aarch64** root
filesystem images, signed Unified Kernel Images (UKIs), and FAT32 ESP images
for the Xiaomi Pad 5 (`nabu`). The implementation is one auditable Bash file;
all package, filesystem, UKI, and ESP work runs inside a rootless Podman
container by default.

The builder never flashes a tablet and never creates an ISO, Android
`boot.img`, or whole-disk GPT image. Existing projects and RPM output trees are
mounted read-only. Only this project's `work/`, `cache/`, and `output/`
directories are writable.

## Quick start

From the workspace root:

```bash
cd Nabu-Fedora-Rawhide-Builder
chmod +x Nabu-Fedora-Rawhide-Builder.sh
./Nabu-Fedora-Rawhide-Builder.sh doctor
./Nabu-Fedora-Rawhide-Builder.sh --dry-run
```

`doctor` checks required host commands, Podman availability/rootless status,
the cached Rawhide image, host architecture, FUSE, writable runtime paths, and
the permissions/readability of the conventional `secure/db.key` and
`secure/db.crt` files. Warnings do not fail the command; missing hard
requirements do.

The dry-run is a real preflight. It starts Fedora Rawhide in Podman, resolves
current aarch64 compose/group/package metadata, inventories and validates the
local Nabu RPMs, creates an isolated local repository, performs dependency
closure, checks the kernel family, and evaluates Secure Boot inputs. It does
not create an image.

For a strict real build, use a signing certificate that is already enrolled in
the target UEFI trust database:

```bash
./Nabu-Fedora-Rawhide-Builder.sh \
  --desktop kde-plasma \
  --filesystem ext4 \
  --shell bash \
  --secure-boot on \
  --sb-key /secure/db.key \
  --sb-cert /secure/db.crt \
  --uefi-trusted-cert /secure/db.crt \
  --non-interactive
```

Private key paths and contents are never written to reports. Manifests contain
only SHA-256 certificate fingerprints. `--generate-development-sb-key` creates
an ephemeral private key and publishes only its enrollment certificate; it is
not accepted as verified strict Secure Boot until the certificate is trusted
by the device firmware.

## Defaults

- Desktop: `kde-plasma`
- Filesystem: `ext4`
- User shell: `bash`
- Secure Boot: `on`
- Bootloader: `systemd-boot`
- Fedora parity: `strict`
- Core/final/ESP sizes: `6G` / `12G` / `350M`
- Compression: Zstandard level `10`
- Locale/timezone/keyboard: `en_US.UTF-8` / `UTC` / `us`
- Architecture and image backend: `auto`

The default build mode is `verbose` while the Nabu first-boot path is being
validated. In this mode the UKI keeps the framebuffer rotation parameter
`fbcon=rotate:1` but omits `quiet splash`, so kernel and first-boot messages
remain visible. Use `--build=release` for a quieter UKI with `quiet splash`.
The existing `--debug` and `--trace` options continue to control builder-side
diagnostic logging.

Use `./Nabu-Fedora-Rawhide-Builder.sh --help` for all profile, reuse,
filesystem, bootloader, repository, cache, logging, and safety options.

## Tests

The project includes 21 fast tests for argument parsing, validation helpers,
desktop/size rules, Secure Boot safeguards, doctor dispatch, and privileged
container opt-in behavior:

```bash
make test
# or run syntax checks as well
make check
```

The test script emits TAP output and can also be run directly as
`./tests/test_builder.sh`.

## Optional privileged container mode

The default remains rootless and unprivileged. `--privileged` explicitly adds
Podman's privileged container flag for environments that require it:

```bash
./Nabu-Fedora-Rawhide-Builder.sh --privileged [other build options]
```

This substantially weakens device and host security isolation. It does not
add host filesystem bind mounts, but privileged containers may see host
devices. The selected mode is recorded in the build manifest and Secure Boot
report, and the builder prints a warning whenever it is enabled.

## Core-first workflow

The pipeline resolves Fedora's official `core` and `hardware-support` groups,
installs the selected Nabu runtime RPM family, configures first boot without a
fixed user or password, and validates the common core before cloning it for
desktop variants. A core/EFI gate failure stops the entire build. With
`--desktop all`, independently failed desktop variants are recorded while
verified variants can still be published with exit code `20`.

Supported profiles are KDE Plasma, KDE Mobile, GNOME, GNOME Mobile (only when a
real mobile session exists for aarch64), Phosh, and No Desktop. Ext4 and Btrfs
are supported. Final images are first written with a `.partial` suffix and are
renamed atomically only after validation.

## Local packages and Rawhide compatibility

RPM selection uses RPM EVR ordering and requires one matching
`kernel-nabu`/`kernel-nabu-core`/`kernel-nabu-modules` family. Runtime images
exclude `kernel-nabu-devel`. RPM payload digests, dependencies, provides,
conflicts, scripts, architecture, NEVRA, source RPM, and SHA-256 are recorded.

Official Fedora repositories retain package signature checking. `gpgcheck=0`
is scoped only to the temporary local repository because the discovered Nabu
RPMs are unsigned. Current Rawhide renamed `systemd-zram-generator` to
`zram-generator`; when the older capability is required, the builder generates
a documented metadata-only compatibility RPM that depends on the current
Fedora implementation.

## Outputs

Every run uses `output/rawhide-YYYYMMDD-HHMMSS-ID/` and contains, as applicable:

- `SUMMARY.md`: the short human-readable result and links to the important files;
- `STATUS.json`: atomically updated machine-readable run state, elapsed seconds,
  weighted stage progress, and estimated remaining seconds;
- `artifacts/rootfs/`: compressed core and desktop filesystem images;
- `artifacts/boot/`: ESP image, EFI-files ZIP, stable `esp.zip` EFI archive,
  and enrollment files;
- `reports/`: Rawhide, Secure Boot, validation, first-boot, parity, and failed
  variant reports;
- `metadata/`: the JSON build manifest, package inventories, fingerprints, and
  focused diagnostics;
- `logs/`: the main log, per-component logs, and structured JSONL events;
- `SHA256SUMS`: checksums for published reports, metadata, and artifacts.

Failed runs also contain `FAILURE.md`, including the failed stage, command,
relevant log tail, and a focused diagnostic when available. `output/latest`
points to the latest completed/partial run and `output/latest-failed` points to
the latest failed run.

The builder takes a project-wide lock so two runs cannot mutate the shared
cache simultaneously. Published images use a `.partial` file followed by an
atomic rename. Work and cache directories are preserved after a real failure
for diagnosis and retry; successful runs still follow `--keep-work` and
`--keep-cache`. Unsafe automatic `--resume` is rejected—validated `--reuse-core`
or `--from-core` is required instead.

Generated output, cache, work trees, private keys, and image files are ignored
by Git.

## Desktop notifications

With `--notify` (the default), one desktop notification is updated as the build
moves through its 24 stages instead of creating a separate notification for
every stage. It shows the current stage/component, active desktop/filesystem,
elapsed time, weighted phase progress, and a stage-based remaining-time
estimate. The estimate is deliberately labelled approximate because package
downloads, compression, multiple filesystems, and desktop variants can change
the duration substantially.

The final notification distinguishes `COMPLETE`, `PREFLIGHT_PASS`, `PARTIAL`,
and `FAILED`. Success includes completed variant and artifact/report counts;
failure includes the preserved cause, exit code, failure stage, elapsed time,
estimated time remaining at failure, and paths to `FAILURE.md` and the main
log. Clicking the final notification opens the run output directory through
`xdg-open` when the notification server supports actions. KDE also receives a
file URL hint for the same directory.

Notification text and stage names follow the host `LC_ALL`, `LC_MESSAGES`, or
`LANG`: `tr*` locales use Turkish and other locales use English. Notifications
are automatically skipped in CI or when no graphical D-Bus desktop session is
available, and can always be disabled with `--no-notify`.

## Host requirements and current verification boundary

The host needs Bash, Podman, GNU core utilities, network access, and either a
native aarch64 CPU or working aarch64 binfmt registration for a real build. An
x86_64 host without binfmt can still run the full repository/RPM dry-run using
DNF5 `--forcearch=aarch64`; real RPM scriptlets are deliberately refused in
that configuration.

Image creation normally uses rootless libguestfs/FUSE. The loop backend remains
fail-closed in the current implementation; selecting `--privileged` does not
silently switch image backends. Full hardware boot, touch, audio, Wi-Fi,
suspend, orientation, and UEFI trust enrollment must be verified on a Xiaomi
Pad 5 and are reported as `NOT_RUN` by software-only builds.

## Exit codes

`0` success, `1` general, `2` arguments, `3` local RPMs, `4` container/arch,
`5` Rawhide, `6` core, `7` kernel/DTB/initramfs, `8` Secure Boot/UKI, `9` ESP,
`10` filesystem, `11` desktop, `12` first boot, `13` strict parity, `20`
partial success, and `130` cancellation.

## License

MIT; see [LICENSE](LICENSE).
