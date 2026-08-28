#!/usr/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

stable_specs=(
  "$root/nabu-repository-config/nabu-repository-config.spec"
  "$root/nabu-core-base/nabu-core-base.spec"
  "$root/nabu-meta/nabu-meta.spec"
  "$root/nabu-branch-manager/nabu-branch-manager.spec"
  "$root/nabu-kernel-maintenance/nabu-kernel-maintenance.spec"
  "$root/nabu-plasma-base/nabu-plasma-base.spec"
  "$root/nabu-plasma-login-theme/nabu-plasma-login-theme.spec"
  "$root/nabu-gnome-base/nabu-gnome-base.spec"
  "$root/nabu-gnome-mobile-base/nabu-gnome-mobile-base.spec"
  "$root/nabu-posh-base/nabu-posh-base.spec"
  "$root/nabu-kde-mobile-base/nabu-kde-mobile-base.spec"
  "$root/nabu-obsolete-packages/nabu-obsolete-packages.spec"
)

for spec in "${stable_specs[@]}" "$root"/nabu-core-meta/*.spec "$root"/nabu-desktop-meta/*.spec; do
  rpmspec -P "$spec" >/dev/null
  if grep -Eq '^Release:.*\.(test|alpha)' "$spec"; then
    echo "stable control package has a test/alpha release: $spec" >&2
    exit 1
  fi
done

obsolete_spec="$root/nabu-obsolete-packages/nabu-obsolete-packages.spec"
if grep -E '^Obsoletes:' "$obsolete_spec" | grep -Ev '^Obsoletes:[[:space:]]+nabu-' >/dev/null; then
  echo "retirement manifest contains a non-Nabu package name" >&2
  exit 1
fi

if grep -REn '^Obsoletes:[[:space:]]+(plasma-|kf5-|sddm|maliit-|qt[56]-)' \
  "$root/nabu-obsolete-packages" "$root/nabu-plasma-base" \
  "$root/nabu-gnome-base" "$root/nabu-gnome-mobile-base" \
  "$root/nabu-posh-base"; then
  echo "routine control package obsoletes a Fedora or KDE package" >&2
  exit 1
fi

echo "Nabu version policy: PASS"
