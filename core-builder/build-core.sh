#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PROFILE="$SCRIPT_DIR/profile.env"
OUTPUT_ROOT="$REPO_ROOT/output/core"
RUNTIME="${CORE_CONTAINER_RUNTIME:-auto}"
SOLVE_ONLY=false
PRINT_CONFIG=false

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<'EOF'
Usage: core-builder/build-core.sh [options]

Options:
  --output PATH       Artifact output root (default: output/core)
  --runtime NAME      auto, podman, or docker
  --solve-only        Run live Fedora Rawhide AArch64 DNF closure only
  --print-config      Print the resolved CORE profile
  --help              Show this help
EOF
}

while (($#)); do
    case "$1" in
        --output) OUTPUT_ROOT="${2:?--output needs a path}"; shift 2 ;;
        --runtime) RUNTIME="${2:?--runtime needs a value}"; shift 2 ;;
        --solve-only) SOLVE_ONLY=true; shift ;;
        --print-config) PRINT_CONFIG=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) core_die "Unknown option: $1" ;;
    esac
done

core_load_profile "$PROFILE"
core_assert_profile

if [[ "$PRINT_CONFIG" == true ]]; then
    sed -n '/^[A-Z0-9_]*=/p' "$PROFILE"
    exit 0
fi

case "$RUNTIME" in
    auto)
        if command -v podman >/dev/null 2>&1; then RUNTIME=podman
        elif command -v docker >/dev/null 2>&1; then RUNTIME=docker
        else core_die "Neither Podman nor Docker is installed"
        fi
        ;;
    podman|docker) core_require_command "$RUNTIME" ;;
    *) core_die "Unsupported container runtime: $RUNTIME" ;;
esac

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT="$(cd -- "$OUTPUT_ROOT" && pwd -P)"

core_log "Pulling identical Fedora environment: $CORE_CONTAINER_IMAGE"
"$RUNTIME" pull --platform linux/arm64 "$CORE_CONTAINER_IMAGE" >/dev/null
image_digest="$($RUNTIME image inspect "$CORE_CONTAINER_IMAGE" --format '{{.Id}}')"
core_log "Container image identity: $image_digest"

run_args=(run --rm --privileged --platform linux/arm64)
if [[ "$RUNTIME" == podman ]]; then
    run_args+=(--security-opt label=disable)
fi
run_args+=(
    -e "CORE_CONTAINER_IMAGE_ID=$image_digest"
    -e "CORE_SOLVE_ONLY=$SOLVE_ONLY"
    -e "CORE_KEEP_UNCOMPRESSED=${CORE_KEEP_UNCOMPRESSED:-1}"
    -v "$REPO_ROOT:/workspace:ro"
    -v "$OUTPUT_ROOT:/output"
    "$CORE_CONTAINER_IMAGE"
    /workspace/core-builder/container-compose.sh
)

"$RUNTIME" "${run_args[@]}"
