#!/bin/bash
echoColor() {
    local printN="${printN:-}"
    case $1 in
        # 红色
        "red") echo -e "\033[31m${printN}$2 \033[0m" ;;
        # 天蓝色
        "skyBlue") echo -e "\033[1;36m${printN}$2 \033[0m" ;;
        # 绿色
        "green") echo -e "\033[32m${printN}$2 \033[0m" ;;
        # 白色
        "white") echo -e "\033[37m${printN}$2 \033[0m" ;;
        # 洋红色
        "magenta") echo -e "\033[35m${printN}$2 \033[0m" ;;
        # 黄色
        "yellow") echo -e "\033[33m${printN}$2 \033[0m" ;;
        # 紫色
        "purple") echo -e "\033[1;35m${printN}$2 \033[0m" ;;
        # 黑底黄字
        "yellowBlack") echo -e "\033[1;33;40m${printN}$2 \033[0m" ;;
        # 绿底白字
        "greenWhite") echo -e "\033[42;37m${printN}$2 \033[0m" ;;
        # 蓝色
        "blue") echo -e "\033[34m${printN}$2 \033[0m" ;;
        # 青色
        "cyan") echo -e "\033[36m${printN}$2 \033[0m" ;;
        # 黑色
        "black") echo -e "\033[30m${printN}$2 \033[0m" ;;
        # 灰色
        "gray") echo -e "\033[90m${printN}$2 \033[0m" ;;
        # 亮红色
        "lightRed") echo -e "\033[91m${printN}$2 \033[0m" ;;
        # 亮绿色
        "lightGreen") echo -e "\033[92m${printN}$2 \033[0m" ;;
        # 亮黄色
        "lightYellow") echo -e "\033[93m${printN}$2 \033[0m" ;;
        # 亮蓝色
        "lightBlue") echo -e "\033[94m${printN}$2 \033[0m" ;;
        # 亮洋红色
        "lightMagenta") echo -e "\033[95m${printN}$2 \033[0m" ;;
        # 亮青色
        "lightCyan") echo -e "\033[96m${printN}$2 \033[0m" ;;
        # 亮白色
        "lightWhite") echo -e "\033[97m${printN}$2 \033[0m" ;;
    esac
}

# 检测系统架构的函数
getPortBindMsg() {
    # $1 type UDP or TCP
    # $2 port
    local msg
    if [ "$1" == "UDP" ]; then
        msg=$(lsof -i "${1}:${2}")
    else
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    fi

    if [ -z "$msg" ]; then
        return
    fi

    local command pid name
    command=$(echo "$msg" | awk '{print $1}')
    pid=$(echo "$msg" | awk '{print $2}')
    name=$(echo "$msg" | awk '{print $9}')
    echoColor purple "$(i18n port_bind_in_use ${1} ${2} ${command} ${name} ${pid})"
    echoColor green "$(i18n port_bind_auto_close_prompt)"
    read -r bindP

    if [ -z "$bindP" ] || [[ ! "$bindP" =~ ^[yY]$ ]]; then
        echoColor red "$(i18n port_bind_exit)"
        if [ "$1" == "TCP" ] && [ "$2" == "80" ]; then
            echoColor red "$(i18n port_bind_alternative_cert_for_80 ${1} ${2})"
        fi
        exit
    fi

    pkill -f "/etc/hihy/bin/appS"
    echoColor purple "$(i18n port_bind_unbinding)"
    sleep 3

    if [ "$1" == "TCP" ]; then
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    else
        msg=$(lsof -i "${1}:${2}")
    fi

    if [ -n "$msg" ]; then
        echoColor red "$(i18n port_bind_close_failed)"
        exit
    else
        echoColor green "$(i18n port_bind_unbound)"
    fi
}

generate_qr() {
    local url=$1

    # 使用最小合法尺寸 1
    local qr_size=1
    local margin=1
    local level="L" # 使用最低纠错级别以减小大小
    # 生成并显示 QR 码
    # -l L: 使用最低级别的纠错
    # -m margin: 设置边距
    # -s 1: 使用最小合法尺寸
    qrencode -t ANSIUTF8 -o - -l "$level" -m "$margin" -s 1 "${url}"

    if [ $? -eq 0 ]; then
        echoColor green "\n$(i18n qr_code_generated_success)"
    else
        echoColor red "\n$(i18n qr_code_generated_failure)"
        return 1
    fi
}

# 服务运行状态: running / stopped / none(未安装)
getServiceRunState() {
    local svc=""
    if [ -f "/etc/rc.d/hihy" ]; then
        svc="/etc/rc.d/hihy"
    elif [ -f "/etc/init.d/hihy" ]; then
        svc="/etc/init.d/hihy"
    else
        echo "none"
        return
    fi
    if "$svc" status 2>/dev/null | grep -q "is running"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# 居中打印头部盒子内容行(仅用于 ASCII 文案,宽度按字符数计算)
menuBoxLine() {
    local text="$1"
    local width=43
    local pad=$(((width - ${#text}) / 2))
    [ "$pad" -lt 0 ] && pad=0
    printf " \033[1;36m│\033[0m%*s%s%*s\033[1;36m│\033[0m\n" "$pad" "" "$text" "$((width - pad - ${#text}))" ""
}

menuSection() {
    printf "\n \033[1m%s\033[0m \033[90m────────────────────────\033[0m\n" "$1"
}

menuItem() {
    printf "  \033[32m%2s\033[0m\033[90m)\033[0m %s\n" "$1" "$2"
}

show_menu() {
    clear
    local state coreV=""
    state=$(getServiceRunState)
    if [ -x "/etc/hihy/bin/appS" ]; then
        coreV=$(getLocalHysteriaVersion 2>/dev/null || true)
        coreV="${coreV#app/}"
    fi

    echo -e " \033[1;36m╭───────────────────────────────────────────╮\033[0m"
    menuBoxLine "$(i18n menu_title) ${hihyV}"
    menuBoxLine "https://github.com/emptysuns/Hi_Hysteria"
    echo -e " \033[1;36m╰───────────────────────────────────────────╯\033[0m"

    # 状态行:服务状态 + 内核版本
    local status_segment
    case "$state" in
        running) status_segment="\033[32m●\033[0m $(i18n menu_status_running)" ;;
        stopped) status_segment="\033[31m●\033[0m $(i18n menu_status_stopped)" ;;
        *) status_segment="\033[90m○\033[0m $(i18n menu_status_not_installed)" ;;
    esac
    if [ -n "$coreV" ]; then
        echo -e "  ${status_segment} \033[90m│\033[0m $(i18n menu_status_core) ${coreV}"
    else
        echo -e "  ${status_segment}"
    fi
    hihy_update_notifycation

    menuSection "$(i18n menu_section_deploy)"
    menuItem 1 "$(i18n menu_item_install)"
    menuItem 16 "$(i18n menu_item_autoinstall)"
    menuItem 2 "$(i18n menu_item_uninstall)"

    menuSection "$(i18n menu_section_service)"
    menuItem 3 "$(i18n menu_item_start)"
    menuItem 4 "$(i18n menu_item_stop)"
    menuItem 5 "$(i18n menu_item_restart)"
    menuItem 6 "$(i18n menu_item_status)"

    menuSection "$(i18n menu_section_config)"
    menuItem 8 "$(i18n menu_item_view_config)"
    menuItem 9 "$(i18n menu_item_reconfigure)"
    menuItem 10 "$(i18n menu_item_switch_ip)"
    menuItem 12 "$(i18n menu_item_acl)"
    menuItem 15 "$(i18n menu_item_socks5)"

    menuSection "$(i18n menu_section_maintain)"
    menuItem 7 "$(i18n menu_item_update_core)"
    menuItem 11 "$(i18n menu_item_update_hihy)"
    menuItem 13 "$(i18n menu_item_traffic)"
    menuItem 14 "$(i18n menu_item_logs)"

    echo -e "\n \033[90m─────────────────────────────────────────\033[0m"
    menuItem 0 "$(i18n menu_item_exit)"
    echo -e " \033[90m$(i18n menu_hint_hihy_cmd "hihy")\033[0m"
    echo ""
    startBackgroundVersionCheck
}

wait_for_continue() {
    echo -e "\n$(echoColor green "$(i18n menu_wait_continue)")"
    read -r -n 1 -s
}

