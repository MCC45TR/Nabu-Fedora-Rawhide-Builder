#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
BUILDER="$ROOT_DIR/Nabu-Fedora-Rawhide-Builder.sh"
PASSED=0
FAILED=0

run_test() {
    local name="$1"
    shift
    if "$@"; then
        printf 'ok %d - %s\n' "$((PASSED + FAILED + 1))" "$name"
        ((PASSED += 1))
    else
        printf 'not ok %d - %s\n' "$((PASSED + FAILED + 1))" "$name"
        ((FAILED += 1))
    fi
}

test_help() {
    "$BUILDER" --help 2>/dev/null | grep -Fq 'Nabu Fedora Rawhide Builder 1.2.0'
}

test_version() {
    [[ "$("$BUILDER" --version 2>/dev/null)" == 'Nabu Fedora Rawhide Builder 1.2.0' ]]
}

test_library_source_has_no_main_side_effect() {
    bash -c 'source "$1"; [[ "$BUILD_ID" == "" ]]' _ "$BUILDER"
}

test_need_value_missing() {
    bash -c 'source "$1"; need_value --desktop ""' _ "$BUILDER" >/dev/null 2>&1
    [[ $? -eq 2 ]]
}

test_valid_choice_accepts() {
    bash -c 'source "$1"; valid_choice ext4 ext4 btrfs' _ "$BUILDER"
}

test_valid_choice_rejects() {
    ! bash -c 'source "$1"; valid_choice xfs ext4 btrfs' _ "$BUILDER"
}

test_valid_size() {
    bash -c 'source "$1"; validate_size 12G' _ "$BUILDER"
}

test_invalid_size() {
    ! bash -c 'source "$1"; validate_size 0G' _ "$BUILDER"
}

test_desktop_single() {
    bash -c 'source "$1"; DESKTOP=gnome; validate_desktop_selection' _ "$BUILDER"
}

test_desktop_csv() {
    bash -c 'source "$1"; DESKTOP=kde-plasma,phosh; validate_desktop_selection' _ "$BUILDER"
}

test_desktop_invalid() {
    ! bash -c 'source "$1"; DESKTOP=invalid; validate_desktop_selection' _ "$BUILDER"
}

test_desktop_all_must_be_exclusive() {
    ! bash -c 'source "$1"; DESKTOP=all,gnome; validate_desktop_selection' _ "$BUILDER"
}

test_parse_privileged() {
    bash -c 'source "$1"; parse_args --privileged; [[ "$PRIVILEGED_CONTAINER" == true ]]' _ "$BUILDER"
}

test_parse_doctor() {
    bash -c 'source "$1"; parse_args doctor; [[ "$ACTION" == doctor ]]' _ "$BUILDER"
}

test_parse_build_mode() {
    bash -c 'source "$1"; parse_args --build=release; [[ "$BUILD_MODE" == release ]]' _ "$BUILDER"
}

test_parse_step_by_notification() {
    bash -c 'source "$1"; parse_args --step-by-notification; [[ "$STEP_BY_NOTIFICATION" == true ]]' _ "$BUILDER"
}

test_unknown_option() {
    bash -c 'source "$1"; parse_args --does-not-exist' _ "$BUILDER" >/dev/null 2>&1
    [[ $? -eq 2 ]]
}

test_external_repo_requires_opt_in() {
    bash -c 'source "$1"; DRY_RUN=true; DEVICE_REPO_URL=https://example.invalid/repo; validate_options' _ "$BUILDER" >/dev/null 2>&1
    [[ $? -eq 2 ]]
}

test_secure_boot_off_rejects_key() {
    bash -c 'source "$1"; SECURE_BOOT=off; SB_KEY=/tmp/test.key; validate_options' _ "$BUILDER" >/dev/null 2>&1
    [[ $? -eq 2 ]]
}

test_default_container_args_are_unprivileged() {
    bash -c 'source "$1"; declare -ga PODMAN_ARGS=(run); append_container_privilege_args; [[ "${#PODMAN_ARGS[@]}" -eq 1 ]]' _ "$BUILDER"
}

test_privileged_container_arg_is_added() {
    bash -c 'source "$1"; PRIVILEGED_CONTAINER=true; declare -ga PODMAN_ARGS=(run); append_container_privilege_args; [[ "${PODMAN_ARGS[1]}" == --privileged ]]' _ "$BUILDER"
}

test_step_notification_helpers() {
    bash -c 'source "$1"; [[ "$(elapsed_minute_mark 0)" == 0 && "$(elapsed_minute_mark 61)" == 2 && "$(stage_remaining_percent 18)" == 28 ]]' _ "$BUILDER"
}

test_doctor_runs() {
    "$BUILDER" doctor 2>/dev/null | grep -Fq 'Doctor summary: 0 failure(s)'
}

printf 'TAP version 13\n'
printf '1..23\n'
run_test 'help output' test_help
run_test 'version output' test_version
run_test 'library sourcing has no main side effect' test_library_source_has_no_main_side_effect
run_test 'need_value rejects a missing value' test_need_value_missing
run_test 'valid_choice accepts a supported value' test_valid_choice_accepts
run_test 'valid_choice rejects an unsupported value' test_valid_choice_rejects
run_test 'validate_size accepts 12G' test_valid_size
run_test 'validate_size rejects zero' test_invalid_size
run_test 'single desktop selection' test_desktop_single
run_test 'comma-separated desktop selection' test_desktop_csv
run_test 'invalid desktop selection' test_desktop_invalid
run_test 'all desktop selection is exclusive' test_desktop_all_must_be_exclusive
run_test 'parse --privileged' test_parse_privileged
run_test 'parse doctor action' test_parse_doctor
run_test 'parse --build=release' test_parse_build_mode
run_test 'parse --step-by-notification' test_parse_step_by_notification
run_test 'reject unknown option' test_unknown_option
run_test 'external repository requires opt-in' test_external_repo_requires_opt_in
run_test 'Secure Boot off rejects a key' test_secure_boot_off_rejects_key
run_test 'default container args remain unprivileged' test_default_container_args_are_unprivileged
run_test 'privileged container arg is explicit' test_privileged_container_arg_is_added
run_test 'step notification helpers' test_step_notification_helpers
run_test 'doctor completes without failures' test_doctor_runs

printf '# %d passed, %d failed\n' "$PASSED" "$FAILED"
((FAILED == 0))
