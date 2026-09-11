#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
top=${1:-$root/rpmbuild}
distgit_commit=790078da1921e40036ee0326bc9a7959111813ff
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

git clone -q --filter=blob:none https://src.fedoraproject.org/rpms/plymouth.git "$work/distgit"
git -C "$work/distgit" checkout -q --detach "$distgit_commit"
test "$(git -C "$work/distgit" rev-parse HEAD)" = "$distgit_commit"

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
for source in charge.plymouth 0001-ply-device-manager-Fix-race-in-fb_device_has_drm_dev.patch \
    0001-ply-device-manager-fix-default-XKB-keymap-fallback-o.patch; do
    install -m0644 "$work/distgit/$source" "$top/SOURCES/"
done
install -m0644 "$root/0001-script-check-console-viewer-before-refresh.patch" "$top/SOURCES/"

curl -fL --retry 5 \
    https://gitlab.freedesktop.org/plymouth/plymouth/-/archive/26.134.222/plymouth-26.134.222.tar.bz2 \
    -o "$top/SOURCES/plymouth-26.134.222.tar.bz2"
printf '%s  %s\n' \
    61d43405fca0208bb2cdd5a1534b8de390fd9e33677709388a6e42feba13f8ba230d0791c63a94648b8ad70946597747b5bdd0ddab35e74c6e3b69a8e212b100 \
    "$top/SOURCES/plymouth-26.134.222.tar.bz2" | sha512sum -c -

sed \
    -e 's/^Release: %autorelease$/Release: 7.nabu1%{?dist}/' \
    -e '/^Patch: 0001-ply-device-manager-fix-default-XKB-keymap-fallback-o.patch$/a Patch100: 0001-script-check-console-viewer-before-refresh.patch' \
    -e 's/^%autochangelog$/* Fri Sep 11 2026 mcc45tr <mcc45tr@gmail.com> - 26.134.222-7.nabu1\n- Backport upstream 88c8dd8 to prevent script-plugin NULL console-viewer crashes on Nabu./' \
    "$work/distgit/plymouth.spec" >"$top/SPECS/plymouth.spec"
grep -Fq 'Patch100: 0001-script-check-console-viewer-before-refresh.patch' "$top/SPECS/plymouth.spec"
grep -Fq 'Release: 7.nabu1%{?dist}' "$top/SPECS/plymouth.spec"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/plymouth.spec"
