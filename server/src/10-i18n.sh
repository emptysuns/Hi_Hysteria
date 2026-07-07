#!/bin/bash
loadPersistedLanguage() {
    if [ -f "$HIHY_I18N_CONF" ] && [ -z "$HIHY_LANG" ]; then
        HIHY_LANG=$(grep -E '^HIHY_LANG=' "$HIHY_I18N_CONF" | tail -n 1 | cut -d'=' -f2-)
    fi
    HIHY_LANG="${HIHY_LANG:-en}"
}

savePersistedLanguage() {
    mkdir -p "$(dirname "$HIHY_I18N_CONF")"
    printf 'HIHY_LANG=%s\n' "$HIHY_LANG" >"$HIHY_I18N_CONF"
}

detectRtlFromMeta() {
    local file="$1"
    grep '"rtl"' "$file" 2>/dev/null | grep -q 'true'
}

getI18nSchemaVersion() {
    local file="$1"
    local line
    line=$(grep -E '"schema_version"' "$file" | head -n 1)
    [ -z "$line" ] && echo "0" && return
    line="${line%%,*}"
    line="${line#*: }"
    printf '%s' "$line"
}

refreshI18nFile() {
    local lang="$1"
    local base_url="https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main"
    mkdir -p "$HIHY_I18N_DIR"
    local url="${base_url}/server/i18n/${lang}.json"
    local out="${HIHY_I18N_DIR}/hy2.sh.${lang}.json"
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$out" "$url" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$out" "$url" 2>/dev/null
    fi
}

# 按 key 读取 JSON 字符串；返回空表示未找到
i18nValueFromFile() {
    local file="$1"
    local key="$2"
    if [ ! -f "$file" ]; then
        return
    fi
    local line
    line=$(grep -E "^\s*\"${key}\":\s*\"" "$file" | head -n 1)
    [ -z "$line" ] && return
    # 提取第一个 "..." 之后的内容
    line="${line#*: \"}"
    line="${line%\"*}"
    printf '%s' "$line"
}

i18nLookup() {
    local key="$1"
    local lang_file="${HIHY_I18N_DIR}/hy2.sh.${HIHY_LANG}.json"
    local en_file="${HIHY_I18N_DIR}/hy2.sh.en.json"
    local value

    if [ -f "$lang_file" ]; then
        local schema
        schema=$(getI18nSchemaVersion "$lang_file")
        if [ "$schema" != "$HIHY_I18N_SCHEMA" ]; then
            # 异步静默更新语言文件
            (refreshI18nFile "$HIHY_LANG") >/dev/null 2>&1 &
            # 本次直接使用英文
            value=$(i18nValueFromFile "$en_file" "$key")
            [ -n "$value" ] && printf '%s' "$value" && return 0
            printf '%s' "$key"
            return 0
        fi
    fi

    value=$(i18nValueFromFile "$lang_file" "$key")
    if [ -n "$value" ]; then
        printf '%s' "$value"
        return 0
    fi

    if [ "$HIHY_LANG" != "en" ]; then
        value=$(i18nValueFromFile "$en_file" "$key")
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return 0
        fi
    fi

    printf '%s' "$key"
}

# Usage: i18n <key> [arg1] [arg2] ...
i18n() {
    local key="$1"
    shift
    local template
    template=$(i18nLookup "$key")
    # 简单模板插值：%s, %d, %%, 依次用 bash printf 填充
    printf -- "$template" "$@"
}
