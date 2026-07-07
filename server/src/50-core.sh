#!/bin/bash
downloadHysteriaCore() {
    local version
    version=$(getLatestHysteriaVersion)

    echo -e "$(i18n latest_hysteria_version) $(echoColor red "${version}")\n$(i18n core_downloading)"

    if [ -z "$version" ]; then
        echoColor red "$(i18n network_error_get_latest_version)"
        exit 1
    fi

    local arch=$(uname -m)
    local url_base="https://github.com/apernet/hysteria/releases/download/${version}/hysteria-linux-"
    local download_url=""

    case "$arch" in
        "x86_64")
            download_url="${url_base}amd64"
            ;;
        "aarch64")
            download_url="${url_base}arm64"
            ;;
        "mips64")
            download_url="${url_base}mipsle"
            ;;
        "s390x")
            download_url="${url_base}s390x"
            ;;
        "i686" | "i386")
            download_url="${url_base}386"
            ;;
        "loongarch64")
            download_url="${url_base}loong64"
            ;;
        *)
            echoColor yellowBlack "$(i18n unsupported_arch ${arch})"
            exit 1
            ;;
    esac

    if command -v wget >/dev/null 2>&1; then
        wget -q -O /etc/hihy/bin/appS --no-check-certificate "$download_url" &
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o /etc/hihy/bin/appS "$download_url" &
    else
        echoColor red "$(i18n network_error_cannot_connect_github)"
        exit 1
    fi

    local dl_pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $dl_pid 2>/dev/null; do
        printf "\r\033[K$(i18n core_downloading) %s" "${spin:i++%4:1}"
        sleep 0.3
    done
    wait $dl_pid
    local dl_rc=$?
    if [ $dl_rc -ne 0 ]; then
        printf "\r\033[K"
        echoColor red "$(i18n network_error_cannot_connect_github)"
        exit 1
    fi
    printf "\r\033[K"

    if [ -f "/etc/hihy/bin/appS" ]; then
        chmod 755 /etc/hihy/bin/appS
        echoColor purple "\n$(i18n download_completed)"
    else
        echoColor red "$(i18n network_error_cannot_connect_github)"
        exit 1
    fi
}

updateHysteriaCore() {
    if [ -f "/etc/hihy/bin/appS" ]; then
        local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
        local remoteV
        remoteV=$(getLatestHysteriaVersion || true)
        echo -e "$(i18n local_core_version) $(echoColor red "${localV}")"
        echo -e "$(i18n remote_core_version) $(echoColor red "${remoteV}")"
        if [ "${localV}" = "${remoteV}" ]; then
            echoColor green "$(i18n already_latest_version)"
        else
            local was_running="false"
            if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
                if [ -f "/etc/rc.d/hihy" ]; then
                    msg=$(/etc/rc.d/hihy status)
                else
                    msg=$(/etc/init.d/hihy status)
                fi
                if [ "${msg}" == "hihy is running" ]; then
                    was_running="true"
                    stop
                    killHysteriaProcess TERM
                fi
            fi

            downloadHysteriaCore
            # 清除版本检查缓存，确保下次运行重新检查（避免显示过时的"有新版本"通知）
            rm -f "$HIHY_VERSION_STATUS_FILE"

            if [ "${was_running}" == "true" ]; then
                start
            fi
            echoColor green "$(i18n hysteria_core_update_done)"
        fi
    else
        echoColor red "$(i18n hysteria_core_not_found)"
        exit 1
    fi
}

