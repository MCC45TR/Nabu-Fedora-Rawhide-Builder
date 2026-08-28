%global debug_package %{nil}
Name:           nabu-plasma-login-transition
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Scoped transition from SDDM to Plasma Login Manager
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch
Requires:       plasma-login-manager
Obsoletes:      sddm < 1
Obsoletes:      sddm-wayland-plasma < 7

%description
Explicit transition package for replacing the legacy display manager. It does
not obsolete Qt, KDE Frameworks or user applications and is not pulled by a
routine Nabu Plasma update.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Isolate the narrowly scoped display-manager transition.

