#!/bin/bash
# 校验 server/hy2.sh 与 server/src/ 同步:
#   - src 改了但忘记重新构建 -> 失败
#   - 产物被手改(绕过 src) -> 失败
# 比对方式:构建到临时文件后与现有产物逐字节比较,不改动工作区。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FRESH="$(mktemp)"
trap 'rm -f "$FRESH"' EXIT

HIHY_BUILD_OUT="$FRESH" bash "$REPO_ROOT/scripts/build.sh" >/dev/null

if cmp -s "$FRESH" "$REPO_ROOT/server/hy2.sh"; then
    echo "test_build: server/hy2.sh is in sync with server/src/. PASS"
else
    echo "test_build: server/hy2.sh differs from a fresh build of server/src/." >&2
    echo "  Either rebuild ('bash scripts/build.sh') or revert manual edits to the artifact." >&2
    diff "$REPO_ROOT/server/hy2.sh" "$FRESH" | head -20 >&2 || true
    exit 1
fi
