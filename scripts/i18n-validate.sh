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

# printf 占位符一致性:每个 key 在各语言中 %s/%d 数量必须与 en 基准一致
# (i18n() 将模板直接喂给 printf,占位符数量/顺序不一致即运行时错位)
placeholder_errors=0
en_data=$(python3 -c "
import json
with open('$BASE') as f:
    data = json.load(f)
for k, v in data.items():
    if k == '_meta': continue
    s = v.count('%s') + v.count('%d')
    print(f'{k}\t{s}')
")
while IFS=$'\t' read -r key en_count; do
    for lang in zh fa ru; do
        f="server/i18n/${lang}.json"
        lang_count=$(python3 -c "
import json
with open('$f') as fh:
    v = json.load(fh).get('$key', '')
print(v.count('%s') + v.count('%d'))
" 2>/dev/null)
        if [ "${lang_count:-0}" != "$en_count" ]; then
            echo "PLACEHOLDER MISMATCH: key='$key' en=${en_count} ${lang}=${lang_count:-0} ($f)"
            placeholder_errors=$((placeholder_errors+1))
        fi
    done
done <<< "$en_data"

if [ "$placeholder_errors" -ne 0 ]; then
    echo "placeholder errors: $placeholder_errors"
    errors=$((errors+placeholder_errors))
fi

if [ "$errors" -eq 0 ]; then
    echo "All translation files are consistent."
else
    exit 1
fi
