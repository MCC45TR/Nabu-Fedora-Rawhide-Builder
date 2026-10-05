%global debug_package %{nil}
%global limine_version 12.6.0

Name:           nabu-boot-integration
Version:        2.0.0
Release:        36.test%{?dist}
Summary:        Unified UKI infrastructure for Xiaomi Pad 5 (nabu)
License:        MIT AND BSD-2-Clause
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        %{name}-%{version}.tar.zst
BuildRequires:  coreutils
BuildRequires:  cpio
BuildRequires:  dracut
BuildRequires:  systemd-rpm-macros
BuildRequires:  zstd
Requires:       binutils
Requires:       cpio
Requires:       dracut
Requires:       kbd-misc
Requires:       systemd-ukify
Requires:       util-linux-core
Recommends:     xiaomi-nabu-firmware
Requires:       zstd
Provides:       nabu-uki-config = %{version}-%{release}
Obsoletes:      nabu-uki-config < %{version}-%{release}
Provides:       nabu-fedora-boot = %{version}-%{release}
Obsoletes:      nabu-fedora-boot < %{version}-%{release}

%description
Shared Nabu UKI, initramfs, console and kernel-install integration. Boot-manager
EFI installation is supplied by exactly one of the systemd-boot, rEFInd or
Limine selector subpackages. Authorized Nabu firmware is recommended but not
redistributed by this package; UKI generation fails closed when it is absent.

%package -n nabu-boot-systemd
Summary:        systemd-boot selector and automatic ESP integration for Nabu
Requires:       %{name} = %{version}-%{release}
Requires:       systemd-boot-unsigned
Provides:       nabu-boot-manager = 2.0.0.3
Provides:       nabu-systemd-boot-config = %{version}-%{release}
Obsoletes:      nabu-systemd-boot-config < %{version}-%{release}
Conflicts:      nabu-boot-refind
Conflicts:      nabu-boot-limine
Conflicts:      nabu-refind-config
Conflicts:      nabu-limine-config

%description -n nabu-boot-systemd
Selects systemd-boot, installs its AArch64 EFI binary and synchronizes the
current Nabu UKI plus the verified Android-return entry on the mounted ESP.

%package -n nabu-boot-refind
Summary:        Nabu rEFInd selector and automatic ESP integration
License:        GPL-3.0-or-later AND BSD-2-Clause AND AGPL-3.0-or-later AND OFL-1.1
Requires:       %{name} = %{version}-%{release}
Requires(post): systemd
Requires(posttrans): systemd
Requires(preun): systemd
Requires(postun): systemd
Provides:       bundled(rEFInd) = 0.14.2
Provides:       bundled(GopRotate) = 1.0
Provides:       nabu-boot-manager = 2.0.0.2
Provides:       nabu-refind-config = %{version}-%{release}
Obsoletes:      nabu-refind-config < %{version}-%{release}
Conflicts:      nabu-boot-systemd
Conflicts:      nabu-boot-limine
Conflicts:      nabu-systemd-boot-config
Conflicts:      nabu-limine-config

%description -n nabu-boot-refind
Selects rEFInd, installs the pinned Nabu AArch64 EFI application and synchronizes the
current Nabu UKI plus the verified Android-return entry on the mounted ESP.
It installs the Nabu rEFInd AArch64 build, bobafetthotmail/refind-theme-regular
at a dark 2x scale, and the pinned GopRotate driver. Native 1600x2560 GOP output
is rotated 270 degrees counter-clockwise to match the kernel's 90-degree panel
orientation. Automatic rotation, touch and USB input drivers are not included.
The nabu-refind command reports status and performs a guarded manual sync;
package upgrades queue the same synchronization after the DNF transaction.

%package -n nabu-boot-limine
Summary:        Limine selector and automatic ESP integration for Nabu
License:        MIT AND BSD-2-Clause
Requires:       %{name} = %{version}-%{release}
Provides:       nabu-boot-manager = 2.0.0.1
Provides:       nabu-limine-config = %{version}-%{release}
Obsoletes:      nabu-limine-config < %{version}-%{release}
Conflicts:      nabu-boot-systemd
Conflicts:      nabu-boot-refind
Conflicts:      nabu-systemd-boot-config
Conflicts:      nabu-refind-config

%description -n nabu-boot-limine
Selects Limine and installs the official Limine %{limine_version} AArch64 UEFI
binary with a generated Nabu UKI and verified Android-return configuration.

%prep
%autosetup

%build

%check
bash -n payload/usr/bin/nabu-regenerate-uki
bash -n payload/usr/libexec/senemos-nabu/kernel-build-identity
grep -Fq 'plymouth.enable=0' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'systemd.show_status=yes' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'systemd.log_level=info' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'rd.udev.log_level=info' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'no_console_suspend' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'ignore_loglevel' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'log_buf_len=8M' payload/usr/bin/nabu-regenerate-uki
grep -Fq '/usr/lib/senemos-nabu/verbose-uki.d' payload/usr/bin/nabu-regenerate-uki
grep -Fq '/usr/lib/senemos-nabu/uki-version.d' payload/usr/bin/nabu-regenerate-uki
grep -Fq 'build_version =~ ^[0-9]{10}$' payload/usr/bin/nabu-regenerate-uki
grep -Fqx 'compress="zstd -15 -q -T2"' payload/usr/lib/dracut/dracut.conf.d/91-nabu-responsive-compression.conf
grep -Fq 'zstd -T2 -15 -q -o "$normalized"' payload/usr/libexec/senemos-nabu/sanitize-initramfs
bash tests/test-kernel-build-identity.sh
grep -Fq 'managed_uki_family' manager/nabu-configure-boot-manager
grep -Fq 'SENEMOS[0-9]+(LTS|U)?' manager/nabu-configure-boot-manager
grep -Fq 'SENEMOS7U' tests/test-boot-manager.sh
grep -Fq 'refind-local.conf' manager/nabu-configure-boot-manager
grep -Fqx "            echo 'scanfor manual'" manager/nabu-configure-boot-manager
grep -Fq 'menuentry "Reboot to Android"' manager/nabu-configure-boot-manager
grep -Fq -- '--family SENEMOS_FAMILY' payload/usr/bin/nabu-regenerate-uki
grep -Fqx 'resolution 1600 2560' manager/refind-theme-regular/theme.conf
grep -Fqx 'big_icon_size 256' manager/refind-theme-regular/theme.conf
grep -Fqx 'small_icon_size 96' manager/refind-theme-regular/theme.conf
grep -Fqx 'font themes/refind-theme-regular/fonts/source-code-pro-extralight-28.png' manager/refind-theme-regular/theme.conf
grep -Fq 'EFI_VENDOR_DIR=/boot/efi/EFI/fedora' payload/etc/kernel/nabu-uki.conf
printf '%s  %s\n' \
    2bd8737e65723645db14a122cfef7a4d9b0a793b08351df9e6f7838a45d7aa96 \
    manager/refind-theme-regular/icons/256-96/os_fedora.png | sha256sum -c -
printf '%s  %s\n' \
    524d6a0ddecf5ec150b6e8b9b124ebe7dcfda72bb26824dab21a8e4537aaf708 \
    manager/refind-theme-regular/icons/256-96/os_android.png | sha256sum -c -
grep -Fqx '            echo '\''rotation 3'\''' manager/nabu-configure-boot-manager
printf '%s  %s\n' \
    c563b52e4068d2e8a836c43b10465b4ea066ca7f3d1266107b6b11698270ee4c \
    manager/refind/refind_aa64.efi | sha256sum -c -
printf '%s  %s\n' \
    23cde353a5bf5d85c2bf45e8ae6db0074d826643b69c39dd42c4bdf6e2e43a89 \
    manager/refind/drivers_aa64/GopRotate_aa64.efi | sha256sum -c -
bash -n payload/usr/libexec/senemos-nabu/sanitize-initramfs
bash -n manager/nabu-configure-boot-manager
bash -n manager/nabu-refind
bash -n manager/nabu-refind-sync
bash tests/test-sanitize-initramfs.sh
bash tests/test-boot-manager.sh
grep -Fq 'copy_tree_fat_safe' manager/nabu-configure-boot-manager
grep -Fq 'EFI/BOOT/BOOTAA64.EFI' manager/nabu-refind
grep -Fqx '0.14.2' manager/refind/VERSION
printf '%s  %s\n' \
    1824330fe1966d4d3a45933a0619b8104a22e0ffedfa6a5c5c133f9868e8d4c6 \
    manager/limine-%{limine_version}-BOOTAA64.EFI | sha256sum -c -

%install
cp -a payload/etc payload/usr %{buildroot}/
install -Dm0755 manager/nabu-configure-boot-manager \
    %{buildroot}%{_bindir}/nabu-configure-boot-manager
install -Dm0755 manager/nabu-refind \
    %{buildroot}%{_bindir}/nabu-refind
install -Dm0755 manager/nabu-refind-sync \
    %{buildroot}%{_libexecdir}/nabu-refind-sync
install -Dm0644 manager/nabu-refind-sync.service \
    %{buildroot}%{_unitdir}/nabu-refind-sync.service
install -Dm0644 manager/nabu-refind-sync.path \
    %{buildroot}%{_unitdir}/nabu-refind-sync.path
install -Dm0644 manager/90-nabu-refind-sync.preset \
    %{buildroot}%{_presetdir}/90-nabu-refind-sync.preset
install -Dm0644 manager/nabu-refind.8 \
    %{buildroot}%{_mandir}/man8/nabu-refind.8

install -Dm0644 manager/loader.conf \
    %{buildroot}%{_datadir}/nabu/bootloader/systemd-boot/loader.conf
install -Dm0644 manager/android.conf \
    %{buildroot}%{_datadir}/nabu/bootloader/systemd-boot/android.conf
install -Dm0644 manager/systemd-boot.selected \
    %{buildroot}%{_prefix}/lib/nabu-boot/managers/systemd-boot.selected
install -Dm0644 manager/refind.selected \
    %{buildroot}%{_prefix}/lib/nabu-boot/managers/refind.selected
install -d -m0755 \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/refind-theme-regular
install -Dm0644 manager/refind-theme-regular/theme.conf \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/refind-theme-regular/theme.conf
cp -a manager/refind-theme-regular/icons manager/refind-theme-regular/fonts \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/refind-theme-regular/
install -Dm0644 manager/refind/refind_aa64.efi \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/refind_aa64.efi
install -Dm0644 manager/refind/VERSION \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/VERSION
install -Dm0644 manager/refind/drivers_aa64/GopRotate_aa64.efi \
    %{buildroot}%{_datadir}/nabu/bootloader/refind/drivers_aa64/GopRotate_aa64.efi
install -Dm0644 manager/limine.selected \
    %{buildroot}%{_prefix}/lib/nabu-boot/managers/limine.selected
install -Dm0644 manager/limine-%{limine_version}-BOOTAA64.EFI \
    %{buildroot}%{_datadir}/nabu/bootloader/limine/BOOTAA64.EFI

%post -n nabu-boot-refind
%systemd_post nabu-refind-sync.path nabu-refind-sync.service

%posttrans -n nabu-boot-refind -p /usr/bin/bash
install -d -m0755 /var/lib/nabu-boot-maintenance
touch /var/lib/nabu-boot-maintenance/refind-sync.pending
if [[ -d /run/systemd/system ]]; then
    /usr/bin/systemctl --no-block start nabu-refind-sync.path >/dev/null 2>&1 || :
    /usr/bin/systemctl --no-block start nabu-refind-sync.service >/dev/null 2>&1 || \
        printf 'Warning: automatic rEFInd ESP synchronization is pending.\n' >&2
fi

%preun -n nabu-boot-refind
%systemd_preun nabu-refind-sync.path nabu-refind-sync.service

%postun -n nabu-boot-refind
%systemd_postun nabu-refind-sync.path nabu-refind-sync.service

%files
%license LICENSE
%config(noreplace) %{_sysconfdir}/kernel/nabu-uki.conf
%config(noreplace) %{_sysconfdir}/systemd/ukify.conf
%config(noreplace) %{_sysconfdir}/vconsole.conf
%{_bindir}/nabu-configure-boot-manager
%{_bindir}/nabu-regenerate-uki
%{_prefix}/lib/senemos-nabu/
%{_libexecdir}/senemos-nabu/
%{_prefix}/lib/dracut/modules.d/95nabu-dtb/
%{_prefix}/lib/dracut/dracut.conf.d/91-nabu-responsive-compression.conf
%{_prefix}/lib/kernel/install.d/95-nabu-uki.install
%dir %{_prefix}/lib/nabu-boot
%dir %{_prefix}/lib/nabu-boot/managers

%files -n nabu-boot-systemd
%{_prefix}/lib/nabu-boot/managers/systemd-boot.selected
%{_datadir}/nabu/bootloader/systemd-boot/

%files -n nabu-boot-refind
%license manager/refind-theme-regular/LICENSE
%license manager/refind/licenses/LICENSE-rEFInd-GPL-3.0
%license manager/refind/licenses/LICENSE-GopRotate-BSD-2-Clause
%doc manager/refind-theme-regular/README.upstream.md manager/refind-theme-regular/README.nabu.md
%doc manager/refind/PROVENANCE.md
%{_prefix}/lib/nabu-boot/managers/refind.selected
%{_datadir}/nabu/bootloader/refind/
%{_bindir}/nabu-refind
%{_libexecdir}/nabu-refind-sync
%{_unitdir}/nabu-refind-sync.service
%{_unitdir}/nabu-refind-sync.path
%{_presetdir}/90-nabu-refind-sync.preset
%{_mandir}/man8/nabu-refind.8*

%files -n nabu-boot-limine
%license manager/LICENSE-limine-BSD-2-Clause
%{_prefix}/lib/nabu-boot/managers/limine.selected
%{_datadir}/nabu/bootloader/limine/

%changelog
* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-36.test
- Keep exactly one loader manifest per SENEMOS family without a duplicate
  canonical alias.
- Remove stale loader manifests for rEFInd and Limine plus legacy image-builder
  Fedora EFI aliases while preserving Android and arbitrary user payloads.

* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-35.test
- Apply the same bounded zstd policy while normalizing the generated initramfs.

* Sat Sep 05 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-34.test
- Limit UKI zstd compression to two workers so post-update maintenance does
  not monopolize all Nabu CPU cores or cause interactive latency.

* Fri Sep 04 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-33.test
- Generate explicit rEFInd entries for one newest UKI per managed family.
- Hide legacy image aliases from automatic discovery and retain Android.
- Restore the five-second rEFInd timeout and prune stale family manifests.

* Thu Sep 03 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-32.test
- Scan the Fedora and Android EFI vendor directories explicitly.
- Show every managed UKI separately instead of folding same-directory kernels.

* Tue Sep 01 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-31.test
- Move managed and user EFI payloads to the standard EFI/fedora directory.
- Let rEFInd discover Fedora and Android loaders dynamically by vendor folder.
- Exclude EFI/BOOT and the legacy EFI/SENEMOS directory to prevent duplicates.
- Preserve a hash manifest and the previous rEFInd configuration during migration.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-29.test
- Align the RPM static family gate with the tested SENEMOS7U contract.

* Mon Aug 31 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-28.test
- Accept the isolated SENEMOS7U UKI family and queue mainline-unstable kernels.

* Sun Aug 30 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-26.test
- Restrict production rEFInd discovery to explicit manual entries
- Prevent duplicate Fedora and Android icons while retaining refind-local.conf

* Sun Aug 30 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-25.test
- Retain one latest UKI independently for SENEMOS6, SENEMOS7 and SENEMOS6LTS.
- Preserve unrecognized user EFI payloads and optional rEFInd local entries.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-24.test
- Install the supplied Fedora and Android artwork for their matching rEFInd
  entries and resolve manual-entry icon paths from the EFI volume root.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-23.test
- Accept the COPR uname form 6.17.0-senemos-YYMMDDHHMM in the shared identity
  helper while preserving the SENEMOS6-YYMMDDHHMM.efi output contract.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-22.test
- Converge an existing versioned rEFInd theme directory in place when an
  older package left pre-rewrite asset paths.
- Prevent the deferred path marker from repeatedly failing into start-limit.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-21.test
- Publish exactly one canonical Linux boot target for every manager.
- Remove fallback.conf and obsolete SENEMOS UKIs only after the new manager
  configuration is committed; preserve the independent Android return entry.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-20.test
- Commit a manager-neutral senemos.conf for rEFInd and Limine so deferred
  maintenance verifies the same canonical UKI used by the boot manager.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-19.test
- Retry a deferred rEFInd ESP synchronization automatically on the next boot.
- Enable a narrow systemd path unit only for the RPM-owned pending marker.
- Rewrite theme asset paths to the versioned EFI/BOOT theme directory.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-18.test
- Copy hard-linked theme assets to FAT32 as independent regular files.
- Install rEFInd, its configuration, 2x theme and GopRotate beside BOOTAA64.EFI.
- Add nabu-refind install, update, status and version commands.
- Queue guarded ESP synchronization after every nabu-boot-refind upgrade.
- Preserve and verify Android plus the explicit known-good fallback artifacts.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-17.test
- Recognize the merged one-RPM kernel family owners in kernel-install.

* Sat Aug 29 2026 mcc45tr <mcc45tr@gmail.com> - 2.0.0-16.test
- Remove synchronous UKI and boot-manager work from every RPM scriptlet.
- Maintain one canonical SENEMOS Linux UKI and preserve Android return.
- Queue kernel-install work for the serialized maintenance service.

* Sat Aug 29 2026 SENEMOS Project <senemos@localhost> - 2.0.0-15.test
- Bundle the pinned Nabu rEFInd 0.14.2 AArch64 application and GopRotate driver.
- Rotate native 1600x2560 GOP output by 270 degrees to match kernel rotation 90.
- Exclude unrelated filesystem drivers and retain a fail-open AArch64 driver path.
- Align with current nabu-core-meta and nabu-boot-manager package naming.

* Sat Aug 29 2026 SENEMOS Project <senemos@localhost> - 2.0.0-14.test
- Install refind-theme-regular with the dark 2x icon and font profile.
- Request the Nabu kernel panel orientation's 2560x1600 logical GOP mode.
- Reserve an empty AArch64 driver directory for future Nabu EFI drivers.
- Keep automatic rotation, touch input and USB input explicitly out of scope.

* Fri Aug 28 2026 SENEMOS Project <senemos@localhost> - 2.0.0-13.test
- Derive timestamped UKI names directly from the exact kernel uname.
- Generate SENEMOS major labels and boot-menu titles from one shared identity helper.
- Replace fixed timestamp fixtures with dynamically generated test identities.

* Fri Aug 28 2026 SENEMOS Project <senemos@localhost> - 2.0.0-12.test
- Accept YYMMDDHHMM kernel build markers for canonical and fallback UKIs.
- Retain compatibility with already-installed legacy four-component markers.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-11.test
- Keep a validated lower-major fallback as the default when a higher-major
  Nabu candidate is installed.
- Apply the same conservative ordering to systemd-boot, rEFInd and Limine
  without modifying or removing the Android-return entry.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-10.test
- Keep the kernel console active through suspend in diagnostic UKIs.
- Preserve an 8 MiB kernel log and ignore console log-level suppression.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-8.test
- Brand canonical and fallback EFI entries from the kernel major and release.
- Name the entries SENEMOS7 v0.0.9.0 and SENEMOS6 v1.4.0.9.
- Read future mainline product versions from an RPM-owned per-kernel marker.
- Accept both new branded UKIs and legacy names during atomic migration.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-7.test
- Honor a kernel-package-owned verbose marker during every UKI regeneration.
- Preserve diagnostic arguments across RPM post-transaction hook ordering.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-6.test
- Add an explicit per-UKI verbose diagnostic mode without changing fallback.
- Remove quiet/Plymouth arguments and expose systemd plus udev boot status.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-5.test
- Add an explicit fallback UKI installation mode without replacing canonical.
- Synchronize canonical, fallback and Android entries for every boot manager.
- Protect the non-target UKI slot during atomic replacement and space checks.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-4.test
- Generate a hardware-scoped initramfs on a running Xiaomi Nabu device.
- Keep generic initramfs generation for offline image construction.
- Retain mandatory firmware, ownership and ESP-space fail-closed gates.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2.0.0-3.test
- Preserve the UKI referenced by fallback.conf during canonical replacement.
- Pass the freshly generated UKI explicitly to boot-manager synchronization.
- Avoid version-sort ambiguity between v1.x fallback and Linux 7.x UKI names.

* Tue Aug 25 2026 SENEMOS Project <senemos@localhost> - 2.0.0-2.test
- Keep authorized Xiaomi firmware as a weak dependency so the public COPR
  graph remains solvable without redistributing proprietary payloads.
- Retain the runtime initramfs gate that refuses a UKI missing Nabu firmware.

* Sun Aug 23 2026 SENEMOS Project <senemos@localhost> - 2.0.0-1.test
- Merge the shared UKI and ESP integration into one package.
- Add mutually exclusive, automatically configured systemd-boot, rEFInd and
  Limine selectors while preserving Android EFI assets.
