#!/bin/bash
# 流量统计文本解析回归测试，覆盖 awk 参数顺序及空/活动连接输出。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hy2.sh"

FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAIL=1; }

# 避免测试依赖外部语言文件，同时让单位输出可预测。
i18n() {
    case "$1" in
        traffic_status_estab) printf 'ESTABLISHED' ;;
        traffic_status_closed) printf 'CLOSED' ;;
        unit_byte_literal) printf 'B' ;;
        unit_kilobyte_literal) printf 'KB' ;;
        unit_megabyte_literal) printf 'MB' ;;
        unit_gigabyte_literal) printf 'GB' ;;
        unit_millisecond_literal) printf 'ms' ;;
        unit_second_literal) printf 's' ;;
        unit_minute_literal) printf 'm' ;;
        unit_hour_literal) printf 'h' ;;
        *) printf '%s' "$1" ;;
    esac
}

fixture='STATE USER CONN FLOWS TX RX ALIVE LAST REQUEST TARGET
ESTAB alice c1 2 1024 2048 2s 500ms source.example:443 target.example:443'

output=$(printf '%s\n' "$fixture" | formatTrafficStreamRows 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'cannot open -v' <<<"$output"; then
    pass "awk options are parsed as options, not file names"
else
    fail "stream parser failed: $output"
fi

if grep -q '^ESTABLISHED|alice|c1|2|1.00KB|2.00KB|2.0s|0.50|source.example:443|target.example:443$' <<<"$output"; then
    pass "active stream row is formatted"
else
    fail "unexpected formatted row: $output"
fi

header_only='STATE USER CONN FLOWS TX RX ALIVE LAST REQUEST TARGET'
empty_output=$(printf '%s\n' "$header_only" | formatTrafficStreamRows)
if [ -z "$empty_output" ]; then
    pass "header-only stream dump produces no rows"
else
    fail "header-only dump produced: $empty_output"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "ALL stats TESTS PASSED"
else
    exit 1
fi
