#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
TEST_ETC="$TEST_ROOT/etc"
TEST_BIN="$TEST_ROOT/bin"
TEST_RC_LOCAL="$TEST_ROOT/rc.local"
TEST_PID_FILE="$TEST_ROOT/hihy.pid"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_ETC" "$TEST_BIN"
touch "$TEST_RC_LOCAL"

export HIHY_ROOT_DIR="$TEST_ETC/hihy"
export HIHY_BIN_LINK="$TEST_BIN/hihy"
export HIHY_RC_LOCAL="$TEST_RC_LOCAL"
export HIHY_PID_FILE="$TEST_PID_FILE"

source "$SCRIPT_DIR/hy2.sh"

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        printf 'ASSERT FAILED: %s\nExpected: %s\nActual: %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_not_exists() {
    local path="$1"
    local message="$2"

    if [ -e "$path" ]; then
        printf 'ASSERT FAILED: %s\nUnexpected path exists: %s\n' "$message" "$path" >&2
        exit 1
    fi
}

reset_state() {
    rm -rf "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_PID_FILE"
    rm -f "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy"
    : > "$TEST_RC_LOCAL"
}

test_not_installed_state() {
    reset_state
    assert_equals "not-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "clean system should be detected as not-installed"
}

test_partial_state_detection_and_recovery() {
    reset_state
    mkdir -p "$HIHY_ROOT_DIR/bin" "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/result" "$TEST_ETC/rc.d"
    touch "$HIHY_ROOT_DIR/bin/appS" "$HIHY_ROOT_DIR/conf/config.yaml" "$TEST_ETC/rc.d/hihy" "$HIHY_BIN_LINK"
    markInstallFailed "download" "network error"

    assert_equals "partially-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "partial install should be detected"

    recoverPartialInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")" "$TEST_RC_LOCAL" "$TEST_PID_FILE"

    assert_not_exists "$HIHY_ROOT_DIR/conf/config.yaml" "recovery should remove partial config"
    assert_not_exists "$TEST_ETC/rc.d/hihy" "recovery should remove partial service script"
    assert_not_exists "$HIHY_BIN_LINK" "recovery should remove launcher link"
    assert_equals "partially-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "remaining owned directories should still be considered partial until uninstall cleans them"
}

test_installed_state_detection() {
    reset_state
    mkdir -p "$HIHY_ROOT_DIR/bin" "$HIHY_ROOT_DIR/conf" "$TEST_ETC/rc.d"
    touch "$HIHY_ROOT_DIR/bin/appS" "$HIHY_ROOT_DIR/conf/config.yaml" "$HIHY_ROOT_DIR/conf/backup.yaml" "$TEST_ETC/rc.d/hihy"

    assert_equals "installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "complete install should be detected as installed"
}

test_failure_marker_round_trip() {
    reset_state
    markInstallFailed "config-test" "unknown"
    assert_equals "partially-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "failure marker should force partial state"
    clearInstallFailureMarker
    assert_equals "not-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "clearing marker should restore clean classification"
}

test_not_installed_state
test_partial_state_detection_and_recovery
test_installed_state_detection
test_failure_marker_round_trip

printf 'All install recovery tests passed.\n'
