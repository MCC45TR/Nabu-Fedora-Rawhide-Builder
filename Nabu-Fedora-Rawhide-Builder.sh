#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2129
# SC2034: documented exit/status interface variables are consumed dynamically by traps and reports.
set -Eeuo pipefail
IFS=$'\n\t'

# Nabu Fedora Rawhide Builder
# A single-file, container-isolated image composer for Xiaomi Pad 5 (nabu).

readonly PROGRAM="Nabu Fedora Rawhide Builder"
readonly SCRIPT_VERSION="1.2.0"
readonly CONTAINER_IMAGE_DEFAULT="registry.fedoraproject.org/fedora:rawhide"
readonly TARGET_ARCH="aarch64"

readonly EXIT_GENERAL=1
readonly EXIT_USAGE=2
readonly EXIT_RPM_MISSING=3
readonly EXIT_CONTAINER=4
readonly EXIT_RAWHIDE=5
readonly EXIT_CORE=6
readonly EXIT_KERNEL=7
readonly EXIT_SECURE_BOOT=8
readonly EXIT_ESP=9
readonly EXIT_FILESYSTEM=10
readonly EXIT_DESKTOP=11
readonly EXIT_FIRSTBOOT=12
readonly EXIT_PARITY=13
readonly EXIT_PARTIAL=20
readonly EXIT_CANCELLED=130

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$SCRIPT_DIR"
HOST_MODE="true"
[[ "${NABU_IN_CONTAINER:-0}" == "1" ]] && HOST_MODE="false"
ACTION="build"

DESKTOP="kde-plasma"
FILESYSTEM="ext4"
DEFAULT_SHELL="bash"
# Keep the first-boot kernel console verbose while the Nabu boot path is being
# validated. Release mode adds quiet/splash to the UKI command line.
BUILD_MODE="verbose"
SECURE_BOOT="on"
SB_KEY=""
SB_CERT=""
UEFI_TRUSTED_CERT=""
GENERATE_DEVELOPMENT_SB_KEY="false"
BOOTLOADER="systemd-boot"
EXISTING_ESP=""
RPM_SEARCH_ROOT=""
RPM_DIR=""
KERNEL_RPM_DIR=""
DEVICE_RPM_DIR=""
BOOT_RPM_DIR=""
FEDORA_PARITY="strict"
RAWHIDE_COMPOSE="latest"
RAWHIDE_COMPOSE_ID=""
RAWHIDE_REPO_BASEURL=""
CORE_ONLY="false"
KEEP_CORE="false"
REUSE_CORE=""
FROM_CORE=""
REBUILD_CORE="false"
VARIANTS_ONLY="false"
CORE_SIZE="6G"
IMAGE_SIZE="12G"
ESP_SIZE="350M"
IMAGE_BACKEND="auto"
ALLOW_PRIVILEGED_IMAGE_BACKEND="false"
PRIVILEGED_CONTAINER="false"
ARCH_MODE="auto"
ALLOW_BINFMT_INSTALL="false"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
COMPRESSION_LEVEL="10"
OUTPUT_ROOT="$SCRIPT_DIR/output"
WORK_ROOT="$SCRIPT_DIR/work"
CACHE_ROOT="$SCRIPT_DIR/cache"
KEEP_CACHE="false"
KEEP_WORK="false"
RESUME="false"
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"
KEYBOARD_LAYOUT="us"
KERNEL_CMDLINE=""
DEVICE_REPO_URL=""
ALLOW_EXTERNAL_REPOS="false"
ALLOW_EXPERIMENTAL_DESKTOP="false"
NOTIFY="yes"
STEP_BY_NOTIFICATION="false"
CLEANUP_CONTAINER_IMAGE="false"
DRY_RUN="false"
NON_INTERACTIVE="false"
DEBUG="false"
TRACE="false"

BUILD_ID=""
BUILD_STAMP=""
BUILD_ROOT=""
ARTIFACTS_DIR=""
ROOTFS_ARTIFACT_DIR=""
BOOT_ARTIFACT_DIR=""
METADATA_DIR=""
REPORTS_DIR=""
STATUS_FILE=""
SUMMARY_FILE=""
WORK_RUN=""
CACHE_RUN=""
LOG_DIR=""
MAIN_LOG=""
EVENT_LOG=""
COMPONENT_LOG=""
CONTAINER_NAME=""
CONTAINER_RC=0
CONTAINER_IMAGE="$CONTAINER_IMAGE_DEFAULT"
CONTAINER_ARCH=""
WORKSPACE_ROOT=""
START_EPOCH="$(date +%s)"
START_ISO="$(date --iso-8601=seconds)"
CURRENT_STAGE="00"
CURRENT_STAGE_NAME="Initialization"
CURRENT_COMPONENT="HOST"
CURRENT_DESKTOP="$DESKTOP"
CURRENT_FILESYSTEM="$FILESYSTEM"
LAST_ERROR_COMMAND=""
ERROR_REPORTED="false"
CLEANUP_DONE="false"
BUILD_LOCK_FD=""
BUILD_LOCK_FILE=""
NOTIFICATION_ID=""
NOTIFICATION_WATCHER_PID=""
SUCCESSFUL_VARIANTS=()
FAILED_VARIANTS=()
SKIPPED_VARIANTS=()
WARNINGS=()
STRICT_PARITY_FAILED="false"
VARIANT_RC=0
ORIGINAL_ARGS=("$@")

declare -a STAGE_NAMES=(
    "unused"
    "Host and workspace discovery"
    "Local Nabu RPM inventory"
    "RPM set compatibility validation"
    "Podman and architecture validation"
    "Fedora Rawhide container preparation"
    "Official Rawhide compose metadata"
    "Fedora package group resolution"
    "Local DNF repository preparation"
    "Minimal Rawhide installroot"
    "Nabu runtime RPM installation"
    "Core system configuration"
    "Core filesystem image creation"
    "Core image validation"
    "Initramfs and DTB validation"
    "Secure Boot UKI creation"
    "EFI and ESP image creation"
    "Desktop variant cloning"
    "Desktop package installation"
    "First-boot configuration"
    "Virtual keyboard and desktop setup"
    "SELinux and systemd validation"
    "Filesystem shrink and verification"
    "Compression, checksums, and parity"
    "Cleanup, final summary, and notification"
)

usage() {
    cat <<'EOF'
Nabu Fedora Rawhide Builder 1.2.0

Builds Fedora Rawhide aarch64 root filesystem images, UKIs, and FAT32 ESP
filesystem images for Xiaomi Pad 5 (nabu). It never flashes a device and never
creates an ISO, Android boot.img, or whole-disk GPT image.

Usage:
  ./Nabu-Fedora-Rawhide-Builder.sh [OPTIONS]
  ./Nabu-Fedora-Rawhide-Builder.sh doctor

General:
  --help                         Show this help
  --version                      Show version
  --dry-run                      Run real RPM/repository/key/architecture preflight
  --non-interactive              Never prompt
  --debug                        Add diagnostic logging
  --trace                        Log redacted commands before execution
  --build MODE                   verbose or release (default: verbose)
  doctor, --doctor               Check host, Podman, storage, architecture,
                                 FUSE, and local signing-file readiness

Image profile:
  --desktop PROFILE              kde-plasma, kde-mobile, gnome, gnome-mobile,
                                 phosh, no-desktop, all, or comma-separated values
  --filesystem TYPE              ext4, btrfs, or all (default: ext4)
  --shell SHELL                  bash, fish, or zsh (default: bash)

Secure Boot and EFI:
  --secure-boot on|off           Default: on
  --sb-key PATH                  PEM private signing key
  --sb-cert PATH                 PEM/DER X.509 signing certificate
  --uefi-trusted-cert PATH       Certificate enrolled/trusted by device UEFI
  --generate-development-sb-key Generate ephemeral development key material
  --bootloader TYPE              systemd-boot, limine, grub, or existing
  --existing-esp PATH            Existing FAT32 filesystem image for existing mode

Local RPM inputs:
  --rpm-search-root PATH         Override discovered workspace RPM search root
  --rpm-dir PATH                 Additional RPM directory
  --kernel-rpm-dir PATH          Kernel RPM directory
  --device-rpm-dir PATH          Device/firmware/config RPM directory
  --boot-rpm-dir PATH            Nabu boot RPM directory

Fedora Rawhide:
  --fedora-parity MODE           strict or relaxed (default: strict)
  --rawhide-compose latest       Resolve current official nightly compose
  --rawhide-compose-id ID        Pin an official compose ID
  --rawhide-repo-baseurl URL     Override official Rawhide Everything base URL

Core-first workflow:
  --core-only                    Produce core plus EFI/ESP, no desktop variants
  --keep-core                    Preserve uncompressed verified core image
  --reuse-core PATH              Reuse core only when fingerprint sidecar matches
  --from-core PATH               Explicitly use a validated core image
  --rebuild-core                 Ignore reusable cache and rebuild core
  --variants-only                Build variants from --from-core/--reuse-core

Sizing and backend:
  --core-size SIZE               Default: 6G
  --image-size SIZE              Default: 12G
  --esp-size SIZE                Default: 350M
  --image-backend TYPE           auto, libguestfs, or loop
  --allow-privileged-image-backend
                                 Permit loop backend; sparse files only
  --privileged                   Run the builder container in privileged mode
                                 (explicit opt-in; weakens host isolation)
  --arch-mode MODE               auto, native, binfmt, or explicit-qemu
  --allow-binfmt-install         Acknowledge permission to install binfmt support

Build behavior:
  --jobs NUMBER                  Parallel jobs
  --compression-level NUMBER     Zstd level 1-19 (default: 10)
  --output PATH                  Output root (default: ./output)
  --work-dir PATH                Work root (default: ./work)
  --cache-dir PATH               Cache root (default: ./cache)
  --keep-cache                   Preserve package/source cache
  --keep-work                    Preserve run work directory
  --resume                       Reserved; rejected until safe stage resume exists
  --locale LOCALE                Default: en_US.UTF-8
  --timezone TIMEZONE            Default: UTC
  --keyboard-layout LAYOUT       Default: us
  --kernel-cmdline STRING        Override validated Nabu kernel command line
  --device-repo-url URL          Optional external device repository
  --allow-external-repos         Permit the explicit device repository
  --allow-experimental-desktop   Permit validated experimental desktop sources
  --notify / --no-notify         Host desktop notification (default: notify)
  --step-by-notification         Send a low-urgency SUCCESS notification at
                                 each completed stage with elapsed minute and
                                 approximate remaining percentage
  --cleanup-container-image      Remove image only if pulled by this invocation

Exit codes:
  0 success, 1 general, 2 arguments, 3 local RPMs, 4 Podman/architecture,
  5 Rawhide, 6 core, 7 kernel, 8 Secure Boot, 9 ESP, 10 filesystem,
  11 desktop, 12 first boot, 13 strict parity, 20 partial success, 130 cancelled.
EOF
}

version() {
    printf '%s %s\n' "$PROGRAM" "$SCRIPT_VERSION"
}

need_value() {
    local option="$1" value="${2-}"
    [[ -n "$value" && "$value" != --* ]] || {
        printf 'ERROR: %s requires a value.\n' "$option" >&2
        exit "$EXIT_USAGE"
    }
    printf '%s\n' "$value"
}

parse_args() {
    while (($#)); do
        case "$1" in
            doctor|--doctor) ACTION="doctor"; shift ;;
            --help) usage; exit 0 ;;
            --version) version; exit 0 ;;
            --dry-run) DRY_RUN="true"; shift ;;
            --non-interactive) NON_INTERACTIVE="true"; shift ;;
            --debug) DEBUG="true"; shift ;;
            --trace) TRACE="true"; DEBUG="true"; shift ;;
            --build) BUILD_MODE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --build=*)
                BUILD_MODE="${1#--build=}"
                [[ -n "$BUILD_MODE" ]] || die_early "$EXIT_USAGE" "--build requires verbose or release."
                shift
                ;;
            --desktop) DESKTOP="$(need_value "$1" "${2-}")"; shift 2 ;;
            --filesystem) FILESYSTEM="$(need_value "$1" "${2-}")"; shift 2 ;;
            --shell) DEFAULT_SHELL="$(need_value "$1" "${2-}")"; shift 2 ;;
            --secure-boot) SECURE_BOOT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --sb-key) SB_KEY="$(need_value "$1" "${2-}")"; shift 2 ;;
            --sb-cert) SB_CERT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --uefi-trusted-cert) UEFI_TRUSTED_CERT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --generate-development-sb-key) GENERATE_DEVELOPMENT_SB_KEY="true"; shift ;;
            --bootloader) BOOTLOADER="$(need_value "$1" "${2-}")"; shift 2 ;;
            --existing-esp) EXISTING_ESP="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rpm-search-root) RPM_SEARCH_ROOT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rpm-dir) RPM_DIR="$(need_value "$1" "${2-}")"; shift 2 ;;
            --kernel-rpm-dir) KERNEL_RPM_DIR="$(need_value "$1" "${2-}")"; shift 2 ;;
            --device-rpm-dir) DEVICE_RPM_DIR="$(need_value "$1" "${2-}")"; shift 2 ;;
            --boot-rpm-dir) BOOT_RPM_DIR="$(need_value "$1" "${2-}")"; shift 2 ;;
            --fedora-parity) FEDORA_PARITY="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rawhide-compose) RAWHIDE_COMPOSE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rawhide-compose-id) RAWHIDE_COMPOSE_ID="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rawhide-repo-baseurl) RAWHIDE_REPO_BASEURL="$(need_value "$1" "${2-}")"; shift 2 ;;
            --core-only) CORE_ONLY="true"; shift ;;
            --keep-core) KEEP_CORE="true"; shift ;;
            --reuse-core) REUSE_CORE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --from-core) FROM_CORE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --rebuild-core) REBUILD_CORE="true"; shift ;;
            --variants-only) VARIANTS_ONLY="true"; shift ;;
            --core-size) CORE_SIZE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --image-size) IMAGE_SIZE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --esp-size) ESP_SIZE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --image-backend) IMAGE_BACKEND="$(need_value "$1" "${2-}")"; shift 2 ;;
            --allow-privileged-image-backend) ALLOW_PRIVILEGED_IMAGE_BACKEND="true"; shift ;;
            --privileged) PRIVILEGED_CONTAINER="true"; shift ;;
            --arch-mode) ARCH_MODE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --allow-binfmt-install) ALLOW_BINFMT_INSTALL="true"; shift ;;
            --jobs) JOBS="$(need_value "$1" "${2-}")"; shift 2 ;;
            --compression-level) COMPRESSION_LEVEL="$(need_value "$1" "${2-}")"; shift 2 ;;
            --output) OUTPUT_ROOT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --work-dir) WORK_ROOT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --cache-dir) CACHE_ROOT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --keep-cache) KEEP_CACHE="true"; shift ;;
            --keep-work) KEEP_WORK="true"; shift ;;
            --resume) RESUME="true"; shift ;;
            --locale) LOCALE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --timezone) TIMEZONE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --keyboard-layout) KEYBOARD_LAYOUT="$(need_value "$1" "${2-}")"; shift 2 ;;
            --kernel-cmdline) KERNEL_CMDLINE="$(need_value "$1" "${2-}")"; shift 2 ;;
            --device-repo-url) DEVICE_REPO_URL="$(need_value "$1" "${2-}")"; shift 2 ;;
            --allow-external-repos) ALLOW_EXTERNAL_REPOS="true"; shift ;;
            --allow-experimental-desktop) ALLOW_EXPERIMENTAL_DESKTOP="true"; shift ;;
            --notify) NOTIFY="yes"; shift ;;
            --no-notify) NOTIFY="no"; shift ;;
            --step-by-notification) STEP_BY_NOTIFICATION="true"; shift ;;
            --cleanup-container-image) CLEANUP_CONTAINER_IMAGE="true"; shift ;;
            --internal-container)
                [[ "${NABU_IN_CONTAINER:-0}" == "1" ]] || {
                    printf 'ERROR: --internal-container is reserved.\n' >&2
                    exit "$EXIT_USAGE"
                }
                shift
                ;;
            --*) printf 'ERROR: Unknown option: %s\n' "$1" >&2; exit "$EXIT_USAGE" ;;
            *) printf 'ERROR: Unexpected positional argument: %s\n' "$1" >&2; exit "$EXIT_USAGE" ;;
        esac
    done
}

valid_choice() {
    local value="$1"; shift
    local candidate
    for candidate in "$@"; do
        [[ "$value" == "$candidate" ]] && return 0
    done
    return 1
}

validate_desktop_selection() {
    local item
    local old_ifs="$IFS"
    IFS=',' read -r -a requested <<<"$DESKTOP"
    IFS="$old_ifs"
    ((${#requested[@]} > 0)) || return 1
    for item in "${requested[@]}"; do
        valid_choice "$item" kde-plasma kde-mobile gnome gnome-mobile phosh no-desktop all || return 1
        if [[ "$item" == "all" && ${#requested[@]} -ne 1 ]]; then
            return 1
        fi
    done
}

validate_size() {
    [[ "$1" =~ ^[1-9][0-9]*([KMGTP]([iI]?[bB])?)?$ ]]
}

validate_options() {
    validate_desktop_selection || die_early "$EXIT_USAGE" "Invalid desktop selection: $DESKTOP"
    valid_choice "$FILESYSTEM" ext4 btrfs all || die_early "$EXIT_USAGE" "Invalid filesystem: $FILESYSTEM"
    valid_choice "$DEFAULT_SHELL" bash fish zsh || die_early "$EXIT_USAGE" "Invalid shell: $DEFAULT_SHELL"
    valid_choice "$BUILD_MODE" verbose release || die_early "$EXIT_USAGE" "Invalid build mode: $BUILD_MODE (use verbose or release)"
    valid_choice "$SECURE_BOOT" on off || die_early "$EXIT_USAGE" "Invalid Secure Boot mode: $SECURE_BOOT"
    valid_choice "$BOOTLOADER" systemd-boot limine grub existing || die_early "$EXIT_USAGE" "Invalid bootloader: $BOOTLOADER"
    valid_choice "$FEDORA_PARITY" strict relaxed || die_early "$EXIT_USAGE" "Invalid Fedora parity mode: $FEDORA_PARITY"
    valid_choice "$IMAGE_BACKEND" auto libguestfs loop || die_early "$EXIT_USAGE" "Invalid image backend: $IMAGE_BACKEND"
    valid_choice "$ARCH_MODE" auto native binfmt explicit-qemu || die_early "$EXIT_USAGE" "Invalid architecture mode: $ARCH_MODE"
    [[ "$RAWHIDE_COMPOSE" == "latest" ]] || die_early "$EXIT_USAGE" "--rawhide-compose currently accepts only 'latest'."
    [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die_early "$EXIT_USAGE" "--jobs must be a positive integer."
    if [[ ! "$COMPRESSION_LEVEL" =~ ^[0-9]+$ ]] || ((COMPRESSION_LEVEL < 1 || COMPRESSION_LEVEL > 19)); then
        die_early "$EXIT_USAGE" "--compression-level must be between 1 and 19."
    fi
    validate_size "$CORE_SIZE" || die_early "$EXIT_USAGE" "Invalid --core-size: $CORE_SIZE"
    validate_size "$IMAGE_SIZE" || die_early "$EXIT_USAGE" "Invalid --image-size: $IMAGE_SIZE"
    validate_size "$ESP_SIZE" || die_early "$EXIT_USAGE" "Invalid --esp-size: $ESP_SIZE"
    [[ "$LOCALE" != *$'\n'* && "$TIMEZONE" != *$'\n'* && "$KEYBOARD_LAYOUT" != *$'\n'* ]] \
        || die_early "$EXIT_USAGE" "Locale, timezone, and keyboard layout must be single-line values."
    if [[ "$IMAGE_BACKEND" == "loop" && "$ALLOW_PRIVILEGED_IMAGE_BACKEND" != "true" ]]; then
        die_early "$EXIT_USAGE" "The loop backend requires --allow-privileged-image-backend."
    fi
    if [[ -n "$DEVICE_REPO_URL" && "$ALLOW_EXTERNAL_REPOS" != "true" ]]; then
        die_early "$EXIT_USAGE" "--device-repo-url requires --allow-external-repos."
    fi
    if [[ "$BOOTLOADER" == "existing" && -z "$EXISTING_ESP" ]]; then
        die_early "$EXIT_USAGE" "--bootloader existing requires --existing-esp PATH."
    fi
    if [[ "$VARIANTS_ONLY" == "true" && -z "$FROM_CORE" && -z "$REUSE_CORE" ]]; then
        die_early "$EXIT_USAGE" "--variants-only requires --from-core or --reuse-core."
    fi
    if [[ -n "$FROM_CORE" && -n "$REUSE_CORE" ]]; then
        die_early "$EXIT_USAGE" "Use only one of --from-core and --reuse-core."
    fi
    if [[ "$CORE_ONLY" == "true" && "$VARIANTS_ONLY" == "true" ]]; then
        die_early "$EXIT_USAGE" "--core-only and --variants-only are mutually exclusive."
    fi
    if [[ "$RESUME" == "true" ]]; then
        die_early "$EXIT_USAGE" "--resume is not implemented safely yet; use --reuse-core or --from-core with a validated fingerprint instead."
    fi
    if [[ "$SECURE_BOOT" == "off" && ( -n "$SB_KEY" || -n "$SB_CERT" || "$GENERATE_DEVELOPMENT_SB_KEY" == "true" ) ]]; then
        die_early "$EXIT_USAGE" "Secure Boot key options cannot be used with --secure-boot off."
    fi
    if [[ "$GENERATE_DEVELOPMENT_SB_KEY" == "true" && ( -n "$SB_KEY" || -n "$SB_CERT" ) ]]; then
        die_early "$EXIT_USAGE" "Development-key generation cannot be combined with --sb-key/--sb-cert."
    fi
    if [[ "$SECURE_BOOT" == "on" && "$VARIANTS_ONLY" != "true" ]]; then
        if [[ "$GENERATE_DEVELOPMENT_SB_KEY" != "true" && ( -z "$SB_KEY" || -z "$SB_CERT" ) ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                WARNINGS+=("Secure Boot key/certificate are absent; a real build would stop before UKI creation.")
            else
                die_early "$EXIT_SECURE_BOOT" "Secure Boot is on; provide --sb-key and --sb-cert or request --generate-development-sb-key."
            fi
        fi
        if [[ "$FEDORA_PARITY" == "strict" && -z "$UEFI_TRUSTED_CERT" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                WARNINGS+=("Strict Secure Boot trust cannot be verified without --uefi-trusted-cert.")
            else
                die_early "$EXIT_SECURE_BOOT" "Strict mode requires --uefi-trusted-cert for VERIFIED_SECURE_BOOT."
            fi
        fi
    fi
}

DOCTOR_FAILURES=0
DOCTOR_WARNINGS=0

doctor_result() {
    local status="$1" label="$2" detail="${3:-}"
    printf '[%-4s] %-28s %s\n' "$status" "$label" "$detail"
    case "$status" in
        FAIL) ((DOCTOR_FAILURES += 1)) ;;
        WARN) ((DOCTOR_WARNINGS += 1)) ;;
    esac
}

doctor_required_command() {
    local command_name="$1"
    if command -v "$command_name" >/dev/null 2>&1; then
        doctor_result PASS "command: $command_name" "$(command -v "$command_name")"
    else
        doctor_result FAIL "command: $command_name" "required on the host"
    fi
}

doctor_storage_path() {
    local label="$1" path="$2" parent
    if [[ -d "$path" ]]; then
        if [[ -r "$path" && -w "$path" && -x "$path" ]]; then
            doctor_result PASS "$label" "$path"
        else
            doctor_result FAIL "$label" "directory is not readable/writable: $path"
        fi
        return
    fi
    parent="$(dirname -- "$path")"
    if [[ -d "$parent" && -w "$parent" ]]; then
        doctor_result PASS "$label" "$path (will be created)"
    else
        doctor_result FAIL "$label" "parent is not writable: $parent"
    fi
}

run_doctor() {
    local command_name rootless="unknown" host_arch key_path key_mode cert_path
    DOCTOR_FAILURES=0
    DOCTOR_WARNINGS=0

    printf '%s %s host doctor\n\n' "$PROGRAM" "$SCRIPT_VERSION"
    for command_name in bash podman realpath sha256sum find date flock; do
        doctor_required_command "$command_name"
    done

    if command -v podman >/dev/null 2>&1; then
        if podman info >/dev/null 2>&1; then
            doctor_result PASS "Podman service" "$(podman --version 2>/dev/null || printf available)"
            rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf unknown)"
            if [[ "$rootless" == "true" ]]; then
                doctor_result PASS "Podman isolation" "rootless"
            elif [[ "$PRIVILEGED_CONTAINER" == "true" ]]; then
                doctor_result WARN "Podman isolation" "rootful plus --privileged requested"
            else
                doctor_result WARN "Podman isolation" "rootless status: $rootless"
            fi
        else
            doctor_result FAIL "Podman service" "podman info failed"
        fi

        if podman image exists "$CONTAINER_IMAGE" >/dev/null 2>&1; then
            doctor_result PASS "Rawhide container image" "$CONTAINER_IMAGE"
        else
            doctor_result WARN "Rawhide container image" "not cached; Podman will pull it on first use"
        fi
    fi

    host_arch="$(uname -m)"
    case "$host_arch" in
        aarch64|arm64)
            doctor_result PASS "Host architecture" "$host_arch (native target execution)"
            ;;
        x86_64|amd64)
            if command -v podman >/dev/null 2>&1 \
                && podman image exists "$CONTAINER_IMAGE" >/dev/null 2>&1 \
                && podman run --rm --arch arm64 "$CONTAINER_IMAGE" /usr/bin/true >/dev/null 2>&1; then
                doctor_result PASS "Host architecture" "$host_arch with working aarch64 binfmt"
            else
                doctor_result WARN "Host architecture" "$host_arch; aarch64 binfmt was not verified (repository dry-run remains available)"
            fi
            ;;
        *)
            doctor_result FAIL "Host architecture" "$host_arch is unsupported"
            ;;
    esac

    if [[ -e /dev/fuse ]]; then
        doctor_result PASS "FUSE device" "/dev/fuse is present"
    else
        doctor_result WARN "FUSE device" "missing; libguestfs/FUSE image operations may fail"
    fi

    doctor_storage_path "work directory" "$WORK_ROOT"
    doctor_storage_path "cache directory" "$CACHE_ROOT"
    doctor_storage_path "output directory" "$OUTPUT_ROOT"

    key_path="$SCRIPT_DIR/secure/db.key"
    cert_path="$SCRIPT_DIR/secure/db.crt"
    if [[ -f "$key_path" ]]; then
        key_mode="$(stat -c '%a' "$key_path" 2>/dev/null || printf unknown)"
        if [[ "$key_mode" == "600" || "$key_mode" == "400" ]]; then
            doctor_result PASS "Secure Boot key" "present with mode $key_mode"
        else
            doctor_result WARN "Secure Boot key" "present with permissive/unknown mode $key_mode"
        fi
    else
        doctor_result WARN "Secure Boot key" "not found at secure/db.key"
    fi
    if [[ -r "$cert_path" ]]; then
        doctor_result PASS "Secure Boot certificate" "secure/db.crt is readable"
    else
        doctor_result WARN "Secure Boot certificate" "not found/readable at secure/db.crt"
    fi

    if [[ "$PRIVILEGED_CONTAINER" == "true" ]]; then
        doctor_result WARN "Container privilege" "--privileged requested; host isolation is substantially reduced"
    else
        doctor_result PASS "Container privilege" "rootless/default isolation requested"
    fi

    printf '\nDoctor summary: %d failure(s), %d warning(s)\n' "$DOCTOR_FAILURES" "$DOCTOR_WARNINGS"
    ((DOCTOR_FAILURES == 0))
}

die_early() {
    local code="$1"; shift
    printf 'ERROR: %s\n' "$*" >&2
    exit "$code"
}

prompt_value() {
    local label="$1" variable="$2" input current
    current="${!variable}"
    read -r -p "$label [$current]: " input
    [[ -z "$input" ]] || printf -v "$variable" '%s' "$input"
}

toggle_value() {
    local variable="$1"
    [[ "${!variable}" == "true" ]] && printf -v "$variable" '%s' false || printf -v "$variable" '%s' true
}

interactive_menu() {
    local choice confirmation
    [[ -t 0 && -t 1 ]] || die_early "$EXIT_USAGE" "Parameterless mode requires a terminal; use --non-interactive with explicit options."
    while true; do
        cat <<EOF

$PROGRAM
 1. Fedora Rawhide compose      ${RAWHIDE_COMPOSE_ID:-latest}
 2. Desktop variant            $DESKTOP
 3. Filesystem                 $FILESYSTEM
 4. Default shell              $DEFAULT_SHELL
 5. Secure Boot                $SECURE_BOOT
 6. Secure Boot key/cert       $([[ -n "$SB_CERT" ]] && printf configured || printf not-configured)
 7. Bootloader                 $BOOTLOADER
 8. Local RPM search root      ${RPM_SEARCH_ROOT:-auto}
 9. Core image                 ${FROM_CORE:-${REUSE_CORE:-build-new}}
10. Core image size            $CORE_SIZE
11. Final image size           $IMAGE_SIZE
12. Compression level          $COMPRESSION_LEVEL
13. CPU thread count           $JOBS
14. Output directory           $OUTPUT_ROOT
15. Keep cache                 $KEEP_CACHE
16. Dry-run                    $DRY_RUN
17. Debug                      $DEBUG
18. Start build
19. Quit
EOF
        read -r -p "Selection: " choice
        case "$choice" in
            1) prompt_value "Compose ID (empty means latest)" RAWHIDE_COMPOSE_ID ;;
            2) prompt_value "Desktop profile" DESKTOP ;;
            3) prompt_value "Filesystem (ext4/btrfs/all)" FILESYSTEM ;;
            4) prompt_value "Shell (bash/fish/zsh)" DEFAULT_SHELL ;;
            5) prompt_value "Secure Boot (on/off)" SECURE_BOOT ;;
            6)
                prompt_value "Private key path" SB_KEY
                prompt_value "Signing certificate path" SB_CERT
                prompt_value "UEFI trusted certificate path" UEFI_TRUSTED_CERT
                ;;
            7) prompt_value "Bootloader" BOOTLOADER ;;
            8) prompt_value "RPM search root" RPM_SEARCH_ROOT ;;
            9) prompt_value "Existing core image (empty builds new)" FROM_CORE ;;
            10) prompt_value "Core size" CORE_SIZE ;;
            11) prompt_value "Final image size" IMAGE_SIZE ;;
            12) prompt_value "Zstd level" COMPRESSION_LEVEL ;;
            13) prompt_value "CPU jobs" JOBS ;;
            14) prompt_value "Output root" OUTPUT_ROOT ;;
            15) toggle_value KEEP_CACHE ;;
            16) toggle_value DRY_RUN ;;
            17) toggle_value DEBUG ;;
            18) break ;;
            19) exit 0 ;;
            *) printf 'Invalid selection.\n' >&2 ;;
        esac
    done
    cat <<EOF

Build summary
  Compose:       ${RAWHIDE_COMPOSE_ID:-latest}
  Desktop:       $DESKTOP
  Filesystem:    $FILESYSTEM
  Shell:         $DEFAULT_SHELL
  Secure Boot:   $SECURE_BOOT
  Bootloader:    $BOOTLOADER
  Parity:        $FEDORA_PARITY
  Arch mode:     $ARCH_MODE
  Backend:       $IMAGE_BACKEND
  Output:        $OUTPUT_ROOT
  Dry-run:       $DRY_RUN
EOF
    read -r -p "Continue? [y/N]: " confirmation
    [[ "$confirmation" =~ ^[Yy]$ ]] || exit "$EXIT_CANCELLED"
}

absolute_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s/%s\n' "$PWD" "$path"
    fi
}

canonical_path() {
    realpath -m -- "$(absolute_path "$1")"
}

path_is_within() {
    local path parent
    path="$(canonical_path "$1")"
    parent="$(canonical_path "$2")"
    [[ "$path" == "$parent" || "$path" == "$parent/"* ]]
}

find_workspace_root() {
    local start="$1" candidate parent marker
    start="$(canonical_path "$start")"
    candidate="$start"
    for _ in 0 1 2; do
        for marker in \
            Nabu-Linux-Spesific-File-Compailer \
            nabu-kernel-test-output \
            nabu-copr-packages-test-output \
            nabu-boot-test-output \
            nabu-linux-builder-main.zip \
            nabu-linux-images-main.zip; do
            if [[ -e "$candidate/$marker" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
        parent="$(dirname -- "$candidate")"
        [[ "$parent" != "$candidate" ]] || break
        candidate="$parent"
    done
    return 1
}

set_output_layout() {
    ARTIFACTS_DIR="$BUILD_ROOT/artifacts"
    ROOTFS_ARTIFACT_DIR="$ARTIFACTS_DIR/rootfs"
    BOOT_ARTIFACT_DIR="$ARTIFACTS_DIR/boot"
    METADATA_DIR="$BUILD_ROOT/metadata"
    REPORTS_DIR="$BUILD_ROOT/reports"
    LOG_DIR="$BUILD_ROOT/logs"
    MAIN_LOG="$LOG_DIR/main.log"
    EVENT_LOG="$LOG_DIR/events.jsonl"
    COMPONENT_LOG="$MAIN_LOG"
    STATUS_FILE="$BUILD_ROOT/STATUS.json"
    SUMMARY_FILE="$BUILD_ROOT/SUMMARY.md"
}

acquire_build_lock() {
    command -v flock >/dev/null 2>&1 \
        || die_early "$EXIT_GENERAL" "Required host command is missing: flock"
    mkdir -p -- "$OUTPUT_ROOT"
    BUILD_LOCK_FILE="$PROJECT_DIR/.nabu-builder.lock"
    exec {BUILD_LOCK_FD}>>"$BUILD_LOCK_FILE"
    if ! flock -n "$BUILD_LOCK_FD"; then
        local owner=""
        owner="$(sed -n '1,4p' "$BUILD_LOCK_FILE" 2>/dev/null | tr '\n' ' ' || true)"
        die_early "$EXIT_GENERAL" "Another builder is already using this project. ${owner:-Lock: $BUILD_LOCK_FILE}"
    fi
    printf 'pid=%s\nstarted=%s\nbuild=%s\nproject=%s\n' \
        "$$" "$START_ISO" "$BUILD_ID" "$PROJECT_DIR" >"$BUILD_LOCK_FILE"
}

release_build_lock() {
    [[ -n "${BUILD_LOCK_FD:-}" ]] || return 0
    flock -u "$BUILD_LOCK_FD" >/dev/null 2>&1 || true
    exec {BUILD_LOCK_FD}>&-
    BUILD_LOCK_FD=""
}

update_latest_link() {
    local link_name="$1" temporary
    [[ "$HOST_MODE" == "true" && -n "${OUTPUT_ROOT:-}" && -n "${BUILD_ID:-}" \
        && -n "${BUILD_ROOT:-}" && -d "$BUILD_ROOT" ]] || return 0
    temporary="$OUTPUT_ROOT/.${link_name}.$$"
    rm -f -- "$temporary"
    ln -s -- "$BUILD_ID" "$temporary"
    mv -Tf -- "$temporary" "$OUTPUT_ROOT/$link_name"
}

initialize_run_paths() {
    BUILD_STAMP="$(date +%Y%m%d-%H%M%S)"
    local short_id
    short_id="$(printf '%s-%s-%s' "$START_EPOCH" "$$" "$RANDOM" | sha256sum | cut -c1-6)"
    BUILD_ID="rawhide-${BUILD_STAMP}-${short_id}"
    OUTPUT_ROOT="$(canonical_path "$OUTPUT_ROOT")"
    WORK_ROOT="$(canonical_path "$WORK_ROOT")"
    CACHE_ROOT="$(canonical_path "$CACHE_ROOT")"
    local managed_root
    for managed_root in "$OUTPUT_ROOT" "$WORK_ROOT" "$CACHE_ROOT"; do
        [[ "$managed_root" != "/" && "$managed_root" != "/home" && "$managed_root" != "$PROJECT_DIR" ]] \
            || die_early "$EXIT_USAGE" "Managed output/work/cache roots cannot be /, /home, or the project root: $managed_root"
        path_is_within "$managed_root" "$PROJECT_DIR" \
            || die_early "$EXIT_USAGE" "Managed output/work/cache roots must remain below the project root: $managed_root"
    done
    [[ "$OUTPUT_ROOT" != "$WORK_ROOT" && "$OUTPUT_ROOT" != "$CACHE_ROOT" && "$WORK_ROOT" != "$CACHE_ROOT" ]] \
        || die_early "$EXIT_USAGE" "Output, work, and cache roots must be distinct."
    BUILD_ROOT="$OUTPUT_ROOT/$BUILD_ID"
    WORK_RUN="$WORK_ROOT/$BUILD_ID"
    CACHE_RUN="$CACHE_ROOT/rawhide"
    set_output_layout
    acquire_build_lock
    mkdir -p -- "$ROOTFS_ARTIFACT_DIR" "$BOOT_ARTIFACT_DIR" \
        "$METADATA_DIR/desktop-package-diffs" "$REPORTS_DIR" "$LOG_DIR" \
        "$WORK_RUN" "$CACHE_RUN/dnf"
    : >"$WORK_RUN/.nabu-builder-work"
    : >"$CACHE_RUN/.nabu-builder-cache"
    : >"$BUILD_ROOT/.nabu-builder-output"
    local log_name
    for log_name in rpm-discovery rawhide-compose core-build uki-build esp-build filesystem validation cleanup; do
        : >"$LOG_DIR/${log_name}.log"
    done
    write_run_status RUNNING 0 "Build initialized"
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

redact() {
    local value="$*"
    [[ -z "$SB_KEY" ]] || value=${value//"$SB_KEY"/[REDACTED-SB-KEY]}
    value=${value//\/run\/secrets\/nabu-sb.key/[REDACTED-SB-KEY]}
    value="$(sed -E 's/([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn])=[^[:space:]]+/\1=[REDACTED]/g' <<<"$value")"
    printf '%s\n' "$value"
}

write_run_status() {
    local state="$1" code="${2:-0}" message="${3:-}" timestamp stage_number=0 temporary
    local elapsed progress remaining remaining_json="null"
    [[ -n "${STATUS_FILE:-}" && -n "${BUILD_ROOT:-}" && -d "$BUILD_ROOT" ]] || return 0
    [[ "$CURRENT_STAGE" =~ ^[0-9]+$ ]] && stage_number="$((10#$CURRENT_STAGE))"
    timestamp="$(date --iso-8601=seconds)"
    message="$(redact "$message")"
    elapsed="$(( $(date +%s) - START_EPOCH ))"
    ((elapsed >= 0)) || elapsed=0
    progress="$(stage_progress_percent "$stage_number")"
    remaining="$(estimated_remaining_seconds "$elapsed" "$progress")"
    ((remaining < 0)) || remaining_json="$remaining"
    temporary="$STATUS_FILE.partial"
    if printf '{"status":"%s","exit_code":%d,"build_id":"%s","stage":%d,"stage_name":"%s","component":"%s","desktop":"%s","filesystem":"%s","elapsed_seconds":%d,"stage_progress_percent":%d,"estimated_remaining_seconds":%s,"updated_at":"%s","message":"%s"}\n' \
        "$(json_escape "$state")" "$code" "$(json_escape "${BUILD_ID:-unknown}")" "$stage_number" \
        "$(json_escape "${CURRENT_STAGE_NAME:-unknown}")" "$(json_escape "${CURRENT_COMPONENT:-unknown}")" \
        "$(json_escape "${CURRENT_DESKTOP:-unknown}")" "$(json_escape "${CURRENT_FILESYSTEM:-unknown}")" \
        "$elapsed" "$progress" "$remaining_json" "$(json_escape "$timestamp")" "$(json_escape "$message")" >"$temporary"; then
        mv -f -- "$temporary" "$STATUS_FILE"
    else
        rm -f -- "$temporary"
        return 0
    fi
}

write_failure_report() {
    local code="$1" line="$2" command="$3" function_name="${4:-main}"
    local report temporary component_path component_relative diagnostic="" line_text
    [[ -n "${BUILD_ROOT:-}" && -d "$BUILD_ROOT" ]] || return 0
    report="$BUILD_ROOT/FAILURE.md"
    [[ ! -s "$report" ]] || return 0
    temporary="$report.partial"
    component_path="${COMPONENT_LOG:-$MAIN_LOG}"
    component_relative="${component_path#"$BUILD_ROOT"/}"
    if [[ "$CURRENT_STAGE" == "13" && -n "${METADATA_DIR:-}" && -s "$METADATA_DIR/core-systemd-verify.txt" ]]; then
        diagnostic="metadata/core-systemd-verify.txt"
    elif [[ "$CURRENT_STAGE" == "08" && -n "${METADATA_DIR:-}" && -s "$METADATA_DIR/local-rpm-repoclosure.txt" ]]; then
        diagnostic="metadata/local-rpm-repoclosure.txt"
    fi
    {
        printf '# Build failed\n\n'
        printf -- '- Build ID: `%s`\n' "${BUILD_ID:-unknown}"
        printf -- '- Exit code: `%s`\n' "$code"
        printf -- '- Stage: `%s` — %s\n' "${CURRENT_STAGE:-00}" "${CURRENT_STAGE_NAME:-unknown}"
        printf -- '- Component: `%s`\n' "${CURRENT_COMPONENT:-unknown}"
        printf -- '- Profile: `%s/%s`\n' "${CURRENT_DESKTOP:-unknown}" "${CURRENT_FILESYSTEM:-unknown}"
        printf -- '- Function/line: `%s:%s`\n' "$function_name" "$line"
        printf -- '- Command: `%s`\n' "$(redact "$command")"
        printf '\n## Start here\n\n'
        printf -- '- Main log: [logs/main.log](logs/main.log)\n'
        printf -- '- Component log: [%s](%s)\n' "$component_relative" "$component_relative"
        [[ -z "$diagnostic" ]] || printf -- '- Focused diagnostic: [%s](%s)\n' "$diagnostic" "$diagnostic"
        printf -- '- Machine-readable state: [STATUS.json](STATUS.json)\n'
        if [[ -s "$component_path" ]]; then
            printf '\n## Last component log lines\n\n```text\n'
            tail -n 60 "$component_path" | while IFS= read -r line_text; do redact "$line_text"; done
            printf '```\n'
        fi
        if [[ -n "$diagnostic" && -s "$BUILD_ROOT/$diagnostic" ]]; then
            printf '\n## Focused diagnostic excerpt\n\n```text\n'
            tail -n 80 "$BUILD_ROOT/$diagnostic" | while IFS= read -r line_text; do redact "$line_text"; done
            printf '```\n'
        fi
    } >"$temporary" 2>/dev/null || true
    if [[ -s "$temporary" ]]; then
        mv -f -- "$temporary" "$report" || true
        printf '# Build summary\n\nStatus: **FAILED**\n\nOpen [FAILURE.md](FAILURE.md) for the cause and relevant log excerpts.\n' \
            >"$SUMMARY_FILE.partial" 2>/dev/null || true
        [[ ! -s "$SUMMARY_FILE.partial" ]] || mv -f -- "$SUMMARY_FILE.partial" "$SUMMARY_FILE" || true
    else
        rm -f -- "$temporary"
    fi
}

log() {
    local severity="$1"; shift
    local message timestamp stage_label clean component_file
    message="$(redact "$*")"
    timestamp="$(date --iso-8601=seconds)"
    stage_label="$(printf '%02d/24' "$((10#$CURRENT_STAGE))" 2>/dev/null || printf '00/24')"
    clean="$timestamp [$stage_label] [$CURRENT_COMPONENT] [$severity] $message"
    printf '%s\n' "$clean"
    if [[ -n "$MAIN_LOG" ]]; then
        printf '%s\n' "$clean" >>"$MAIN_LOG"
        component_file="${COMPONENT_LOG:-$MAIN_LOG}"
        [[ "$component_file" == "$MAIN_LOG" ]] || printf '%s\n' "$clean" >>"$component_file"
    fi
    if [[ -n "$EVENT_LOG" ]]; then
        printf '{"timestamp":"%s","stage":%d,"component":"%s","severity":"%s","message":"%s"}\n' \
            "$(json_escape "$timestamp")" "$((10#$CURRENT_STAGE))" "$(json_escape "$CURRENT_COMPONENT")" \
            "$(json_escape "$severity")" "$(json_escape "$message")" >>"$EVENT_LOG"
    fi
}

debug() { [[ "$DEBUG" == "true" ]] && log DEBUG "$*" || :; }
warn() { WARNINGS+=("$*"); log WARN "$*"; }

stage() {
    local number="$1" component="$2"
    CURRENT_STAGE="$(printf '%02d' "$number")"
    CURRENT_STAGE_NAME="${STAGE_NAMES[$number]}"
    CURRENT_COMPONENT="$component"
    COMPONENT_LOG="$MAIN_LOG"
    case "$number" in
        2|3|8) COMPONENT_LOG="$LOG_DIR/rpm-discovery.log" ;;
        6|7) COMPONENT_LOG="$LOG_DIR/rawhide-compose.log" ;;
        9|10|11|12|13) COMPONENT_LOG="$LOG_DIR/core-build.log" ;;
        14|15) COMPONENT_LOG="$LOG_DIR/uki-build.log" ;;
        16) COMPONENT_LOG="$LOG_DIR/esp-build.log" ;;
        21|22) COMPONENT_LOG="$LOG_DIR/validation.log" ;;
        24) COMPONENT_LOG="$LOG_DIR/cleanup.log" ;;
    esac
    log INFO "$CURRENT_STAGE_NAME"
    write_run_status RUNNING 0 "$CURRENT_STAGE_NAME"
}

run() {
    if [[ "$TRACE" == "true" ]]; then
        local rendered="" arg
        for arg in "$@"; do
            printf -v rendered '%s %q' "$rendered" "$arg"
        done
        log TRACE "Command:${rendered}"
    fi
    "$@"
}

safe_remove_tree() {
    local path="$1" allowed_root="$2" marker="$3"
    path="$(canonical_path "$path")"
    allowed_root="$(canonical_path "$allowed_root")"
    [[ -n "$path" && "$path" != "/" && "$path" != "/home" ]] || return 1
    path_is_within "$path" "$PROJECT_DIR" || return 1
    [[ "$path" != "$allowed_root" && "$path" == "$allowed_root/"* ]] || return 1
    [[ -f "$path/$marker" ]] || return 1
    # Files written through a rootless container bind mount can be protected by
    # the container user namespace. Remove them there first so failed builds do
    # not leave an undeletable work directory on the host.
    if command -v podman >/dev/null 2>&1; then
        podman unshare rm -rf --one-file-system -- "$path" && return 0
    fi
    rm -rf --one-file-system -- "$path"
}

container_work_path_safe() {
    local path
    path="$(canonical_path "$1")"
    [[ -f /work/.nabu-builder-work && -n "$path" && "$path" != "/" && "$path" != "/home" && "$path" != "/work" && "$path" == /work/* ]]
}

safe_remove_container_tree() {
    local path="$1"
    container_work_path_safe "$path" || return 1
    rm -rf --one-file-system -- "$(canonical_path "$path")"
}

list_partial_artifacts() {
    [[ -n "$BUILD_ROOT" && -d "$BUILD_ROOT" ]] || return 0
    find "$BUILD_ROOT" -type f \( -name '*.partial' -o -name '*.part' \) -print 2>/dev/null | sort
}

handle_error() {
    local code="$1" line="$2" command="$3" function_name="${4:-main}"
    local container_report_present="false"
    [[ "$ERROR_REPORTED" == "false" ]] || return 0
    if ((code == EXIT_PARTIAL)); then
        ERROR_REPORTED="true"
        log WARN "Build completed with partial success (exit $EXIT_PARTIAL); verified artifacts and failure reports are preserved."
        return 0
    fi
    ERROR_REPORTED="true"
    LAST_ERROR_COMMAND="$(redact "$command")"
    log ERROR "Build failed: stage=$CURRENT_STAGE ($CURRENT_STAGE_NAME), component=$CURRENT_COMPONENT, desktop=$CURRENT_DESKTOP, filesystem=$CURRENT_FILESYSTEM, exit=$code, function=$function_name, line=$line, command=$LAST_ERROR_COMMAND"
    log ERROR "Container=${CONTAINER_NAME:-none}; work=${WORK_RUN:-not-created}; main-log=${MAIN_LOG:-not-created}; component-log=${COMPONENT_LOG:-not-created}"
    if [[ -n "$BUILD_ID" ]]; then
        log ERROR "Automatic stage resume is disabled; use --reuse-core only with a validated fingerprint, or rerun after reviewing FAILURE.md."
        while IFS= read -r artifact; do
            [[ -n "$artifact" ]] && log ERROR "Partial artifact: $artifact"
        done < <(list_partial_artifacts)
    fi
    if [[ "$HOST_MODE" == "true" && -s "${BUILD_ROOT:-}/FAILURE.md" ]]; then
        container_report_present="true"
        log ERROR "The container's detailed STATUS.json and FAILURE.md were preserved; the host wrapper did not replace their stage and cause."
    fi
    if [[ "$container_report_present" != "true" ]]; then
        write_run_status FAILED "$code" "$CURRENT_STAGE_NAME: $LAST_ERROR_COMMAND" || true
        write_failure_report "$code" "$line" "$LAST_ERROR_COMMAND" "$function_name" || true
    fi
    update_latest_link latest-failed || true
}

cleanup_host() {
    local rc="$1"
    [[ "$HOST_MODE" == "true" ]] || return 0
    [[ "$ACTION" != "doctor" ]] || return 0
    [[ "$CLEANUP_DONE" == "false" ]] || return 0
    CLEANUP_DONE="true"
    if [[ -n "$CONTAINER_NAME" ]]; then
        podman rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    if ((rc != 0 && rc != EXIT_PARTIAL)); then
        [[ -z "$WORK_RUN" || ! -d "$WORK_RUN" ]] || warn "Failed build work directory preserved for diagnosis: $WORK_RUN"
        [[ -z "$CACHE_RUN" || ! -d "$CACHE_RUN" ]] || warn "Failed build cache preserved for a faster retry: $CACHE_RUN"
    else
        if [[ -n "$WORK_RUN" && -d "$WORK_RUN" && "$KEEP_WORK" != "true" ]]; then
            safe_remove_tree "$WORK_RUN" "$WORK_ROOT" .nabu-builder-work || warn "Refused unsafe work cleanup: $WORK_RUN"
        fi
        if [[ "$KEEP_CACHE" != "true" && -n "$CACHE_RUN" && -d "$CACHE_RUN" ]]; then
            safe_remove_tree "$CACHE_RUN" "$CACHE_ROOT" .nabu-builder-cache || warn "Refused unsafe cache cleanup: $CACHE_RUN"
        fi
    fi
    if [[ "$CLEANUP_CONTAINER_IMAGE" == "true" && "${CONTAINER_IMAGE_WAS_PRESENT:-true}" != "true" ]]; then
        if ! podman ps -a --format '{{.Image}}' | grep -Fxq "$CONTAINER_IMAGE"; then
            podman image rm "$CONTAINER_IMAGE" >/dev/null 2>&1 || warn "Container image cleanup was not possible."
        fi
    fi
    stop_notification_watcher
    release_build_lock
    send_notification "$rc" || true
    return 0
}

notification_available() {
    [[ "$NOTIFY" == "yes" ]] || return 1
    [[ -z "${CI:-}" ]] || return 1
    command -v notify-send >/dev/null 2>&1 || return 1
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_CURRENT_DESKTOP:-}" ]]
}

notification_language() {
    local system_locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    system_locale="${system_locale,,}"
    [[ "$system_locale" == tr* ]] && printf 'tr\n' || printf 'en\n'
}

format_duration() {
    local seconds="${1:-0}" language="${2:-en}" hours minutes remainder
    ((seconds >= 0)) || seconds=0
    hours=$((seconds / 3600))
    minutes=$(((seconds % 3600) / 60))
    remainder=$((seconds % 60))
    if [[ "$language" == "tr" ]]; then
        if ((hours > 0)); then
            printf '%d sa %d dk\n' "$hours" "$minutes"
        elif ((minutes > 0)); then
            printf '%d dk %d sn\n' "$minutes" "$remainder"
        else
            printf '%d sn\n' "$remainder"
        fi
    elif ((hours > 0)); then
        printf '%dh %dm\n' "$hours" "$minutes"
    elif ((minutes > 0)); then
        printf '%dm %ds\n' "$minutes" "$remainder"
    else
        printf '%ds\n' "$remainder"
    fi
}

elapsed_minute_mark() {
    local seconds="${1:-0}"
    ((seconds >= 0)) || seconds=0
    if ((seconds == 0)); then
        printf '0\n'
    else
        printf '%d\n' "$(((seconds + 59) / 60))"
    fi
}

stage_progress_percent() {
    local stage_number="${1:-0}"
    [[ "$stage_number" =~ ^[0-9]+$ ]] || stage_number=0
    case "$stage_number" in
        0) printf '0\n' ;;  1) printf '1\n' ;;  2) printf '2\n' ;;
        3) printf '3\n' ;;  4) printf '4\n' ;;  5) printf '7\n' ;;
        6) printf '10\n' ;; 7) printf '12\n' ;; 8) printf '15\n' ;;
        9) printf '22\n' ;; 10) printf '28\n' ;; 11) printf '32\n' ;;
        12) printf '40\n' ;; 13) printf '42\n' ;; 14) printf '47\n' ;;
        15) printf '52\n' ;; 16) printf '55\n' ;; 17) printf '58\n' ;;
        18) printf '72\n' ;; 19) printf '78\n' ;; 20) printf '82\n' ;;
        21) printf '88\n' ;; 22) printf '93\n' ;; 23) printf '98\n' ;;
        *) printf '100\n' ;;
    esac
}

stage_remaining_percent() {
    local progress
    progress="$(stage_progress_percent "$1")"
    progress="${progress:-0}"
    if ((progress >= 100)); then
        printf '0\n'
    elif ((progress <= 0)); then
        printf '100\n'
    else
        printf '%d\n' "$((100 - progress))"
    fi
}

localized_stage_name() {
    local stage_number="$1" language="$2" fallback="$3"
    if [[ "$language" != "tr" ]]; then
        printf '%s\n' "$fallback"
        return 0
    fi
    case "$stage_number" in
        0) printf 'Başlatma\n' ;;
        1) printf 'Ana sistem ve çalışma alanı keşfi\n' ;;
        2) printf 'Yerel Nabu RPM envanteri\n' ;;
        3) printf 'RPM uyumluluk doğrulaması\n' ;;
        4) printf 'Podman ve mimari doğrulaması\n' ;;
        5) printf 'Fedora Rawhide konteyner hazırlığı\n' ;;
        6) printf 'Resmî Rawhide compose metadatası\n' ;;
        7) printf 'Fedora paket gruplarını çözümleme\n' ;;
        8) printf 'Yerel DNF deposunu hazırlama\n' ;;
        9) printf 'Minimal Rawhide kök sistemi\n' ;;
        10) printf 'Nabu çalışma zamanı RPM kurulumu\n' ;;
        11) printf 'Core sistem yapılandırması\n' ;;
        12) printf 'Core dosya sistemi imajı oluşturma\n' ;;
        13) printf 'Core imaj doğrulaması\n' ;;
        14) printf 'Initramfs ve DTB doğrulaması\n' ;;
        15) printf 'Secure Boot UKI oluşturma\n' ;;
        16) printf 'EFI ve ESP imajı oluşturma\n' ;;
        17) printf 'Masaüstü varyantını klonlama\n' ;;
        18) printf 'Masaüstü paketlerini kurma\n' ;;
        19) printf 'İlk açılış yapılandırması\n' ;;
        20) printf 'Sanal klavye ve masaüstü ayarı\n' ;;
        21) printf 'SELinux ve systemd doğrulaması\n' ;;
        22) printf 'Dosya sistemini küçültme ve doğrulama\n' ;;
        23) printf 'Sıkıştırma, checksum ve parity\n' ;;
        24) printf 'Temizlik, son özet ve bildirim\n' ;;
        *) printf '%s\n' "$fallback" ;;
    esac
}

estimated_remaining_seconds() {
    local elapsed="$1" progress="$2"
    if ((elapsed < 30 || progress < 3 || progress >= 100)); then
        printf '%s\n' -1
    else
        printf '%d\n' "$((elapsed * (100 - progress) / progress))"
    fi
}

status_field() {
    local field="$1" fallback="${2:-}"
    if [[ -n "${STATUS_FILE:-}" && -s "$STATUS_FILE" ]] && command -v jq >/dev/null 2>&1; then
        local value
        value="$(jq -r --arg field "$field" '.[$field] // empty' "$STATUS_FILE" 2>/dev/null || true)"
        [[ -z "$value" ]] || { printf '%s\n' "$value"; return 0; }
    fi
    printf '%s\n' "$fallback"
}

emit_replaceable_notification() {
    local urgency="$1" icon="$2" title="$3" body="$4" timeout="${5:-10000}" id
    notification_available || return 0
    if [[ -n "$NOTIFICATION_ID" ]]; then
        notify-send --replace-id="$NOTIFICATION_ID" --urgency="$urgency" --expire-time="$timeout" \
            --app-name="$PROGRAM" --icon="$icon" "$title" "$body" >/dev/null 2>&1 || true
    else
        id="$(notify-send --print-id --urgency="$urgency" --expire-time="$timeout" \
            --app-name="$PROGRAM" --icon="$icon" "$title" "$body" 2>/dev/null || true)"
        [[ "$id" =~ ^[0-9]+$ ]] && NOTIFICATION_ID="$id"
    fi
}

emit_transient_notification() {
    local urgency="$1" icon="$2" title="$3" body="$4" timeout="${5:-8000}"
    notification_available || return 0
    notify-send --urgency="$urgency" --expire-time="$timeout" \
        --app-name="$PROGRAM" --icon="$icon" "$title" "$body" >/dev/null 2>&1 || true
}

send_build_started_notification() {
    local language title body
    notification_available || return 0
    language="$(notification_language)"
    if [[ "$language" == "tr" ]]; then
        title="Nabu Rawhide derlemesi başladı"
        printf -v body 'Durum: Hazırlanıyor\nProfil: %s / %s\nMod: %s\nBuild ID: %s\nİlerleme bildirimleri bu bildirimi güncelleyecek.' \
            "$DESKTOP" "$FILESYSTEM" "$BUILD_MODE" "$BUILD_ID"
    else
        title="Nabu Rawhide build started"
        printf -v body 'Status: Preparing\nProfile: %s / %s\nMode: %s\nBuild ID: %s\nProgress updates will replace this notification.' \
            "$DESKTOP" "$FILESYSTEM" "$BUILD_MODE" "$BUILD_ID"
    fi
    emit_replaceable_notification normal system-run "$title" "$body" 10000
}

send_step_completion_notification() {
    local completed_stage_number="$1" completed_stage_name="$2" component="$3" desktop="$4" filesystem="$5"
    local next_stage_number="${6:-}" next_stage_name="${7:-}"
    local language elapsed elapsed_text minute_mark remaining_percent title body completed_label next_label
    notification_available || return 0
    [[ "$STEP_BY_NOTIFICATION" == "true" ]] || return 0
    [[ "$completed_stage_number" =~ ^[0-9]+$ ]] || return 0
    ((completed_stage_number > 0)) || return 0

    language="$(notification_language)"
    elapsed="$(( $(date +%s) - START_EPOCH ))"
    elapsed_text="$(format_duration "$elapsed" "$language")"
    minute_mark="$(elapsed_minute_mark "$elapsed")"
    remaining_percent="$(stage_remaining_percent "$completed_stage_number")"
    completed_label="$(localized_stage_name "$completed_stage_number" "$language" "$completed_stage_name")"
    if [[ "$next_stage_number" =~ ^[0-9]+$ ]] && [[ -n "$next_stage_name" ]]; then
        next_label="$(localized_stage_name "$next_stage_number" "$language" "$next_stage_name")"
    else
        next_stage_number=""
        next_label=""
    fi

    if [[ "$language" == "tr" ]]; then
        title="Nabu aşama SUCCESS — ${completed_stage_number}/24"
        if [[ -n "$next_stage_number" ]]; then
            printf -v body 'Durum: SUCCESS\nBiten: %s/24 — %s\nBileşen: %s\nProfil: %s / %s\nDakika: %s\nGeçen süre: %s\nYaklaşık kalan: %%%s\nSıradaki: %s/24 — %s' \
                "$completed_stage_number" "$completed_label" "$component" "$desktop" "$filesystem" \
                "$minute_mark" "$elapsed_text" "$remaining_percent" "$next_stage_number" "$next_label"
        else
            printf -v body 'Durum: SUCCESS\nBiten: %s/24 — %s\nBileşen: %s\nProfil: %s / %s\nDakika: %s\nGeçen süre: %s\nYaklaşık kalan: %%%s' \
                "$completed_stage_number" "$completed_label" "$component" "$desktop" "$filesystem" \
                "$minute_mark" "$elapsed_text" "$remaining_percent"
        fi
    else
        title="Nabu step SUCCESS — ${completed_stage_number}/24"
        if [[ -n "$next_stage_number" ]]; then
            printf -v body 'Status: SUCCESS\nFinished: %s/24 — %s\nComponent: %s\nProfile: %s / %s\nMinute: %s\nElapsed: %s\nApprox remaining: %s%%\nNext: %s/24 — %s' \
                "$completed_stage_number" "$completed_label" "$component" "$desktop" "$filesystem" \
                "$minute_mark" "$elapsed_text" "$remaining_percent" "$next_stage_number" "$next_label"
        else
            printf -v body 'Status: SUCCESS\nFinished: %s/24 — %s\nComponent: %s\nProfile: %s / %s\nMinute: %s\nElapsed: %s\nApprox remaining: %s%%' \
                "$completed_stage_number" "$completed_label" "$component" "$desktop" "$filesystem" \
                "$minute_mark" "$elapsed_text" "$remaining_percent"
        fi
    fi
    emit_transient_notification low dialog-information "$title" "$body" 7000
}

send_stage_notification() {
    local stage_number="$1" stage_name="$2" component="$3" desktop="$4" filesystem="$5"
    local language elapsed progress remaining elapsed_text remaining_text title body
    notification_available || return 0
    language="$(notification_language)"
    stage_name="$(localized_stage_name "$stage_number" "$language" "$stage_name")"
    elapsed="$(( $(date +%s) - START_EPOCH ))"
    progress="$(stage_progress_percent "$stage_number")"
    remaining="$(estimated_remaining_seconds "$elapsed" "$progress")"
    elapsed_text="$(format_duration "$elapsed" "$language")"
    if ((remaining >= 0)); then
        remaining_text="$(format_duration "$remaining" "$language")"
    elif [[ "$language" == "tr" ]]; then
        remaining_text="hesaplanıyor"
    else
        remaining_text="calculating"
    fi
    if [[ "$language" == "tr" ]]; then
        title="Nabu derleniyor — yaklaşık %$progress"
        printf -v body 'Durum: Hata yok, işlem devam ediyor\nAşama: %s/24 — %s\nBileşen: %s\nProfil: %s / %s\nGeçen süre: %s\nTahmini kalan: %s (aşama bazlı)\nBuild ID: %s' \
            "$stage_number" "$stage_name" "$component" "$desktop" "$filesystem" "$elapsed_text" "$remaining_text" "$BUILD_ID"
    else
        title="Nabu build in progress — about $progress%"
        printf -v body 'Status: No error, build is running\nStage: %s/24 — %s\nComponent: %s\nProfile: %s / %s\nElapsed: %s\nEstimated remaining: %s (stage-based)\nBuild ID: %s' \
            "$stage_number" "$stage_name" "$component" "$desktop" "$filesystem" "$elapsed_text" "$remaining_text" "$BUILD_ID"
    fi
    emit_replaceable_notification normal system-run "$title" "$body" 12000
}

notification_progress_watcher() {
    local last_key="" last_running_stage_number="" last_running_stage_name="" last_running_component=""
    local last_running_desktop="" last_running_filesystem=""
    local state stage_number stage_name component desktop filesystem key snapshot
    while :; do
        if [[ -s "${STATUS_FILE:-}" ]] && command -v jq >/dev/null 2>&1; then
            snapshot="$(jq -r '[.status // "", ((.stage // 0) | tostring), .stage_name // "unknown", .component // "unknown", .desktop // "unknown", .filesystem // "unknown"] | @tsv' \
                "$STATUS_FILE" 2>/dev/null || true)"
            if [[ -z "$snapshot" ]]; then
                sleep 3
                continue
            fi
            IFS=$'\t' read -r state stage_number stage_name component desktop filesystem <<<"$snapshot"
            key="$state:$stage_number:$stage_name:$desktop:$filesystem"
            if [[ "$state" == "RUNNING" && "$key" != "$last_key" ]]; then
                if [[ -n "$last_running_stage_number" ]]; then
                    send_step_completion_notification \
                        "$last_running_stage_number" "$last_running_stage_name" "$last_running_component" \
                        "$last_running_desktop" "$last_running_filesystem" "$stage_number" "$stage_name"
                fi
                if [[ "$component" != "CONTAINER" ]]; then
                    send_stage_notification "$stage_number" "$stage_name" "$component" "$desktop" "$filesystem"
                fi
                last_running_stage_number="$stage_number"
                last_running_stage_name="$stage_name"
                last_running_component="$component"
                last_running_desktop="$desktop"
                last_running_filesystem="$filesystem"
                last_key="$key"
            fi
        fi
        sleep 3
    done
}

start_notification_watcher() {
    notification_available || return 0
    send_build_started_notification
    (
        trap - ERR EXIT INT TERM HUP
        set +e
        notification_progress_watcher
    ) &
    NOTIFICATION_WATCHER_PID=$!
}

stop_notification_watcher() {
    [[ -n "$NOTIFICATION_WATCHER_PID" ]] || return 0
    kill "$NOTIFICATION_WATCHER_PID" >/dev/null 2>&1 || true
    wait "$NOTIFICATION_WATCHER_PID" >/dev/null 2>&1 || true
    NOTIFICATION_WATCHER_PID=""
}

send_notification() {
    local rc="$1" language title body urgency icon action_label open_path action
    local elapsed elapsed_text stage_number stage_name progress remaining remaining_text status_message
    local rootfs_count=0 boot_count=0 report_count=0 variant_count=0 result_label variant_list="none"
    notification_available || return 0
    language="$(notification_language)"
    elapsed="$(( $(date +%s) - START_EPOCH ))"
    elapsed_text="$(format_duration "$elapsed" "$language")"
    stage_number="$(status_field stage "$((10#$CURRENT_STAGE))")"
    stage_name="$(status_field stage_name "$CURRENT_STAGE_NAME")"
    stage_name="$(localized_stage_name "$stage_number" "$language" "$stage_name")"
    status_message="$(status_field message '')"
    progress="$(stage_progress_percent "$stage_number")"
    remaining="$(estimated_remaining_seconds "$elapsed" "$progress")"
    if ((remaining >= 0)); then
        remaining_text="$(format_duration "$remaining" "$language")"
    elif [[ "$language" == "tr" ]]; then
        remaining_text="hesaplanamadı"
    else
        remaining_text="unavailable"
    fi
    [[ ! -d "${ROOTFS_ARTIFACT_DIR:-}" ]] || rootfs_count="$(find "$ROOTFS_ARTIFACT_DIR" -maxdepth 1 -type f ! -name '*.partial' | wc -l)"
    [[ ! -d "${BOOT_ARTIFACT_DIR:-}" ]] || boot_count="$(find "$BOOT_ARTIFACT_DIR" -maxdepth 1 -type f ! -name '*.partial' | wc -l)"
    [[ ! -d "${REPORTS_DIR:-}" ]] || report_count="$(find "$REPORTS_DIR" -maxdepth 1 -type f | wc -l)"
    if [[ -s "${METADATA_DIR:-}/successful-variants.txt" ]]; then
        variant_count="$(wc -l <"$METADATA_DIR/successful-variants.txt")"
        variant_list="$(paste -sd, "$METADATA_DIR/successful-variants.txt" | sed 's/,/, /g')"
    fi
    open_path="${BUILD_ROOT:-$PROJECT_DIR}"
    if ((rc == 0)); then
        urgency="normal"; icon="emblem-default"
        if [[ "$DRY_RUN" == "true" ]]; then
            result_label="PREFLIGHT_PASS"
        else
            result_label="COMPLETE"
        fi
        if [[ "$language" == "tr" ]]; then
            title="Nabu Rawhide işlemi tamamlandı"
            action_label="Çıktı klasörünü aç"
            printf -v body 'Durum: %s — hata yok\nTamamlanan varyantlar (%s): %s\nDosyalar: %s rootfs, %s boot dosyası, %s rapor\nToplam süre: %s\nSon aşama: %s/24 — %s\nBuild ID: %s\nÖzet: %s/SUMMARY.md\nÇıktı: %s\nKlasörü açmak için bildirime tıklayın.' \
                "$result_label" "$variant_count" "$variant_list" "$rootfs_count" "$boot_count" "$report_count" "$elapsed_text" \
                "$stage_number" "$stage_name" "$BUILD_ID" "$open_path" "$open_path"
        else
            title="Nabu Rawhide operation completed"
            action_label="Open output folder"
            printf -v body 'Status: %s — no error\nCompleted variants (%s): %s\nFiles: %s rootfs, %s boot files, %s reports\nTotal time: %s\nFinal stage: %s/24 — %s\nBuild ID: %s\nSummary: %s/SUMMARY.md\nOutput: %s\nClick the notification to open the folder.' \
                "$result_label" "$variant_count" "$variant_list" "$rootfs_count" "$boot_count" "$report_count" "$elapsed_text" \
                "$stage_number" "$stage_name" "$BUILD_ID" "$open_path" "$open_path"
        fi
    elif ((rc == EXIT_PARTIAL)); then
        urgency="normal"; icon="dialog-warning"; result_label="PARTIAL"
        if [[ "$language" == "tr" ]]; then
            title="Nabu kısmen tamamlandı"
            action_label="Raporları aç"
            printf -v body 'Durum: PARTIAL — bazı varyantlarda hata/atlama var\nTamamlanan varyantlar (%s): %s\nDosyalar: %s rootfs, %s boot dosyası, %s rapor\nToplam süre: %s\nSon aşama: %s/24 — %s\nBuild ID: %s\nÇıktı: %s\nAyrıntı: %s/reports/FAILED-VARIANTS.md\nKlasörü açmak için bildirime tıklayın.' \
                "$variant_count" "$variant_list" "$rootfs_count" "$boot_count" "$report_count" "$elapsed_text" \
                "$stage_number" "$stage_name" "$BUILD_ID" "$open_path" "$open_path"
        else
            title="Nabu build partially completed"
            action_label="Open reports"
            printf -v body 'Status: PARTIAL — some variants failed or were skipped\nCompleted variants (%s): %s\nFiles: %s rootfs, %s boot files, %s reports\nTotal time: %s\nFinal stage: %s/24 — %s\nBuild ID: %s\nOutput: %s\nDetails: %s/reports/FAILED-VARIANTS.md\nClick the notification to open the folder.' \
                "$variant_count" "$variant_list" "$rootfs_count" "$boot_count" "$report_count" "$elapsed_text" \
                "$stage_number" "$stage_name" "$BUILD_ID" "$open_path" "$open_path"
        fi
    else
        urgency="critical"; icon="dialog-error"; result_label="FAILED"
        [[ -n "$status_message" ]] || status_message="exit $rc"
        if [[ "$language" == "tr" ]]; then
            title="Nabu derlemesi başarısız — aşama $stage_number/24"
            action_label="Hata klasörünü aç"
            printf -v body 'Durum: FAILED — hata var\nNeden: %s\nHata aşaması: %s/24 — %s\nÇıkış kodu: %s\nHatanın oluştuğu süre: %s\nO anda tahmini kalan: %s (aşama bazlı)\nBuild ID: %s\nHata raporu: %s/FAILURE.md\nAna log: %s' \
                "$status_message" "$stage_number" "$stage_name" "$rc" "$elapsed_text" "$remaining_text" "$BUILD_ID" \
                "$open_path" "${MAIN_LOG:-oluşturulmadı}"
        else
            title="Nabu build failed — stage $stage_number/24"
            action_label="Open failure folder"
            printf -v body 'Status: FAILED — error detected\nReason: %s\nFailed stage: %s/24 — %s\nExit code: %s\nFailure occurred after: %s\nEstimated remaining at failure: %s (stage-based)\nBuild ID: %s\nFailure report: %s/FAILURE.md\nMain log: %s' \
                "$status_message" "$stage_number" "$stage_name" "$rc" "$elapsed_text" "$remaining_text" "$BUILD_ID" \
                "$open_path" "${MAIN_LOG:-not created}"
        fi
    fi
    (
        trap - ERR EXIT INT TERM HUP
        set +e
        local -a notification_args=(--urgency="$urgency" --expire-time=30000 --app-name="$PROGRAM" --icon="$icon")
        [[ -z "$NOTIFICATION_ID" ]] || notification_args+=(--replace-id="$NOTIFICATION_ID")
        notification_args+=(--hint="string:x-kde-urls:file://$open_path" --action="default=$action_label")
        action="$(notify-send "${notification_args[@]}" "$title" "$body" 2>/dev/null || true)"
        if [[ "$action" == "default" ]] && command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$open_path" >/dev/null 2>&1 || true
        fi
    ) </dev/null >/dev/null 2>&1 &
}

handle_exit() {
    local rc="$1"
    if ((rc != 0)) && [[ "$ERROR_REPORTED" == "false" ]]; then
        handle_error "$rc" "${BASH_LINENO[0]:-0}" "${LAST_ERROR_COMMAND:-exit}" "${FUNCNAME[1]:-main}"
    fi
    if [[ "$HOST_MODE" == "true" ]]; then
        cleanup_host "$rc"
    else
        cleanup_container_state || true
    fi
    if [[ "$HOST_MODE" == "true" && -t 1 ]]; then
        printf '\a'
    fi
    # An EXIT trap must not replace the pipeline's successful exit status with
    # a best-effort cleanup or notification status.
    return 0
}

on_signal() {
    local signal="$1"
    log ERROR "Received signal $signal; cancelling."
    exit "$EXIT_CANCELLED"
}

install_traps() {
    trap 'handle_error "$?" "$LINENO" "$BASH_COMMAND" "${FUNCNAME[0]:-main}"' ERR
    trap 'handle_exit "$?"' EXIT
    trap 'on_signal INT' INT
    trap 'on_signal TERM' TERM
    trap 'on_signal HUP' HUP
}

require_host_command() {
    command -v "$1" >/dev/null 2>&1 || die_early "$2" "Required host command is missing: $1"
}

validate_input_file() {
    local path="$1" label="$2"
    [[ -f "$path" && -r "$path" ]] || die_early "$EXIT_USAGE" "$label is not a readable regular file."
}

validate_input_directory() {
    local path="$1" label="$2"
    [[ -d "$path" && -r "$path" ]] || die_early "$EXIT_USAGE" "$label is not a readable directory: $path"
}

host_preflight() {
    stage 1 HOST
    require_host_command bash "$EXIT_GENERAL"
    require_host_command podman "$EXIT_CONTAINER"
    require_host_command realpath "$EXIT_GENERAL"
    require_host_command sha256sum "$EXIT_GENERAL"
    require_host_command find "$EXIT_GENERAL"
    require_host_command date "$EXIT_GENERAL"

    WORKSPACE_ROOT="$(find_workspace_root "$PWD" || find_workspace_root "$SCRIPT_DIR" || true)"
    [[ -n "$WORKSPACE_ROOT" ]] || die_early "$EXIT_GENERAL" "Could not identify a workspace root within the current directory and two parents."
    if [[ -z "$RPM_SEARCH_ROOT" ]]; then
        RPM_SEARCH_ROOT="$WORKSPACE_ROOT"
    else
        RPM_SEARCH_ROOT="$(canonical_path "$RPM_SEARCH_ROOT")"
    fi
    validate_input_directory "$RPM_SEARCH_ROOT" "RPM search root"
    log INFO "Workspace root: $WORKSPACE_ROOT"
    log INFO "Project directory: $PROJECT_DIR"
    log INFO "RPM search root: $RPM_SEARCH_ROOT"
    log INFO "Existing projects and RPM outputs are mounted read-only and are never changed."

    local path label
    while IFS='|' read -r path label; do
        [[ -z "$path" ]] || validate_input_directory "$(canonical_path "$path")" "$label"
    done <<EOF
$RPM_DIR|RPM directory
$KERNEL_RPM_DIR|Kernel RPM directory
$DEVICE_RPM_DIR|Device RPM directory
$BOOT_RPM_DIR|Boot RPM directory
EOF

    [[ -z "$FROM_CORE" ]] || validate_input_file "$(canonical_path "$FROM_CORE")" "Core image"
    [[ -z "$REUSE_CORE" ]] || validate_input_file "$(canonical_path "$REUSE_CORE")" "Reusable core image"
    [[ -z "$EXISTING_ESP" ]] || validate_input_file "$(canonical_path "$EXISTING_ESP")" "Existing ESP image"
    [[ -z "$SB_KEY" ]] || validate_input_file "$(canonical_path "$SB_KEY")" "Secure Boot private key"
    [[ -z "$SB_CERT" ]] || validate_input_file "$(canonical_path "$SB_CERT")" "Secure Boot certificate"
    [[ -z "$UEFI_TRUSTED_CERT" ]] || validate_input_file "$(canonical_path "$UEFI_TRUSTED_CERT")" "UEFI trusted certificate"
}

container_image_preflight() {
    stage 4 CONTAINER
    local host_arch test_output
    host_arch="$(uname -m)"
    CONTAINER_IMAGE_WAS_PRESENT="false"
    podman image exists "$CONTAINER_IMAGE" && CONTAINER_IMAGE_WAS_PRESENT="true"
    log INFO "Host architecture: $host_arch; requested mode: $ARCH_MODE"
    log INFO "Podman version: $(podman --version)"

    case "$host_arch" in
        aarch64|arm64)
            [[ "$ARCH_MODE" != "explicit-qemu" ]] || warn "explicit-qemu is unnecessary on an aarch64 host; native execution will be used."
            CONTAINER_ARCH="arm64"
            ;;
        x86_64|amd64)
            if [[ "$ARCH_MODE" == "native" ]]; then
                die_early "$EXIT_CONTAINER" "--arch-mode native requires an aarch64 host."
            fi
            local arch_rc=0
            if test_output="$(podman run --rm --arch arm64 "$CONTAINER_IMAGE" /usr/bin/true 2>&1)"; then
                arch_rc=0
            else
                arch_rc=$?
            fi
            if ((arch_rc == 0)); then
                CONTAINER_ARCH="arm64"
                log INFO "Existing aarch64 binfmt execution is functional."
            elif [[ "$DRY_RUN" == "true" ]]; then
                CONTAINER_ARCH="amd64-preflight"
                local arch_reason
                if grep -qi 'exec format error' <<<"$test_output"; then
                    arch_reason="exec format error"
                else
                    arch_reason="$(redact "$test_output" | awk 'NF {line=$0} END {print line}')"
                fi
                warn "Aarch64 binfmt is unavailable (${arch_reason:-probe failed}); dry-run will query aarch64 repositories with DNF5 --forcearch."
                if [[ "$ALLOW_BINFMT_INSTALL" == "true" ]]; then
                    warn "--allow-binfmt-install was acknowledged, but dry-run does not mutate host binfmt state."
                fi
            elif [[ "$ARCH_MODE" == "explicit-qemu" ]]; then
                die_early "$EXIT_CONTAINER" "Explicit QEMU cannot safely execute all RPM scriptlets without a working binfmt registration; refusing an unverifiable build."
            else
                if [[ "$ALLOW_BINFMT_INSTALL" == "true" ]]; then
                    die_early "$EXIT_CONTAINER" "Aarch64 binfmt is absent. Host binfmt installation is authorized but deliberately not performed by an unpinned helper; install Fedora qemu-user-binfmt, then rerun."
                fi
                die_early "$EXIT_CONTAINER" "Aarch64 binfmt is not functional. Configure it explicitly or use an aarch64 host; the builder will not change host binfmt without authorization."
            fi
            ;;
        *) die_early "$EXIT_CONTAINER" "Unsupported host architecture: $host_arch" ;;
    esac
}

add_env_arg() {
    local name="$1" value="$2"
    PODMAN_ARGS+=(--env "$name=$value")
}

add_optional_readonly_mount() {
    local host_path="$1" container_path="$2" kind="$3"
    [[ -n "$host_path" ]] || return 0
    host_path="$(canonical_path "$host_path")"
    if [[ "$kind" == "dir" ]]; then
        validate_input_directory "$host_path" "$container_path"
    else
        validate_input_file "$host_path" "$container_path"
    fi
    PODMAN_ARGS+=(--volume "$host_path:$container_path:ro")
}

append_container_privilege_args() {
    if [[ "$PRIVILEGED_CONTAINER" == "true" ]]; then
        PODMAN_ARGS+=(--privileged)
    fi
}

export_container_options() {
    add_env_arg NABU_DESKTOP "$DESKTOP"
    add_env_arg NABU_FILESYSTEM "$FILESYSTEM"
    add_env_arg NABU_DEFAULT_SHELL "$DEFAULT_SHELL"
    add_env_arg NABU_BUILD_MODE "$BUILD_MODE"
    add_env_arg NABU_SECURE_BOOT "$SECURE_BOOT"
    add_env_arg NABU_GENERATE_DEVELOPMENT_SB_KEY "$GENERATE_DEVELOPMENT_SB_KEY"
    add_env_arg NABU_BOOTLOADER "$BOOTLOADER"
    add_env_arg NABU_FEDORA_PARITY "$FEDORA_PARITY"
    add_env_arg NABU_RAWHIDE_COMPOSE "$RAWHIDE_COMPOSE"
    add_env_arg NABU_RAWHIDE_COMPOSE_ID "$RAWHIDE_COMPOSE_ID"
    add_env_arg NABU_RAWHIDE_REPO_BASEURL "$RAWHIDE_REPO_BASEURL"
    add_env_arg NABU_CORE_ONLY "$CORE_ONLY"
    add_env_arg NABU_KEEP_CORE "$KEEP_CORE"
    add_env_arg NABU_REBUILD_CORE "$REBUILD_CORE"
    add_env_arg NABU_VARIANTS_ONLY "$VARIANTS_ONLY"
    add_env_arg NABU_CORE_SIZE "$CORE_SIZE"
    add_env_arg NABU_IMAGE_SIZE "$IMAGE_SIZE"
    add_env_arg NABU_ESP_SIZE "$ESP_SIZE"
    add_env_arg NABU_IMAGE_BACKEND "$IMAGE_BACKEND"
    add_env_arg NABU_ALLOW_PRIVILEGED_IMAGE_BACKEND "$ALLOW_PRIVILEGED_IMAGE_BACKEND"
    add_env_arg NABU_PRIVILEGED_CONTAINER "$PRIVILEGED_CONTAINER"
    add_env_arg NABU_ARCH_MODE "$ARCH_MODE"
    add_env_arg NABU_JOBS "$JOBS"
    add_env_arg NABU_COMPRESSION_LEVEL "$COMPRESSION_LEVEL"
    add_env_arg NABU_KEEP_CACHE "$KEEP_CACHE"
    add_env_arg NABU_KEEP_WORK "$KEEP_WORK"
    add_env_arg NABU_RESUME "$RESUME"
    add_env_arg NABU_LOCALE "$LOCALE"
    add_env_arg NABU_TIMEZONE "$TIMEZONE"
    add_env_arg NABU_KEYBOARD_LAYOUT "$KEYBOARD_LAYOUT"
    add_env_arg NABU_KERNEL_CMDLINE "$KERNEL_CMDLINE"
    add_env_arg NABU_DEVICE_REPO_URL "$DEVICE_REPO_URL"
    add_env_arg NABU_ALLOW_EXTERNAL_REPOS "$ALLOW_EXTERNAL_REPOS"
    add_env_arg NABU_ALLOW_EXPERIMENTAL_DESKTOP "$ALLOW_EXPERIMENTAL_DESKTOP"
    add_env_arg NABU_DRY_RUN "$DRY_RUN"
    add_env_arg NABU_DEBUG "$DEBUG"
    add_env_arg NABU_TRACE "$TRACE"
    add_env_arg NABU_BUILD_ID "$BUILD_ID"
    add_env_arg NABU_BUILD_STAMP "$BUILD_STAMP"
    add_env_arg NABU_START_ISO "$START_ISO"
    add_env_arg NABU_START_EPOCH "$START_EPOCH"
    add_env_arg NABU_CONTAINER_ARCH "$CONTAINER_ARCH"
    add_env_arg NABU_SCRIPT_VERSION "$SCRIPT_VERSION"
    add_env_arg NABU_HOST_ARCH "$(uname -m)"
    add_env_arg NABU_HOST_OS "$(if [[ -r /etc/os-release ]]; then . /etc/os-release; printf '%s' "${PRETTY_NAME:-unknown}"; else printf unknown; fi)"
    add_env_arg NABU_PODMAN_VERSION "$(podman --version)"
    add_env_arg NABU_CONTAINER_DIGEST "$(podman image inspect --format '{{.Digest}}' "$CONTAINER_IMAGE" 2>/dev/null || printf unknown)"
}

run_container() {
    stage 5 CONTAINER
    CONTAINER_NAME="nabu-fedora-rawhide-builder-$$-$RANDOM"
    # shellcheck disable=SC2054 # Commas belong to Podman tmpfs option values.
    declare -ga PODMAN_ARGS=(
        run --rm --name "$CONTAINER_NAME"
        --security-opt label=disable
        --volume "$SCRIPT_DIR/Nabu-Fedora-Rawhide-Builder.sh:/builder/Nabu-Fedora-Rawhide-Builder.sh:ro"
        --volume "$WORKSPACE_ROOT:/workspace:ro"
        --volume "$WORK_RUN:/work:rw"
        --volume "$CACHE_RUN:/cache:rw"
        --volume "$CACHE_RUN/dnf:/var/cache/libdnf5:rw"
        --volume "$BUILD_ROOT:/output:rw"
        --tmpfs /tmp:rw,nodev,nosuid,size=6G
        --tmpfs /run:rw,nodev,nosuid,size=256M
        --env NABU_IN_CONTAINER=1
    )
    append_container_privilege_args
    if [[ "$PRIVILEGED_CONTAINER" == "true" ]]; then
        warn "Privileged container mode is enabled; Podman device and security isolation is substantially reduced."
    fi
    if [[ "$CONTAINER_ARCH" == "arm64" ]]; then
        PODMAN_ARGS+=(--arch arm64)
    else
        PODMAN_ARGS+=(--arch amd64)
    fi
    [[ ! -e /dev/fuse || "$IMAGE_BACKEND" == "loop" ]] || PODMAN_ARGS+=(--device /dev/fuse)

    add_optional_readonly_mount "$RPM_SEARCH_ROOT" /rpm-search-root dir
    add_optional_readonly_mount "$RPM_DIR" /extra-rpm/general dir
    add_optional_readonly_mount "$KERNEL_RPM_DIR" /extra-rpm/kernel dir
    add_optional_readonly_mount "$DEVICE_RPM_DIR" /extra-rpm/device dir
    add_optional_readonly_mount "$BOOT_RPM_DIR" /extra-rpm/boot dir
    add_optional_readonly_mount "$FROM_CORE" /inputs/from-core.img file
    add_optional_readonly_mount "$REUSE_CORE" /inputs/reuse-core.img file
    if [[ -n "$REUSE_CORE" && -f "$(canonical_path "$REUSE_CORE").fingerprint" ]]; then
        add_optional_readonly_mount "$(canonical_path "$REUSE_CORE").fingerprint" /inputs/reuse-core.img.fingerprint file
    fi
    add_optional_readonly_mount "$EXISTING_ESP" /inputs/existing-esp.img file
    add_optional_readonly_mount "$SB_KEY" /run/secrets/nabu-sb.key file
    add_optional_readonly_mount "$SB_CERT" /inputs/nabu-sb.crt file
    add_optional_readonly_mount "$UEFI_TRUSTED_CERT" /inputs/uefi-trusted.crt file
    export_container_options

    log INFO "Starting container $CONTAINER_NAME from $CONTAINER_IMAGE ($CONTAINER_ARCH); privileged=$PRIVILEGED_CONTAINER."
    if [[ "$PRIVILEGED_CONTAINER" == "true" ]]; then
        log WARN "No host filesystem is bind-mounted except declared project inputs, but privileged mode may expose host devices."
    else
        log INFO "No host /boot, /boot/efi, root filesystem, physical disk, or NVMe device is mounted."
    fi
    if podman "${PODMAN_ARGS[@]}" "$CONTAINER_IMAGE" /usr/bin/bash /builder/Nabu-Fedora-Rawhide-Builder.sh --internal-container; then
        CONTAINER_RC=0
    else
        CONTAINER_RC=$?
    fi
    CONTAINER_NAME=""
    # Return the container status through CONTAINER_RC. This keeps setup
    # fail-fast without changing the caller's errexit setting.
    return 0
}

load_container_options() {
    DESKTOP="${NABU_DESKTOP:?}"
    FILESYSTEM="${NABU_FILESYSTEM:?}"
    DEFAULT_SHELL="${NABU_DEFAULT_SHELL:?}"
    BUILD_MODE="${NABU_BUILD_MODE:?}"
    SECURE_BOOT="${NABU_SECURE_BOOT:?}"
    GENERATE_DEVELOPMENT_SB_KEY="${NABU_GENERATE_DEVELOPMENT_SB_KEY:?}"
    BOOTLOADER="${NABU_BOOTLOADER:?}"
    FEDORA_PARITY="${NABU_FEDORA_PARITY:?}"
    RAWHIDE_COMPOSE="${NABU_RAWHIDE_COMPOSE:?}"
    RAWHIDE_COMPOSE_ID="${NABU_RAWHIDE_COMPOSE_ID:-}"
    RAWHIDE_REPO_BASEURL="${NABU_RAWHIDE_REPO_BASEURL:-}"
    CORE_ONLY="${NABU_CORE_ONLY:?}"
    KEEP_CORE="${NABU_KEEP_CORE:?}"
    REBUILD_CORE="${NABU_REBUILD_CORE:?}"
    VARIANTS_ONLY="${NABU_VARIANTS_ONLY:?}"
    CORE_SIZE="${NABU_CORE_SIZE:?}"
    IMAGE_SIZE="${NABU_IMAGE_SIZE:?}"
    ESP_SIZE="${NABU_ESP_SIZE:?}"
    IMAGE_BACKEND="${NABU_IMAGE_BACKEND:?}"
    ALLOW_PRIVILEGED_IMAGE_BACKEND="${NABU_ALLOW_PRIVILEGED_IMAGE_BACKEND:?}"
    PRIVILEGED_CONTAINER="${NABU_PRIVILEGED_CONTAINER:?}"
    ARCH_MODE="${NABU_ARCH_MODE:?}"
    JOBS="${NABU_JOBS:?}"
    COMPRESSION_LEVEL="${NABU_COMPRESSION_LEVEL:?}"
    KEEP_CACHE="${NABU_KEEP_CACHE:?}"
    KEEP_WORK="${NABU_KEEP_WORK:?}"
    RESUME="${NABU_RESUME:?}"
    LOCALE="${NABU_LOCALE:?}"
    TIMEZONE="${NABU_TIMEZONE:?}"
    KEYBOARD_LAYOUT="${NABU_KEYBOARD_LAYOUT:?}"
    KERNEL_CMDLINE="${NABU_KERNEL_CMDLINE:-}"
    DEVICE_REPO_URL="${NABU_DEVICE_REPO_URL:-}"
    ALLOW_EXTERNAL_REPOS="${NABU_ALLOW_EXTERNAL_REPOS:?}"
    ALLOW_EXPERIMENTAL_DESKTOP="${NABU_ALLOW_EXPERIMENTAL_DESKTOP:?}"
    DRY_RUN="${NABU_DRY_RUN:?}"
    DEBUG="${NABU_DEBUG:?}"
    TRACE="${NABU_TRACE:?}"
    BUILD_ID="${NABU_BUILD_ID:?}"
    BUILD_STAMP="${NABU_BUILD_STAMP:?}"
    START_ISO="${NABU_START_ISO:?}"
    START_EPOCH="${NABU_START_EPOCH:?}"
    CONTAINER_ARCH="${NABU_CONTAINER_ARCH:?}"
    WORKSPACE_ROOT="/workspace"
    RPM_SEARCH_ROOT="/rpm-search-root"
    WORK_RUN="/work"
    CACHE_RUN="/cache"
    BUILD_ROOT="/output"
    set_output_layout
    FROM_CORE=""
    REUSE_CORE=""
    EXISTING_ESP=""
    SB_KEY=""
    SB_CERT=""
    UEFI_TRUSTED_CERT=""
    [[ -f /inputs/from-core.img ]] && FROM_CORE="/inputs/from-core.img"
    [[ -f /inputs/reuse-core.img ]] && REUSE_CORE="/inputs/reuse-core.img"
    [[ -f /inputs/existing-esp.img ]] && EXISTING_ESP="/inputs/existing-esp.img"
    [[ -f /run/secrets/nabu-sb.key ]] && SB_KEY="/run/secrets/nabu-sb.key"
    [[ -f /inputs/nabu-sb.crt ]] && SB_CERT="/inputs/nabu-sb.crt"
    [[ -f /inputs/uefi-trusted.crt ]] && UEFI_TRUSTED_CERT="/inputs/uefi-trusted.crt"
    return 0
}

container_install_tools() {
    stage 5 CONTAINER
    local -a packages=(
        bash coreutils findutils grep sed gawk util-linux file curl ca-certificates
        dnf5 dnf5-plugins rpm rpm-build createrepo_c jq git openssl
    )
    if [[ "$DRY_RUN" != "true" ]]; then
        packages+=(
            rpm-build zstd zip unzip systemd-ukify systemd-boot-unsigned dracut
            kmod binutils sbsigntools dosfstools mtools e2fsprogs btrfs-progs
            rsync tar xz libguestfs-tools-c fuse2fs policycoreutils selinux-policy-targeted
        )
    fi
    # This is a disposable build-tools container, never a booted operating
    # system. Avoiding scriptlets here prevents Rawhide's broken swtpm SELinux
    # module from aborting the tool installation; target-root scriptlets remain
    # enabled and are handled separately with a local capability package.
    if dnf5 -y --setopt=install_weak_deps=False --setopt=tsflags=noscripts install "${packages[@]}" 2>&1 | tee -a "$COMPONENT_LOG"; then
        :
    else
        local rc="${PIPESTATUS[0]}"
        log ERROR "Container tool transaction failed (exit $rc); full package and scriptlet output is in $COMPONENT_LOG."
        return "$rc"
    fi
    command -v rpm >/dev/null
    command -v dnf5 >/dev/null
    command -v jq >/dev/null
    log INFO "Container tools installed from Fedora Rawhide; host package state was not modified."
}

declare -a RPM_CANDIDATES=()
declare -a SELECTED_RPMS=()
declare -A SELECTED_BY_REQUIREMENT=()
declare -A RPM_NAME=()
declare -A RPM_EVR=()
declare -A RPM_ARCH=()
declare -A RPM_NEVRA=()
declare -A RPM_SHA256=()
declare -A RPM_SOURCE=()
declare -A RPM_SIGNED=()

discover_rpm_candidates() {
    stage 2 RPM
    local -a roots=()
    local directory rpm_path
    roots+=("$RPM_SEARCH_ROOT")
    for directory in /extra-rpm/general /extra-rpm/kernel /extra-rpm/device /extra-rpm/boot; do
        [[ -d "$directory" ]] && roots+=("$directory")
    done
    declare -A seen=()
    for directory in "${roots[@]}"; do
        while IFS= read -r -d '' rpm_path; do
            [[ "$rpm_path" == */Nabu-Fedora-Rawhide-Builder/output/* ]] && continue
            [[ "$rpm_path" == */Nabu-Fedora-Rawhide-Builder/work/* ]] && continue
            [[ "$rpm_path" == */Nabu-Fedora-Rawhide-Builder/cache/* ]] && continue
            [[ -n "${seen[$rpm_path]:-}" ]] && continue
            seen[$rpm_path]=1
            RPM_CANDIDATES+=("$rpm_path")
        done < <(
            if [[ "$directory" == "$RPM_SEARCH_ROOT" ]]; then
                find "$directory" -maxdepth 5 -type f -name '*.rpm' \
                    \( -path '*/nabu-kernel-test-output/*' \
                    -o -path '*/nabu-copr-packages-test-output/*' \
                    -o -path '*/nabu-boot-test-output/*' \
                    -o -path '*/Nabu-Linux-Spesific-File-Compailer/*' \) -print0
            else
                find "$directory" -maxdepth 4 -type f -name '*.rpm' -print0
            fi
        )
    done
    ((${#RPM_CANDIDATES[@]} > 0)) || {
        log ERROR "No RPM files were discovered in the permitted search locations."
        return "$EXIT_RPM_MISSING"
    }
    mapfile -t RPM_CANDIDATES < <(printf '%s\n' "${RPM_CANDIDATES[@]}" | sort -u)
    : >"$METADATA_DIR/local-rpm-inventory.txt"
    local file name epoch version release arch source nevra sha signature signature_rc
    for file in "${RPM_CANDIDATES[@]}"; do
        IFS='|' read -r name epoch version release arch source < <(
            rpm -qp --qf '%{NAME}|%{EPOCHNUM}|%{VERSION}|%{RELEASE}|%{ARCH}|%{SOURCERPM}\n' "$file"
        )
        IFS=$'\n\t'
        [[ "$arch" == "aarch64" || "$arch" == "noarch" ]] || {
            log WARN "Ignoring non-aarch64 RPM: $name-$version-$release.$arch"
            continue
        }
        nevra="$name-$epoch:$version-$release.$arch"
        sha="$(sha256sum "$file" | awk '{print $1}')"
        RPM_NAME[$file]="$name"
        RPM_EVR[$file]="$epoch:$version-$release"
        RPM_ARCH[$file]="$arch"
        RPM_NEVRA[$file]="$nevra"
        RPM_SHA256[$file]="$sha"
        RPM_SOURCE[$file]="$source"
        signature_rc=0
        if signature="$(rpm -Kv "$file" 2>&1)"; then
            signature_rc=0
        else
            signature_rc=$?
        fi
        if grep -qiE '(digest: BAD|NOT OK|FAILED)' <<<"$signature"; then
            log ERROR "RPM digest/integrity validation failed for $file"
            return "$EXIT_RPM_MISSING"
        fi
        grep -q 'Payload SHA256 digest: OK' <<<"$signature" || {
            log ERROR "RPM payload SHA256 could not be verified for $file (rpm exit $signature_rc)."
            return "$EXIT_RPM_MISSING"
        }
        if grep -q 'NOTFOUND' <<<"$signature"; then
            RPM_SIGNED[$file]="false"
        else
            RPM_SIGNED[$file]="true"
        fi
        printf '%s|%s|%s|%s|%s\n' "$nevra" "$sha" "$source" "$file" "$( [[ "${RPM_SIGNED[$file]}" == true ]] && printf SIGNED || printf UNSIGNED )" \
            >>"$METADATA_DIR/local-rpm-inventory.txt"
        {
            printf '===== %s =====\n' "$file"
            printf '%s\n' "$signature"
            printf '%s\n' '--- requires ---'; rpm -qpR "$file"
            printf '%s\n' '--- provides ---'; rpm -qp --provides "$file"
            printf '%s\n' '--- conflicts ---'; rpm -qp --conflicts "$file"
            printf '%s\n' '--- obsoletes ---'; rpm -qp --obsoletes "$file"
            printf '%s\n' '--- scripts ---'; rpm -qp --scripts "$file"
            printf '%s\n' '--- payload ---'; rpm -qpl "$file"
        } >>"$LOG_DIR/rpm-discovery.log" 2>&1
        log INFO "Inventoried $nevra sha256=$sha"
    done
}

rpm_provides_requirement() {
    local file="$1" requirement="$2"
    [[ "${RPM_NAME[$file]:-}" == "$requirement" ]] && return 0
    rpm -qp --provides "$file" | awk -v requirement="$requirement" '$1 == requirement { found=1 } END { exit !found }'
}

rpm_evr_compare() {
    local left="$1" right="$2" escaped_left escaped_right
    escaped_left=${left//\\/\\\\}; escaped_left=${escaped_left//\"/\\\"}
    escaped_right=${right//\\/\\\\}; escaped_right=${escaped_right//\"/\\\"}
    rpm --eval "%{lua:print(rpm.vercmp(\"$escaped_left\", \"$escaped_right\"))}"
}

select_latest_requirement() {
    local requirement="$1" file best="" comparison
    for file in "${!RPM_NAME[@]}"; do
        rpm_provides_requirement "$file" "$requirement" || continue
        if [[ -z "$best" ]]; then
            best="$file"
            continue
        fi
        comparison="$(rpm_evr_compare "${RPM_EVR[$file]}" "${RPM_EVR[$best]}")"
        if ((comparison > 0)); then
            best="$file"
        elif ((comparison == 0)) && [[ "${RPM_SHA256[$file]}" != "${RPM_SHA256[$best]}" ]]; then
            log ERROR "Ambiguous duplicate RPMs have equal EVR but different payload hashes for $requirement."
            return "$EXIT_RPM_MISSING"
        fi
    done
    [[ -n "$best" ]] || return 1
    SELECTED_BY_REQUIREMENT[$requirement]="$best"
}

select_rpm_set() {
    stage 3 RPM
    local -a mandatory=(kernel-nabu kernel-nabu-core kernel-nabu-modules xiaomi-nabu-firmware nabu-fedora-configs-core nabu-fedora-boot)
    local -a optional=(kernel-nabu-modules-extra kernel-nabu-devel xiaomi-nabu-configs alsa-ucm-conf-sm8150)
    local requirement file
    local -a missing=()
    for requirement in "${mandatory[@]}"; do
        if ! select_latest_requirement "$requirement"; then
            missing+=("$requirement")
        fi
    done
    if ((${#missing[@]})); then
        printf '%s\n' "${missing[@]}" >"$METADATA_DIR/missing-local-rpms.txt"
        log ERROR "Required local RPMs are missing: ${missing[*]}"
        return "$EXIT_RPM_MISSING"
    fi
    for requirement in "${optional[@]}"; do
        select_latest_requirement "$requirement" || log WARN "Optional local RPM not found: $requirement"
    done
    for requirement in "${!SELECTED_BY_REQUIREMENT[@]}"; do
        file="${SELECTED_BY_REQUIREMENT[$requirement]}"
        if [[ "${RPM_NAME[$file]}" == "kernel-nabu-devel" ]]; then
            log INFO "Selected build-only kernel family validator => ${RPM_NEVRA[$file]} (excluded from runtime image)"
            continue
        fi
        SELECTED_RPMS+=("$file")
        log INFO "Selected $requirement => ${RPM_NEVRA[$file]}"
    done
    mapfile -t SELECTED_RPMS < <(printf '%s\n' "${SELECTED_RPMS[@]}" | sort -u)

    local kernel_evr="${RPM_EVR[${SELECTED_BY_REQUIREMENT[kernel-nabu]}]}"
    for requirement in kernel-nabu-core kernel-nabu-modules kernel-nabu-devel; do
        [[ -n "${SELECTED_BY_REQUIREMENT[$requirement]:-}" ]] || continue
        [[ "${RPM_EVR[${SELECTED_BY_REQUIREMENT[$requirement]}]}" == "$kernel_evr" ]] || {
            log ERROR "Kernel RPM set does not share one EVR family."
            return "$EXIT_RPM_MISSING"
        }
    done
    if [[ -n "${SELECTED_BY_REQUIREMENT[kernel-nabu-modules-extra]:-}" ]]; then
        [[ "${RPM_EVR[${SELECTED_BY_REQUIREMENT[kernel-nabu-modules-extra]}]}" == "$kernel_evr" ]] || {
            log ERROR "kernel-nabu-modules-extra is from a different kernel family."
            return "$EXIT_RPM_MISSING"
        }
    fi
    local core_uname modules_uname
    core_uname="$(rpm -qp --provides "${SELECTED_BY_REQUIREMENT[kernel-nabu-core]}" | awk '$1=="kernel-nabu-core-uname-r" {print $3; exit}')"
    modules_uname="$(rpm -qpR "${SELECTED_BY_REQUIREMENT[kernel-nabu-modules]}" | awk '$1=="kernel-nabu-core-uname-r" {print $3; exit}')"
    [[ -n "$core_uname" && "$core_uname" == "$modules_uname" ]] || {
        log ERROR "Kernel core/modules uname-r dependency mismatch."
        return "$EXIT_RPM_MISSING"
    }
    KERNEL_RELEASE="$core_uname"
    KERNEL_NEVRA="${RPM_NEVRA[${SELECTED_BY_REQUIREMENT[kernel-nabu]}]}"
    log INFO "Validated kernel family $kernel_evr; uname-r=$KERNEL_RELEASE"
}

prepare_local_repository() {
    stage 8 RPM
    LOCAL_REPO="/work/local-rpm-repository"
    [[ ! -e "$LOCAL_REPO" ]] || safe_remove_container_tree "$LOCAL_REPO"
    mkdir -p "$LOCAL_REPO"
    local rpm_file
    for rpm_file in "${SELECTED_RPMS[@]}"; do
        cp --reflink=auto -- "$rpm_file" "$LOCAL_REPO/"
    done
    generate_rawhide_compatibility_rpms
    generate_rawhide_swtpm_selinux_compatibility_rpm
    run createrepo_c --checksum sha256 "$LOCAL_REPO"
    cat >"/work/nabu-local.repo" <<EOF
[nabu-local]
name=Nabu local build inputs (explicitly unsigned)
baseurl=file://$LOCAL_REPO
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=never
EOF
    warn "Local RPM repository uses narrowly scoped gpgcheck=0 because the discovered user-built RPMs are unsigned; official Fedora repositories retain gpgcheck=1."
}

generate_rawhide_compatibility_rpms() {
    local configs_rpm="${SELECTED_BY_REQUIREMENT[nabu-fedora-configs-core]:-}"
    local compat_manifest="$METADATA_DIR/generated-compatibility-rpms.txt"
    : >"$compat_manifest"
    [[ -n "$configs_rpm" ]] || return 0
    rpm -qpR "$configs_rpm" | awk '$1 == "systemd-zram-generator" { found=1 } END { exit !found }' || return 0

    if dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" repoquery --available --whatprovides systemd-zram-generator 2>/dev/null \
        | grep -q '^systemd-zram-generator'; then
        return 0
    fi
    repo_package_exists zram-generator || {
        log ERROR "The local configs RPM requires the retired systemd-zram-generator capability, and Rawhide has neither that capability nor its zram-generator successor."
        return "$EXIT_RPM_MISSING"
    }

    local topdir="/work/compat-rpmbuild" spec generated
    spec="$topdir/SPECS/nabu-rawhide-zram-compat.spec"
    mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    cat >"$spec" <<'EOF'
Name:           nabu-rawhide-zram-compat
Version:        1
Release:        1
Summary:        Nabu compatibility capability for the Rawhide zram-generator rename
License:        MIT
BuildArch:      noarch
Requires:       zram-generator
Provides:       systemd-zram-generator = 1

%description
Metadata-only compatibility package for Nabu RPMs built before Fedora renamed
the systemd-zram-generator binary package to zram-generator.

%prep
%build
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
printf '%s\n' 'Compatibility metadata only; implementation is provided by zram-generator.' > %{buildroot}%{_datadir}/doc/%{name}/README

%files
%{_datadir}/doc/%{name}/README
EOF
    if ! rpmbuild -bb --define "_topdir $topdir" "$spec" >>"$COMPONENT_LOG" 2>&1; then
        log ERROR "Failed to build the zram package-rename compatibility RPM; see $COMPONENT_LOG."
        return "$EXIT_RPM_MISSING"
    fi
    generated="$(find "$topdir/RPMS" -type f -name 'nabu-rawhide-zram-compat-*.rpm' -print -quit)"
    [[ -n "$generated" ]] || {
        log ERROR "Failed to create the narrowly scoped zram compatibility RPM."
        return "$EXIT_RPM_MISSING"
    }
    cp -- "$generated" "$LOCAL_REPO/"
    printf '%s  %s\n' "$(sha256sum "$generated" | awk '{print $1}')" "$(rpm -qp --qf '%{NEVRA}' "$generated")" >>"$compat_manifest"
    warn "Generated a metadata-only compatibility RPM: systemd-zram-generator -> zram-generator (Fedora Rawhide package rename)."
}

generate_rawhide_swtpm_selinux_compatibility_rpm() {
    repo_package_exists swtpm-selinux || return 0

    local topdir="/work/compat-rpmbuild-swtpm" spec generated
    spec="$topdir/SPECS/nabu-rawhide-swtpm-selinux-compat.spec"
    mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    cat >"$spec" <<'EOF'
Name:           nabu-rawhide-swtpm-selinux-compat
Version:        1
Release:        1
Summary:        Nabu compatibility capability for the broken Rawhide swtpm SELinux module
License:        MIT
BuildArch:      noarch
Provides:       swtpm-selinux = 1

%description
Metadata-only compatibility capability. Nabu images do not use a virtual TPM;
the current Rawhide swtpm-selinux module cannot be linked against the targeted
policy from the same compose.

%prep
%build
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
printf '%s\n' 'Compatibility capability only; no virtual TPM SELinux policy is installed.' > %{buildroot}%{_datadir}/doc/%{name}/README

%files
%{_datadir}/doc/%{name}/README
EOF
    if ! rpmbuild -bb --define "_topdir $topdir" "$spec" >>"$COMPONENT_LOG" 2>&1; then
        log ERROR "Failed to build the swtpm SELinux compatibility RPM; see $COMPONENT_LOG."
        return "$EXIT_RPM_MISSING"
    fi
    generated="$(find "$topdir/RPMS" -type f -name 'nabu-rawhide-swtpm-selinux-compat-*.rpm' -print -quit)"
    [[ -n "$generated" ]] || {
        log ERROR "Failed to create the swtpm SELinux compatibility RPM."
        return "$EXIT_RPM_MISSING"
    }
    cp -- "$generated" "$LOCAL_REPO/"
    printf '%s  %s\n' "$(sha256sum "$generated" | awk '{print $1}')" "$(rpm -qp --qf '%{NEVRA}' "$generated")" \
        >>"$METADATA_DIR/generated-compatibility-rpms.txt"
    warn "Generated a metadata-only compatibility RPM for Rawhide's broken swtpm-selinux policy module."
}

RAWHIDE_COMPOSE_DATE=""
RAWHIDE_COMPOSE_STATUS=""
RAWHIDE_REPOMD_SHA256=""
RAWHIDE_COMPS_SHA256=""
RAWHIDE_COMPS_LOCATION=""
RAWHIDE_KICKSTART_SHA=""
RAWHIDE_METALINK="https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=aarch64"
declare -a DNF_RAW_ARGS=()
declare -a DNF_EXTERNAL_REPO_ARGS=()

resolve_rawhide_metadata() {
    stage 6 RAWHIDE
    local compose_base repomd_url repomd_file compose_json
    if [[ -n "$RAWHIDE_COMPOSE_ID" ]]; then
        compose_base="https://kojipkgs.fedoraproject.org/compose/rawhide/$RAWHIDE_COMPOSE_ID"
    else
        compose_base="https://kojipkgs.fedoraproject.org/compose/rawhide/latest-Fedora-Rawhide"
        RAWHIDE_COMPOSE_ID="$(curl -fsSL --retry 3 "$compose_base/COMPOSE_ID")"
        compose_base="https://kojipkgs.fedoraproject.org/compose/rawhide/$RAWHIDE_COMPOSE_ID"
    fi
    RAWHIDE_COMPOSE_STATUS="$(curl -fsSL --retry 3 "$compose_base/STATUS")"
    compose_json="$(curl -fsSL --retry 3 "$compose_base/compose/metadata/composeinfo.json")"
    RAWHIDE_COMPOSE_DATE="$(jq -r '.payload.compose.date // empty' <<<"$compose_json")"
    [[ -n "$RAWHIDE_COMPOSE_DATE" ]] || RAWHIDE_COMPOSE_DATE="$(sed -nE 's/^Fedora-Rawhide-([0-9]{8}).*/\1/p' <<<"$RAWHIDE_COMPOSE_ID")"
    jq . <<<"$compose_json" >"$METADATA_DIR/rawhide-compose-metadata.json"
    printf '%s\n' "$RAWHIDE_COMPOSE_ID" "$RAWHIDE_COMPOSE_STATUS" >>"$LOG_DIR/rawhide-compose.log"
    if [[ -z "$RAWHIDE_REPO_BASEURL" ]]; then
        RAWHIDE_REPO_BASEURL="$compose_base/compose/Everything/aarch64/os"
    fi
    RAWHIDE_REPO_BASEURL="${RAWHIDE_REPO_BASEURL%/}"
    DNF_RAW_ARGS=(
        "${DNF_ARCH_ARGS[@]}"
        "--setopt=rawhide.baseurl=$RAWHIDE_REPO_BASEURL"
        "--setopt=rawhide.metalink="
        "--setopt=rawhide.mirrorlist="
    )
    if [[ -n "$DEVICE_REPO_URL" ]]; then
        DNF_EXTERNAL_REPO_ARGS=(
            "--repofrompath=nabu-device,$DEVICE_REPO_URL"
            "--setopt=nabu-device.gpgcheck=1"
        )
        warn "The explicitly authorized device repository is enabled with package signature verification."
    fi
    repomd_url="$RAWHIDE_REPO_BASEURL/repodata/repomd.xml"
    repomd_file="/work/repomd.xml"
    curl -fsSL --retry 3 "$repomd_url" -o "$repomd_file"
    RAWHIDE_REPOMD_SHA256="$(sha256sum "$repomd_file" | awk '{print $1}')"
    IFS=' ' read -r RAWHIDE_COMPS_SHA256 RAWHIDE_COMPS_LOCATION < <(
        awk '
            /<data type="group">/ { in_group=1 }
            in_group && /<checksum / { line=$0; sub(/^[^>]*>/,"",line); sub(/<.*$/,"",line); checksum=line }
            in_group && /<location href=/ { line=$0; sub(/^.*href="/,"",line); sub(/".*$/,"",line); print checksum, line; exit }
        ' "$repomd_file"
    )
    [[ -n "$RAWHIDE_COMPS_SHA256" && -n "$RAWHIDE_COMPS_LOCATION" ]] || {
        log ERROR "Official Rawhide repomd.xml has no comps/group metadata."
        return "$EXIT_RAWHIDE"
    }
    RAWHIDE_KICKSTART_SHA="$(git ls-remote https://pagure.io/fedora-kickstarts.git HEAD | awk 'NR==1 {print $1}')"
    [[ "$RAWHIDE_KICKSTART_SHA" =~ ^[0-9a-f]{40}$ ]] || {
        log ERROR "Could not resolve Fedora kickstarts commit SHA."
        return "$EXIT_RAWHIDE"
    }
    [[ "$RAWHIDE_COMPOSE_STATUS" == "FINISHED" ]] || warn "Official compose status is $RAWHIDE_COMPOSE_STATUS; repository metadata will still be verified and the status recorded."
    log INFO "Rawhide compose=$RAWHIDE_COMPOSE_ID date=$RAWHIDE_COMPOSE_DATE status=$RAWHIDE_COMPOSE_STATUS"
    log INFO "repomd sha256=$RAWHIDE_REPOMD_SHA256; comps sha256=$RAWHIDE_COMPS_SHA256; kickstart=$RAWHIDE_KICKSTART_SHA"
}

DNF_ARCH_ARGS=(--forcearch=aarch64 --releasever=rawhide)
declare -A PROFILE_ENVIRONMENT=(
    [kde-plasma]=kde-desktop-environment
    [kde-mobile]=kde-mobile-environment
    [gnome]=workstation-product-environment
    [phosh]=phosh-desktop-environment
)
RESOLVED_GROUPS=()
RESOLVED_ENVIRONMENTS=()
GNOME_MOBILE_AVAILABLE="false"

dnf_group_exists() {
    awk -v id="$1" '$1 == id { found=1 } END { exit !found }' /work/rawhide-groups.txt
}

dnf_environment_exists() {
    awk -v id="$1" '$1 == id { found=1 } END { exit !found }' /work/rawhide-environments.txt
}

repo_package_exists() {
    dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" repoquery --available --qf '%{name}' "$1" 2>/dev/null | grep -Fxq "$1"
}

resolve_fedora_groups() {
    stage 7 RAWHIDE
    run dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" group list --available --hidden > /work/rawhide-groups.txt
    run dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" environment list --available > /work/rawhide-environments.txt
    cp /work/rawhide-groups.txt "$METADATA_DIR/rawhide-group-list.txt"
    cp /work/rawhide-environments.txt "$METADATA_DIR/rawhide-environment-list.txt"
    local group environment profile
    for group in core hardware-support; do
        dnf_group_exists "$group" || {
            log ERROR "Required official Fedora group ID is absent: $group"
            return "$EXIT_RAWHIDE"
        }
        RESOLVED_GROUPS+=("$group")
    done
    while IFS= read -r profile; do
        [[ -n "$profile" ]] || continue
        case "$profile" in
            no-desktop|gnome-mobile) continue ;;
        esac
        environment="${PROFILE_ENVIRONMENT[$profile]}"
        dnf_environment_exists "$environment" || {
            log ERROR "Official environment $environment required for $profile is absent; no fallback was substituted."
            return "$EXIT_RAWHIDE"
        }
        RESOLVED_ENVIRONMENTS+=("$environment")
    done < <(expand_desktops)
    if repo_package_exists gnome-mobile || repo_package_exists gnome-shell-mobile; then
        GNOME_MOBILE_AVAILABLE="true"
    fi
    log INFO "Resolved official groups: ${RESOLVED_GROUPS[*]}"
    log INFO "Resolved official environments: ${RESOLVED_ENVIRONMENTS[*]:-none}"
    [[ "$GNOME_MOBILE_AVAILABLE" == "true" ]] || log WARN "GNOME_MOBILE_UNAVAILABLE: Rawhide has no distinct gnome-mobile or gnome-shell-mobile package/session."
}

expand_desktops() {
    if [[ "$DESKTOP" == "all" ]]; then
        printf '%s\n' kde-plasma kde-mobile gnome gnome-mobile phosh no-desktop
    else
        tr ',' '\n' <<<"$DESKTOP"
    fi
}

expand_filesystems() {
    if [[ "$FILESYSTEM" == "all" ]]; then
        printf '%s\n' ext4 btrfs
    else
        printf '%s\n' "$FILESYSTEM"
    fi
}

certificate_fingerprint() {
    local certificate="$1"
    openssl x509 -in "$certificate" -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/^.*=//; s/://g' \
        || openssl x509 -inform DER -in "$certificate" -noout -fingerprint -sha256 | sed 's/^.*=//; s/://g'
}

SIGNING_CERT_FINGERPRINT=""
TRUSTED_CERT_FINGERPRINT=""
SECURE_BOOT_STATUS="SECURE_BOOT_DISABLED"
ACTIVE_SB_KEY=""
ACTIVE_SB_CERT=""

secure_boot_preflight() {
    [[ "$SECURE_BOOT" == "on" ]] || {
        SECURE_BOOT_STATUS="SECURE_BOOT_DISABLED"
        return 0
    }
    if [[ "$GENERATE_DEVELOPMENT_SB_KEY" == "true" ]]; then
        mkdir -p /work/private-keys
        chmod 0700 /work/private-keys
        ACTIVE_SB_KEY="/work/private-keys/development.key"
        ACTIVE_SB_CERT="/work/private-keys/development.crt"
        openssl req -new -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
            -subj "/CN=Nabu Fedora Rawhide Development Key/" \
            -keyout "$ACTIVE_SB_KEY" -out "$ACTIVE_SB_CERT" >/dev/null 2>&1
        chmod 0600 "$ACTIVE_SB_KEY"
        cp "$ACTIVE_SB_CERT" "$BOOT_ARTIFACT_DIR/nabu-development-sb-enrollment.crt"
        SECURE_BOOT_STATUS="DEVELOPMENT_KEY_REQUIRES_UEFI_ENROLLMENT"
        warn "An ephemeral development Secure Boot key was generated; its private half will be destroyed and the public certificate requires UEFI enrollment."
    else
        ACTIVE_SB_KEY="$SB_KEY"
        ACTIVE_SB_CERT="$SB_CERT"
    fi
    if [[ -z "$ACTIVE_SB_KEY" || -z "$ACTIVE_SB_CERT" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            SECURE_BOOT_STATUS="PREFLIGHT_MISSING_SIGNING_INPUTS"
            warn "Secure Boot signing inputs are missing; real build would exit $EXIT_SECURE_BOOT."
            return 0
        fi
        return "$EXIT_SECURE_BOOT"
    fi
    openssl pkey -in "$ACTIVE_SB_KEY" -noout >/dev/null
    SIGNING_CERT_FINGERPRINT="$(certificate_fingerprint "$ACTIVE_SB_CERT")"
    [[ -n "$SIGNING_CERT_FINGERPRINT" ]] || return "$EXIT_SECURE_BOOT"
    if [[ -n "$UEFI_TRUSTED_CERT" ]]; then
        TRUSTED_CERT_FINGERPRINT="$(certificate_fingerprint "$UEFI_TRUSTED_CERT")"
    fi
    if [[ -n "$TRUSTED_CERT_FINGERPRINT" && "$SIGNING_CERT_FINGERPRINT" == "$TRUSTED_CERT_FINGERPRINT" ]]; then
        SECURE_BOOT_STATUS="VERIFIED_SECURE_BOOT"
    elif [[ "$GENERATE_DEVELOPMENT_SB_KEY" != "true" ]]; then
        SECURE_BOOT_STATUS="SIGNED_BUT_TRUST_NOT_VERIFIED"
    fi
    log INFO "Secure Boot certificate fingerprint: $SIGNING_CERT_FINGERPRINT"
    log INFO "UEFI trust status: $SECURE_BOOT_STATUS"
    if [[ "$FEDORA_PARITY" == "strict" && "$DRY_RUN" != "true" && "$SECURE_BOOT_STATUS" != "VERIFIED_SECURE_BOOT" ]]; then
        log ERROR "Strict mode requires identical signing and UEFI-trusted certificate fingerprints."
        return "$EXIT_SECURE_BOOT"
    fi
}

dnf_target() {
    local root="$1"; shift
    # The local compatibility RPM provides this capability without installing
    # Rawhide's currently un-linkable virtual TPM policy module. The target's
    # remaining RPM scriptlets and SELinux policy setup still run normally.
    # The installroot starts empty, so it has no rawhide.repo of its own.
    # Reuse the prepared container repository definitions while preserving the
    # explicitly pinned Rawhide base URL in DNF_RAW_ARGS.
    if dnf5 -y --use-host-config --installroot="$root" "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" \
        --setopt=install_weak_deps=True \
        --setopt=keepcache=True \
        --setopt=cachedir=/cache/dnf \
        --setopt=gpgcheck=1 \
        --repofrompath="nabu-local,file:///work/local-rpm-repository" \
        --setopt=nabu-local.gpgcheck=0 \
        --exclude=swtpm-selinux \
        "$@" 2>&1 | tee -a "$COMPONENT_LOG"; then
        return 0
    fi
    local rc="${PIPESTATUS[0]}"
    log ERROR "DNF5 transaction failed (exit $rc); full package and scriptlet output is in $COMPONENT_LOG."
    return "$rc"
}

install_available_packages() {
    local root="$1" required="$2"; shift 2
    local -a install=()
    local package
    for package in "$@"; do
        if repo_package_exists "$package"; then
            install+=("$package")
        elif [[ "$required" == "required" ]]; then
            log ERROR "Required Rawhide package is unavailable for aarch64: $package"
            return "$EXIT_RAWHIDE"
        else
            warn "Optional Rawhide package unavailable for aarch64: $package"
        fi
    done
    ((${#install[@]} == 0)) || dnf_target "$root" install "${install[@]}"
}

CORE_ROOTFS=""
CORE_IMAGE=""
CORE_FINGERPRINT=""

create_core_installroot() {
    local filesystem="$1"
    stage 9 CORE
    CORE_ROOTFS="/work/core-rootfs-$filesystem"
    [[ ! -e "$CORE_ROOTFS" ]] || safe_remove_container_tree "$CORE_ROOTFS"
    mkdir -p "$CORE_ROOTFS"
    warn "Rawhide's broken swtpm-selinux policy module is replaced by a local metadata-only compatibility capability; Nabu has no virtual TPM dependency."
    dnf_target "$CORE_ROOTFS" group install core hardware-support
    install_available_packages "$CORE_ROOTFS" required \
        fedora-release fedora-repos fedora-gpg-keys bash dnf5 systemd systemd-udev \
        NetworkManager firewalld policycoreutils selinux-policy-targeted dracut \
        systemd-ukify systemd-boot-unsigned util-linux podman pipewire wireplumber \
        initial-setup openssl ca-certificates kmod
    install_available_packages "$CORE_ROOTFS" optional \
        NetworkManager-wifi systemd-oomd-defaults zram-generator-defaults \
        systemd-zram-generator qrtr rmtfs tqftpserv qbootctl alsa-utils alsa-ucm
    log INFO "Official Core and Hardware Support groups installed into the aarch64 installroot."
}

install_nabu_runtime_rpms() {
    local root="$1"
    stage 10 CORE
    local -a package_names=()
    local file name
    for file in "${SELECTED_RPMS[@]}"; do
        name="${RPM_NAME[$file]}"
        [[ "$name" == "kernel-nabu-devel" ]] && continue
        package_names+=("$name")
    done
    dnf_target "$root" install "${package_names[@]}"
    if rpm --root "$root" -q kernel-nabu-devel >/dev/null 2>&1; then
        log ERROR "kernel-nabu-devel leaked into the runtime image."
        return "$EXIT_RPM_MISSING"
    fi
    log INFO "Installed selected local runtime RPM set through the temporary createrepo_c repository."
}

write_shell_firstboot_service() {
    local root="$1" shell_path
    case "$DEFAULT_SHELL" in
        bash) shell_path=/bin/bash ;;
        fish) shell_path=/usr/bin/fish ;;
        zsh) shell_path=/bin/zsh ;;
    esac
    mkdir -p "$root/usr/libexec" "$root/usr/lib/systemd/system" "$root/etc/systemd/system/multi-user.target.wants"
    cat >"$root/usr/libexec/nabu-apply-default-shell" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
marker=/var/lib/nabu-firstboot/shell-applied
[[ ! -e \"\$marker\" ]] || exit 0
uid_min=1000
if [[ -r /etc/login.defs ]]; then
    configured=\$(awk '\$1 == "UID_MIN" { print \$2; exit }' /etc/login.defs)
    [[ \"\${configured:-}\" =~ ^[0-9]+\$ ]] && uid_min=\$configured
fi
user=\$(getent passwd | awk -F: -v min=\"\$uid_min\" '\$3 >= min && \$3 < 65534 && \$1 != "nobody" { print \$1; exit }')
[[ -n \"\$user\" ]] || exit 75
usermod --shell '$shell_path' \"\$user\"
[[ \$(getent passwd \"\$user\" | cut -d: -f7) == '$shell_path' ]]
install -d -m0755 /var/lib/nabu-firstboot
touch \"\$marker\"
systemctl disable nabu-apply-default-shell.service >/dev/null 2>&1 || true
EOF
    chmod 0755 "$root/usr/libexec/nabu-apply-default-shell"
    cat >"$root/usr/lib/systemd/system/nabu-apply-default-shell.service" <<'EOF'
[Unit]
Description=Apply selected shell to the first Initial Setup user
After=initial-setup.service systemd-user-sessions.service
ConditionPathExists=!/var/lib/nabu-firstboot/shell-applied

[Service]
Type=oneshot
ExecStart=/usr/libexec/nabu-apply-default-shell
Restart=on-failure
RestartSec=15s

[Install]
WantedBy=multi-user.target
EOF
    ln -sfn /usr/lib/systemd/system/nabu-apply-default-shell.service \
        "$root/etc/systemd/system/multi-user.target.wants/nabu-apply-default-shell.service"
}

write_fstab() {
    local root="$1" filesystem="$2"
    mkdir -p "$root/etc"
    if [[ "$filesystem" == "ext4" ]]; then
        cat >"$root/etc/fstab" <<'EOF'
PARTLABEL=linux / ext4 rw,errors=remount-ro,x-systemd.growfs 0 1
PARTLABEL=esp /boot/efi vfat umask=0077 0 2
EOF
    else
        cat >"$root/etc/fstab" <<'EOF'
PARTLABEL=linux / btrfs rw,subvol=@,compress=zstd:3,noatime 0 0
PARTLABEL=linux /home btrfs rw,subvol=@home,compress=zstd:3,noatime 0 0
PARTLABEL=esp /boot/efi vfat umask=0077 0 2
EOF
    fi
}

repair_known_runtime_packaging_issues() {
    local root="$1" unit report
    unit="$root/usr/lib/systemd/system/ath10k-shutdown.service"
    report="$METADATA_DIR/applied-compatibility-fixes.txt"
    [[ -f "$unit" ]] || return 0
    if grep -qx -- '-ExecStop=/usr/sbin/modprobe -r ath10k_snoc ath10k_core' "$unit"; then
        sed -i 's#^-ExecStop=/usr/sbin/modprobe -r ath10k_snoc ath10k_core$#ExecStop=-/usr/sbin/modprobe -r ath10k_snoc ath10k_core#' "$unit"
        grep -qx -- 'ExecStop=-/usr/sbin/modprobe -r ath10k_snoc ath10k_core' "$unit" \
            || return "$EXIT_CORE"
        printf '%s\n' 'nabu-fedora-configs-core: corrected malformed -ExecStop directive in ath10k-shutdown.service; RPM source should use ExecStop=-command.' \
            >>"$report"
        warn "Corrected the known malformed ath10k-shutdown.service ExecStop directive and recorded the compatibility fix."
    fi
    if grep -Eq '^-[A-Za-z][A-Za-z]+=' "$unit"; then
        log ERROR "Malformed systemd directive remains in ${unit#"$root"}: $(grep -Em1 '^-[A-Za-z][A-Za-z]+=' "$unit")"
        return "$EXIT_CORE"
    fi
}

enable_unit_offline() {
    local root="$1" unit="$2" target="${3:-multi-user.target}"
    [[ -f "$root/usr/lib/systemd/system/$unit" || -f "$root/lib/systemd/system/$unit" ]] || return 1
    mkdir -p "$root/etc/systemd/system/$target.wants"
    ln -sfn "/usr/lib/systemd/system/$unit" "$root/etc/systemd/system/$target.wants/$unit"
}

set_default_target_offline() {
    local root="$1" target="$2"
    mkdir -p "$root/etc/systemd/system"
    ln -sfn "/usr/lib/systemd/system/$target" "$root/etc/systemd/system/default.target"
}

configure_initial_setup() {
    local root="$1" graphical="$2"
    [[ -x "$root/usr/libexec/initial-setup/run-initial-setup" ]] || {
        log ERROR "Fedora Initial Setup runner is absent."
        return "$EXIT_FIRSTBOOT"
    }
    if [[ "$graphical" == "true" ]]; then
        [[ -x "$root/usr/libexec/initial-setup/initial-setup-graphical" ]] || {
            log ERROR "Graphical variant lacks initial-setup-gui payload."
            return "$EXIT_FIRSTBOOT"
        }
    else
        [[ -x "$root/usr/libexec/initial-setup/initial-setup-text" ]] || {
            log ERROR "Text Initial Setup payload is absent."
            return "$EXIT_FIRSTBOOT"
        }
    fi
    : >"$root/.unconfigured"
    enable_unit_offline "$root" initial-setup.service "$( [[ "$graphical" == true ]] && printf graphical.target || printf multi-user.target )"
    if [[ -f "$root/usr/lib/systemd/system/initial-setup-reconfiguration.service" ]]; then
        enable_unit_offline "$root" initial-setup-reconfiguration.service "$( [[ "$graphical" == true ]] && printf graphical.target || printf multi-user.target )"
    fi
}

configure_core_system() {
    local root="$1" filesystem="$2"
    stage 11 CORE
    install_available_packages "$root" required "$DEFAULT_SHELL"
    write_fstab "$root" "$filesystem"
    repair_known_runtime_packaging_issues "$root"
    write_shell_firstboot_service "$root"
    set_default_target_offline "$root" multi-user.target
    configure_initial_setup "$root" false
    mkdir -p "$root/etc/locale.conf.d" "$root/etc/vconsole.conf.d" "$root/etc/systemd"
    printf 'LANG=%s\n' "$LOCALE" >"$root/etc/locale.conf"
    printf 'KEYMAP=%s\n' "$KEYBOARD_LAYOUT" >"$root/etc/vconsole.conf"
    ln -sfn "/usr/share/zoneinfo/$TIMEZONE" "$root/etc/localtime"
    printf '%s\n' "$TIMEZONE" >"$root/etc/timezone"
    printf 'SELINUX=enforcing\nSELINUXTYPE=targeted\n' >"$root/etc/selinux/config"
    enable_unit_offline "$root" NetworkManager.service multi-user.target || return "$EXIT_CORE"
    enable_unit_offline "$root" firewalld.service multi-user.target || return "$EXIT_CORE"
    : >"$root/etc/machine-id"
    rm -f "$root/var/lib/systemd/random-seed"
    find "$root/etc/ssh" -maxdepth 1 -type f -name 'ssh_host_*' -delete 2>/dev/null || true
    log INFO "Core configured for SELinux enforcing, Fedora Initial Setup TUI, NetworkManager, firewalld, and idempotent first-user shell selection."
}

clean_rootfs() {
    local root="$1"
    container_work_path_safe "$root" || return "$EXIT_CORE"
    : >"$root/etc/machine-id"
    rm -f "$root/var/lib/systemd/random-seed"
    find "$root/etc/ssh" -maxdepth 1 -type f -name 'ssh_host_*' -delete 2>/dev/null || true
    local cleanup_dir
    for cleanup_dir in "$root/var/cache/dnf" "$root/tmp" "$root/var/tmp" "$root/var/log/journal"; do
        [[ ! -d "$cleanup_dir" ]] || find "$cleanup_dir" -xdev -mindepth 1 -delete 2>/dev/null || true
    done
    rm -f "$root/etc/yum.repos.d/nabu-local.repo" "$root/etc/dnf/repos.d/nabu-local.repo"
    find "$root" -xdev -type f \( -name 'qemu-aarch64-static' -o -name '*.key' \) -delete 2>/dev/null || true
    [[ ! -d "$root/work/local-rpm-repository" ]] || safe_remove_container_tree "$root/work/local-rpm-repository"
}

offline_selinux_label() {
    local root="$1" contexts
    contexts="$root/etc/selinux/targeted/contexts/files/file_contexts"
    [[ -f "$contexts" && -x "$(command -v setfiles)" ]] || {
        : >"$root/.autorelabel"
        warn "Offline SELinux labeling tool/policy was unavailable; /.autorelabel was scheduled."
        return 0
    }
    if ! setfiles -F -r "$root" "$contexts" "$root" >>"$LOG_DIR/validation.log" 2>&1; then
        : >"$root/.autorelabel"
        warn "Offline SELinux xattr labeling was not permitted; first boot will relabel through /.autorelabel."
    fi
}

ensure_backend_available() {
    if [[ "$IMAGE_BACKEND" == "loop" ]]; then
        log ERROR "The loop backend is intentionally unavailable in rootless mode because no host block device is passed into the container."
        return "$EXIT_FILESYSTEM"
    fi
    if ! command -v guestmount >/dev/null 2>&1; then
        log ERROR "libguestfs guestmount is unavailable; no unsafe loop fallback will occur."
        return "$EXIT_FILESYSTEM"
    fi
}

create_ext4_image_from_root() {
    local root="$1" image="$2" size="$3"
    truncate -s "$size" "$image"
    mkfs.ext4 -F -L fedora_nabu -O metadata_csum,64bit -d "$root" "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    e2fsck -f -y "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    resize2fs -M "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    local block_count block_size margin_bytes final_bytes
    block_count="$(dumpe2fs -h "$image" 2>/dev/null | awk -F: '/Block count/ {gsub(/ /,"",$2); print $2; exit}')"
    block_size="$(dumpe2fs -h "$image" 2>/dev/null | awk -F: '/Block size/ {gsub(/ /,"",$2); print $2; exit}')"
    [[ "$block_count" =~ ^[0-9]+$ && "$block_size" =~ ^[0-9]+$ ]] || return "$EXIT_FILESYSTEM"
    margin_bytes=$((256 * 1024 * 1024))
    final_bytes=$((block_count * block_size + margin_bytes))
    truncate -s "$final_bytes" "$image"
    resize2fs "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    e2fsck -f -n "$image" >>"$LOG_DIR/filesystem.log" 2>&1
}

create_btrfs_image_from_root() {
    local root="$1" image="$2" size="$3" mountpoint="/work/btrfs-create-mount"
    ensure_backend_available
    truncate -s "$size" "$image"
    mkfs.btrfs -f -L fedora_nabu "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    mkdir -p "$mountpoint"
    guestmount -a "$image" -m /dev/sda "$mountpoint"
    btrfs subvolume create "$mountpoint/@" >>"$LOG_DIR/filesystem.log"
    btrfs subvolume create "$mountpoint/@home" >>"$LOG_DIR/filesystem.log"
    rsync -aHAX --numeric-ids "$root/" "$mountpoint/@/"
    mkdir -p "$mountpoint/@/home"
    sync
    guestunmount "$mountpoint"
    btrfs check --readonly "$image" >>"$LOG_DIR/filesystem.log" 2>&1
}

compute_core_fingerprint() {
    local filesystem="$1" material="/work/core-fingerprint.material"
    {
        printf 'compose=%s\nrepomd=%s\ncomps=%s\nkickstart=%s\nfilesystem=%s\n' \
            "$RAWHIDE_COMPOSE_ID" "$RAWHIDE_REPOMD_SHA256" "$RAWHIDE_COMPS_SHA256" "$RAWHIDE_KICKSTART_SHA" "$filesystem"
        printf 'cert=%s\nprofile=core+hardware-support\nscript=%s\n' "$SIGNING_CERT_FINGERPRINT" "$SCRIPT_VERSION"
        local file
        for file in "${SELECTED_RPMS[@]}"; do
            printf '%s=%s\n' "${RPM_NEVRA[$file]}" "${RPM_SHA256[$file]}"
        done | sort
    } >"$material"
    CORE_FINGERPRINT="$(sha256sum "$material" | awk '{print $1}')"
}

create_core_image() {
    local root="$1" filesystem="$2"
    stage 12 FILESYSTEM
    CORE_IMAGE="/work/core-$filesystem.img"
    local partial="$CORE_IMAGE.partial"
    rm -f "$CORE_IMAGE" "$partial"
    clean_rootfs "$root"
    offline_selinux_label "$root"
    case "$filesystem" in
        ext4) create_ext4_image_from_root "$root" "$partial" "$CORE_SIZE" ;;
        btrfs) create_btrfs_image_from_root "$root" "$partial" "$CORE_SIZE" ;;
    esac
    [[ -s "$partial" ]] || return "$EXIT_FILESYSTEM"
    mv "$partial" "$CORE_IMAGE"
    compute_core_fingerprint "$filesystem"
    printf '%s\n' "$CORE_FINGERPRINT" >"$CORE_IMAGE.fingerprint"
    log INFO "Core image created as an unpartitioned $filesystem filesystem image."
}

validate_rootfs_tree() {
    local root="$1" filesystem="$2" variant="$3"
    local selected_file selected_name
    for selected_file in "${SELECTED_RPMS[@]}"; do
        selected_name="${RPM_NAME[$selected_file]}"
        rpm --root "$root" -q "$selected_name" >/dev/null 2>&1 || {
            log ERROR "Selected Nabu runtime package is absent from the image: $selected_name"
            return "$EXIT_RPM_MISSING"
        }
    done
    if [[ -s "$METADATA_DIR/generated-compatibility-rpms.txt" ]]; then
        rpm --root "$root" -q --whatprovides systemd-zram-generator >/dev/null 2>&1 || return "$EXIT_RPM_MISSING"
    fi
    [[ -s "$root/boot/vmlinuz-$KERNEL_RELEASE" ]] || return "$EXIT_KERNEL"
    [[ -d "$root/usr/lib/modules/$KERNEL_RELEASE" ]] || return "$EXIT_KERNEL"
    [[ -s "$root/usr/lib/modules/$KERNEL_RELEASE/modules.dep" ]] || return "$EXIT_KERNEL"
    [[ -s "$root/usr/lib/modules/$KERNEL_RELEASE/dtb/qcom/sm8150-xiaomi-nabu.dtb" ]] || return "$EXIT_KERNEL"
    file "$root/boot/vmlinuz-$KERNEL_RELEASE" | grep -Eq 'ARM64|aarch64' || return "$EXIT_KERNEL"
    file "$root/usr/lib/modules/$KERNEL_RELEASE/dtb/qcom/sm8150-xiaomi-nabu.dtb" | grep -q 'Device Tree Blob' || return "$EXIT_KERNEL"
    find "$root/usr/lib/firmware" -type f -size +0c -print -quit | grep -q . || return "$EXIT_KERNEL"
    find "$root/usr/share/alsa/ucm2" -type f -print -quit | grep -q . || return "$EXIT_KERNEL"
    rpm --root "$root" -qa --qf '%{NAME}|%{ARCH}\n' | awk -F'|' '$2 == "x86_64" { bad=1; print > "/dev/stderr" } END { exit bad }' || return "$EXIT_RPM_MISSING"
    ! rpm --root "$root" -q kernel-nabu-devel >/dev/null 2>&1 || return "$EXIT_RPM_MISSING"
    [[ ! -e "$root/etc/yum.repos.d/nabu-local.repo" && ! -e "$root/etc/dnf/repos.d/nabu-local.repo" ]] || return "$EXIT_RPM_MISSING"
    [[ -L "$root/etc/systemd/system/default.target" ]] || {
        log ERROR "Offline default.target link is absent from the image."
        return "$EXIT_CORE"
    }
    # These are absolute links into the target root. A plain -e test resolves
    # them against the builder container's /usr, causing a false negative.
    [[ -L "$root/etc/systemd/system/multi-user.target.wants/NetworkManager.service" || \
       -e "$root/etc/systemd/system/multi-user.target.wants/NetworkManager.service" ]] || {
        log ERROR "Offline NetworkManager enablement is absent from the image."
        return "$EXIT_CORE"
    }
    [[ -L "$root/etc/systemd/system/multi-user.target.wants/firewalld.service" || \
       -e "$root/etc/systemd/system/multi-user.target.wants/firewalld.service" ]] || {
        log ERROR "Offline firewalld enablement is absent from the image."
        return "$EXIT_CORE"
    }
    [[ -x "$root/usr/libexec/nabu-apply-default-shell" ]] || return "$EXIT_FIRSTBOOT"
    [[ -e "$root/.unconfigured" ]] || return "$EXIT_FIRSTBOOT"
    [[ "$filesystem" == "ext4" || -s "$root/etc/fstab" ]] || return "$EXIT_FILESYSTEM"
    if [[ "$variant" == "no-desktop" || "$variant" == "core" ]]; then
        [[ "$(readlink "$root/etc/systemd/system/default.target")" == */multi-user.target ]] || return "$EXIT_CORE"
        [[ ! -e "$root/etc/systemd/system/display-manager.service" ]] || return "$EXIT_DESKTOP"
    fi
}

verify_kernel_security_config() {
    local root="$1" config report
    config="$root/boot/config-$KERNEL_RELEASE"
    report="$METADATA_DIR/kernel-config-summary.txt"
    [[ -f "$config" ]] || return "$EXIT_KERNEL"
    grep -E '^(CONFIG_MODULE_SIG|CONFIG_MODULE_SIG_FORCE|CONFIG_LOCK_DOWN_KERNEL|CONFIG_SECURITY_LOCKDOWN_LSM|CONFIG_LOAD_UEFI_KEYS|CONFIG_INTEGRITY_PLATFORM_KEYRING|CONFIG_EFI_STUB|CONFIG_EXT4_FS|CONFIG_BTRFS_FS)=' "$config" >"$report" || true
    if grep -qx 'CONFIG_MODULE_SIG_FORCE=y' "$config"; then
        local module signer
        while IFS= read -r -d '' module; do
            signer="$(modinfo -F signer "$module" 2>/dev/null || true)"
            [[ -n "$signer" ]] || {
                log ERROR "CONFIG_MODULE_SIG_FORCE=y but unsigned module found: ${module#"$root"}"
                return "$EXIT_SECURE_BOOT"
            }
        done < <(find "$root/usr/lib/modules/$KERNEL_RELEASE" -type f \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) -print0)
    fi
}

validate_core_gate() {
    local root="$1" filesystem="$2"
    stage 13 VALIDATION
    validate_rootfs_tree "$root" "$filesystem" core
    verify_kernel_security_config "$root"
    rpm --root "$root" -Va >"$METADATA_DIR/core-rpm-verify.txt" 2>&1 || true
    rpm --root "$root" -qa --qf '%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort \
        >"$METADATA_DIR/core-package-manifest.txt"
    local -a units=(NetworkManager.service firewalld.service initial-setup.service nabu-apply-default-shell.service ath10k-shutdown.service)
    if ! systemd-analyze verify --man=no --generators=no --root="$root" "${units[@]}" >"$METADATA_DIR/core-systemd-verify.txt" 2>&1; then
        local verify_reason
        verify_reason="$(grep -Em1 'Unknown key|Failed to|not found|error|Error|invalid|Invalid' "$METADATA_DIR/core-systemd-verify.txt" || true)"
        log ERROR "Offline systemd verification failed for core units: ${verify_reason:-see metadata/core-systemd-verify.txt}"
        return "$EXIT_CORE"
    fi
    case "$filesystem" in
        ext4) e2fsck -f -n "$CORE_IMAGE" >>"$LOG_DIR/validation.log" 2>&1 ;;
        btrfs) btrfs check --readonly "$CORE_IMAGE" >>"$LOG_DIR/validation.log" 2>&1 ;;
    esac
    log INFO "CORE GATE passed: filesystem, RPM architecture, kernel, modules, DTB, firmware, ALSA UCM, SELinux plan, systemd, and first boot."
}

generate_initramfs() {
    local root="$1"
    stage 14 KERNEL
    run chroot "$root" depmod -a "$KERNEL_RELEASE"
    run chroot "$root" dracut --force --kver "$KERNEL_RELEASE" "/boot/initramfs-$KERNEL_RELEASE.img"
    [[ -s "$root/boot/initramfs-$KERNEL_RELEASE.img" ]] || return "$EXIT_KERNEL"
    lsinitrd "$root/boot/initramfs-$KERNEL_RELEASE.img" >"$METADATA_DIR/initramfs-contents.txt"
    grep -q 'sm8150-xiaomi-nabu.dtb' "$METADATA_DIR/initramfs-contents.txt" || {
        log ERROR "Generated initramfs does not contain the Nabu DTB."
        return "$EXIT_KERNEL"
    }
    log INFO "depmod and dracut completed explicitly for $KERNEL_RELEASE."
}

resolve_kernel_cmdline() {
    local root="$1" value="" source="" word
    local IFS=' '
    local -a words=() normalized=()
    if [[ -n "$KERNEL_CMDLINE" ]]; then
        value="$KERNEL_CMDLINE"; source="--kernel-cmdline"
    elif [[ -f "$root/etc/systemd/ukify.conf" ]]; then
        value="$(sed -nE 's/^[[:space:]]*Cmdline[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$root/etc/systemd/ukify.conf" | tail -n1)"
        source="nabu-fedora-boot:/etc/systemd/ukify.conf"
    elif [[ -f "$root/etc/kernel/cmdline" ]]; then
        value="$(tr '\n' ' ' <"$root/etc/kernel/cmdline" | sed 's/[[:space:]]*$//')"
        source="/etc/kernel/cmdline"
    fi
    if [[ -z "$value" ]]; then
        value="root=PARTLABEL=linux rw rootwait fw_devlink=permissive"
        source="documented fallback"
        warn "No validated device cmdline was found; using the documented fallback."
    fi

    # The display is physically mounted in portrait orientation, while the
    # tablet hardware, stands, and desktop sessions are intended for
    # landscape use. Keep the framebuffer rotation enabled in every build.
    # Verbose builds deliberately remove quiet/splash so first-boot failures
    # remain visible. Release builds add them back after validation.
    read -r -a words <<<"$value"
    for word in "${words[@]}"; do
        case "$word" in
            quiet|splash|fbcon=rotate:*) continue ;;
            *) normalized+=("$word") ;;
        esac
    done
    normalized+=("fbcon=rotate:1")
    [[ "$BUILD_MODE" == "release" ]] && normalized+=(quiet splash)
    value="${normalized[*]}"

    [[ "$value" == *'root=PARTLABEL=linux'* ]] || warn "Kernel cmdline does not contain root=PARTLABEL=linux; user/device configuration takes precedence."
    printf '%s\n' "$value" >"/work/kernel-cmdline"
    printf '%s\n' "$source" >"/work/kernel-cmdline-source"
    cp /work/kernel-cmdline "$METADATA_DIR/kernel-cmdline.txt"
    cp /work/kernel-cmdline-source "$METADATA_DIR/kernel-cmdline-source.txt"
    log INFO "Kernel cmdline source: $source; build=$BUILD_MODE; cmdline=$value"
}

UKI_PATH=""

build_uki() {
    local root="$1"
    stage 15 UKI
    resolve_kernel_cmdline "$root"
    local kernel="$root/boot/vmlinuz-$KERNEL_RELEASE"
    local initrd="$root/boot/initramfs-$KERNEL_RELEASE.img"
    local dtb="$root/usr/lib/modules/$KERNEL_RELEASE/dtb/qcom/sm8150-xiaomi-nabu.dtb"
    local stub="$root/usr/lib/systemd/boot/efi/linuxaa64.efi.stub"
    [[ -s "$stub" ]] || stub="/usr/lib/systemd/boot/efi/linuxaa64.efi.stub"
    [[ -s "$stub" ]] || return "$EXIT_SECURE_BOOT"
    UKI_PATH="/work/fedora-nabu-$KERNEL_RELEASE.efi"
    local -a ukify_args=(
        build --linux="$kernel" --initrd="$initrd" --devicetree="$dtb"
        --cmdline="@/work/kernel-cmdline" --os-release="@$root/usr/lib/os-release"
        --uname="$KERNEL_RELEASE" --efi-arch=aa64 --stub="$stub" --output="$UKI_PATH"
    )
    if [[ "$SECURE_BOOT" == "on" ]]; then
        ukify_args+=(--secureboot-private-key="$ACTIVE_SB_KEY" --secureboot-certificate="$ACTIVE_SB_CERT")
    fi
    run ukify "${ukify_args[@]}"
    [[ -s "$UKI_PATH" ]] || return "$EXIT_SECURE_BOOT"
    file "$UKI_PATH" | grep -Eq 'PE32\+.*Aarch64|Aarch64.*PE32\+' || return "$EXIT_SECURE_BOOT"
    ukify inspect "$UKI_PATH" >"$METADATA_DIR/uki-inspect.txt"
    grep -q '\.linux' "$METADATA_DIR/uki-inspect.txt" || return "$EXIT_SECURE_BOOT"
    grep -q '\.initrd' "$METADATA_DIR/uki-inspect.txt" || return "$EXIT_SECURE_BOOT"
    grep -q '\.dtb' "$METADATA_DIR/uki-inspect.txt" || return "$EXIT_SECURE_BOOT"
    grep -q '\.cmdline' "$METADATA_DIR/uki-inspect.txt" || return "$EXIT_SECURE_BOOT"
    if [[ "$SECURE_BOOT" == "on" ]]; then
        sbverify --list "$UKI_PATH" >"$METADATA_DIR/uki-signature.txt"
        grep -qi 'signature' "$METADATA_DIR/uki-signature.txt" || return "$EXIT_SECURE_BOOT"
    fi
    log INFO "UKI contains kernel, initramfs, Nabu DTB, cmdline, os-release, uname, AA64 stub, and requested signature."
}

sign_efi_binary() {
    local source="$1" destination="$2"
    if [[ "$SECURE_BOOT" == "on" ]]; then
        sbsign --key "$ACTIVE_SB_KEY" --cert "$ACTIVE_SB_CERT" --output "$destination" "$source" \
            >>"$LOG_DIR/esp-build.log" 2>&1
        sbverify --list "$destination" >>"$LOG_DIR/esp-build.log" 2>&1
    else
        cp -- "$source" "$destination"
    fi
    [[ -s "$destination" ]] || return "$EXIT_SECURE_BOOT"
    file "$destination" | grep -Eq 'PE32\+.*Aarch64|Aarch64.*PE32\+' || return "$EXIT_ESP"
}

build_systemd_bootloader() {
    local root="$1" destination="$2" source
    for source in \
        "$root/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" \
        /usr/lib/systemd/boot/efi/systemd-bootaa64.efi; do
        [[ -s "$source" ]] && break
    done
    [[ -s "$source" ]] || return "$EXIT_ESP"
    sign_efi_binary "$source" "$destination"
}

build_grub_bootloader() {
    local destination="$1" unsigned="/work/grubaa64-unsigned.efi" config="/work/grub-embedded.cfg"
    install_available_packages / required grub2-efi-aa64-modules grub2-tools-extra
    cat >"$config" <<EOF
set timeout=5
set default=0
menuentry 'Fedora Rawhide on Xiaomi Pad 5' {
    chainloader /EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi
}
EOF
    grub2-mkstandalone -O arm64-efi -o "$unsigned" "boot/grub/grub.cfg=$config"
    sign_efi_binary "$unsigned" "$destination"
}

build_limine_bootloader() {
    local destination="$1" source=""
    if repo_package_exists limine; then
        dnf5 -y install limine
        source="$(find /usr/share /usr/lib -type f \( -iname 'BOOTAA64.EFI' -o -iname 'limine-aa64.efi' \) -print -quit 2>/dev/null || true)"
    fi
    [[ -n "$source" && -s "$source" ]] || {
        log ERROR "Rawhide does not provide a verified AArch64 Limine EFI binary; no binary fallback was used."
        return "$EXIT_ESP"
    }
    sign_efi_binary "$source" "$destination"
}

mtools_make_directory() {
    local image="$1" path="$2" current="" part
    local old_ifs="$IFS"
    IFS='/' read -r -a parts <<<"${path#/}"
    IFS="$old_ifs"
    for part in "${parts[@]}"; do
        [[ -n "$part" ]] || continue
        current="$current/$part"
        mmd -i "$image" "::$current" >/dev/null 2>&1 || true
    done
}

validate_existing_esp() {
    local image="$1" temp="/work/existing-bootaa64.efi"
    fsck.vfat -n "$image" >>"$LOG_DIR/esp-build.log" 2>&1
    mdir -i "$image" ::/EFI/BOOT/BOOTAA64.EFI >/dev/null
    mcopy -i "$image" ::/EFI/BOOT/BOOTAA64.EFI "$temp"
    file "$temp" | grep -Eq 'PE32\+.*Aarch64|Aarch64.*PE32\+' || return "$EXIT_ESP"
    if [[ "$SECURE_BOOT" == "on" ]]; then
        sbverify --list "$temp" >>"$LOG_DIR/esp-build.log" 2>&1 || return "$EXIT_SECURE_BOOT"
    fi
}

ESP_IMAGE=""

build_esp() {
    local root="$1"
    stage 16 ESP
    local sb_mode bootloader_binary tree="/work/efi-tree"
    sb_mode="$( [[ "$SECURE_BOOT" == on ]] && printf SB || printf NOSB )"
    ESP_IMAGE="/work/nabu-fedora-rawhide-esp-$BOOTLOADER-$sb_mode-$BUILD_STAMP.img"
    [[ ! -e "$tree" ]] || safe_remove_container_tree "$tree"
    mkdir -p "$tree/EFI/BOOT" "$tree/EFI/Linux" "$tree/EFI/fedora"
    bootloader_binary="$tree/EFI/BOOT/BOOTAA64.EFI"

    if [[ "$BOOTLOADER" == "existing" ]]; then
        validate_existing_esp "$EXISTING_ESP"
        cp --reflink=auto "$EXISTING_ESP" "$ESP_IMAGE.partial"
    else
        case "$BOOTLOADER" in
            systemd-boot) build_systemd_bootloader "$root" "$bootloader_binary" ;;
            grub) build_grub_bootloader "$bootloader_binary" ;;
            limine) build_limine_bootloader "$bootloader_binary" ;;
        esac
        cp "$UKI_PATH" "$tree/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi"
        case "$BOOTLOADER" in
            systemd-boot)
                mkdir -p "$tree/loader/entries"
                cat >"$tree/loader/loader.conf" <<EOF
default fedora-nabu.conf
timeout 5
editor no
EOF
                cat >"$tree/loader/entries/fedora-nabu.conf" <<EOF
title Fedora Rawhide (Xiaomi Pad 5)
efi /EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi
EOF
                ;;
            limine)
                cat >"$tree/limine.conf" <<EOF
timeout: 5
/Fedora Rawhide (Xiaomi Pad 5)
    protocol: efi_chainload
    image_path: boot():/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi
EOF
                ;;
            grub) : ;;
        esac
        truncate -s "$ESP_SIZE" "$ESP_IMAGE.partial"
        mkfs.vfat -F 32 -n ESPNABU "$ESP_IMAGE.partial" >>"$LOG_DIR/esp-build.log" 2>&1
        while IFS= read -r directory; do
            mtools_make_directory "$ESP_IMAGE.partial" "${directory#"$tree"}"
        done < <(find "$tree" -mindepth 1 -type d | sort)
        while IFS= read -r file; do
            mcopy -o -i "$ESP_IMAGE.partial" "$file" "::/${file#"$tree"/}"
        done < <(find "$tree" -type f | sort)
    fi

    if [[ "$BOOTLOADER" == "existing" ]]; then
        mtools_make_directory "$ESP_IMAGE.partial" /EFI/Linux
        mcopy -o -i "$ESP_IMAGE.partial" "$UKI_PATH" "::/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi"
    fi
    fsck.vfat -n "$ESP_IMAGE.partial" >>"$LOG_DIR/esp-build.log" 2>&1
    mdir -i "$ESP_IMAGE.partial" ::/EFI/BOOT/BOOTAA64.EFI >/dev/null
    mdir -i "$ESP_IMAGE.partial" "::/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi" >/dev/null
    local verify_dir="/work/esp-verify"
    [[ ! -e "$verify_dir" ]] || safe_remove_container_tree "$verify_dir"
    mkdir -p "$verify_dir"
    mcopy -i "$ESP_IMAGE.partial" ::/EFI/BOOT/BOOTAA64.EFI "$verify_dir/BOOTAA64.EFI"
    mcopy -i "$ESP_IMAGE.partial" "::/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi" "$verify_dir/nabu.efi"
    local verified_efi
    for verified_efi in "$verify_dir/BOOTAA64.EFI" "$verify_dir/nabu.efi"; do
        file "$verified_efi" | grep -Eq 'PE32\+.*Aarch64|Aarch64.*PE32\+' || return "$EXIT_ESP"
    done
    if [[ "$SECURE_BOOT" == "on" ]]; then
        sbverify --list "$verify_dir/BOOTAA64.EFI" >>"$LOG_DIR/esp-build.log" 2>&1
        sbverify --list "$verify_dir/nabu.efi" >>"$LOG_DIR/esp-build.log" 2>&1
    fi
    mv "$ESP_IMAGE.partial" "$ESP_IMAGE"
    local published_esp efi_zip esp_zip
    published_esp="$BOOT_ARTIFACT_DIR/$(basename "$ESP_IMAGE")"
    cp "$ESP_IMAGE" "$published_esp.partial"
    mv "$published_esp.partial" "$published_esp"
    zstd -T"$JOBS" -"$COMPRESSION_LEVEL" -f "$ESP_IMAGE" -o "$published_esp.zst.partial"
    zstd -t "$published_esp.zst.partial"
    mv "$published_esp.zst.partial" "$published_esp.zst"
    if [[ "$BOOTLOADER" != "existing" ]]; then
        efi_zip="$BOOT_ARTIFACT_DIR/nabu-fedora-rawhide-efi-files-$BOOTLOADER-$sb_mode-$BUILD_STAMP.zip"
        (cd "$tree" && zip -X -q -r - .) >"$efi_zip.partial"
    else
        safe_remove_container_tree "$tree"
        mkdir -p "$tree/EFI/BOOT" "$tree/EFI/Linux"
        mcopy -i "$ESP_IMAGE" ::/EFI/BOOT/BOOTAA64.EFI "$tree/EFI/BOOT/BOOTAA64.EFI"
        mcopy -i "$ESP_IMAGE" "::/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi" "$tree/EFI/Linux/fedora-nabu-$KERNEL_RELEASE.efi"
        efi_zip="$BOOT_ARTIFACT_DIR/nabu-fedora-rawhide-efi-files-existing-$sb_mode-$BUILD_STAMP.zip"
        (cd "$tree" && zip -X -q -r - .) >"$efi_zip.partial"
    fi
    unzip -t "$efi_zip.partial" >/dev/null
    mv "$efi_zip.partial" "$efi_zip"
    # Publish a stable, easy-to-consume ESP archive name in addition to the
    # descriptive, timestamped EFI-files archive.  Copy only after the ZIP
    # integrity gate above has passed, then validate the published copy too.
    esp_zip="$BOOT_ARTIFACT_DIR/esp.zip"
    cp "$efi_zip" "$esp_zip.partial"
    unzip -t "$esp_zip.partial" >/dev/null
    mv "$esp_zip.partial" "$esp_zip"
    stat -c 'ESP image bytes: %s' "$ESP_IMAGE" >"$METADATA_DIR/esp-size.txt"
    log INFO "ESP GATE passed: FAT32, BOOTAA64.EFI, AA64 UKI, config targets, signatures, and image size."
}

mount_image_rw() {
    local image="$1" filesystem="$2" mountpoint="$3"
    ensure_backend_available
    mkdir -p "$mountpoint"
    if [[ "$filesystem" == "ext4" ]]; then
        guestmount -a "$image" -m /dev/sda "$mountpoint"
        printf '%s\n' "$mountpoint"
    else
        guestmount -a "$image" -m /dev/sda "$mountpoint"
        [[ -d "$mountpoint/@" ]] || return "$EXIT_FILESYSTEM"
        btrfs filesystem resize max "$mountpoint" >>"$LOG_DIR/filesystem.log" 2>&1
        printf '%s\n' "$mountpoint/@"
    fi
}

mount_image_ro() {
    local image="$1" filesystem="$2" mountpoint="$3"
    ensure_backend_available
    mkdir -p "$mountpoint"
    guestmount --ro -a "$image" -m /dev/sda "$mountpoint"
    if [[ "$filesystem" == "btrfs" ]]; then
        [[ -d "$mountpoint/@" ]] || return "$EXIT_FILESYSTEM"
        printf '%s\n' "$mountpoint/@"
    else
        printf '%s\n' "$mountpoint"
    fi
}

grow_variant_image() {
    local image="$1" filesystem="$2"
    truncate -s "$IMAGE_SIZE" "$image"
    if [[ "$filesystem" == "ext4" ]]; then
        e2fsck -f -y "$image" >>"$LOG_DIR/filesystem.log" 2>&1
        resize2fs "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    fi
}

configure_display_manager() {
    local root="$1" manager="$2"
    rm -f "$root/etc/systemd/system/display-manager.service"
    case "$manager" in
        sddm)
            [[ -f "$root/usr/lib/systemd/system/sddm.service" ]] || return "$EXIT_DESKTOP"
            ln -sfn /usr/lib/systemd/system/sddm.service "$root/etc/systemd/system/display-manager.service"
            ;;
        gdm)
            [[ -f "$root/usr/lib/systemd/system/gdm.service" ]] || return "$EXIT_DESKTOP"
            ln -sfn /usr/lib/systemd/system/gdm.service "$root/etc/systemd/system/display-manager.service"
            ;;
        phrog)
            if [[ -f "$root/usr/lib/systemd/system/greetd.service" ]]; then
                ln -sfn /usr/lib/systemd/system/greetd.service "$root/etc/systemd/system/display-manager.service"
            elif [[ -f "$root/usr/lib/systemd/system/gdm.service" ]]; then
                ln -sfn /usr/lib/systemd/system/gdm.service "$root/etc/systemd/system/display-manager.service"
            else
                return "$EXIT_DESKTOP"
            fi
            ;;
    esac
    set_default_target_offline "$root" graphical.target
}

configure_plasma_keyboard() {
    local root="$1"
    rpm --root "$root" -q maliit-keyboard >/dev/null 2>&1 || return "$EXIT_DESKTOP"
    rpm --root "$root" -q maliit-framework >/dev/null 2>&1 || return "$EXIT_DESKTOP"
    mkdir -p "$root/etc/xdg" "$root/etc/environment.d"
    cat >"$root/etc/xdg/kwinrc" <<'EOF'
[Wayland]
InputMethod=maliit-keyboard
VirtualKeyboardEnabled=true
EOF
    cat >"$root/etc/environment.d/90-nabu-maliit.conf" <<'EOF'
QT_IM_MODULE=wayland
MALIIT_ENABLE_HARDWARE_KEYBOARD=1
EOF
}

configure_plasma_onboarding() {
    local root="$1"
    [[ -x "$root/usr/bin/plasma-welcome" ]] || return "$EXIT_DESKTOP"
    [[ -x "$root/usr/libexec/plasma-setup" ]] || return "$EXIT_DESKTOP"
    mkdir -p "$root/etc/systemd/system/plasma-setup.service.d"
    cat >"$root/etc/systemd/system/plasma-setup.service.d/10-fedora-initial-setup-order.conf" <<'EOF'
[Unit]
After=initial-setup.service
Wants=initial-setup.service
EOF
    enable_unit_offline "$root" plasma-setup.service graphical.target || return "$EXIT_DESKTOP"
    # Plasma Setup suppresses its account module when Fedora Initial Setup has
    # already created a regular user. Plasma Welcome's KDED module owns its
    # LastSeenVersion marker and launches once on the first Plasma session.
}

install_desktop_environment() {
    local root="$1" profile="$2"
    stage 18 DESKTOP
    local environment="${PROFILE_ENVIRONMENT[$profile]:-}"
    case "$profile" in
        no-desktop)
            set_default_target_offline "$root" multi-user.target
            rm -f "$root/etc/systemd/system/display-manager.service"
            return 0
            ;;
        gnome-mobile)
            if [[ "$GNOME_MOBILE_AVAILABLE" != "true" ]]; then
                log ERROR "GNOME_MOBILE_UNAVAILABLE: no distinct Rawhide session exists; normal GNOME and Phosh are not substituted."
                return "$EXIT_DESKTOP"
            fi
            [[ "$ALLOW_EXPERIMENTAL_DESKTOP" == "true" ]] || {
                log ERROR "GNOME Mobile is experimental and requires --allow-experimental-desktop."
                return "$EXIT_DESKTOP"
            }
            ;;
        *)
            [[ -n "$environment" ]] || return "$EXIT_DESKTOP"
            dnf_target "$root" environment install "$environment"
            ;;
    esac
    case "$profile" in
        kde-plasma)
            install_available_packages "$root" required sddm plasma-welcome plasma-setup maliit-keyboard maliit-framework plasma-keyboard plasma-discover plasma-discover-packagekit
            ;;
        kde-mobile)
            install_available_packages "$root" required sddm plasma-mobile plasma-settings maliit-keyboard maliit-framework plasma-keyboard
            install_available_packages "$root" optional plasma-dialer plasma-phonebook
            ;;
        gnome)
            install_available_packages "$root" required gdm gnome-initial-setup gnome-software
            ;;
        gnome-mobile)
            install_available_packages "$root" required gdm gnome-initial-setup
            if repo_package_exists gnome-mobile; then
                dnf_target "$root" install gnome-mobile
            else
                dnf_target "$root" install gnome-shell-mobile
            fi
            ;;
        phosh)
            install_available_packages "$root" required phosh phoc feedbackd NetworkManager pipewire wireplumber
            if repo_package_exists squeekboard; then
                dnf_target "$root" install squeekboard
            elif repo_package_exists stevia; then
                dnf_target "$root" install stevia
                warn "Rawhide replaced unavailable squeekboard with official Stevia OSK for Phosh; recorded as a desktop profile difference."
            else
                log ERROR "No validated Rawhide Phosh on-screen keyboard is available."
                return "$EXIT_DESKTOP"
            fi
            install_available_packages "$root" optional calls chatty ModemManager phrog
            ;;
    esac
}

configure_variant() {
    local root="$1" profile="$2" filesystem="$3"
    stage 19 FIRSTBOOT
    install_available_packages "$root" required "$DEFAULT_SHELL"
    write_shell_firstboot_service "$root"
    write_fstab "$root" "$filesystem"
    case "$profile" in
        no-desktop)
            configure_initial_setup "$root" false
            set_default_target_offline "$root" multi-user.target
            rm -f "$root/etc/systemd/system/display-manager.service"
            ;;
        *)
            install_available_packages "$root" required initial-setup-gui
            configure_initial_setup "$root" true
            case "$profile" in
                kde-plasma|kde-mobile) configure_display_manager "$root" sddm ;;
                gnome|gnome-mobile) configure_display_manager "$root" gdm ;;
                phosh) configure_display_manager "$root" phrog ;;
            esac
            ;;
    esac
    stage 20 DESKTOP
    case "$profile" in
        kde-plasma)
            configure_plasma_keyboard "$root"
            configure_plasma_onboarding "$root"
            ;;
        kde-mobile)
            configure_plasma_keyboard "$root"
            [[ -f "$root/usr/share/wayland-sessions/plasma-mobile.desktop" || -f "$root/usr/share/wayland-sessions/plasmamobile.desktop" ]] \
                || return "$EXIT_DESKTOP"
            ;;
        gnome|gnome-mobile) : ;;
        phosh)
            [[ -f "$root/usr/share/wayland-sessions/phosh.desktop" || -f "$root/usr/share/wayland-sessions/phosh-wayland.desktop" ]] \
                || return "$EXIT_DESKTOP"
            ;;
    esac
    clean_rootfs "$root"
    offline_selinux_label "$root"
}

desktop_validation_exit_code() {
    if [[ "$FEDORA_PARITY" == "strict" ]]; then
        printf '%s\n' "$EXIT_PARITY"
    else
        printf '%s\n' "$EXIT_DESKTOP"
    fi
}

validate_variant_tree() {
    local root="$1" profile="$2" filesystem="$3"
    validate_rootfs_tree "$root" "$filesystem" "$profile"
    [[ -e "$root/.unconfigured" ]] || return "$EXIT_FIRSTBOOT"
    case "$profile" in
        kde-plasma)
            [[ -e "$root/etc/systemd/system/display-manager.service" ]] || return "$(desktop_validation_exit_code)"
            [[ -x "$root/usr/bin/plasma-welcome" && -x "$root/usr/libexec/plasma-setup" ]] || return "$(desktop_validation_exit_code)"
            [[ -x "$root/usr/bin/maliit-keyboard" && -f "$root/etc/xdg/kwinrc" ]] || return "$(desktop_validation_exit_code)"
            ;;
        kde-mobile)
            [[ -x "$root/usr/bin/maliit-keyboard" ]] || return "$(desktop_validation_exit_code)"
            find "$root/usr/share/wayland-sessions" -type f -iname '*mobile*.desktop' -print -quit | grep -q . || return "$(desktop_validation_exit_code)"
            ;;
        gnome)
            find "$root/usr/share/wayland-sessions" -type f -iname '*gnome*.desktop' -print -quit | grep -q . || return "$(desktop_validation_exit_code)"
            [[ -x "$root/usr/bin/gnome-initial-setup" || -x "$root/usr/libexec/gnome-initial-setup" ]] || return "$(desktop_validation_exit_code)"
            ;;
        gnome-mobile)
            find "$root/usr/share/wayland-sessions" -type f -iname '*mobile*.desktop' -print -quit | grep -q . || return "$(desktop_validation_exit_code)"
            ;;
        phosh)
            find "$root/usr/share/wayland-sessions" -type f -iname '*phosh*.desktop' -print -quit | grep -q . || return "$(desktop_validation_exit_code)"
            [[ -x "$root/usr/bin/phoc" ]] || return "$(desktop_validation_exit_code)"
            [[ -x "$root/usr/bin/stevia" || -x "$root/usr/bin/squeekboard" ]] || return "$(desktop_validation_exit_code)"
            ;;
        no-desktop)
            [[ ! -e "$root/etc/systemd/system/display-manager.service" ]] || return "$(desktop_validation_exit_code)"
            ;;
    esac
    local -a units=(initial-setup.service nabu-apply-default-shell.service NetworkManager.service firewalld.service)
    systemd-analyze verify --root="$root" "${units[@]}" >>"$LOG_DIR/validation.log" 2>&1
}

shrink_and_validate_image() {
    local image="$1" filesystem="$2"
    stage 22 FILESYSTEM
    if [[ "$filesystem" == "ext4" ]]; then
        e2fsck -f -y "$image" >>"$LOG_DIR/filesystem.log" 2>&1
        resize2fs -M "$image" >>"$LOG_DIR/filesystem.log" 2>&1
        local blocks size final
        blocks="$(dumpe2fs -h "$image" 2>/dev/null | awk -F: '/Block count/ {gsub(/ /,"",$2);print $2;exit}')"
        size="$(dumpe2fs -h "$image" 2>/dev/null | awk -F: '/Block size/ {gsub(/ /,"",$2);print $2;exit}')"
        final=$((blocks * size + 256 * 1024 * 1024))
        truncate -s "$final" "$image"
        resize2fs "$image" >>"$LOG_DIR/filesystem.log" 2>&1
        e2fsck -f -n "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    else
        btrfs check --readonly "$image" >>"$LOG_DIR/filesystem.log" 2>&1
    fi
}

build_variant_from_core() {
    local core_image="$1" filesystem="$2" profile="$3"
    CURRENT_DESKTOP="$profile"
    CURRENT_FILESYSTEM="$filesystem"
    VARIANT_RC=0
    stage 17 DESKTOP
    local working="/work/variant-$profile-$filesystem.img" mountpoint="/work/mnt-$profile-$filesystem" root
    COMPONENT_LOG="$LOG_DIR/desktop-$profile.log"; : >"$COMPONENT_LOG"
    rm -f "$working"
    [[ ! -e "$mountpoint" ]] || safe_remove_container_tree "$mountpoint"
    mkdir -p "$mountpoint"
    if ! cp --reflink=auto "$core_image" "$working"; then
        VARIANT_RC="$EXIT_FILESYSTEM"
        return 0
    fi
    if grow_variant_image "$working" "$filesystem"; then
        :
    else
        VARIANT_RC=$?
        rm -f "$working"
        return 0
    fi
    if root="$(mount_image_rw "$working" "$filesystem" "$mountpoint")"; then
        :
    else
        VARIANT_RC=$?
        rm -f "$working"
        return 0
    fi
    local rc=0
    if install_desktop_environment "$root" "$profile" && configure_variant "$root" "$profile" "$filesystem" && {
        stage 21 VALIDATION
        validate_variant_tree "$root" "$profile" "$filesystem"
    }; then
        rc=0
    else
        rc=$?
    fi
    rpm --root "$root" -qa --qf '%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort \
        >"$METADATA_DIR/installed-packages-$profile-$filesystem.txt" || true
    if ! sync; then
        ((rc != 0)) || rc="$EXIT_FILESYSTEM"
    fi
    if ! guestunmount "$mountpoint" >/dev/null 2>&1; then
        ((rc != 0)) || rc="$EXIT_FILESYSTEM"
    fi
    if ((rc != 0)); then
        rm -f "$working"
        VARIANT_RC="$rc"
        return 0
    fi
    local final="$ROOTFS_ARTIFACT_DIR/nabu-fedora-rawhide-$profile-$filesystem-$DEFAULT_SHELL-aarch64-$BUILD_STAMP.img.zst"
    if shrink_and_validate_image "$working" "$filesystem" \
        && zstd -T"$JOBS" -"$COMPRESSION_LEVEL" -f "$working" -o "$final.partial" \
        && zstd -t "$final.partial" \
        && mv "$final.partial" "$final"; then
        :
    else
        rc=$?
        rm -f "$working" "$final.partial"
        VARIANT_RC="$rc"
        return 0
    fi
    SUCCESSFUL_VARIANTS+=("$profile/$filesystem")
    log INFO "Validated variant published atomically: $final"
    rm -f "$working"
}

record_variant_failure() {
    local profile="$1" filesystem="$2" rc="$3" report="$REPORTS_DIR/FAILED-VARIANTS.md"
    if [[ ! -s "$report" ]]; then
        printf '# Failed desktop variants\n\nThe build continued so other requested variants could still be produced.\n\n' >"$report"
    fi
    printf -- '- `%s/%s`: exit `%s`; see [desktop log](../logs/desktop-%s.log).\n' \
        "$profile" "$filesystem" "$rc" "$profile" >>"$report"
}

publish_core_artifact() {
    local filesystem="$1" final
    final="$ROOTFS_ARTIFACT_DIR/nabu-fedora-rawhide-core-$filesystem-aarch64-$BUILD_STAMP.img.zst"
    zstd -T"$JOBS" -"$COMPRESSION_LEVEL" -f "$CORE_IMAGE" -o "$final.partial"
    zstd -t "$final.partial"
    mv "$final.partial" "$final"
    cp "$CORE_IMAGE.fingerprint" "$METADATA_DIR/core-$filesystem.fingerprint"
    if [[ "$KEEP_CORE" == "true" ]]; then
        cp --reflink=auto "$CORE_IMAGE" "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img.partial"
        mv "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img.partial" "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img"
        cp "$CORE_IMAGE.fingerprint" "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img.fingerprint.partial"
        mv "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img.fingerprint.partial" "$ROOTFS_ARTIFACT_DIR/core-$filesystem.img.fingerprint"
    fi
}

sync_initramfs_into_core_image() {
    local filesystem="$1" mountpoint image_root
    mountpoint="/work/core-initramfs-mount-$filesystem"
    [[ ! -e "$mountpoint" ]] || safe_remove_container_tree "$mountpoint"
    mkdir -p "$mountpoint"
    image_root="$(mount_image_rw "$CORE_IMAGE" "$filesystem" "$mountpoint")"
    mkdir -p "$image_root/boot"
    cp "$CORE_ROOTFS/boot/initramfs-$KERNEL_RELEASE.img" "$image_root/boot/"
    sync
    guestunmount "$mountpoint"
    case "$filesystem" in
        ext4) e2fsck -f -n "$CORE_IMAGE" >>"$LOG_DIR/validation.log" 2>&1 ;;
        btrfs) btrfs check --readonly "$CORE_IMAGE" >>"$LOG_DIR/validation.log" 2>&1 ;;
    esac
}

validate_reused_core() {
    local image="$1" filesystem="$2" check_fingerprint="$3" mountpoint root
    mountpoint="/work/reuse-core-mount-$filesystem"
    [[ -s "$image" ]] || return "$EXIT_CORE"
    local detected
    detected="$(blkid -p -o value -s TYPE "$image" 2>/dev/null || true)"
    [[ "$detected" == "$filesystem" ]] || {
        log ERROR "Reusable core filesystem is $detected, requested $filesystem."
        return "$EXIT_FILESYSTEM"
    }
    if [[ "$check_fingerprint" == "true" ]]; then
        [[ -f /inputs/reuse-core.img.fingerprint ]] || {
            log ERROR "--reuse-core requires a .fingerprint sidecar."
            return "$EXIT_CORE"
        }
        compute_core_fingerprint "$filesystem"
        [[ "$(tr -d '\n' </inputs/reuse-core.img.fingerprint)" == "$CORE_FINGERPRINT" ]] || {
            log ERROR "Reusable core fingerprint does not match current compose/RPM/certificate/profile inputs."
            return "$EXIT_CORE"
        }
    else
        warn "--from-core bypasses cache fingerprint matching by explicit user request; structural validation still applies."
    fi
    [[ ! -e "$mountpoint" ]] || safe_remove_container_tree "$mountpoint"
    mkdir -p "$mountpoint"
    root="$(mount_image_ro "$image" "$filesystem" "$mountpoint")"
    validate_rootfs_tree "$root" "$filesystem" core
    guestunmount "$mountpoint"
}

dry_run_dependency_check() {
    if dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" \
        --repofrompath="nabu-local,file:///work/local-rpm-repository" \
        --setopt=nabu-local.gpgcheck=0 \
        repoclosure --check=nabu-local >"$METADATA_DIR/local-rpm-repoclosure.txt" 2>&1; then
        log INFO "Local RPM dependency closure is satisfiable against current official Rawhide repositories."
    else
        log ERROR "Local RPM dependency closure failed; see local-rpm-repoclosure.txt."
        return "$EXIT_RPM_MISSING"
    fi
    dnf5 "${DNF_RAW_ARGS[@]}" "${DNF_EXTERNAL_REPO_ARGS[@]}" repoquery --available --qf '%{name}|%{evr}|%{arch}' \
        systemd-ukify systemd-boot-unsigned initial-setup >"$METADATA_DIR/rawhide-required-package-snapshot.txt"
}

write_dry_run_report() {
    cat >"$REPORTS_DIR/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide Builder — Dry-run Report

- Build ID: \`$BUILD_ID\`
- Result: **PREFLIGHT_PASS**
- Compose: \`$RAWHIDE_COMPOSE_ID\` ($RAWHIDE_COMPOSE_STATUS)
- Compose date: \`$RAWHIDE_COMPOSE_DATE\`
- Repository metadata SHA256: \`$RAWHIDE_REPOMD_SHA256\`
- Comps SHA256: \`$RAWHIDE_COMPS_SHA256\`
- Fedora kickstarts commit: \`$RAWHIDE_KICKSTART_SHA\`
- Target architecture: \`aarch64\`
- Architecture execution: \`$CONTAINER_ARCH\`
- Secure Boot preflight: \`$SECURE_BOOT_STATUS\`
- Selected local runtime RPMs: ${#SELECTED_RPMS[@]}

The dry-run queried current Fedora Rawhide aarch64 metadata, resolved official
group/environment IDs, inspected RPM metadata/payloads/scripts/signatures,
performed RPM dependency closure, checked Secure Boot inputs, and did not create
or modify a filesystem image.
EOF
}

write_security_report() {
    cat >"$METADATA_DIR/secure-boot-report.txt" <<EOF
mode=$SECURE_BOOT
status=$SECURE_BOOT_STATUS
signing_certificate_sha256=${SIGNING_CERT_FINGERPRINT:-not-provided}
uefi_trusted_certificate_sha256=${TRUSTED_CERT_FINGERPRINT:-not-provided}
private_key_path=REDACTED_AND_NOT_RECORDED
container_privileged=$PRIVILEGED_CONTAINER
kernel_release=${KERNEL_RELEASE:-unknown}
module_signature_policy=$(grep -h '^CONFIG_MODULE_SIG_FORCE=' "$METADATA_DIR/kernel-config-summary.txt" 2>/dev/null || printf 'not-evaluated')
EOF
}

write_parity_report() {
    local parity_status="$1"
    cat >"$REPORTS_DIR/FEDORA-RAWHIDE-PARITY.md" <<EOF
# Fedora Rawhide Parity Report

## Reference

- Compose date: \`$RAWHIDE_COMPOSE_DATE\`
- Compose ID: \`$RAWHIDE_COMPOSE_ID\`
- Compose status: \`$RAWHIDE_COMPOSE_STATUS\`
- Repository metalink: \`$RAWHIDE_METALINK\`
- Repository base URL: \`$RAWHIDE_REPO_BASEURL\`
- repomd.xml SHA256: \`$RAWHIDE_REPOMD_SHA256\`
- Comps location: \`$RAWHIDE_COMPS_LOCATION\`
- Comps SHA256: \`$RAWHIDE_COMPS_SHA256\`
- Fedora kickstarts commit: \`$RAWHIDE_KICKSTART_SHA\`

## Official package profiles

- Core groups: ${RESOLVED_GROUPS[*]}
- Desktop environments: ${RESOLVED_ENVIRONMENTS[*]:-none}
- Requested profiles: \`$DESKTOP\`

## Expected Nabu differences

- Fedora's stock kernel is replaced by \`$KERNEL_NEVRA\` (release \`$KERNEL_RELEASE\`).
- Nabu firmware, ALSA UCM, core configuration, and boot integration come from
  the locally discovered RPM repository.
- The root filesystem is an unpartitioned aarch64 filesystem image for the
  existing \`linux\` partition; it is not an official ISO or GPT disk image.
- A Nabu DTB and device-specific kernel command line are embedded in the UKI.
- Local RPM GPG verification is disabled only for the isolated local repository;
  all Fedora repositories use official GPG verification.

## Package/profile differences

- Official package groups are installed without a script-embedded KDE, GNOME,
  Workstation, or Core package manifest.
- Architecture-unavailable x86_64 packages are excluded by \`--forcearch=aarch64\`
  and final RPM architecture validation.
- GNOME Mobile status: $( [[ "$GNOME_MOBILE_AVAILABLE" == true ]] && printf AVAILABLE || printf GNOME_MOBILE_UNAVAILABLE ).
- Failed variants: ${FAILED_VARIANTS[*]:-none}
- Skipped variants: ${SKIPPED_VARIANTS[*]:-none}

## Result

**$parity_status**
EOF
}

write_validation_report() {
    cat >"$REPORTS_DIR/VALIDATION-REPORT.md" <<EOF
# Validation Report

- RPM dependency closure: checked
- Kernel family consistency: checked
- x86_64 RPM exclusion: checked
- Kernel image/modules/DTB/firmware/ALSA UCM: checked
- Initramfs DTB content: $( [[ -f "$METADATA_DIR/initramfs-contents.txt" ]] && printf checked || printf not-built )
- UKI PE/COFF sections and signature: $( [[ -f "$METADATA_DIR/uki-inspect.txt" ]] && printf checked || printf not-built )
- FAT32 ESP and AArch64 fallback loader: $( [[ -n "$ESP_IMAGE" ]] && printf checked || printf not-built )
- systemd offline units: checked for built roots
- SELinux: enforcing with offline labels or explicit first-boot relabel fallback
- Ext4: e2fsck/resize2fs; Btrfs: readonly btrfs check
- Hardware boot test: NOT_RUN (requires physical Xiaomi Pad 5)
EOF
}

write_firstboot_report() {
    cat >"$REPORTS_DIR/FIRST-BOOT-REPORT.md" <<EOF
# First Boot Report

- No fixed end-user account or password is created during image composition.
- \`/.unconfigured\` and current Fedora Initial Setup systemd units are used.
- Graphical variants install Initial Setup GUI before the display manager.
- No Desktop uses Initial Setup TUI and \`multi-user.target\`.
- The selected shell (\`$DEFAULT_SHELL\`) is applied once to the first normal
  UID_MIN user, never root or a system account.
- KDE images order Plasma Setup after Fedora Initial Setup. Plasma Setup detects
  the existing regular user and suppresses duplicate account creation.
- Plasma Welcome relies on its current KDED \`LastSeenVersion\` marker and opens
  on the first Plasma session.
EOF
}

lines_to_json_array() {
    if (($# == 0)); then
        printf '[]\n'
    else
        printf '%s\n' "$@" | jq -R . | jq -s .
    fi
}

write_output_summary() {
    local result artifact relative size
    if [[ "$DRY_RUN" == "true" ]]; then
        result="PREFLIGHT_PASS"
    elif ((${#FAILED_VARIANTS[@]} > 0 || ${#SKIPPED_VARIANTS[@]} > 0)); then
        if ((${#SUCCESSFUL_VARIANTS[@]} > 0)); then
            result="PARTIAL"
        else
            result="FAILED"
        fi
    else
        result="COMPLETE"
    fi
    {
        printf '# Nabu Fedora Rawhide build summary\n\n'
        printf -- '- Status: **%s**\n' "$result"
        printf -- '- Build ID: `%s`\n' "$BUILD_ID"
        printf -- '- Build mode: `%s`\n' "$BUILD_MODE"
        printf -- '- Desktop/filesystem: `%s` / `%s`\n' "$DESKTOP" "$FILESYSTEM"
        printf -- '- Rawhide compose: `%s` (%s)\n' "$RAWHIDE_COMPOSE_ID" "$RAWHIDE_COMPOSE_STATUS"
        printf -- '- Secure Boot: `%s`\n' "$SECURE_BOOT_STATUS"
        printf -- '- Hardware boot test: `NOT_RUN`\n'
        printf '\n## Start here\n\n'
        printf -- '- Root filesystem images: [artifacts/rootfs](artifacts/rootfs)\n'
        printf -- '- ESP, EFI ZIP and enrollment files: [artifacts/boot](artifacts/boot)\n'
        printf -- '- Human-readable checks: [reports](reports)\n'
        printf -- '- Package lists and machine metadata: [metadata](metadata)\n'
        printf -- '- Main log: [logs/main.log](logs/main.log)\n'
        printf -- '- Current machine-readable state: [STATUS.json](STATUS.json)\n'
        printf '\n## Produced artifacts\n\n'
        if find "$ARTIFACTS_DIR" -type f -print -quit 2>/dev/null | grep -q .; then
            while IFS= read -r artifact; do
                relative="${artifact#"$BUILD_ROOT"/}"
                size="$(stat -c %s "$artifact")"
                printf -- '- `%s` — %s bytes\n' "$relative" "$size"
            done < <(find "$ARTIFACTS_DIR" -type f ! -name '*.partial' -print | sort)
        else
            printf -- '- None (preflight or build failed before publication).\n'
        fi
        printf '\n## Variant result\n\n'
        printf -- '- Successful: %s\n' "${SUCCESSFUL_VARIANTS[*]:-none}"
        printf -- '- Failed: %s\n' "${FAILED_VARIANTS[*]:-none}"
        printf -- '- Skipped: %s\n' "${SKIPPED_VARIANTS[*]:-none}"
    } >"$SUMMARY_FILE.partial"
    mv -f -- "$SUMMARY_FILE.partial" "$SUMMARY_FILE"
}

write_build_manifest() {
    local finish_iso duration artifacts_json local_rpms_json discovered_rpms_json nabu_added_json warnings_json success_json failed_json skipped_json
    local installed_count=0 kernel_sha result resolved_cmdline=""
    finish_iso="$(date --iso-8601=seconds)"
    duration="$(( $(date +%s) - START_EPOCH ))"
    if [[ "$DRY_RUN" == "true" ]]; then
        : >"$METADATA_DIR/installed-packages.txt"
        result="PREFLIGHT_PASS"
    else
        find "$METADATA_DIR" -maxdepth 1 -type f \( -name 'installed-packages-*.txt' -o -name 'core-package-manifest.txt' \) -print0 \
            | sort -z | xargs -0 -r cat | sort -u >"$METADATA_DIR/installed-packages.txt"
        result="BUILD_COMPLETE"
    fi
    installed_count="$(wc -l <"$METADATA_DIR/installed-packages.txt")"
    : >"$METADATA_DIR/successful-variants.txt"
    : >"$METADATA_DIR/failed-variants.txt"
    : >"$METADATA_DIR/skipped-variants.txt"
    ((${#SUCCESSFUL_VARIANTS[@]} == 0)) || printf '%s\n' "${SUCCESSFUL_VARIANTS[@]}" >"$METADATA_DIR/successful-variants.txt"
    ((${#FAILED_VARIANTS[@]} == 0)) || printf '%s\n' "${FAILED_VARIANTS[@]}" >"$METADATA_DIR/failed-variants.txt"
    ((${#SKIPPED_VARIANTS[@]} == 0)) || printf '%s\n' "${SKIPPED_VARIANTS[@]}" >"$METADATA_DIR/skipped-variants.txt"
    kernel_sha="${RPM_SHA256[${SELECTED_BY_REQUIREMENT[kernel-nabu]}]}"
    [[ ! -s "$METADATA_DIR/kernel-cmdline.txt" ]] || resolved_cmdline="$(<"$METADATA_DIR/kernel-cmdline.txt")"
    artifacts_json="$(find "$ARTIFACTS_DIR" -type f ! -name '*.partial' -print0 \
        | sort -z | while IFS= read -r -d '' artifact; do
            jq -n --arg path "${artifact#"$BUILD_ROOT"/}" --argjson size "$(stat -c %s "$artifact")" \
                --arg sha256 "$(sha256sum "$artifact" | awk '{print $1}')" \
                '{path:$path,size:$size,sha256:$sha256}'
        done | jq -s .)"
    local_rpms_json="$(for file in "${SELECTED_RPMS[@]}"; do
        jq -n --arg nevra "${RPM_NEVRA[$file]}" --arg sha256 "${RPM_SHA256[$file]}" \
            --arg arch "${RPM_ARCH[$file]}" --arg source_rpm "${RPM_SOURCE[$file]}" \
            --arg signed "${RPM_SIGNED[$file]}" \
            '{nevra:$nevra,arch:$arch,source_rpm:$source_rpm,sha256:$sha256,rpm_signature_present:($signed=="true")}'
    done | jq -s .)"
    discovered_rpms_json="$(for file in "${RPM_CANDIDATES[@]}"; do
        [[ -n "${RPM_NAME[$file]:-}" ]] || continue
        jq -n --arg nevra "${RPM_NEVRA[$file]}" --arg sha256 "${RPM_SHA256[$file]}" \
            --arg arch "${RPM_ARCH[$file]}" --arg source_rpm "${RPM_SOURCE[$file]}" \
            --arg signed "${RPM_SIGNED[$file]}" \
            '{nevra:$nevra,arch:$arch,source_rpm:$source_rpm,sha256:$sha256,rpm_signature_present:($signed=="true")}'
    done | jq -s .)"
    nabu_added_json="$({
        for file in "${SELECTED_RPMS[@]}"; do printf '%s\n' "${RPM_NEVRA[$file]}"; done
        [[ ! -s "$METADATA_DIR/generated-compatibility-rpms.txt" ]] || awk '{print $2}' "$METADATA_DIR/generated-compatibility-rpms.txt"
    } | jq -R . | jq -s .)"
    warnings_json="$(lines_to_json_array "${WARNINGS[@]}")"
    success_json="$(lines_to_json_array "${SUCCESSFUL_VARIANTS[@]}")"
    failed_json="$(lines_to_json_array "${FAILED_VARIANTS[@]}")"
    skipped_json="$(lines_to_json_array "${SKIPPED_VARIANTS[@]}")"
    jq -n \
        --arg schema_version "1" --arg result "$result" --arg target_arch "$TARGET_ARCH" --arg build_id "$BUILD_ID" --arg started "$START_ISO" --arg finished "$finish_iso" --argjson duration "$duration" \
        --arg host_arch "${NABU_HOST_ARCH:-$(uname -m)}" --arg host_os "${NABU_HOST_OS:-unknown}" \
        --arg podman "${NABU_PODMAN_VERSION:-unknown}" --arg container_image "$CONTAINER_IMAGE" --arg container_privileged "$PRIVILEGED_CONTAINER" \
        --arg container_digest "${NABU_CONTAINER_DIGEST:-unknown}" --arg container_arch "$CONTAINER_ARCH" \
        --arg compose_id "$RAWHIDE_COMPOSE_ID" --arg compose_date "$RAWHIDE_COMPOSE_DATE" --arg compose_status "$RAWHIDE_COMPOSE_STATUS" \
        --arg rawhide_baseurl "$RAWHIDE_REPO_BASEURL" --arg repomd "$RAWHIDE_REPOMD_SHA256" --arg comps "$RAWHIDE_COMPS_SHA256" --arg kickstart "$RAWHIDE_KICKSTART_SHA" \
        --arg desktop "$DESKTOP" --arg filesystem "$FILESYSTEM" --arg shell "$DEFAULT_SHELL" --arg build_mode "$BUILD_MODE" \
        --arg secure_boot "$SECURE_BOOT" --arg signing_fp "$SIGNING_CERT_FINGERPRINT" --arg trusted_fp "$TRUSTED_CERT_FINGERPRINT" \
        --arg secure_status "$SECURE_BOOT_STATUS" --arg bootloader "$BOOTLOADER" --arg kernel_nevra "$KERNEL_NEVRA" \
        --arg kernel_release "$KERNEL_RELEASE" --arg kernel_sha "$kernel_sha" --arg kernel_cmdline "$resolved_cmdline" --arg core_fingerprint "$CORE_FINGERPRINT" \
        --arg parity "${PARITY_STATUS:-PREFLIGHT_ONLY}" --arg hardware "NOT_RUN" \
        --argjson installed_count "$installed_count" --argjson local_rpms "$local_rpms_json" --argjson discovered_rpms "$discovered_rpms_json" --argjson nabu_added "$nabu_added_json" --argjson artifacts "$artifacts_json" \
        --argjson successful "$success_json" --argjson failed "$failed_json" --argjson skipped "$skipped_json" --argjson warnings "$warnings_json" \
        '{schema_version:$schema_version,result:$result,build_id:$build_id,start_time:$started,end_time:$finished,duration_seconds:$duration,
          target_architecture:$target_arch,
          host:{architecture:$host_arch,os:$host_os,podman:$podman},
          container:{image:$container_image,digest:$container_digest,architecture:$container_arch,privileged:($container_privileged=="true")},
          rawhide:{compose_id:$compose_id,compose_date:$compose_date,compose_status:$compose_status,baseurl:$rawhide_baseurl,repository_metadata_sha256:$repomd,comps_sha256:$comps,kickstart_commit:$kickstart},
          repository_policy:{official_fedora_gpgcheck:true,local_nabu_gpgcheck:false,local_exception:"Discovered user-built Nabu RPMs are unsigned; exception is scoped to nabu-local only"},
          selection:{desktop:$desktop,filesystem:$filesystem,shell:$shell,build_mode:$build_mode,bootloader:$bootloader},
          secure_boot:{mode:$secure_boot,signing_certificate_sha256:$signing_fp,uefi_trusted_certificate_sha256:$trusted_fp,status:$secure_status},
          kernel:{nevra:$kernel_nevra,release:$kernel_release,rpm_sha256:$kernel_sha,cmdline:$kernel_cmdline},local_rpms:$local_rpms,discovered_local_rpms:$discovered_rpms,
          core_image_fingerprint:$core_fingerprint,installed_package_count:$installed_count,added_nabu_packages:$nabu_added,fedora_parity_status:$parity,
          artifacts:$artifacts,successful_variants:$successful,failed_variants:$failed,skipped_variants:$skipped,warnings:$warnings,hardware_test_status:$hardware}' \
        >"$METADATA_DIR/build-manifest.json.partial"
    jq empty "$METADATA_DIR/build-manifest.json.partial"
    mv "$METADATA_DIR/build-manifest.json.partial" "$METADATA_DIR/build-manifest.json"
}

write_checksums() {
    (cd "$BUILD_ROOT" && find artifacts metadata reports SUMMARY.md -type f ! -name '*.partial' -print0 \
        | sort -z | xargs -0 sha256sum) >"$BUILD_ROOT/SHA256SUMS.partial"
    mv "$BUILD_ROOT/SHA256SUMS.partial" "$BUILD_ROOT/SHA256SUMS"
    (cd "$BUILD_ROOT" && sha256sum -c SHA256SUMS --quiet --ignore-missing)
}

finalize_reports() {
    stage 23 REPORT
    if [[ "$DRY_RUN" == "true" ]]; then
        PARITY_STATUS="PREFLIGHT_ONLY"
        write_dry_run_report
    elif ((${#FAILED_VARIANTS[@]} > 0 || ${#SKIPPED_VARIANTS[@]} > 0)); then
        PARITY_STATUS="FAIL"
    elif [[ "$RAWHIDE_COMPOSE_STATUS" == "FINISHED" ]]; then
        PARITY_STATUS="PASS_WITH_EXPECTED_DIFFERENCES"
    else
        PARITY_STATUS="PASS_WITH_EXPECTED_DIFFERENCES"
    fi
    write_security_report
    write_parity_report "$PARITY_STATUS"
    write_validation_report
    write_firstboot_report
    if [[ "$DRY_RUN" != "true" ]]; then
        cat >"$REPORTS_DIR/BUILD-REPORT.md" <<EOF
# Nabu Fedora Rawhide Build Report

- Build ID: \`$BUILD_ID\`
- Compose: \`$RAWHIDE_COMPOSE_ID\`
- Successful variants: ${SUCCESSFUL_VARIANTS[*]:-none}
- Failed variants: ${FAILED_VARIANTS[*]:-none}
- Skipped variants: ${SKIPPED_VARIANTS[*]:-none}
- Secure Boot: \`$SECURE_BOOT_STATUS\`
- Fedora parity: \`$PARITY_STATUS\`
- Hardware test: \`NOT_RUN\`
EOF
    fi
    write_output_summary
    write_build_manifest
    write_checksums
}

cleanup_container_state() {
    [[ "$CLEANUP_DONE" == "false" ]] || return 0
    CLEANUP_DONE="true"
    if [[ "$ERROR_REPORTED" == "false" ]]; then
        stage 24 CLEANUP
    else
        COMPONENT_LOG="$LOG_DIR/cleanup.log"
        log INFO "Cleaning temporary container state while preserving the original failed stage in STATUS.json."
    fi
    if command -v guestunmount >/dev/null 2>&1; then
        local mountpoint
        while IFS= read -r mountpoint; do
            guestunmount "$mountpoint" >/dev/null 2>&1 || true
        done < <(find /work -mindepth 1 -maxdepth 1 -type d \( -name '*mount*' -o -name 'mnt-*' \) -print 2>/dev/null)
    fi
    [[ ! -f /output/.nabu-builder-output ]] || find /output -type f \( -name '*.partial' -o -name '*.part' \) -delete 2>/dev/null || true
    # Cleanup must never turn a successful build or preflight into a failure.
    # The directory is confined to the marked /work mount; retain it only if
    # an unexpected deletion problem occurs, and report that condition.
    if [[ -e /work/private-keys ]] && ! safe_remove_container_tree /work/private-keys; then
        log WARN "Could not remove temporary private-key directory; it remains inside the isolated work directory."
    fi
    find /work -type f -name 'qemu-aarch64-static' -delete 2>/dev/null || true
    log INFO "Temporary private keys, QEMU helpers, and partial artifacts were removed."
}

container_pipeline() {
    load_container_options
    container_install_tools
    stage 1 HOST
    log INFO "Read-only input workspace is /workspace; writable work/output/cache are isolated mounts."
    discover_rpm_candidates
    select_rpm_set
    secure_boot_preflight
    resolve_rawhide_metadata
    resolve_fedora_groups
    prepare_local_repository
    dry_run_dependency_check
    if [[ "$DRY_RUN" == "true" ]]; then
        finalize_reports
        cleanup_container_state
        log INFO "Dry-run completed without creating an image."
        return 0
    fi

    local filesystem profile rc core_source check_fp
    local esp_built="false"
    while IFS= read -r filesystem; do
        [[ -n "$filesystem" ]] || continue
        CURRENT_FILESYSTEM="$filesystem"
        if [[ "$VARIANTS_ONLY" == "true" ]]; then
            if [[ -n "$REUSE_CORE" ]]; then
                core_source="$REUSE_CORE"; check_fp="true"
            else
                core_source="$FROM_CORE"; check_fp="false"
            fi
            validate_reused_core "$core_source" "$filesystem" "$check_fp"
            CORE_IMAGE="$core_source"
        else
            create_core_installroot "$filesystem"
            install_nabu_runtime_rpms "$CORE_ROOTFS"
            configure_core_system "$CORE_ROOTFS" "$filesystem"
            create_core_image "$CORE_ROOTFS" "$filesystem"
            validate_core_gate "$CORE_ROOTFS" "$filesystem"
            generate_initramfs "$CORE_ROOTFS"
            sync_initramfs_into_core_image "$filesystem"
            build_uki "$CORE_ROOTFS"
            if [[ "$esp_built" != "true" ]]; then
                build_esp "$CORE_ROOTFS"
                esp_built="true"
            fi
            publish_core_artifact "$filesystem"
        fi

        if [[ "$CORE_ONLY" != "true" ]]; then
            while IFS= read -r profile; do
                [[ -n "$profile" ]] || continue
                if [[ "$profile" == "gnome-mobile" && "$GNOME_MOBILE_AVAILABLE" != "true" ]]; then
                    if [[ "$DESKTOP" == "all" ]]; then
                        SKIPPED_VARIANTS+=("$profile/$filesystem:GNOME_MOBILE_UNAVAILABLE")
                        log WARN "Skipping $profile/$filesystem: GNOME_MOBILE_UNAVAILABLE."
                        continue
                    fi
                fi
                build_variant_from_core "$CORE_IMAGE" "$filesystem" "$profile"
                rc="$VARIANT_RC"
                if ((rc != 0)); then
                    FAILED_VARIANTS+=("$profile/$filesystem:$rc")
                    ((rc == EXIT_PARITY)) && STRICT_PARITY_FAILED="true"
                    record_variant_failure "$profile" "$filesystem" "$rc"
                    log ERROR "Variant $profile/$filesystem failed with exit $rc; continuing other requested variants."
                fi
            done < <(expand_desktops)
        fi
    done < <(expand_filesystems)

    finalize_reports
    cleanup_container_state
    if ((${#FAILED_VARIANTS[@]} > 0 || ${#SKIPPED_VARIANTS[@]} > 0)); then
        if ((${#SUCCESSFUL_VARIANTS[@]} > 0)); then
            return "$EXIT_PARTIAL"
        fi
        [[ "$STRICT_PARITY_FAILED" != "true" ]] || return "$EXIT_PARITY"
        return "$EXIT_DESKTOP"
    fi
    return 0
}

host_main() {
    local original_count="${#ORIGINAL_ARGS[@]}"
    parse_args "${ORIGINAL_ARGS[@]}"
    if [[ "$ACTION" == "doctor" ]]; then
        if run_doctor; then
            return 0
        else
            return "$?"
        fi
    fi
    if ((original_count == 0)) && [[ "$NON_INTERACTIVE" != "true" ]]; then
        interactive_menu
    fi
    validate_options
    initialize_run_paths
    host_preflight
    start_notification_watcher
    container_image_preflight
    run_container
    local rc="$CONTAINER_RC"
    if ((rc == 0)); then
        if [[ "$DRY_RUN" == "true" ]]; then
            write_run_status PREFLIGHT_PASS 0 "Build preflight completed successfully"
        else
            write_run_status COMPLETE 0 "Build completed successfully"
        fi
        update_latest_link latest
        log INFO "Build completed successfully: $BUILD_ROOT"
    elif ((rc == EXIT_PARTIAL)); then
        write_run_status PARTIAL "$rc" "Build completed with partial success"
        update_latest_link latest
        log WARN "Build completed with partial success: $BUILD_ROOT"
    else
        handle_error "$rc" "$LINENO" "podman container pipeline" "host_main"
        update_latest_link latest-failed
        return "$rc"
    fi
    return "$rc"
}

main() {
    install_traps
    if [[ "$HOST_MODE" == "true" ]]; then
        host_main
    else
        container_pipeline
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
