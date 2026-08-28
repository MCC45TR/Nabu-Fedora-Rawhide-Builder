%global debug_package %{nil}
%global __strip /bin/true
%global nabu_release 7.2.0
%global uname_r 7.2.0-nabu-senemos-mainline-alpha

Name:           senemos-nabu-kernel-mainline-alpha
Epoch:          2
Version:        0.0.9.2
Release:        1.alpha%{?dist}
Summary:        Alpha Linux 7.2 mainline SENEMOS kernel for Xiaomi Pad 5
License:        GPL-2.0-only AND MIT
URL:            https://github.com/MCC45TR/nabu-linux-kernel/tree/7.2.0-test
ExclusiveArch:  aarch64
Source0:        nabu-v%{nabu_release}-rpm-payload.tar.gz
Source5:        91-nabu-late-xhci.conf
Source6:        90-nabu-late-xhci.conf
BuildRequires:  systemd-rpm-macros
Requires:       senemos-nabu-kernel-mainline-alpha-core = %{epoch}:%{version}-%{release}
Requires:       senemos-nabu-kernel-mainline-alpha-modules = %{epoch}:%{version}-%{release}
Requires:       senemos-nabu-pen-autopair
Requires:       senemos-nabu-kernel-alpha-fallback >= 1:1.17.0-0.4.alpha.v1.4.0.9
Requires:       nabu-kernel-maintenance >= 1.0.0-1
Provides:       senemos-nabu-kernel-mainline-alpha-v0.0.9.2
Provides:       senemos-nabu-kernel = %{epoch}:%{version}-%{release}
Obsoletes:      senemos-nabu-kernel < %{epoch}:%{version}-%{release}
Obsoletes:      senemos-nabu-kernel-core < %{epoch}:%{version}-%{release}
Obsoletes:      senemos-nabu-kernel-modules < %{epoch}:%{version}-%{release}

%description
Isolated alpha build of upstream Linux 7.2 with the reviewed Xiaomi Pad 5
(nabu) hardware enablement carried from the SENEMOS 6.17 line. The selector
replaces the former 6.17 selector package during a managed Rawhide migration.
Versioned 6.17 core and modules packages remain installed as bootable fallbacks
while this kernel completes physical hardware acceptance testing.

%package -n senemos-nabu-kernel-mainline-alpha-core
Summary:        Linux %{uname_r} image, device tree and UKI integration
Requires(posttrans): coreutils
Provides:       installonlypkg(kernel)
Provides:       kernel-uname-r
Provides:       kernel-nabu-core-uname-r
Obsoletes:      senemos-nabu-kernel-mainline-alpha-core < %{epoch}:%{version}-%{release}

%description -n senemos-nabu-kernel-mainline-alpha-core
Kernel image, configuration, symbol map and Xiaomi Pad 5 device tree. The
post-transaction hook only records pending work; the serialized maintenance
service prepares the canonical UKI after the RPM transaction.

%package -n senemos-nabu-kernel-mainline-alpha-modules
Summary:        Linux %{uname_r} loadable modules
Requires:       senemos-nabu-kernel-mainline-alpha-core = %{epoch}:%{version}-%{release}
Provides:       installonlypkg(kernel)
Provides:       kernel-modules-uname-r
Obsoletes:      senemos-nabu-kernel-mainline-alpha-modules < %{epoch}:%{version}-%{release}

%description -n senemos-nabu-kernel-mainline-alpha-modules
Loadable modules built against the exact Linux %{uname_r} ABI.

%prep

%build

%install
mkdir -p %{buildroot}
tar -xzf %{SOURCE0} -C %{buildroot}
install -Dm0644 %{SOURCE5} %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-omit-early-xhci.conf
install -Dm0644 %{SOURCE6} %{buildroot}%{_prefix}/lib/modules-load.d/90-nabu-late-xhci.conf
install -d -m0755 %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d
printf 'v%%s\n' '%{version}' > \
    %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%check
if tar --numeric-owner -tvzf %{SOURCE0} | awk '$2 != "0/0" { print; bad=1; exit } END { exit bad }'; then
    :
else
    echo 'Kernel payload contains a non-root owner.' >&2
    exit 1
fi
test -s %{buildroot}/boot/vmlinuz-%{uname_r}
test -s %{buildroot}/boot/System.map-%{uname_r}
test -s %{buildroot}/boot/config-%{uname_r}
test -s %{buildroot}%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
test -d %{buildroot}%{_prefix}/lib/modules/%{uname_r}/kernel
test ! -e %{buildroot}%{_prefix}/lib/modules/%{uname_r}/build
test ! -e %{buildroot}%{_prefix}/lib/modules/%{uname_r}/source
grep -Fxq 'v%{version}' \
    %{buildroot}%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%posttrans -n senemos-nabu-kernel-mainline-alpha-core
install -d -m0755 /var/lib/nabu-kernel-maintenance
printf '%%s\n' '%{uname_r}' > /var/lib/nabu-kernel-maintenance/pending-kernel

%postun -n senemos-nabu-kernel-mainline-alpha-core
if [ "$1" -eq 0 ]; then
    /usr/sbin/depmod -a || :
fi

%files
%{_prefix}/lib/dracut/dracut.conf.d/90-nabu-omit-early-xhci.conf
%{_prefix}/lib/modules-load.d/90-nabu-late-xhci.conf
%{_prefix}/lib/senemos-nabu/uki-version.d/%{uname_r}

%files -n senemos-nabu-kernel-mainline-alpha-core
/boot/vmlinuz-%{uname_r}
/boot/System.map-%{uname_r}
/boot/config-%{uname_r}
%{_prefix}/lib/modules/%{uname_r}/dtb/qcom/sm8150-xiaomi-nabu.dtb
%{_prefix}/lib/modules/%{uname_r}/modules.*

%files -n senemos-nabu-kernel-mainline-alpha-modules
%{_prefix}/lib/modules/%{uname_r}/kernel/

%changelog
* Fri Aug 28 2026 SENEMOS Project <senemos@localhost> - 2:0.0.9.2-1.alpha
- Remove DNF and UKI generation from the RPM transaction.
- Record pending UKI work for the branch-aware serialized maintenance service.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2:0.0.9.1-1.alpha
- Recover the SLPI FastRPC channel without repeating a retained VMID assignment.
- Restore automatic touchscreen binding and the missing QDSP6 audio DAIs.
- Build MSM DRM into the image to match the validated Nabu boot ordering.
- Return the canonical 7.2 UKI to quiet Plymouth startup after diagnostics.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 2:0.0.9.0-1.alpha
- Start the experimental mainline product version at v0.0.9.0.
- Keep Linux 7.2 as the kernel ABI while separating product and kernel versions.
- Own the per-kernel EFI product-version marker used by boot integration.
- Require the v1.4.0.9 alpha fallback and retire older stable kernel slots.
- Require branded SENEMOS6 and SENEMOS7 EFI integration.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.8.alpha
- Own a per-kernel verbose marker so every RPM hook preserves diagnostics.
- Supersede the ordering-sensitive 0.7 diagnostic packaging revision.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.7.alpha
- Generate only the 7.2 canonical UKI in temporary verbose diagnostic mode.
- Keep the 6.17 alpha fallback command line and UKI unchanged.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.6.alpha
- Make the automatic updater follow the renamed mainline selector and core.
- Match the 7.2 canonical UKI filename generated by nabu-regenerate-uki.
- Add build-time checks for the successor package names in the updater.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.5.alpha
- Replace older packaging revisions of the same 7.2 kernel ABI instead of
  co-installing duplicate owners through installonlypkg(kernel).
- Continue preserving the differently named 6.17 core and modules fallbacks.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.4.alpha
- Repair the disabled timer once when upgrading from the known-broken 0.2
  renamed-selector transaction.
- Preserve administrator-disabled state for every other installed version.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.3.alpha
- Preserve the enabled update timer across the renamed-selector transaction.
- Do not override an administrator-disabled timer on later package upgrades.

* Thu Aug 27 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.2.alpha
- Declare the mainline-alpha selector as the successor to senemos-nabu-kernel.
- Move the updater timer and late-XHCI policy into the successor selector.
- Preserve installed versioned 6.17 core and modules packages as fallbacks.

* Wed Aug 26 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-0.1.alpha
- Isolate the Linux 7.2 mainline candidate from the validated 6.17 package.
- Mark the kernel ABI and all RPM names as mainline alpha.
- Keep the stable kernel, updater integration and Android fallback untouched.

* Wed Aug 26 2026 SENEMOS Project <senemos@localhost> - 1:7.2.0-1.senemos
- Rebase the Xiaomi Pad 5 kernel from Linux 6.17 to verified upstream Linux 7.2.
- Preserve the stable 60/120 Hz display path, DT2W, charging, audio, FastRPC,
  tablet-mode and late-XHCI fixes while quarantining experimental 90 Hz mode.
- Restore the IDT P9418 stylus charging driver and complete the Nabu audio,
  fuel-gauge and touchscreen device-tree contracts.
- Port the v1.4.0.7.1 pogo-keyboard, WCN3990 scan, post-enable touch wake and
  IDTP9418 event/MAC ABI with automatic BlueZ stylus pairing.
