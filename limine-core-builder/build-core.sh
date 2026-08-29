#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROFILE="$SCRIPT_DIR/profile.env"
OUTPUT_ROOT="$REPO_ROOT/output/limine-core"
RUNTIME="${LIMINE_CORE_CONTAINER_RUNTIME:-auto}"
SOLVE_ONLY=false
PRINT_CONFIG=false

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf '%s\n' \
        'Usage: limine-core-builder/build-core.sh [options]' \
        '' \
        '  --output PATH       Artifact output root' \
        '  --runtime NAME      auto, podman, or docker' \
        '  --solve-only        Run only the live DNF closure gate' \
        '  --print-config      Print the immutable build profile' \
        '  --help              Show this help'
}

while (($#)); do
    case "$1" in
        --output) OUTPUT_ROOT="${2:?--output needs a path}"; shift 2 ;;
        --runtime) RUNTIME="${2:?--runtime needs a value}"; shift 2 ;;
        --solve-only) SOLVE_ONLY=true; shift ;;
        --print-config) PRINT_CONFIG=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) limine_core_die "Unknown option: $1" ;;
    esac
done

limine_core_load_profile "$PROFILE"
limine_core_assert_profile

if [[ "$PRINT_CONFIG" == true ]]; then
    sed -n '/^LIMINE_CORE_[A-Z0-9_]*=/p' "$PROFILE"
    exit 0
fi

case "$RUNTIME" in
    auto)
        if command -v podman >/dev/null 2>&1; then RUNTIME=podman
        elif command -v docker >/dev/null 2>&1; then RUNTIME=docker
        else limine_core_die "Neither Podman nor Docker is installed"
        fi
        ;;
    podman|docker) limine_core_require_command "$RUNTIME" ;;
    *) limine_core_die "Unsupported container runtime: $RUNTIME" ;;
esac

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT="$(cd -- "$OUTPUT_ROOT" && pwd -P)"
limine_core_log "Pulling identical Fedora environment: $LIMINE_CORE_CONTAINER_IMAGE"
"$RUNTIME" pull --platform linux/arm64 "$LIMINE_CORE_CONTAINER_IMAGE" >/dev/null
image_digest="$($RUNTIME image inspect "$LIMINE_CORE_CONTAINER_IMAGE" --format '{{.Id}}')"
limine_core_log "Container image identity: $image_digest"

run_args=(run --rm --privileged --platform linux/arm64)
if [[ "$RUNTIME" == podman ]]; then
    run_args+=(--security-opt label=disable)
fi
run_args+=(
    -e "LIMINE_CORE_CONTAINER_IMAGE_ID=$image_digest"
    -e "LIMINE_CORE_SOLVE_ONLY=$SOLVE_ONLY"
    -e "LIMINE_CORE_KEEP_UNCOMPRESSED=${LIMINE_CORE_KEEP_UNCOMPRESSED:-1}"
    -v "$REPO_ROOT:/workspace:ro"
    -v "$OUTPUT_ROOT:/output"
    "$LIMINE_CORE_CONTAINER_IMAGE"
    /workspace/limine-core-builder/container-compose.sh
)

"$RUNTIME" "${run_args[@]}"
