#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

bash -n "$root/nabu" "$root/nabu-kernel-maintenance" "$root/build-srpms.sh" "$root/test-kernel-maintenance-family.sh"
bash "$root/test-kernel-maintenance-family.sh"
bash "$root/test-gnome-mobile-repo-sync.sh"
mapfile -t specs < <(find "$root" -maxdepth 1 -type f -name '*.spec' | sort)
[[ ${#specs[@]} -eq 6 ]] || fail "expected six specs"

for spec in "${specs[@]}"; do
    rpmspec -P "$spec" >/dev/null
    name=$(rpmspec -q --qf '%{name}\n' "$spec")
    [[ $name != *-minimal-* && $name != *-optimal-* ]] || fail "legacy profile name: $name"
done

mobile="$root/gnome-mobile-nabu-meta.spec"
grep -Fq 'Source2:        gnome-mobile-copr.repo' "$mobile" || fail "GNOME Mobile repo source missing"
grep -Fq 'nabu-gnome-mobile-sync.timer' "$mobile" || fail "GNOME Mobile sync timer missing"
grep -Fq '20-nabu-mobile-user-mode.conf' "$mobile" || fail "GNOME Mobile Initial Setup override missing"
grep -Fq 'enable-animations false' "$root/20-nabu-mobile-user-mode.conf" || fail "GNOME Mobile Initial Setup crash guard missing"
! grep -Fq '/usr/bin/systemctl --no-block start nabu-gnome-mobile-sync' "$mobile" || fail "GNOME Mobile starts a nested DNF transaction from RPM posttrans"
grep -Fqx 'gpgcheck=1' "$root/gnome-mobile-copr.repo" || fail "GNOME Mobile gpgcheck disabled"
grep -Fqx 'skip_if_unavailable=False' "$root/gnome-mobile-copr.repo" || fail "GNOME Mobile repo fails open"
grep -Fq 'gnome-shell mutter gnome-settings-daemon' "$root/test-gnome-mobile-repo-sync.sh" || fail "GNOME Mobile package set missing"
for gnome_spec in "$root/gnome-nabu-meta.spec" "$root/gnome-mobile-nabu-meta.spec"; do
    grep -Fq 'Requires:       mutter >= 51~rc-1' "$gnome_spec" || fail "upstream Mutter auto-rotation fix is not required by $gnome_spec"
done
while IFS= read -r copr_spec; do
    source_name=$(sed -nE 's/^Name:[[:space:]]+([^[:space:]]+).*/\1/p' "$copr_spec" | head -n 1)
    [[ -n $source_name ]] || fail "source package name missing in $copr_spec"
    [[ $source_name == *nabu* ]] || fail \
        "default Fedora package fork is forbidden in Nabu COPR: $source_name ($copr_spec)"
done < <(find "$root/.." \
    -path '*/.rpmbuild*' -prune -o \
    -path '*/rpmbuild' -prune -o \
    -type f -name '*.spec' -print)

core="$root/nabu-core-meta.spec"
grep -Fq 'Requires:       (senemos-nabu-kernel-alpha or senemos-nabu-kernel-mainline-unstable)' "$core" || fail "two-family kernel OR requirement"
grep -Fq 'Recommends:     senemos-nabu-kernel-alpha' "$core" || fail "alpha recommendation"
grep -Fq 'nabu-kernel-maintenance-api = 5' "$core" || fail "maintenance API"
! grep -Eq 'dnf5.*upgrade|loader/entries/fallback' "$root/nabu-kernel-maintenance" || fail "legacy update/fallback maintenance remains"
grep -Fq 'pending.d' "$root/nabu-kernel-maintenance" || fail "per-family pending queue missing"
grep -Fq 'kernel-build-identity' "$root/nabu-kernel-maintenance" || fail "shared kernel identity helper missing"
grep -Fq '[mainline-unstable]=SENEMOS7U' "$root/nabu-kernel-maintenance" || fail "unstable EFI family mapping missing"
grep -Fq '[alpha]=SENEMOS6' "$root/nabu-kernel-maintenance" || fail "SENEMOS6 EFI family mapping missing"
! grep -Eq '\[(stable|mainline|lts)\]=' "$root/nabu-kernel-maintenance" || fail "unsupported EFI family mapping remains"
grep -Fq 'prepared_digest =~ ^[0-9a-f]{64}$' "$root/nabu-kernel-maintenance" || fail "per-family prepared UKI digest gate missing"
grep -Fq 'uki_digest=$(sha256sum' "$root/nabu-kernel-maintenance" || fail "prepared UKI digest is not recorded"
! grep -Fq 'Canonical Nabu entry does not reference a complete UKI.' "$root/nabu-kernel-maintenance" || fail "manifest-only UKI verification remains"
grep -Fq 'ReadWritePaths=/boot /boot/efi /usr/lib/modules ' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.service" || fail "kernel modules and ESP are not explicitly writable in maintenance sandbox"
grep -Fq 'After=nabu-refind-sync.service' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.service" || fail "rEFInd synchronization is not ordered before UKI maintenance"
! grep -Fq 'OnUnitInactiveSec=' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.timer" || fail "failed UKI work would be retried forever"
grep -Fq '"$regenerate_command" --family "$family"' "$root/nabu-kernel-maintenance" || fail "family-aware regeneration missing"
! sed '/^%changelog/,$d' "$root/nabu-core-meta.spec" | grep -Eq '^Obsoletes:[[:space:]]+senemos-nabu-kernel.*-(core|modules)' || fail "CORE would erase a possibly running split kernel"
grep -Fxq 'installonly_limit=2' "$root/80-nabu-kernel-retention.conf" || fail "two-version kernel retention missing"
grep -Fxq 'installonlypkgs=senemos-nabu-kernel,senemos-nabu-kernel-alpha,senemos-nabu-kernel-mainline-alpha,senemos-nabu-kernel-lts' "$root/80-nabu-kernel-retention.conf" || fail "fallback kernel install-only names missing"
! grep -Fq 'senemos-nabu-kernel-mainline-unstable' "$root/80-nabu-kernel-retention.conf" || fail "canonical 7.2.2 package must self-update"
[[ ! -e "$root/81-nabu-sensor-orientation.rules" ]] || fail "legacy sensor orientation rule still shipped"
[[ ! -e "$root/nabu-import-mount-matrix" ]] || fail "legacy mount-matrix helper still shipped"
grep -Fq '[alpha]=senemos-nabu-kernel-alpha' "$root/nabu-kernel-maintenance" || fail "single RPM alpha owner"
for old in nabu-core-stable-meta nabu-core-alpha-meta nabu-core-unstable-meta nabu-core-base nabu-meta; do
    grep -Eq "^Obsoletes:[[:space:]]+$old" "$core" || fail "missing CORE transition for $old"
done

for spec in "$root"/*-nabu-meta.spec; do
    grep -Fq 'Requires:       nabu-core-meta >= 3.0.0' "$spec" || fail "missing CORE dependency in $spec"
    grep -Fq 'Requires:       glibc-all-langpacks' "$spec" || fail "missing hard locale dependency in $spec"
    grep -Fq 'Provides:       nabu-language-support' "$spec" || fail "locale payload not merged into $spec"
    grep -Fq 'Provides:       nabu-desktop-profile-meta = 3' "$spec" || fail "manifest ABI mismatch in $spec"
    grep -Fq 'Conflicts:      nabu-desktop-profile-meta' "$spec" && fail "self-conflicting DE transition in $spec"
    grep -Eq '^Recommends:' "$spec" && fail "weak dependency in release manifest $spec"
done

for merged in nabu-system-integration nabu-runtime-integration nabu-flashlight-integration nabu-sar-service nabu-ssc-probe nabu-suspend-diagnostics; do
    grep -Eq "^Obsoletes:[[:space:]]+$merged" "$core" || fail "missing merged CORE transition for $merged"
done

for retired in nabu-system-integration nabu-kde-integration nabu-kde-config nabu-kde-color-profiles nabu-kde-widgets nabu-language-support nabu-kde-l10n nabu-plasma-setup-l10n nabu-plasma-login-theme nabu-flashlight-integration nabu-sar-service; do
    grep -RqE "^Requires:[[:space:]]+$retired([[:space:]]|$)" "$root"/*.spec && fail "standalone integration dependency remains: $retired"
done

(cd "$root/vendor" && sha256sum -c SHA256SUMS >/dev/null) || fail "vendored source checksum"

for spec in "$root"/*-nabu-meta.spec; do
    if grep -E '^Obsoletes:' "$spec" | grep -Ev '^Obsoletes:[[:space:]]+nabu-' >/dev/null; then
        fail "non-Nabu package obsoleted by $spec"
    fi
done

grep -Rq '^Name:.*minimal\|^Name:.*optimal' "$root" && fail "minimal/optimal package remains"
printf 'PASS: unified two-meta release policy\n'
