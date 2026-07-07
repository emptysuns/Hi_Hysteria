#!/bin/bash
HIHY_BIN_LINK="${HIHY_BIN_LINK:-/usr/bin/hihy}"
HIHY_HYSTERIA2_URL="${HIHY_HYSTERIA2_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh}"
HIHY_HYSTERIA1_URL="${HIHY_HYSTERIA1_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/install.sh}"
HIHY_I18N_SCHEMA="${HIHY_I18N_SCHEMA:-1}"
HIHY_I18N_BASE_URL="${HIHY_I18N_BASE_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main}"
HIHY_I18N_DIR="${HIHY_I18N_DIR:-/etc/hihy/i18n}"
HIHY_I18N_CONF="${HIHY_I18N_CONF:-/etc/hihy/conf/i18n.conf}"
HIHY_DEFAULT_LANG="${HIHY_DEFAULT_LANG:-en}"
HIHY_SUPPORTED_LANGUAGES="en zh fa ru"
HIHY_LANG="${HIHY_LANG:-}"

# ---------- minimal i18n: 按 key 从已下载的 JSON 文件读值;找不到则显示 key 本身 ----------
i18nValueFromFile() {
    local file="$1"
    local key="$2"
    [ ! -f "$file" ] && return
    local line
    line=$(grep -E "^\s*\"${key}\":\s*\"" "$file" | head -n 1)
    [ -z "$line" ] && return
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
        value=$(i18nValueFromFile "$lang_file" "$key")
        [ -n "$value" ] && printf '%s' "$value" && return 0
    fi

    if [ "$HIHY_LANG" != "en" ] && [ -f "$en_file" ]; then
        value=$(i18nValueFromFile "$en_file" "$key")
        [ -n "$value" ] && printf '%s' "$value" && return 0
    fi

    printf '%s' "$key"
}

i18n() {
    local key="$1"
    shift
    local template
    template=$(i18nLookup "$key")
    printf "$template" "$@"
}

# ---------- download helpers ----------
downloadHihyScript() {
    local url="$1"
    local output_path="${2:-$HIHY_BIN_LINK}"
    local output_dir
    local temp_output_path
    local output_name

    output_dir="$(dirname "$output_path")"
    output_name="$(basename "$output_path")"
    mkdir -p "$output_dir" || return 1
    temp_output_path="$(mktemp "$output_dir/.${output_name}.tmp.XXXXXX")" || return 1

    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$temp_output_path" "$url" || {
            rm -f "$temp_output_path"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$temp_output_path" "$url" || {
            rm -f "$temp_output_path"
            return 1
        }
    else
        echo -e "\033[31mcurl/wget not found — cannot download hihy. Please install curl or wget and try again.\033[0m" >&2
        return 1
    fi

    chmod +x "$temp_output_path" && mv "$temp_output_path" "$output_path" || {
        rm -f "$temp_output_path"
        return 1
    }
}

downloadI18nFile() {
    local lang="$1"
    local base_url="$2"
    mkdir -p "$HIHY_I18N_DIR"
    local url="${base_url}/server/i18n/${lang}.json"
    local out="${HIHY_I18N_DIR}/hy2.sh.${lang}.json"
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$out" "$url" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$out" "$url" 2>/dev/null
    else
        return 1
    fi
}

# ---------- hysteria version ----------
resolveHysteriaVersion() {
    local selected_version="$1"

    if [ "$selected_version" = "1" ] || [ -z "$selected_version" ]; then
        printf '%s\n' "hysteria2"
    elif [ "$selected_version" = "2" ]; then
        printf '%s\n' "hysteria1"
    else
        return 1
    fi
}

# ---------- language selection / persistence ----------
parseLanguageOption() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --lang=*)
                HIHY_LANG="${1#*=}"
                shift
                ;;
            --lang)
                shift
                HIHY_LANG="${1:-}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

promptLanguageSelection() {
    local default_index=1
    case "$HIHY_DEFAULT_LANG" in
        zh) default_index=2 ;;
        fa) default_index=3 ;;
        ru) default_index=4 ;;
    esac
    echo -e "\033[32mPlease select language / 请选择语言 / لطفاً زبان را انتخاب کنید / Выберите язык:"
    echo -e "\033[33m 1) English"
    echo -e " 2) 中文"
    echo -e " 3) فارسی"
    echo -e " 4) Русский"
    echo -ne "\033[32mLanguage (default ${default_index}): \033[0m"
    read -r lang_choice
    case "${lang_choice:-$default_index}" in
        2) HIHY_LANG="zh" ;;
        3) HIHY_LANG="fa" ;;
        4) HIHY_LANG="ru" ;;
        *) HIHY_LANG="en" ;;
    esac
}

persistLanguage() {
    mkdir -p "$(dirname "$HIHY_I18N_CONF")"
    printf 'HIHY_LANG=%s\n' "$HIHY_LANG" >"$HIHY_I18N_CONF"
}

isSupportedLanguage() {
    case " $HIHY_SUPPORTED_LANGUAGES " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

validateLanguage() {
    if [ -n "${1:-}" ] && ! isSupportedLanguage "$1"; then
        echo -e "\033[33mWarning: unsupported language '$1'. Falling back to interactive selection.\033[0m" >&2
        return 1
    fi
}

# ---------- main ----------
main() {
    local hysteria_version
    local download_url

    parseLanguageOption "$@"

    if ! validateLanguage "$HIHY_LANG"; then
        unset HIHY_LANG
        promptLanguageSelection
    fi

    persistLanguage

    # 尽早下载 i18n 语言文件，后续提示使用所选语言
    downloadI18nFile "$HIHY_LANG" "$HIHY_I18N_BASE_URL" || true
    if [ "$HIHY_LANG" != "en" ]; then
        downloadI18nFile "en" "$HIHY_I18N_BASE_URL" >/dev/null 2>&1 || true
    fi

    # hysteria 版本选择（现在可以用所选语言显示了）
    echo -e "\033[32m$(i18n install_select_hysteria_version)\n\n\033[0m\033[33m\033[01m$(i18n install_hysteria2_option)\n$(i18n install_hysteria1_option)\033[0m\033[32m\n\n$(i18n install_enter_number)\033[0m"
    read hysteria_version
    hysteria_version="$(resolveHysteriaVersion "$hysteria_version")" || {
        echo -e "\033[31m$(i18n error_input_error)\033[0m"
        exit 1
    }

    if [ "$hysteria_version" = "hysteria2" ]; then
        download_url="$HIHY_HYSTERIA2_URL"
    else
        download_url="$HIHY_HYSTERIA1_URL"
    fi

    echo -e "-> $(i18n install_selected_version "$(printf '\033[32m%s\033[0m' "$hysteria_version")")"
    echo -e "$(i18n install_downloading_hihy)"

    if ! downloadHihyScript "$download_url" "$HIHY_BIN_LINK"; then
        exit 1
    fi

    if ! "$HIHY_BIN_LINK"; then
        echo -e "\033[31m$(i18n install_hihy_launch_failed)\033[0m" >&2
        exit 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
