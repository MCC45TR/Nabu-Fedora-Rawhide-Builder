#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
top=${1:-$root/rpmbuild}
distgit_commit=b854e9b0de0be0b0bbeab427effdc20e15d899dc
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

git clone -q --filter=blob:none https://src.fedoraproject.org/rpms/powerdevil.git "$work/distgit"
git -C "$work/distgit" checkout -q --detach "$distgit_commit"
test "$(git -C "$work/distgit" rev-parse HEAD)" = "$distgit_commit"

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
install -m0644 "$root/0001-keyboard-backlight-require-positive-range.patch" "$top/SOURCES/"
curl -fL --retry 5 \
    https://download.kde.org/stable/plasma/6.7.5/powerdevil-6.7.5.tar.xz \
    -o "$top/SOURCES/powerdevil-6.7.5.tar.xz"
curl -fL --retry 5 \
    https://download.kde.org/stable/plasma/6.7.5/powerdevil-6.7.5.tar.xz.sig \
    -o "$top/SOURCES/powerdevil-6.7.5.tar.xz.sig"
printf '%s  %s\n' \
    93af580e2bc0a3a6c354c0a1c08bdc93b4355fddeabb461a1a1f6b9026d437fb5f70e046c9e5542e298a8852c792bbd134a445cc8ab4ede8e36a3965c14823fc \
    "$top/SOURCES/powerdevil-6.7.5.tar.xz" | sha512sum -c -
printf '%s  %s\n' \
    cd5ca0bb0388e5d943995f0cfb36c74ce7b1ada25a9a1e86733a5dcd9e00e2c6ea455380ab7f1df63a94f803ecadb596bab2956ece304017bc226597d4191c18 \
    "$top/SOURCES/powerdevil-6.7.5.tar.xz.sig" | sha512sum -c -

sed \
    -e 's/^Release: 2%{?dist}$/Release: 3.nabu1%{?dist}/' \
    -e '/^Source1:/a Patch100: 0001-keyboard-backlight-require-positive-range.patch' \
    "$work/distgit/powerdevil.spec" >"$top/SPECS/powerdevil.spec"
grep -Fq 'Patch100: 0001-keyboard-backlight-require-positive-range.patch' "$top/SPECS/powerdevil.spec"
grep -Fq 'Release: 3.nabu1%{?dist}' "$top/SPECS/powerdevil.spec"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/powerdevil.spec"
