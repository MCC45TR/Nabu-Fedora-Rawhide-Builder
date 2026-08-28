%global debug_package %{nil}
%global nabu_meta_version %(cat %{_sourcedir}/nabu-meta-version)
Name:           nabu-meta
Version:        %{nabu_meta_version}
Release:        1%{?dist}
Summary:        Nabu release dependency manifest
License:        MIT
URL:            https://copr.fedorainfracloud.org/coprs/mcc45tr/nabu-linux/
Source0:        nabu-meta-version
BuildArch:      noarch
Requires:       nabu-core-abi = 1
Requires:       nabu-core-branch
Requires:       nabu-obsolete-packages >= 1.0-1
Provides:       nabu-release-manifest = 1

%description
Top-level dependency manifest for Nabu installations. Updating this package
pulls newly required components while package renames and retirements are kept
in the independently versioned nabu-obsolete-packages package. Existing branch
selections are retained; fresh solving deterministically prefers stable.

%files

%changelog
* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - %{nabu_meta_version}-1
- Adopt the shared Istanbul YYMMDDHHMM meta-package version.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.1.0-1
- Define the release manifest role independently from component versions.
- Pull the dedicated package rename and retirement manifest.

* Fri Aug 28 2026 MCC45TR <mcc45tr@gmail.com> - 1.0.0-33.test
- Stop forcing Rawhide installations onto the unstable branch.
- Preserve an installed branch through the shared virtual capability.
