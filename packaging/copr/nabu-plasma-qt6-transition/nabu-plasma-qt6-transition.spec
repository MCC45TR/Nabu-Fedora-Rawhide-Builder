%global debug_package %{nil}
Name:           nabu-plasma-qt6-transition
Version:        1.0.0
Release:        33.test%{?dist}
Summary:        Retired automatic Qt5 transition compatibility marker
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
BuildArch:      noarch

%description
Compatibility marker replacing earlier revisions that carried broad Obsoletes.
It intentionally has no package-removal metadata. Optional cleanup is performed
by nabu desktop migrate plasma-qt6 after explicit administrator approval.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Retire automatic Qt5 and KF5 removal from normal DNF transactions.

