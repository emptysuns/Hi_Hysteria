#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
TEST_ETC="$TEST_ROOT/etc"
TEST_BIN="$TEST_ROOT/bin"
MOCK_BIN="$TEST_ROOT/mock-bin"
TEST_RC_LOCAL="$TEST_ROOT/rc.local"
TEST_PID_FILE="$TEST_ROOT/hihy.pid"
ORIGINAL_PATH="$PATH"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_ETC" "$TEST_BIN" "$MOCK_BIN"
touch "$TEST_RC_LOCAL"

export HIHY_ROOT_DIR="$TEST_ETC/hihy"
export HIHY_BIN_LINK="$TEST_BIN/hihy"
export HIHY_YQ_BIN="$TEST_BIN/yq"
export HIHY_RC_LOCAL="$TEST_RC_LOCAL"
export HIHY_PID_FILE="$TEST_PID_FILE"
export printN=""

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

assert_file_contains() {
    local path="$1"
    local expected="$2"
    local message="$3"

    if ! grep -Fq "$expected" "$path"; then
        printf 'ASSERT FAILED: %s\nMissing text: %s\nFile: %s\n' "$message" "$expected" "$path" >&2
        exit 1
    fi
}

assert_output_contains() {
    local output="$1"
    local expected="$2"
    local message="$3"

    if [[ "$output" != *"$expected"* ]]; then
        printf 'ASSERT FAILED: %s\nMissing text: %s\nOutput was:\n%s\n' "$message" "$expected" "$output" >&2
        exit 1
    fi
}

assert_file_not_contains() {
    local path="$1"
    local unexpected="$2"
    local message="$3"

    if [ -f "$path" ] && grep -Fq "$unexpected" "$path"; then
        printf 'ASSERT FAILED: %s\nUnexpected text: %s\nFile: %s\n' "$message" "$unexpected" "$path" >&2
        exit 1
    fi
}

link_required_command() {
    local command_name="$1"
    local command_path

    command_path="$(command -v "$command_name")"
    if [ -z "$command_path" ]; then
        printf 'ASSERT FAILED: required command not found: %s\n' "$command_name" >&2
        exit 1
    fi

    ln -s "$command_path" "$MOCK_BIN/$command_name"
}

reset_state() {
    rm -rf "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_PID_FILE"
    rm -f "$HIHY_YQ_BIN"
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
    touch "$HIHY_ROOT_DIR/bin/appS" "$HIHY_ROOT_DIR/conf/config.yaml" "$HIHY_ROOT_DIR/conf/backup.yaml" "$TEST_ETC/rc.d/hihy" "$HIHY_BIN_LINK"

    assert_equals "installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "complete install should be detected as installed"
}

test_missing_launcher_is_partial_state() {
    reset_state
    mkdir -p "$HIHY_ROOT_DIR/bin" "$HIHY_ROOT_DIR/conf" "$TEST_ETC/rc.d"
    touch "$HIHY_ROOT_DIR/bin/appS" "$HIHY_ROOT_DIR/conf/config.yaml" "$HIHY_ROOT_DIR/conf/backup.yaml" "$TEST_ETC/rc.d/hihy"

    assert_equals "partially-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "missing launcher should be detected as partial install"
}

test_install_validation_uses_iptables_backend() {
    reset_state
    assert_file_contains "$SCRIPT_DIR/hy2.sh" 'env HYSTERIA_FIREWALL_BACKEND="iptables" /etc/hihy/bin/appS -c "$yaml_file" server > "$debug_file" 2>&1 &' "install validation helper should force the iptables backend"
}

test_cached_version_notifications_are_displayed() {
    reset_state
    mkdir -p "$HIHY_ROOT_DIR/result"
    cat > "$HIHY_VERSION_STATUS_FILE" <<EOF
checked_at=123
hihy_status=update
hihy_remote=ver9.99-z
core_status=update
core_remote=app/v9.99.9
EOF

    local output
    output=$(displayCachedVersionNotifications)
    assert_output_contains "$output" "hihy需更新,version:vver9.99-z" "cached hihy update notice should be shown"
    assert_output_contains "$output" "hysteria2 core有更新,version:app/v9.99.9" "cached core update notice should be shown"
}

test_version_check_ttl_and_lock_guard() {
    reset_state
    mkdir -p "$HIHY_ROOT_DIR/result"

    cat > "$HIHY_VERSION_STATUS_FILE" <<EOF
checked_at=$(date +%s)
hihy_status=current
hihy_remote=ver1.04-a
core_status=missing
core_remote=
EOF
    if shouldStartVersionCheck; then
        printf 'ASSERT FAILED: fresh cache should prevent new background checks\n' >&2
        exit 1
    fi

    rm -f "$HIHY_VERSION_STATUS_FILE"
    cat > "$HIHY_VERSION_CHECK_LOCK_FILE" <<EOF
pid=$$
started_at=$(date +%s)
EOF
    if shouldStartVersionCheck; then
        printf 'ASSERT FAILED: active lock should prevent new background checks\n' >&2
        exit 1
    fi
}

test_show_menu_starts_background_check_after_render() {
    reset_state
    local output
    output=$(show_menu)
    assert_output_contains "$output" "Hi Hysteria" "menu should render immediately"
    sleep 1
    if [ ! -f "$HIHY_VERSION_CHECK_LOCK_FILE" ] && [ ! -f "$HIHY_VERSION_STATUS_FILE" ]; then
        printf 'ASSERT FAILED: show_menu should trigger asynchronous version-check state activity\n' >&2
        exit 1
    fi
}

test_failure_marker_round_trip() {
    reset_state
    markInstallFailed "config-test" "unknown"
    assert_equals "partially-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "failure marker should force partial state"
    clearInstallFailureMarker
    assert_equals "not-installed" "$(classifyInstallState "$HIHY_ROOT_DIR" "$HIHY_BIN_LINK" "$TEST_ETC/init.d/hihy" "$TEST_ETC/rc.d/hihy" "$(getInstallFailureMarker "$HIHY_ROOT_DIR")")" "clearing marker should restore clean classification"
}

test_firewall_port_range_cleanup() {
    reset_state

    local mock_listen_value=":443,47000-48000"
    local ufw_state="$TEST_ROOT/ufw.state"
    local firewall_log="$TEST_ROOT/firewall.log"

    : > "$ufw_state"
    : > "$firewall_log"

    cat > "$MOCK_BIN/systemctl" <<'EOF'
#!/bin/sh
exit 1
EOF

    cat > "$MOCK_BIN/ufw" <<'EOF'
#!/bin/sh
state="${UFW_STATE:?}"
log="${FIREWALL_LOG:?}"

case "$1" in
    status)
        echo "Status: active"
        [ -f "$state" ] && cat "$state"
        ;;
    allow)
        echo "ufw allow $2" >> "$log"
        printf '%s ALLOW Anywhere\n' "$2" >> "$state"
        ;;
    delete)
        echo "ufw delete $2 $3" >> "$log"
        tmp="${state}.tmp"
        grep -Fv "$3 ALLOW Anywhere" "$state" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$state"
        ;;
    *)
        exit 1
        ;;
esac
EOF

    chmod +x "$MOCK_BIN/systemctl" "$MOCK_BIN/ufw"

    export PATH="$MOCK_BIN:/usr/bin:/bin"
    export UFW_STATE="$ufw_state"
    export FIREWALL_LOG="$firewall_log"

    # 该测试只覆盖防火墙清理流程，只需要模拟 listen 字段即可。
    getYamlValue() {
        if [ "$2" = "listen" ]; then
            echo "$mock_listen_value"
        fi
    }

    allowPort udp 47000:48000
    assert_file_contains "$firewall_log" "ufw allow 47000:48000/udp" "ufw allow should include protocol for port ranges"

    cat > "$ufw_state" <<'EOF'
443/udp ALLOW Anywhere
47000:48000/udp ALLOW Anywhere
EOF

    delHihyFirewallPort udp
    assert_file_contains "$firewall_log" "ufw delete allow 443/udp" "single-port ufw cleanup should use protocol-qualified rule"
    assert_file_contains "$firewall_log" "ufw delete allow 47000:48000/udp" "range cleanup should convert listen range back to ufw colon syntax"
    assert_file_not_contains "$ufw_state" "47000:48000/udp ALLOW Anywhere" "range rule should be removed from ufw state"

    export PATH="$ORIGINAL_PATH"
}

test_yq_download_uses_curl_when_wget_is_missing() {
    reset_state

    local apt_log="$TEST_ROOT/apt.log"
    local chmod_log="$TEST_ROOT/chmod.log"
    local curl_log="$TEST_ROOT/curl.log"
    local uname_log="$TEST_ROOT/uname.log"

    cat > "$MOCK_BIN/apt" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${APT_LOG:?}"
EOF

    cat > "$MOCK_BIN/chmod" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${CHMOD_LOG:?}"
/bin/chmod "$@"
EOF

    cat > "$MOCK_BIN/uname" <<'EOF'
#!/bin/sh
printf 'args=%s\n' "$*" >> "${UNAME_LOG:?}"
printf 'x86_64\n'
EOF

    cat > "$MOCK_BIN/curl" <<'EOF'
#!/bin/sh
log_file="${MOCK_CURL_LOG:?}"
output_path=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o)
            output_path="$2"
            shift 2
            ;;
        -fsSL)
            shift
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done
printf '%s\n' "$url" >> "$log_file"
printf '#!/bin/sh\necho mocked-yq\n' > "$output_path"
EOF

    chmod +x "$MOCK_BIN/apt" "$MOCK_BIN/chmod" "$MOCK_BIN/curl" "$MOCK_BIN/uname"

    export APT_LOG="$apt_log"
    export CHMOD_LOG="$chmod_log"
    export MOCK_CURL_LOG="$curl_log"
    export UNAME_LOG="$uname_log"
    export PATH="$MOCK_BIN"

    assert_equals "absent" "$([ -e "$MOCK_BIN/wget" ] && echo present || echo absent)" "test setup should not provide wget"

    checkSystemForUpdate
    export PATH="$ORIGINAL_PATH"

    assert_file_contains "$apt_log" "update" "missing dependencies should still trigger package manager refresh"
    assert_file_contains "$uname_log" "args=-m" "architecture detection should consult uname"
    assert_file_contains "$curl_log" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_" "curl fallback should download yq when wget is unavailable"
    assert_file_contains "$chmod_log" "+x $HIHY_YQ_BIN" "downloaded yq binary should be marked executable"
    assert_file_contains "$HIHY_YQ_BIN" "mocked-yq" "downloaded yq binary should be written to the configured path"
}

test_not_installed_state
test_partial_state_detection_and_recovery
test_installed_state_detection
test_missing_launcher_is_partial_state
test_install_validation_uses_iptables_backend
test_cached_version_notifications_are_displayed
test_version_check_ttl_and_lock_guard
test_show_menu_starts_background_check_after_render
test_failure_marker_round_trip
test_firewall_port_range_cleanup
test_yq_download_uses_curl_when_wget_is_missing

printf 'All install recovery tests passed.\n'
