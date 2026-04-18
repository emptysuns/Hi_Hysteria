#!/bin/bash
HIHY_BIN_LINK="${HIHY_BIN_LINK:-/usr/bin/hihy}"
HIHY_HYSTERIA2_URL="${HIHY_HYSTERIA2_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh}"
HIHY_HYSTERIA1_URL="${HIHY_HYSTERIA1_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/install.sh}"

downloadHihyScript() {
    local url="$1"
    local output_path="${2:-$HIHY_BIN_LINK}"
    local output_dir
    local temp_output_path

    output_dir="$(dirname "$output_path")"
    mkdir -p "$output_dir" || return 1
    temp_output_path="$(mktemp "${output_path}.tmp.XXXXXX")" || return 1

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

    chmod +x "$temp_output_path" && mv "$temp_output_path" "$output_path"
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

main() {
    local hysteria_version
    local download_url

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

    "$HIHY_BIN_LINK"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
