#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
top=${1:-$root/rpmbuild}
version=$(rpmspec -q --qf '%{VERSION}\n' "$root/ksystemstats.spec" | head -n1)
archive="ksystemstats-${version}.tar.xz"
url="https://download.kde.org/stable/plasma/${version}/${archive}"

mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
curl --fail --location --retry 4 --output "$top/SOURCES/$archive" "$url"
printf '%s  %s\n' \
    3dbac18114f1dfbaa861e311447f9ef43a28b3d87d18926fc03d61d801c4287c1589fb7be0460001e4ba84836f58637a604940ff4bd52fcd9668cfad4eee08ef \
    "$top/SOURCES/$archive" | sha512sum -c -
printf '%s  %s\n' \
    4a2498d3eb2751ca703141d534c7ac02f04a03f8a5e011d20d501526c702c44c \
    "$root/patches/0001-gpu-add-Linux-MSM-Adreno-sensors.patch" | sha256sum -c -

install -m0644 "$root/ksystemstats.spec" "$top/SPECS/"
install -m0644 "$root/patches/0001-gpu-add-Linux-MSM-Adreno-sensors.patch" "$top/SOURCES/"
rpmbuild -bs --define "_topdir $top" "$top/SPECS/ksystemstats.spec"
