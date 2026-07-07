#!/bin/bash
hihyUpdate() {
    localV=${hihyV}
    remoteV=$(getLatestHihyVersion || true)
    if [ -z $remoteV ]; then
        echoColor red "$(i18n network_error_cannot_connect_github)"
        exit
    fi
    if [ "${localV}" = "${remoteV}" ]; then
        echoColor green "$(i18n already_latest_version)"
        # 清除版本检查缓存，防止因缓存过期而显示过时的"有新版本"通知
        rm -f "$HIHY_VERSION_STATUS_FILE"
    else
        rm -f "$HIHY_BIN_LINK"
        if ! installHihyLauncher /dev/null "$HIHY_BIN_LINK"; then
            echoColor red "$(i18n hihy_cmd_install_fail)"
            exit 1
        fi
        echoColor green "$(i18n hihy_update_complete)"
        # 清除版本检查缓存，确保下次运行时重新检查并显示正确状态
        rm -f "$HIHY_VERSION_STATUS_FILE"
    fi

}

changeIp64() {
    local socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
    local config_file="/etc/hihy/conf/config.yaml"
    if [ "${socks5_status}" == "true" ]; then
        echoColor red "$(i18n ip_priority_socks5_active_error)"
        exit 1
    fi
    mode_now=$(getYamlValue "$config_file" "outbounds[0].direct.mode")

    echoColor purple "$(i18n ip_priority_current_mode "$(echoColor red "${mode_now}")")"
    echoColor yellow "$(i18n ip_priority_choice_ipv4)"
    echoColor yellow "$(i18n ip_priority_choice_ipv6)"
    echoColor yellow "$(i18n ip_priority_choice_auto)"
    echoColor yellow "$(i18n prompt_exit)"
    read -r -p "$(i18n prompt_choose)" input
    case $input in
        1)
            if [ "${mode_now}" == "46" ]; then
                echoColor yellow "$(i18n ip_priority_already_ipv4)"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "46"
                restart
                echoColor green "$(i18n switch_success)"
            fi

            ;;
        2)
            if [ "${mode_now}" == "64" ]; then
                echoColor yellow "$(i18n ip_priority_already_ipv6)"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "64"
                restart
                echoColor green "$(i18n switch_success)"
            fi

            ;;

        3)
            if [ "${mode_now}" == "auto" ]; then
                echoColor yellow "$(i18n ip_priority_already_auto)"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "auto"
                restart
                echoColor green "$(i18n switch_success)"
            fi
            ;;
        0) exit 0 ;;
        *)
            echoColor red "$(i18n error_input_error)"
            exit 1
            ;;
    esac
}

changeServerConfig() {
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "$(i18n change_config_install_first)"
        exit
    fi
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
        portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
    fi
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    stop
    killHysteriaProcess TERM
    cleanupHysteria2Iptables >/dev/null 2>&1 || true
    if [ "${masquerade_tcp}" == "true" ]; then
        delHihyFirewallPort tcp
        delHihyFirewallPort udp
    else
        delHihyFirewallPort udp
    fi
    updateHysteriaCore
    setHysteriaConfig
    start
    generate_client_config
    echoColor green "$(i18n change_config_success)"

}

aclControl() {
    local acl_file="/etc/hihy/acl/acl.txt"
    if [ ! -f "${acl_file}" ]; then
        echoColor red "$(i18n acl_file_not_found)"
        exit 1
    fi
    echoColor purple "$(i18n acl_action_prompt)"
    echoColor yellow "$(i18n acl_choice_add)"
    echoColor yellow "$(i18n acl_choice_delete)"
    echoColor yellow "$(i18n acl_choice_view)"
    echoColor yellow "$(i18n menu_option_exit)"
    read -r -p "$(i18n menu_prompt_choice)" input
    case $input in
        1)
            echoColor green "$(i18n acl_control_method_title)"
            echoColor yellow "$(i18n acl_choice_v4_suffix)"
            echoColor yellow "$(i18n acl_choice_v6_suffix)"
            echoColor yellow "$(i18n acl_choice_reject_suffix)"
            read -r -p "$(i18n menu_prompt_choice)" input
            case $input in
                1)
                    read -r -p "$(i18n acl_v4_domain_prompt)" domain
                    if [ -z "${domain}" ]; then
                        echoColor red "$(i18n domain_cannot_be_empty)"
                        exit 1
                    fi
                    if grep -q "v4_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "$(i18n acl_rule_exists)"
                    else
                        echo "v4_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "$(i18n add_success)"
                        restart
                    fi
                    ;;
                2)
                    read -r -p "$(i18n acl_v6_domain_prompt)" domain
                    if [ -z "${domain}" ]; then
                        echoColor red "$(i18n domain_cannot_be_empty)"
                        exit 1
                    fi
                    if grep -q "v6_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "$(i18n acl_rule_exists)"
                    else
                        echo "v6_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "$(i18n add_success)"
                        restart
                    fi
                    ;;
                3)
                    read -r -p "$(i18n acl_reject_domain_prompt)" rejectInput
                    if [ -z "${rejectInput}" ]; then
                        echoColor red "$(i18n domain_cannot_be_empty)"
                        exit 1
                    fi
                    if grep -q "reject(suffix:${rejectInput})" "${acl_file}"; then
                        echoColor red "$(i18n acl_rule_exists)"
                    else
                        echo "reject(suffix:${rejectInput})" >>"${acl_file}"
                        echoColor green "$(i18n add_success)"
                        restart
                    fi
                    ;;
                *)
                    echoColor red "$(i18n error_input_error)"
                    exit 1
                    ;;
            esac
            ;;
        2)
            read -r -p "$(i18n acl_delete_rule_prompt)" domain
            if [ -z "${domain}" ]; then
                echoColor red "$(i18n domain_cannot_be_empty)"
                exit 1
            fi
            if grep -q "${domain}" "${acl_file}"; then
                sed -i "/${domain}/d" "${acl_file}"
                echoColor green "$(i18n delete_success)"
                restart
            else
                echoColor red "$(i18n acl_rule_not_exists)"
            fi

            ;;
        3)
            echoColor purple "$(i18n acl_current_list)"
            cat "${acl_file}"
            ;;
        0) exit 0 ;;
        *)
            echoColor red "$(i18n error_input_error)"
            exit 1
            ;;
    esac

}

addSocks5Outbound() {
    if [ ! -f "/etc/hihy/conf/config.yaml" ]; then
        echoColor red "$(i18n config_file_not_found)"
        exit 1
    fi
    local server_config="/etc/hihy/conf/config.yaml"
    local backup_config="/etc/hihy/conf/backup.yaml"
    echo -e "$(i18n socks5_warp_tip)"
    echoColor yellow "$(i18n menu_option_exit)"
    read -r -p "$(i18n menu_prompt_choice)" num
    if [ -z "${num}" ] || [ ${num} == "1" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "$(i18n socks5_already_enabled)"
            exit 1
        fi
        local conf_file="/etc/wireguard/proxy.conf"
        if [ -f "$conf_file" ]; then
            echoColor green "$(i18n socks5_warp_config_found)"
        else
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh w
        fi

        if [ ! -f "$conf_file" ]; then
            echoColor red "$(i18n socks5_warp_config_not_found)"
            exit 1
        fi
        local port=$(grep "BindAddress" "$conf_file" | grep -v "^#" | awk -F':' '{print $2}')
        echoColor purple "$(i18n socks5_local_warp_port "$(echoColor red "${port}")")"

        # 在数组开头插入新的outbound配置
        yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'"}}] + .outbounds' -i "${server_config}"

        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "$(i18n socks5_add_warp_success)"

    elif [ ${num} == "2" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "$(i18n socks5_already_enabled)"
            exit 1
        fi
        read -r -p "$(i18n socks5_addr_prompt)" socks5_addr
        if [ -z "${socks5_addr}" ]; then
            echoColor red "$(i18n addr_cannot_be_empty)"
            exit 1
        fi
        read -r -p "$(i18n socks5_user_prompt)" socks5_user
        if [ -n "${socks5_user}" ]; then
            read -r -p "$(i18n socks5_pass_prompt)" socks5_pass
            if [ -z "${socks5_pass}" ]; then
                echoColor red "$(i18n password_cannot_be_empty)"
                exit 1
            fi
        fi
        local server_config="/etc/hihy/conf/config.yaml"
        if [ -n "${socks5_user}" ]; then
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'", "username": "'$socks5_user'", "password": "'$socks5_pass'"}}] + .outbounds' -i "${server_config}"
        else
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'"}}] + .outbounds' -i "${server_config}"

        fi
        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "$(i18n socks5_add_custom_success)"
    elif [ ${num} == "3" ]; then
        # 删除outbounds相关配置
        outbound_name=$(getYamlValue ${server_config} "outbounds[0].name")
        if [ "${outbound_name}" == "warp" ] || [ "${outbound_name}" == "custom" ]; then
            yq eval 'del(.outbounds[0])' -i "${server_config}"
            if [ "${outbound_name}" == "warp" ]; then
                warp u
            fi
            restart
            addOrUpdateYaml ${backup_config} "socks5_status" "false"
            echoColor green "$(i18n uninstall_success)"
        else
            echoColor red "$(i18n socks5_outbound_not_found)"
        fi

    else
        echoColor red "$(i18n error_input_error)"
        exit 1
    fi

}

