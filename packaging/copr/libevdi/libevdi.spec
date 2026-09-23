Name:           libevdi
Version:        1.15.1
Release:        1%{?dist}
Summary:        Native userspace API for Extensible Virtual Display Interface
License:        LGPL-2.1-or-later AND MIT
URL:            https://github.com/DisplayLink/evdi
Source0:        https://github.com/DisplayLink/evdi/archive/refs/tags/v%{version}.tar.gz#/evdi-%{version}.tar.gz
Source1:        upstream.sha256
Source2:        nabu-displaylink-status.cpp
Source3:        test-status.py
Source4:        README.md
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  python3
ExclusiveArch:  aarch64

%description
The native C EVDI library, without the optional Python bindings, DKMS sources,
proprietary DisplayLinkManager or automatically started services. Modern
DisplayLink docks need both a matching EVDI kernel module and the separately
licensed DisplayLinkManager; this library alone does not drive USB displays.

%package devel
Summary:        Headers for the EVDI native userspace API
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
Native C/C++ development interface for libevdi.

%package -n nabu-displaylink-tools
Summary:        On-demand read-only DisplayLink diagnostics for Nabu
License:        MIT
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description -n nabu-displaylink-tools
A small C++20 sysfs snapshot command that reports DisplayLink USB devices,
negotiated speed and EVDI version. No privileged service, polling, module
loading, virtual screen creation, external commands or Python runtime.

%prep
(cd %{_sourcedir} && sha256sum -c %{SOURCE1})
%autosetup -n evdi-%{version}
cp %{SOURCE4} NABU-README.md

%build
%set_build_flags
%make_build -C library
g++ -std=c++20 %{build_cxxflags} %{SOURCE2} -Ilibrary \
    -Llibrary -levdi %{build_ldflags} -o nabu-displaylink-status

%install
%make_install -C library LIBDIR=%{_libdir}
install -Dm0644 library/evdi_lib.h %{buildroot}%{_includedir}/evdi_lib.h
install -Dm0755 nabu-displaylink-status %{buildroot}%{_bindir}/nabu-displaylink-status

%check
LD_LIBRARY_PATH="$PWD/library" python3 %{SOURCE3} ./nabu-displaylink-status
LD_LIBRARY_PATH="$PWD/library" ./nabu-displaylink-status --help

%files
%license library/LICENSE LICENSE
%doc NABU-README.md
%{_libdir}/libevdi.so.1
%{_libdir}/libevdi.so.%{version}

%files devel
%{_includedir}/evdi_lib.h
%{_libdir}/libevdi.so

%files -n nabu-displaylink-tools
%license LICENSE
%doc NABU-README.md
%{_bindir}/nabu-displaylink-status

%changelog
* Wed Sep 23 2026 mcc45tr <mcc45tr@gmail.com> - 1.15.1-1
- Ship native library and C++ read-only diagnostics; no Python runtime or DKMS.
