#!/bin/bash
# 组装 server/src/*.sh -> server/hy2.sh (单文件分发产物)
# 用法: bash scripts/build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/server/src"
OUT="$REPO_ROOT/server/hy2.sh"
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
        # 首模块(00-header.sh):保留 shebang,紧跟 GENERATED 声明
        head -n 1 "$m" >"$TMP"
        cat >>"$TMP" <<'GEN'
# =============================================================================
# GENERATED FILE — DO NOT EDIT.
# Source lives in server/src/*.sh. Edit there and run: bash scripts/build.sh
# =============================================================================
GEN
        tail -n +2 "$m" >>"$TMP"
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
