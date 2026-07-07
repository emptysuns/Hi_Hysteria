#!/bin/bash
set -euo pipefail

SCRIPT_FILE="${1:-server/hy2.sh}"
OUT_FILE="${2:-server/i18n/en.json}"

keys=$(grep -oE 'i18n [a-zA-Z0-9_]+' "$SCRIPT_FILE" | sed 's/i18n //' | sort -u)

tmp=$(mktemp)
{
    printf '{\n  "_meta": {\n    "schema_version": 1,\n    "language": "en",\n    "rtl": false\n  }'
    while IFS= read -r k; do
        [ -z "$k" ] && continue
        printf ',\n  "%s": "%s"' "$k" "$k"
    done <<< "$keys"
    printf '\n}\n'
} > "$tmp"

python3 -m json.tool "$tmp" > "${tmp}.formatted"
mv "${tmp}.formatted" "$OUT_FILE"
rm -f "$tmp"

echo "Wrote $OUT_FILE with $(echo "$keys" | grep -c '^' || true) keys."
