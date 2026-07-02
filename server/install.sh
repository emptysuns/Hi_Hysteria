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
        echo -e "\033[31m未找到 curl 或 wget，无法下载 hihy，请先安装其中之一后重试\033[0m" >&2
        return 1
    fi

    chmod +x "$temp_output_path" && mv "$temp_output_path" "$output_path" || {
        rm -f "$temp_output_path"
        return 1
    }
}

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

promptLanguageSelection() {
    local default_index=1
    case "$HIHY_DEFAULT_LANG" in
        zh) default_index=2 ;;
        fa) default_index=3 ;;
        ru) default_index=4 ;;
    esac
    echo -e "\033[32mPlease select installation language / 请选择安装语言:"
    echo -e "\033[33m 1) English"
    echo -e " 2) 中文"
    echo -e " 3) فارسی"
    echo -e " 4) Русский"
    echo -ne "\033[32mLanguage (default: ${default_index}): \033[0m"
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

main() {
    local hysteria_version
    local download_url

    parseLanguageOption "$@"

    if ! validateLanguage "$HIHY_LANG"; then
        unset HIHY_LANG
        promptLanguageSelection
    fi

    persistLanguage

    echo -e "\033[32m请选择安装的hysteria版本:\n\n\033[0m\033[33m\033[01m1、hysteria2(推荐,LTS性能更好)\n2、hysteria1(NLTS,未来无功能更新,但支持faketcp.被UDP QoS可以选择)\033[0m\033[32m\n\n输入序号:\033[0m"
    read hysteria_version
    hysteria_version="$(resolveHysteriaVersion "$hysteria_version")" || {
        echo -e "\033[31m输入错误,请重新运行脚本\033[0m"
        exit 1
    }

    if [ "$hysteria_version" = "hysteria2" ]; then
        download_url="$HIHY_HYSTERIA2_URL"
    else
        download_url="$HIHY_HYSTERIA1_URL"
    fi

    echo -e "-> 您选择的hysteria版本为: \033[32m$hysteria_version\033[0m"
    echo -e "Downloading hihy..."

    if ! downloadHihyScript "$download_url" "$HIHY_BIN_LINK"; then
        exit 1
    fi

    if ! downloadI18nFile "$HIHY_LANG" "$HIHY_I18N_BASE_URL"; then
        echo -e "\033[33mWarning: failed to download language file, English fallback embedded.\033[0m" >&2
    fi
    if [ "$HIHY_LANG" != "en" ]; then
        downloadI18nFile "en" "$HIHY_I18N_BASE_URL" >/dev/null 2>&1 || true
    fi

    if ! "$HIHY_BIN_LINK"; then
        echo -e "\033[31mhihy 启动失败，请检查下载结果或稍后重试\033[0m" >&2
        exit 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
