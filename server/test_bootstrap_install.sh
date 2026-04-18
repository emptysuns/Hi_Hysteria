#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
TEST_BIN="$TEST_ROOT/bin"
MOCK_BIN="$TEST_ROOT/mock-bin"
ORIGINAL_PATH="$PATH"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN" "$MOCK_BIN"

export HIHY_BIN_LINK="$TEST_BIN/hihy"

source "$SCRIPT_DIR/install.sh"

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        printf 'ASSERT FAILED: %s\nExpected: %s\nActual: %s\n' "$message" "$expected" "$actual" >&2
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

assert_executable() {
    local path="$1"
    local message="$2"

    if [ ! -x "$path" ]; then
        printf 'ASSERT FAILED: %s\nPath is not executable: %s\n' "$message" "$path" >&2
        exit 1
    fi
}

reset_state() {
    rm -f "$HIHY_BIN_LINK"
    rm -rf "$MOCK_BIN"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$ORIGINAL_PATH"
}

linkRequiredCommand() {
    local command_name="$1"
    local command_path

    command_path="$(command -v "$command_name")"
    if [ -z "$command_path" ]; then
        printf 'ASSERT FAILED: required command not found: %s\n' "$command_name" >&2
        exit 1
    fi

    ln -s "$command_path" "$MOCK_BIN/$command_name"
}

setupMinimalCommandPath() {
    local command_name

    for command_name in dirname mkdir chmod cat mv rm; do
        linkRequiredCommand "$command_name"
    done
}

test_download_uses_curl_when_wget_is_missing() {
    reset_state

    local curl_log="$TEST_ROOT/curl.log"
    setupMinimalCommandPath
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
cat <<'SCRIPT' > "$output_path"
#!/bin/sh
echo mocked
SCRIPT
EOF
    chmod +x "$MOCK_BIN/curl"

    export MOCK_CURL_LOG="$curl_log"

    (
        export PATH="$MOCK_BIN"
        downloadHihyScript "https://example.com/hy2.sh" "$HIHY_BIN_LINK"
    )

    assert_file_contains "$curl_log" "https://example.com/hy2.sh" "curl fallback should be used for downloads"
    assert_file_contains "$HIHY_BIN_LINK" "echo mocked" "downloaded bootstrap script should be written"
    assert_executable "$HIHY_BIN_LINK" "downloaded bootstrap script should be executable"
}

test_download_fails_cleanly_without_download_client() {
    reset_state

    setupMinimalCommandPath
    if (
        export PATH="$MOCK_BIN"
        downloadHihyScript "https://example.com/hy2.sh" "$HIHY_BIN_LINK" >/dev/null 2>&1
    ); then
        printf 'ASSERT FAILED: download should fail when curl and wget are unavailable\n' >&2
        exit 1
    fi

    assert_equals "absent" "$([ -e "$HIHY_BIN_LINK" ] && echo present || echo absent)" "failed downloads should not leave a bootstrap script behind"
}

test_resolve_hysteria_version_mapping() {
    assert_equals "hysteria2" "$(resolveHysteriaVersion "1")" "option 1 should resolve to hysteria2"
    assert_equals "hysteria2" "$(resolveHysteriaVersion "")" "empty selection should default to hysteria2"
    assert_equals "hysteria1" "$(resolveHysteriaVersion "2")" "option 2 should resolve to hysteria1"

    if resolveHysteriaVersion "3" >/dev/null 2>&1; then
        printf 'ASSERT FAILED: invalid selections should fail validation\n' >&2
        exit 1
    fi
}

test_download_uses_curl_when_wget_is_missing
test_download_fails_cleanly_without_download_client
test_resolve_hysteria_version_mapping

printf 'All bootstrap installer tests passed.\n'
