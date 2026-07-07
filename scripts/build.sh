#!/bin/bash
# 组装 server/src/*.sh -> server/hy2.sh (单文件分发产物)
# 用法: bash scripts/build.sh
#
# 产物行号约定:
#   line 1: shebang
#   line 2: hihyV="ver1.XX"  (getLatestHihyVersion 依赖此位置,不可移位)
#   line 3+: GENERATED header + 其余模块
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/server/src"
# HIHY_BUILD_OUT 允许把产物写到别处(test_build.sh 用它做无副作用比对)
OUT="${HIHY_BUILD_OUT:-$REPO_ROOT/server/hy2.sh}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

shopt -s nullglob
modules=("$SRC_DIR"/*.sh)
shopt -u nullglob

if [ "${#modules[@]}" -eq 0 ]; then
    echo "ERROR: no modules found in $SRC_DIR" >&2
    exit 1
fi

first=1
for m in "${modules[@]}"; do
    if [ "$first" -eq 1 ]; then
        # line 1: shebang
        head -n 1 "$m" >"$TMP"
        # line 2: hihyV (getLatestHihyVersion 依赖 sed -n '2p')
        grep '^hihyV=' "$m" | head -n 1 >>"$TMP"
        # line 3+: GENERATED header
        cat >>"$TMP" <<'GEN'
# =============================================================================
# GENERATED FILE — DO NOT EDIT.
# Source lives in server/src/*.sh. Edit there and run: bash scripts/build.sh
# =============================================================================
GEN
        # 00-header.sh 余下内容(去掉 shebang 和 hihyV 行)
        tail -n +2 "$m" | grep -v '^hihyV=' >>"$TMP"
        first=0
    else
        printf '\n# ----- %s -----\n' "$(basename "$m")" >>"$TMP"
        if head -n 1 "$m" | grep -q '^#!'; then
            tail -n +2 "$m" >>"$TMP"
        else
            cat "$m" >>"$TMP"
        fi
    fi
done

bash -n "$TMP" || { echo "ERROR: assembled script failed syntax check" >&2; exit 1; }
mv "$TMP" "$OUT"
trap - EXIT
chmod +x "$OUT"
echo "Built $OUT from ${#modules[@]} modules."

if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S error "$OUT"; then
        echo "shellcheck: no errors"
    else
        echo "shellcheck: errors above (review)" >&2
    fi
fi
