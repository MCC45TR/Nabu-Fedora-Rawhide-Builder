%global debug_package %{nil}
Name:           nabu-obsolete-packages
Version:        1.0
Release:        1%{?dist}
Summary:        Narrow package retirement manifest for Nabu Linux
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch

# Temporary transition packages were replaced by stock-package-safe APIs and
# explicit administrator-invoked migration tooling. Only Nabu-owned package
# names are retired here; Fedora and KDE package names are forbidden.
Obsoletes:      nabu-plasma-qt6-transition < 1.1.0
Obsoletes:      nabu-plasma-login-transition < 1.1.0

%description
Central, auditable retirement manifest for Nabu-owned package names. New
package names carry their own precise Provides/Obsoletes mapping. This package
must never obsolete Fedora or KDE packages and is updated independently when a
Nabu-owned compatibility name reaches the end of its transition window.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0-1
- Retire the two temporary Nabu Plasma transition markers.
- Establish one package for future Nabu-owned retirements only.
