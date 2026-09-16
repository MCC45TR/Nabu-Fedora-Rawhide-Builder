#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
family=${NABU_STABLE_SERIES:-7.2}
releases_url=${NABU_RELEASES_URL:-https://www.kernel.org/releases.json}
signing_fingerprint=B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1
spec=$root/senemos-nabu-kernel-mainline.spec
current=$(sed -nE 's/^Version:[[:space:]]+([^[:space:]]+).*/\1/p' "$spec")
metadata=$(mktemp)
archive=$(mktemp)
sums=$(mktemp)
signature_status=$(mktemp)
gpg_home=$(mktemp -d)
saved_spec=$(mktemp)
saved_sum=$(mktemp)
cleanup() {
    rm -f -- "$metadata" "$archive" "$sums" "$signature_status" \
        "$saved_spec" "$saved_sum"
    find "$gpg_home" -depth -delete 2>/dev/null || :
}
restore() {
    local status=$?
    trap - ERR INT TERM EXIT
    if (( status == 0 )); then
        status=1
    fi
    if [[ -s $saved_spec && -s $saved_sum ]]; then
        cp "$saved_spec" "$spec"
        cp "$saved_sum" "$root/upstream.sha256"
    fi
    cleanup
    exit "$status"
}
trap cleanup EXIT

[[ $family =~ ^[0-9]+[.][0-9]+$ ]]
[[ $current =~ ^${family//./[.]}[.][0-9]+$ ]]
curl -L --fail --retry 3 --output "$metadata" "$releases_url"
read -r latest source_url < <(python3 -c '
import json, sys
family = tuple(map(int, sys.argv[2].split(".")))
with open(sys.argv[1], encoding="utf-8") as stream:
    releases = json.load(stream)["releases"]
stable = [item for item in releases
          if item["moniker"] == "stable"
          and tuple(map(int, item["version"].split(".")[:2])) == family]
if not stable:
    raise SystemExit(f"no stable release found for {sys.argv[2]}.x")
selected = max(stable, key=lambda item: tuple(map(int, item["version"].split("."))))
print(selected["version"], selected["source"])
' "$metadata" "$family")
[[ $latest =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]
[[ $source_url == https://cdn.kernel.org/pub/linux/kernel/v*.x/linux-$latest.tar.xz ]]

if [[ $latest == "$current" ]]; then
    printf 'Linux %s is already the current %s.x stable release.\n' \
        "$current" "$family"
    if [[ -n ${GITHUB_OUTPUT:-} ]]; then
        printf 'updated=false\nversion=%s\n' "$current" >>"$GITHUB_OUTPUT"
    fi
    exit 0
fi
if [[ $(printf '%s\n%s\n' "$latest" "$current" | sort -V | tail -n1) != "$latest" ]]; then
    printf 'Refusing to downgrade Linux %s to %s.\n' "$current" "$latest" >&2
    exit 1
fi

cp "$spec" "$saved_spec"
cp "$root/upstream.sha256" "$saved_sum"
trap restore ERR INT TERM

archive_name=linux-$latest.tar.xz
sums_url=${NABU_SUMS_URL:-${source_url%/$archive_name}/sha256sums.asc}
curl -L --fail --retry 3 --output "$sums" "$sums_url"
chmod 0700 "$gpg_home"
gpg --batch --homedir "$gpg_home" --keyserver hkps://keyserver.ubuntu.com \
    --recv-keys "$signing_fingerprint"
gpg --batch --homedir "$gpg_home" --status-fd 1 --verify "$sums" \
    >"$signature_status"
verified_fingerprint=$(awk '$2 == "VALIDSIG" { print $3; exit }' \
    "$signature_status")
[[ $verified_fingerprint == "$signing_fingerprint" ]]
archive_hash=$(sed -nE \
    "s/^([0-9a-f]{64})  ${archive_name//./[.]}$/\\1/p" "$sums")
[[ $archive_hash =~ ^[0-9a-f]{64}$ ]]
if [[ -n ${NABU_UPSTREAM_ARCHIVE:-} ]]; then
    install -m0644 "$NABU_UPSTREAM_ARCHIVE" "$archive"
else
    curl -L --fail --retry 3 --output "$archive" "$source_url"
fi
printf '%s  %s\n' "$archive_hash" "$archive" | sha256sum -c -
printf '%s  %s\n' "$archive_hash" "$archive_name" > "$root/upstream.sha256"
sed -i -E "s/^Version:[[:space:]]+.*/Version:        $latest/" "$spec"
sed -i -E 's/^Release:[[:space:]]+.*/Release:        1%{?dist}/' "$spec"
changelog_date=$(LC_ALL=C date -u '+%a %b %d %Y')
sed -i "/^%changelog$/a\\
* $changelog_date SENEMOS kernel updater <mcc45tr@gmail.com> - $latest-1\\
- Accept signed Linux $latest after the complete Nabu stable patch gate.\\
\\
" "$spec"

TMPDIR=${TMPDIR:-/tmp} NABU_UPSTREAM_ARCHIVE="$archive" \
    "${NABU_PATCH_GATE:-$root/test-patch-series.sh}"
trap - ERR INT TERM
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    printf 'updated=true\nversion=%s\n' "$latest" >>"$GITHUB_OUTPUT"
fi
printf 'Accepted signed Linux %s as %s-1 after the complete Nabu stable patch gate.\n' \
    "$latest" "$latest"
