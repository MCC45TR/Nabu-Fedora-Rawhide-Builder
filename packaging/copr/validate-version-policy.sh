#!/usr/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

stable_specs=("$root"/nabu-unified-meta/*.spec)

for spec in "${stable_specs[@]}"; do
  rpmspec -P "$spec" >/dev/null
  if grep -Eq '^Release:.*\.(test|alpha)' "$spec"; then
    echo "stable control package has a test/alpha release: $spec" >&2
    exit 1
  fi
done

if grep -hE '^Obsoletes:' "${stable_specs[@]}" | grep -Ev '^Obsoletes:[[:space:]]+nabu-' >/dev/null; then
  echo "unified manifest obsoletes a non-Nabu package" >&2
  exit 1
fi

"$root/nabu-unified-meta/test-unified-meta.sh"
echo "Nabu version policy: PASS"
