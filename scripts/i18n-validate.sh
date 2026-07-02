#!/bin/bash
set -euo pipefail

BASE="server/i18n/en.json"
[ ! -f "$BASE" ] && echo "missing $BASE" && exit 1

base_keys=$(python3 -c "import json; print('\n'.join(json.load(open('$BASE')).keys()))" | grep -v '^_meta$' | sort)

errors=0
for f in server/i18n/*.json; do
    [ "$f" = "$BASE" ] && continue
    keys=$(python3 -c "import json; print('\n'.join(json.load(open('$f')).keys()))" | grep -v '^_meta$' | sort)
    missing=$(comm -23 <(echo "$base_keys") <(echo "$keys"))
    extra=$(comm -13 <(echo "$base_keys") <(echo "$keys"))
    if [ -n "$missing" ] || [ -n "$extra" ]; then
        echo "VALIDATION ERROR: $f"
        [ -n "$missing" ] && echo "  missing keys:" && echo "$missing" | sed 's/^/    /'
        [ -n "$extra" ] && echo "  extra keys:" && echo "$extra" | sed 's/^/    /'
        errors=$((errors+1))
    fi
done

if [ "$errors" -eq 0 ]; then
    echo "All translation files are consistent."
else
    exit 1
fi
