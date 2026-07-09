#!/bin/bash
# hysteria release 资产的架构后缀:复用 getArchitecture 单一映射表,
# 仅补充 hysteria 特有的差异项(mips64 板卡多为小端,官方只发 mipsle)
getHysteriaCoreArch() {
    case "$(uname -m)" in
        mips64) echo "mipsle" ;;
        *)
            local mapped
            mapped=$(getArchitecture)
            if [ "$mapped" = "unknown" ]; then
                echo ""
            else
                echo "$mapped"
            fi
            ;;
    esac
}

downloadHysteriaCore() {
    local version
    version=$(getLatestHysteriaVersion)

    echo -e "$(i18n latest_hysteria_version) $(echoColor red "${version}")\n$(i18n core_downloading)"

    if [ -z "$version" ]; then
        echoColor red "$(i18n network_error_get_latest_version)"
        return 1
    fi

    local arch
    arch=$(getHysteriaCoreArch)
    if [ -z "$arch" ]; then
        echoColor yellowBlack "$(i18n unsupported_arch "$(uname -m)")"
        return 1
    fi
    local download_url="https://github.com/apernet/hysteria/releases/download/${version}/hysteria-linux-${arch}"

    # 下载到临时文件,校验后原子替换,避免失败时破坏现有可用内核
    mkdir -p /etc/hihy/bin
    local temp_bin="/etc/hihy/bin/.appS.tmp.$$"

    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$temp_bin" --no-check-certificate "$download_url" &
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$temp_bin" "$download_url" &
    else
        echoColor red "$(i18n network_error_cannot_connect_github)"
        return 1
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
    printf "\r\033[K"
    if [ $dl_rc -ne 0 ] || [ ! -s "$temp_bin" ]; then
        rm -f "$temp_bin"
        echoColor red "$(i18n network_error_cannot_connect_github)"
        return 1
    fi

    # ELF 魔数校验:防止把镜像/网关返回的错误页当成二进制装进去
    if [ "$(head -c 4 "$temp_bin" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]; then
        rm -f "$temp_bin"
        echoColor red "$(i18n core_download_invalid)"
        return 1
    fi

    chmod 755 "$temp_bin"
    mv "$temp_bin" /etc/hihy/bin/appS
    echoColor purple "\n$(i18n download_completed)"
}

updateHysteriaCore() {
    if [ ! -f "/etc/hihy/bin/appS" ]; then
        echoColor red "$(i18n hysteria_core_not_found)"
        return 1
    fi

    local localV
    localV=$(getLocalHysteriaVersion || true)
    local remoteV
    remoteV=$(getLatestHysteriaVersion || true)
    echo -e "$(i18n local_core_version) $(echoColor red "${localV}")"
    echo -e "$(i18n remote_core_version) $(echoColor red "${remoteV}")"

    # 拿不到远端版本时不要盲目重装(旧逻辑会当作"有更新"直接下载,网络故障时半途报废)
    if [ -z "${remoteV}" ]; then
        echoColor yellow "$(i18n update_skip_no_remote)"
        return 1
    fi

    if [ "${localV}" = "${remoteV}" ]; then
        echoColor green "$(i18n already_latest_version)"
        return 0
    fi

    local was_running="false"
    if [ "$(getServiceRunState)" = "running" ]; then
        was_running="true"
        stop
        killHysteriaProcess TERM
    fi

    if ! downloadHysteriaCore; then
        # 下载失败时旧内核仍完好,恢复服务
        if [ "${was_running}" == "true" ]; then
            start
        fi
        return 1
    fi
    # 清除版本检查缓存，确保下次运行重新检查（避免显示过时的"有新版本"通知）
    rm -f "$HIHY_VERSION_STATUS_FILE"

    if [ "${was_running}" == "true" ]; then
        start
    fi
    echoColor green "$(i18n hysteria_core_update_done)"
}
