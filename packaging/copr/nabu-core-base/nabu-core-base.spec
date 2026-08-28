%global debug_package %{nil}
Name:           nabu-core-base
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Kernel-independent operating-system and hardware stack for Nabu
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       nabu-repository-config >= 1.0.0-33.test
Requires:       nabu-branch-manager >= 1.1.0-1
Requires:       nabu-kernel-maintenance >= 1.0.0-1
Requires:       nabu-boot-integration >= 2.0.0
Requires:       nabu-boot-manager
Requires:       nabu-system-integration >= 2.0.0-5.test
Requires:       hexagonrpc-nabu
Requires:       libssc-nabu
Requires:       python3-ssc-nabu
Requires:       iio-sensor-proxy-nabu
Requires:       senemos-nabu-plymouth >= 1.0.0-5.test
Provides:       nabu-core = %{version}-%{release}
Provides:       nabu-core-abi = 1

%description
Kernel-independent CORE foundation for Fedora on Xiaomi Pad 5. Exactly one
independent branch selector supplies nabu-core-branch; kernel and UKI updates
are serialized by nabu-kernel-maintenance.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Move CORE dependency policy to its own source package.
- Require the branch-aware serialized kernel maintenance service.

