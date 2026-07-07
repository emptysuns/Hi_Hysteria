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
            echoColor "$(i18n port_bind_alternative_cert_for_80 ${1} ${2})"
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

countdown() {
    local seconds=$1
    echo -ne "\033[32m$(i18n countdown_prefix)\033[0m "

    while [ $seconds -gt 0 ]; do
        # 打印当前数字
        echo -ne "\033[31m$seconds\033[0m"
        sleep 1

        # 计算退格数量
        local digits=${#seconds}
        for ((i = 0; i < digits; i++)); do
            echo -ne "\b \b"
        done

        ((seconds--))
    done

    # 清除最后一个数字并显示完成消息
    echo -ne " " # 清除最后显示的数字
    echo -e "\n\033[32m$(i18n countdown_done)\033[0m"
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

show_menu() {
    clear
    echo -e " -------------------------------------------"
    echo -e "|**********      $(i18n menu_title)       **********|"
    echo -e "|**********    Author: emptysuns   **********|"
    echo -e "|**********     $(i18n menu_version "$(echoColor red "${hihyV}")")    **********|"
    echo -e " -------------------------------------------"
    echo -e "$(i18n menu_hint_hihy_cmd "$(echoColor green "hihy")")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_install)")"
    echo -e "$(echoColor magenta "$(i18n menu_option_uninstall)")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_start)")"
    echo -e "$(echoColor magenta "$(i18n menu_option_stop)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_restart)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_status)")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_update_core)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_view_config)")"
    echo -e "$(echoColor red "$(i18n menu_option_reconfigure)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_switch_ip_priority)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_update_hihy)")"
    echo -e "$(echoColor lightMagenta "$(i18n menu_option_acl)")"
    echo -e "$(echoColor skyBlue "$(i18n menu_option_traffic_stats)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_logs)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_socks5)")"

    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor magenta "$(i18n menu_option_exit)")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e ""
    hihy_update_notifycation
    echo -e "\n"
    startBackgroundVersionCheck
}

wait_for_continue() {
    echo -e "\n$(echoColor green "$(i18n menu_wait_continue)")"
    read -r -n 1 -s
}

