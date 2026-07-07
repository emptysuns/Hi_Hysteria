#!/bin/bash
killHysteriaProcess() {
    local signal="${1:-TERM}"
    local pid_file="${2:-/var/run/hihy.pid}"

    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "-${signal}" "$pid" 2>/dev/null || true
            sleep 1
        fi
        rm -f "$pid_file"
    fi

    if pgrep -f "/etc/hihy/bin/appS" >/dev/null 2>&1; then
        pkill "-${signal}" -f "/etc/hihy/bin/appS" 2>/dev/null || true
        sleep 2
        if pgrep -f "/etc/hihy/bin/appS" >/dev/null 2>&1; then
            pkill -9 -f "/etc/hihy/bin/appS" 2>/dev/null || true
            sleep 1
        fi
    fi
}

cleanupHysteria2Iptables() {
    for table in nat mangle; do
        if command -v iptables-save >/dev/null 2>&1; then
            iptables -t "$table" -S 2>/dev/null | grep -oP 'HYSTERIA-\S+' | sort -u | while read -r chain; do
                iptables -t "$table" -S 2>/dev/null | grep -E " -j $chain$" | sed 's/-A/-D/' | while read -r rule; do
                    iptables -t "$table" $rule 2>/dev/null || true
                done
                iptables -t "$table" -F "$chain" 2>/dev/null || true
                iptables -t "$table" -X "$chain" 2>/dev/null || true
            done
        fi
        if command -v ip6tables-save >/dev/null 2>&1; then
            ip6tables -t "$table" -S 2>/dev/null | grep -oP 'HYSTERIA-\S+' | sort -u | while read -r chain; do
                ip6tables -t "$table" -S 2>/dev/null | grep -E " -j $chain$" | sed 's/-A/-D/' | while read -r rule; do
                    ip6tables -t "$table" $rule 2>/dev/null || true
                done
                ip6tables -t "$table" -F "$chain" 2>/dev/null || true
                ip6tables -t "$table" -X "$chain" 2>/dev/null || true
            done
        fi
    done
}

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echoColor red "$(i18n error_root_required)"
        exit 1
    fi
}

uninstall() {
    local install_state
    install_state=$(classifyInstallState)
    portHoppingStatus=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingStatus" "false")
    if [ "$install_state" = "not-installed" ]; then
        echoColor red "$(i18n hysteria_not_installed)"
        exit 1
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "$(i18n partial_uninstall_cleanup)"
    fi

    # 停止服务
    if [ -f "/etc/alpine-release" ]; then
        if [ -f "/etc/init.d/hihy" ]; then
            rc-service hihy stop >/dev/null 2>&1 || true
            rc-update del hihy default >/dev/null 2>&1 || true
            rm -f /etc/init.d/hihy
        fi
    else
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop >/dev/null 2>&1 || true
            rm -f /etc/rc.d/hihy
        fi
    fi

    killHysteriaProcess TERM

    # 删除 iptables 规则（脚本和 Hysteria2 自身添加的）
    if command -v iptables-save >/dev/null 2>&1 && command -v iptables-restore >/dev/null 2>&1; then
        iptables-save 2>/dev/null | grep -v "hihysteria" | iptables-restore >/dev/null 2>&1 || true
    fi
    if command -v ip6tables-save >/dev/null 2>&1 && command -v ip6tables-restore >/dev/null 2>&1; then
        ip6tables-save 2>/dev/null | grep -v "hihysteria" | ip6tables-restore >/dev/null 2>&1 || true
    fi
    cleanupHysteria2Iptables

    # 保存 iptables 规则
    if [ -d "/etc/iptables" ]; then
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save >/etc/iptables/rules.v4
        fi
        if command -v ip6tables-save >/dev/null 2>&1; then
            ip6tables-save >/etc/iptables/rules.v6
        fi
    fi

    # 删除定时任务
    crontab -l 2>/dev/null | grep -v "hihy cronTask" | crontab -

    delHihyFirewallPort udp
    delHihyFirewallPort tcp

    # 删除相关目录和文件
    rm -rf /etc/hihy
    rm -f /var/run/hihy.pid

    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/hihy start/d' /etc/rc.local
        if grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
            sed -i '/\/etc\/rc.d\/allow-port start/d' /etc/rc.local
        fi
    fi

    if [ -f "$HIHY_BIN_LINK" ]; then
        rm "$HIHY_BIN_LINK"
    fi

    # 检测并提示卸载WARP/WireProxy
    if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        echoColor purple "\n$(i18n warp_detected)"
        echoColor green "$(i18n warp_uninstall_prompt)"
        echo -e "\033[33m\033[01m$(i18n warp_uninstall_choice)\033[0m\033[32m\n\n$(i18n prompt_enter_number):\033[0m"
        read -r warpUninstallChoice
        if [ -z "${warpUninstallChoice}" ] || [ "${warpUninstallChoice}" == "1" ]; then
            echoColor purple "\n$(i18n warp_uninstalling)"
            warp u || true
            echoColor purple "\n$(i18n warp_uninstall_done)"
        else
            echoColor purple "\n$(i18n warp_keep_installation)"
        fi
    fi
    clearInstallFailureMarker

    # 删除 Arch Linux 的 rc.local systemd 服务
    uninstall_rc_local_for_arch
    # 检查是否完全删除
    if [ ! -d "/etc/hihy" ]; then
        echoColor green "$(i18n uninstall_complete)"
    else
        echoColor red "$(i18n uninstall_error)"
        exit 1
    fi
}

