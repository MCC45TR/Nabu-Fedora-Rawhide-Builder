Name:           ksystemstats
Version:        6.7.4
Release:        2.nabu1%{?dist}
Summary:        Daemon that collects statistics about the running system

License:        BSD-2-Clause AND BSD-3-Clause AND CC0-1.0 AND GPL-2.0-only AND GPL-3.0-only AND (GPL-2.0-only OR GPL-3.0-only)
URL:            https://invent.kde.org/plasma/%{name}
Source0:        https://download.kde.org/stable/plasma/%{version}/%{name}-%{version}.tar.xz
Patch0:         0001-gpu-add-Linux-MSM-Adreno-sensors.patch

BuildRequires:  libksysguard-devel
BuildRequires:  kf6-rpm-macros
BuildRequires:  systemd-rpm-macros
BuildRequires:  extra-cmake-modules
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(KF6Crash)
BuildRequires:  cmake(KF6DBusAddons)
BuildRequires:  cmake(KF6DocTools)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6IconThemes)
BuildRequires:  cmake(KF6ItemViews)
BuildRequires:  cmake(KF6KIO)
BuildRequires:  cmake(KF6NewStuff)
BuildRequires:  cmake(KF6Notifications)
BuildRequires:  cmake(KF6Solid)
BuildRequires:  cmake(KF6WindowSystem)
BuildRequires:  cmake(KF6NetworkManagerQt)
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  libnl3-devel
BuildRequires:  lm_sensors-devel
BuildRequires:  systemd-devel
BuildRequires:  pkgconfig(libpcap)
BuildRequires:  libdrm-devel

%description
KSystemStats is a daemon that collects statistics about the running system.
This build adds subscription-gated Qualcomm MSM/Adreno GPU usage and frequency
sensors using the Linux DRM fdinfo and devfreq interfaces.

%package devel
Summary:        Developer files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
%{summary}.

%prep
%autosetup -p1

%build
%cmake_kf6
%cmake_build

%install
%cmake_install
%find_lang ksystemstats_plugins

%files -f ksystemstats_plugins.lang
%doc README.md
%license LICENSES/*
%{_kf6_bindir}/ksystemstats
%{_kf6_bindir}/kstatsviewer
%{_datadir}/dbus-1/services/org.kde.ksystemstats1.service
%{_userunitdir}/plasma-ksystemstats.service
%{_qt6_plugindir}/ksystemstats/
%{_kf6_datadir}/qlogging-categories6/ksystemstats.categories
%caps(cap_perfmon=ep) %{_libexecdir}/ksystemstats_intel_helper

%changelog
* Sat Sep 05 2026 MCC45TR <mcc45tr@gmail.com> - 6.7.4-2.nabu1
- Add subscription-gated Linux MSM/Adreno GPU sensors
