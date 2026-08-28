%global debug_package %{nil}
%global legacy_meta_max 9999999999-99

Name:           nabu-core-meta
Version:        2.0.0
Release:        4%{?dist}
Summary:        Complete hardware and kernel policy for Xiaomi Pad 5
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-linux-copr.repo
Source1:        90-nabu-disable-cisco-openh264.repo
Source2:        nabu
Source3:        nabu.8
Source4:        nabu-kernel-maintenance
Source5:        nabu-kernel-maintenance.service
Source6:        nabu-kernel-maintenance.timer
Source7:        90-nabu-kernel-maintenance.preset
Source8:        kernel.conf
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

# One kernel family is mandatory.  Alpha is listed first and recommended for
# fresh installations, while installed stable/mainline kernels continue to
# satisfy the hard requirement and multiple families may coexist.
Requires:       (senemos-nabu-kernel-alpha or senemos-nabu-kernel or senemos-nabu-kernel-mainline-alpha or senemos-nabu-kernel-lts)
Recommends:     senemos-nabu-kernel-alpha

# Hardware, boot, firmware and service payloads remain independently built
# where architecture, ABI, licensing or physical validation lifecycles differ.
Requires:       nabu-boot-integration >= 2.0.0
Requires:       nabu-boot-manager
Requires:       nabu-system-integration >= 2.0.0-5.test
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu
Requires:       python3-ssc-nabu
Requires:       iio-sensor-proxy-nabu
Requires:       xiaomi-nabu-firmware
Requires:       senemos-nabu-plymouth >= 1.0.0-5.test
Requires:       nabu-flashlight-integration
Requires:       nabu-sar-service
Requires:       bash
Requires:       coreutils
Requires:       dnf5
Requires:       rpm
Requires:       sudo
Requires:       systemd
Requires:       util-linux-core

Provides:       nabu-release-manifest = 2
Provides:       nabu-core = %{version}-%{release}
Provides:       nabu-core-abi = 1
Provides:       nabu-core-abi = 2
Provides:       nabu-core-branch = 2
Provides:       nabu-repository-config = %{version}-%{release}
Provides:       nabu-repository-config-api = 2
Provides:       nabu-branch-manager = %{version}-%{release}
Provides:       nabu-branch-manager-api = 2
Provides:       nabu-kernel-maintenance = %{version}-%{release}
Provides:       nabu-kernel-maintenance-api = 2
Provides:       nabu-meta = %{version}-%{release}

# Bounded Nabu-only transition.  No Fedora, KDE or third-party package is
# obsoleted.  Kernel payload packages are deliberately retained.
Obsoletes:      nabu-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-base < %{legacy_meta_max}
Obsoletes:      nabu-core-stable-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-alpha-meta < %{legacy_meta_max}
Obsoletes:      nabu-core-unstable-meta < %{legacy_meta_max}
Obsoletes:      nabu-repository-config < %{legacy_meta_max}
Obsoletes:      nabu-branch-manager < %{legacy_meta_max}
Obsoletes:      nabu-kernel-maintenance < %{legacy_meta_max}
Obsoletes:      nabu-obsolete-packages < %{legacy_meta_max}
Obsoletes:      nabu-desktop-migration < %{legacy_meta_max}

%description
The single hardware-side release manifest for Fedora on Xiaomi Pad 5 (nabu).
It installs the required firmware, boot, audio, sensor, power and service
components and guarantees that at least one supported Nabu kernel family is
installed.  Alpha is the recommended family, but stable, mainline and the
reserved future LTS family may be installed together without replacing this
meta package.  The package also owns repository configuration and the safe
kernel/UKI maintenance control plane so their versions cannot drift apart.

%prep

%build
bash -n %{SOURCE2}
bash -n %{SOURCE4}

%install
install -Dm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
install -Dm0755 %{SOURCE2} %{buildroot}%{_bindir}/nabu
install -Dm0644 %{SOURCE3} %{buildroot}%{_mandir}/man8/nabu.8
install -Dm0755 %{SOURCE4} %{buildroot}%{_libexecdir}/nabu-kernel-maintenance
install -Dm0644 %{SOURCE5} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.service
install -Dm0644 %{SOURCE6} %{buildroot}%{_unitdir}/nabu-kernel-maintenance.timer
install -Dm0644 %{SOURCE7} %{buildroot}%{_presetdir}/90-nabu-kernel-maintenance.preset
install -Dm0644 %{SOURCE8} %{buildroot}%{_sysconfdir}/nabu/kernel.conf
install -d %{buildroot}%{_sysconfdir}/systemd/system
ln -s /dev/null %{buildroot}%{_sysconfdir}/systemd/system/nabu-kernel-update.timer

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/nabu-linux-copr.repo
%config(noreplace) %{_sysconfdir}/dnf/repos.override.d/90-nabu-disable-cisco-openh264.repo
%config(noreplace) %{_sysconfdir}/nabu/kernel.conf
%config %{_sysconfdir}/systemd/system/nabu-kernel-update.timer
%{_bindir}/nabu
%{_mandir}/man8/nabu.8*
%{_libexecdir}/nabu-kernel-maintenance
%{_unitdir}/nabu-kernel-maintenance.service
%{_unitdir}/nabu-kernel-maintenance.timer
%{_presetdir}/90-nabu-kernel-maintenance.preset

%post
%systemd_post nabu-kernel-maintenance.timer

%posttrans
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable --now nabu-kernel-maintenance.timer >/dev/null 2>&1 || :
    /usr/bin/systemctl reset-failed nabu-kernel-maintenance.service >/dev/null 2>&1 || :
fi

%preun
%systemd_preun nabu-kernel-maintenance.timer

%postun
%systemd_postun_with_restart nabu-kernel-maintenance.timer

%changelog
* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-4
- Preserve the device's existing explicit loader default instead of assuming it
  must be fallback.conf, and hash-guard Android/fallback entries and EFI files.
- Clear the obsolete failed-unit state after installing the corrected policy.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-3
- Re-enable and start the maintenance timer in post-transaction so removal of
  the superseded standalone package cannot undo the new CORE policy.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-2
- Retire the shared one-shot desktop migration helper from the unambiguous CORE
  transition instead of making multiple DE manifests compete for it.

* Sat Aug 29 2026 MCC45TR <mcc45tr@gmail.com> - 2.0.0-1
- Replace the split CORE base, branch selectors and control packages with one
  release manifest while retaining all install-only kernel payloads.
- Require at least one kernel family, recommend alpha and permit co-installing
  stable, alpha, mainline and the future LTS family.
- Make firmware, flashlight and SAR hardware support explicit dependencies.
