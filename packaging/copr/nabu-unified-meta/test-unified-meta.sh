#!/usr/bin/bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

bash -n "$root/nabu" "$root/nabu-kernel-maintenance" "$root/nabu-kernel-offline-finalize" "$root/build-srpms.sh" "$root/test-kernel-maintenance-family.sh"
bash "$root/test-kernel-maintenance-family.sh"
bash "$root/test-offline-kernel-finalize.sh"
bash "$root/test-gnome-mobile-repo-sync.sh"
[[ -d "$root/vendor-src/nabu-system-integration-2.0.0" ]] || fail "canonical system-integration source missing"
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
    grep -Fqx 'Requires:       mutter' "$gnome_spec" || fail "Fedora Mutter dependency is missing from $gnome_spec"
    ! grep -Eq '^Requires:[[:space:]]+mutter[[:space:]]+[<>=]' "$gnome_spec" || fail "stale Mutter EVR floor remains in $gnome_spec"
done
while IFS= read -r copr_spec; do
    source_name=$(sed -nE 's/^Name:[[:space:]]+([^[:space:]]+).*/\1/p' "$copr_spec" | head -n 1)
    [[ -n $source_name ]] || fail "source package name missing in $copr_spec"
    [[ $source_name == *nabu* || $source_name == senemos-fastfetch-config ]] || fail \
        "default Fedora package fork is forbidden in Nabu COPR: $source_name ($copr_spec)"
done < <(find "$root/.." \
    -path '*/.rpmbuild*' -prune -o \
    -path '*/rpmbuild' -prune -o \
    -type f -name '*.spec' -print)

core="$root/nabu-core-meta.spec"
! sed '/^%changelog/,$d' "$core" | grep -Eq 'systemctl (restart|try-restart) (nabu-sensor-registry-runtime|hexagonrpcd-sdsp|iio-sensor-proxy)' || fail "CORE upgrade disrupts the live sensor stack"
! sed '/^%changelog/,$d' "$core" | grep -Fq '%systemd_postun_with_restart' || fail "CORE upgrade marks hardware services for a live restart"
grep -Fqx 'RefuseManualStop=yes' "$root/vendor-src/nabu-system-integration-2.0.0/payload/usr/lib/systemd/system/ath10k-shutdown.service" || fail "ath10k shutdown helper can be restarted by RPM transactions"
grep -Fqx 'softdep snd_soc_sm8150 pre: snd_soc_wcd934x' "$root/vendor-src/nabu-system-integration-2.0.0/payload/usr/lib/modprobe.d/80-nabu-audio.conf" || fail "WCD934x codec is not ordered before the SM8150 sound card"
grep -Fq 'monitor_sensor_bin' "$root/vendor-src/nabu-system-integration-2.0.0/runtime/nabu-sensor-session-gate" || fail "SensorProxy is not warmed before graphical login"
grep -Fq 'Source11:       nabu-sar-service-0.2.3.tar.zst' "$core" || fail "SAR 0.2.3 source missing"
grep -Fq '%{_libexecdir}/nabu-sar-control' "$core" || fail "SAR control helper not packaged"
grep -Fq '%{_unitdir}/nabu-cct-iio-bridge.service' "$core" || fail "CCT bridge unit not packaged"
grep -Fq '%{_prefix}/lib/modules-load.d/nabu-cct-iio.conf' "$core" || fail "CCT module policy not packaged"
grep -Fq 'Requires:       senemos-nabu-kernel-mainline >= 7.2.3-1' "$core" || fail "mainline stable migration requirement"
grep -Fq 'Recommends:     senemos-fastfetch-config >= 1.2.0-1' "$core" || fail "optional Fastfetch configuration recommendation"
grep -Fqx 'Requires:       alsa-ucm-utils' "$core" || fail "UCM diagnostic tools are missing from CORE"
grep -Fqx 'Requires:       pipewire-alsa' "$core" || fail "ALSA-to-PipeWire playback integration is missing from CORE"
! grep -Eq '^Requires:[[:space:]]+senemos-fastfetch-config([[:space:]]|$)' "$core" || fail "Fastfetch configuration became mandatory"
! grep -Fq '%{_sysconfdir}/xdg/fastfetch/config.jsonc' "$core" || fail "CORE still owns the optional Fastfetch configuration"
fastfetch_spec="$root/../nabu-core-meta/senemos-fastfetch-config/senemos-fastfetch-config.spec"
grep -Fq '%{_sysconfdir}/xdg/fastfetch/config.jsonc' "$fastfetch_spec" || fail "optional package does not own the system Fastfetch configuration"
grep -Fq 'Conflicts:      nabu-core-meta < 3.0.0-56' "$fastfetch_spec" || fail "Fastfetch ownership migration is not transaction-safe"
grep -Fq 'nabu-kernel-maintenance-api = 5' "$core" || fail "maintenance API"
! grep -Eq 'dnf5.*upgrade|loader/entries/fallback' "$root/nabu-kernel-maintenance" || fail "legacy update/fallback maintenance remains"
grep -Fq 'pending.d' "$root/nabu-kernel-maintenance" || fail "per-family pending queue missing"
grep -Fq 'kernel-build-identity' "$root/nabu-kernel-maintenance" || fail "shared kernel identity helper missing"
grep -Fq '[mainline-unstable]=SENEMOS7U' "$root/nabu-kernel-maintenance" || fail "unstable EFI family mapping missing"
grep -Fq '[kernel]=SENEMOS6' "$root/nabu-kernel-maintenance" || fail "SENEMOS6 EFI family mapping missing"
grep -Fq '[mainline]=SENEMOS7' "$root/nabu-kernel-maintenance" || fail "mainline EFI family mapping missing"
grep -Fq 'prepared_digest =~ ^[0-9a-f]{64}$' "$root/nabu-kernel-maintenance" || fail "per-family prepared UKI digest gate missing"
grep -Fq 'uki_digest=$(sha256sum' "$root/nabu-kernel-maintenance" || fail "prepared UKI digest is not recorded"
! grep -Fq 'Canonical Nabu entry does not reference a complete UKI.' "$root/nabu-kernel-maintenance" || fail "manifest-only UKI verification remains"
grep -Fq 'ReadWritePaths=/boot /boot/efi /usr/lib/modules ' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.service" || fail "kernel modules and ESP are not explicitly writable in maintenance sandbox"
grep -Fq 'After=nabu-refind-sync.service' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.service" || fail "rEFInd synchronization is not ordered before UKI maintenance"
! grep -Fq 'OnUnitInactiveSec=' "$root/../nabu-kernel-maintenance/nabu-kernel-maintenance.timer" || fail "failed UKI work would be retried forever"
grep -Fq '"$regenerate_command" --family "$family"' "$root/nabu-kernel-maintenance" || fail "family-aware regeneration missing"
grep -Fq 'ExecStartPost=/usr/libexec/nabu-kernel-offline-finalize' "$root/90-nabu-offline-uki-finalize.conf" || fail "offline transaction does not finalize queued UKIs"
grep -Fq '"$maintenance"' "$root/nabu-kernel-offline-finalize" || fail "offline UKI finalizer does not invoke maintenance"
! sed '/^%changelog/,$d' "$root/nabu-core-meta.spec" | grep -Eq '^Obsoletes:[[:space:]]+senemos-nabu-kernel.*-(core|modules)' || fail "CORE would erase a possibly running split kernel"
grep -Fxq 'installonly_limit=2' "$root/80-nabu-kernel-retention.conf" || fail "two-version kernel retention missing"
! grep -Fq 'installonlypkgs=' "$root/80-nabu-kernel-retention.conf" || fail "SENEMOS families must replace older same-family packages"
[[ ! -e "$root/81-nabu-sensor-orientation.rules" ]] || fail "legacy sensor orientation rule still shipped"
[[ ! -e "$root/nabu-import-mount-matrix" ]] || fail "legacy mount-matrix helper still shipped"
grep -Fq '[kernel]=senemos-nabu-kernel' "$root/nabu-kernel-maintenance" || fail "single RPM kernel owner"
grep -Fq '[mainline]=senemos-nabu-kernel-mainline' "$root/nabu-kernel-maintenance" || fail "single RPM mainline owner"
grep -Fq '[mainline-unstable]=senemos-nabu-kernel-mainline-unstable' "$root/nabu-kernel-maintenance" || fail "single RPM development owner"
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

for kde_spec in "$root/kde-plasma-nabu-meta.spec" "$root/kde-plasma-mobile-nabu-meta.spec"; do
    grep -Fq 'Requires:       kdeplasma-addons' "$kde_spec" || fail "missing Kameleon provider in $kde_spec"
    grep -Fq 'Requires:       firewalld' "$kde_spec" || fail "missing firewalld runtime in $kde_spec"
    grep -Fq 'Requires:       udisks2' "$kde_spec" || fail "missing UDisks2 storage service in $kde_spec"
    grep -Fq 'firewall-offline-cmd --add-service=kdeconnect' "$kde_spec" || fail "KDE Connect firewall policy missing in $kde_spec"
    grep -Fq '%firewalld_reload' "$kde_spec" || fail "firewalld reload missing in $kde_spec"
    ! grep -Eq '^Requires:[[:space:]]+(langpacks|hunspell)-tr$' "$kde_spec" || fail "maintainer locale forced in $kde_spec"
    grep -Fq "grep -Fq '/usr/libexec/nabu-sar-control'" "$kde_spec" || fail "KDE SAR widget gate missing in $kde_spec"
    grep -Fq '%{_prefix}/lib/environment.d/90-nabu-powerdevil.conf' "$kde_spec" || fail "Nabu DSI PowerDevil policy missing in $kde_spec"
done
grep -Fxq 'POWERDEVIL_NO_DDCUTIL=1' "$root/90-nabu-powerdevil.conf" || fail "PowerDevil DDC probe is not disabled for Nabu DSI"

widget_archive="$root/vendor/nabu-kde-widgets-debug-1.0.1.tar.zst"
weather_service=$(tar --zstd -xOf "$widget_archive" \
    nabu-kde-widgets-debug-1.0.1/com.mcc45tr.filesearch/contents/ui/components/WeatherService.js)
config_general=$(tar --zstd -xOf "$widget_archive" \
    nabu-kde-widgets-debug-1.0.1/com.mcc45tr.filesearch/contents/ui/config/ConfigGeneral.qml)
logic_controller=$(tar --zstd -xOf "$widget_archive" \
    nabu-kde-widgets-debug-1.0.1/com.mcc45tr.filesearch/contents/ui/components/LogicController.qml)
grep -Fq 'controller.requests.splice(index, 1)' <<<"$weather_service" \
    || fail "completed weather requests remain retained"
grep -Fq 'xhr.onreadystatechange = null' <<<"$weather_service" \
    || fail "weather request callback cycle remains retained"
grep -Fq 'property bool cfg_expanding' <<<"$config_general" \
    || fail "Plasma expanding compatibility key is missing"
grep -Fq 'property int cfg_length' <<<"$config_general" \
    || fail "Plasma length compatibility key is missing"
grep -Fq 'function backgroundMaintenanceInterval()' <<<"$logic_controller" \
    || fail "File Search deadline scheduler is missing"
grep -Fq 'interval: logicRoot.backgroundMaintenanceInterval()' <<<"$logic_controller" \
    || fail "File Search still uses fixed maintenance polling"
! grep -Fq 'new XMLHttpRequest' <<<"$logic_controller" \
    || fail "File Search still attempts blocked local XHR cache reads"
grep -Fq 'systemctl enable nabu-locale-packages.path nabu-locale-packages.timer' "$root/nabu-core-meta.spec" || fail "locale units not enabled on upgrades"
grep -Fq 'systemctl reset-failed nabu-locale-packages.path nabu-locale-packages.service' "$root/nabu-core-meta.spec" || fail "failed locale watcher not recovered"
grep -Fq 'systemctl restart nabu-locale-packages.path nabu-locale-packages.timer' "$root/nabu-core-meta.spec" || fail "corrected locale watcher not activated"
grep -Fq 'modules-load.d/nabu-audio-codecs.conf' "$root/nabu-core-meta.spec" || fail "obsolete early audio module list not masked"
grep -Fq 'readlink %{buildroot}%{_sysconfdir}/modules-load.d/nabu-audio-codecs.conf' "$root/nabu-core-meta.spec" || fail "audio module mask package gate missing"
grep -Fxq 'Nice=10' "$root/20-nabu-packagekit-qos.conf" || fail "PackageKit CPU priority not lowered"
grep -Fxq 'IOSchedulingClass=idle' "$root/20-nabu-packagekit-qos.conf" || fail "PackageKit I/O priority not idle"
for gnome_spec in "$root/gnome-nabu-meta.spec" "$root/gnome-mobile-nabu-meta.spec"; do
    grep -Fq "grep -Fq '/usr/libexec/nabu-sar-control'" "$gnome_spec" || fail "GNOME SAR tile gate missing in $gnome_spec"
    grep -Fq "grep -Fq 'show-hold-awake'" "$gnome_spec" || fail "GNOME SAR preference gate missing in $gnome_spec"
done

for merged in nabu-system-integration nabu-runtime-integration nabu-flashlight-integration nabu-sar-service nabu-ssc-probe nabu-suspend-diagnostics; do
    grep -Eq "^Obsoletes:[[:space:]]+$merged" "$core" || fail "missing merged CORE transition for $merged"
done

for retired in nabu-system-integration nabu-kde-integration nabu-kde-config nabu-kde-color-profiles nabu-kde-widgets nabu-language-support nabu-kde-l10n nabu-plasma-setup-l10n nabu-plasma-login-theme nabu-flashlight-integration nabu-sar-service; do
    grep -RqE "^Requires:[[:space:]]+$retired([[:space:]]|$)" "$root"/*.spec && fail "standalone integration dependency remains: $retired"
done

(cd "$root/vendor" && sha256sum -c SHA256SUMS >/dev/null) || fail "vendored source checksum"
sar_archive="$root/vendor/nabu-sar-service-0.2.3.tar.zst"
sar_prefix="nabu-sar-service-0.2.3"
tar --zstd -xOf "$sar_archive" \
    "$sar_prefix/src/nabu-cct-iio-bridge.c" \
    | grep -Fq '#define CCT_INVALID_WARNING_USEC (30 * G_USEC_PER_SEC)' \
    || fail "TCS3701 invalid-sample warning throttle missing"
tar --zstd -xOf "$sar_archive" \
    "$sar_prefix/src/nabu-cct-iio-bridge.c" \
    | grep -Fq 'SSC_SENSOR_DATA_TYPE, "cct_front"' \
    || fail "TCS3701 native CCT endpoint missing"
sar_config=$(tar --zstd -xOf "$sar_archive" "$sar_prefix/data/nabu-sar.conf")
grep -Fxq 'Enabled=false' <<<"$sar_config" || fail "SAR mapping is enabled before calibration"
grep -Fxq 'ChannelMask=0' <<<"$sar_config" || fail "uncalibrated SAR channel mapping remains"
grep -Fxq 'HeldThreshold=0' <<<"$sar_config" || fail "uncalibrated SAR held threshold remains"
grep -Fxq 'ReleasedThreshold=0' <<<"$sar_config" || fail "uncalibrated SAR released threshold remains"
sar_service=$(tar --zstd -xOf "$sar_archive" "$sar_prefix/src/nabu-sar-service.c")
grep -Fq 'service->classifier.channel_mask = 0;' <<<"$sar_service" \
    || fail "SAR classifier embeds an uncalibrated channel selection"
! grep -Fq 'ProximityNear' <<<"$sar_service" || fail "SAR leaked into screen proximity API"
grep -Fq 'BuildRequires:  libssc-nabu-devel >= 0.4.4-9.nabu8.test' "$core" \
    || fail "typed TCS3701 libssc build dependency missing"

for spec in "$root"/*-nabu-meta.spec; do
    if grep -E '^Obsoletes:' "$spec" | grep -Ev '^Obsoletes:[[:space:]]+nabu-' >/dev/null; then
        fail "non-Nabu package obsoleted by $spec"
    fi
done

grep -Rq '^Name:.*minimal\|^Name:.*optimal' "$root" && fail "minimal/optimal package remains"
printf 'PASS: unified two-meta release policy\n'
