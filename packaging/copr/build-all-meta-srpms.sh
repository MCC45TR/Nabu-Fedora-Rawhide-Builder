#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$root/nabu-unified-meta/build-srpms.sh" "${1:-$root/meta-rpmbuild}"
