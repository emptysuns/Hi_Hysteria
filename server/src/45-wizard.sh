#!/bin/bash
startInstallValidationProcess() {
    local yaml_file="$1"
    local debug_file="${2:-./hihy_debug.info}"

    /etc/hihy/bin/appS -c "$yaml_file" server >"$debug_file" 2>&1 &
}

# ---------- 输入校验辅助 ----------
isPositiveInt() {
    case "${1:-}" in
        '' | *[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

isValidPort() {
    isPositiveInt "$1" && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

getUdpPortPid() {
    lsof -i "udp:${1}" 2>/dev/null | grep -v "PID" | awk '{print $2}' | head -n 1
}

isUdpPortFree() {
    [ -z "$(getUdpPortPid "$1")" ]
}

getRandomFreeUdpPort() {
    local candidate tries=0
    while [ "$tries" -lt 20 ]; do
        candidate=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
        if isUdpPortFree "$candidate"; then
            echo "$candidate"
            return 0
        fi
        tries=$((tries + 1))
    done
    return 1
}

# ---------- 配置默认值:向导/一键共用的唯一基线,保证 write 阶段引用的变量全部有值 ----------
setConfigDefaults() {
    realmMode="false"
    realmName=""
    realmURI=""
    useAcme=false
    useLocalCert=false
    useDns=false
    dns=""
    domain="www.bing.com"
    ip=""
    local_cert=""
    local_key=""
    cloudflare_api_token=""
    duckdns_api_token=""
    duckdns_override_domain=""
    gandi_api_token=""
    godaddy_api_token=""
    namedotcom_api_token=""
    namedotcom_user=""
    namedotcom_server=""
    vultr_api_token=""
    port=""
    portHoppingStatus="false"
    portHoppingStart=""
    portHoppingEnd=""
    portHoppingIntervalMode=""
    portHoppingHopInterval=""
    portHoppingMinHopInterval=""
    portHoppingMaxHopInterval=""
    congestion_mode="bbr"
    congestion_type="bbr"
    congestion_bbr_profile="standard"
    ignore_client_bandwidth="true"
    delay=""
    download=""
    upload=""
    auth_secret=""
    obfs_status="false"
    obfs_type=""
    obfs_pass=""
    masquerade_status="false"
    masquerade_type=""
    masquerade_string=""
    masquerade_stuff=""
    masquerade_proxy=""
    masquerade_xforwarded="false"
    masquerade_file=""
    masquerade_tcp="false"
    block_http3="false"
    remarks=""
    pinSHA256=""
    insecure="0"
}

# ---------- 交互式配置收集(原 setHysteriaConfig 前半段,只读输入、只设变量) ----------
collectHysteriaConfig() {
    echoColor yellowBlack "$(i18n config_start_title)"
    echoColor green "$(i18n realm_prompt_title)"
    echo -e "$(i18n realm_intro_line1)"
    echo -e "$(i18n realm_intro_line2)"
    echo -e "$(i18n realm_intro_line3)"
    echo -e "$(i18n realm_intro_line4)"
    echoColor yellow "$(i18n realm_warning_core_only)"
    echoColor yellow "$(i18n realm_choice_disable_default)"
    echoColor yellow "$(i18n realm_choice_enable)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r realmChoice
    if [ -z "${realmChoice}" ] || [ "${realmChoice}" == "1" ]; then
        realmMode="false"
    else
        realmMode="true"
        realmName=$(generate_uuid)
        echo -e "\n->$(i18n realm_name_label)$(echoColor red "${realmName}")\n"
        echoColor green "$(i18n realm_server_prompt)"
        echo -e "$(i18n realm_server_official_hint)"
        echoColor yellow "$(i18n realm_server_choice_official)"
        echoColor yellow "$(i18n realm_server_choice_custom)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r realmServerChoice
        if [ -z "${realmServerChoice}" ] || [ "${realmServerChoice}" == "1" ]; then
            realmAddress="realm.hy2.io"
            realmPassword="public"
        else
            echoColor green "$(i18n realm_address_prompt)"
            read -r realmAddressInput
            while [ -z "${realmAddressInput}" ]; do
                echoColor red "$(i18n realm_address_empty)"
                read -r realmAddressInput
            done
            realmAddress="${realmAddressInput}"
            echoColor green "$(i18n realm_password_prompt)"
            read -r realmPasswordInput
            if [ -z "${realmPasswordInput}" ]; then
                realmPassword="public"
            else
                realmPassword="${realmPasswordInput}"
            fi
        fi
        realmURI="realm://${realmPassword}@${realmAddress}/${realmName}"
        echo -e "\n->$(i18n realm_uri_label)$(echoColor red "${realmURI}")\n"
        if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
            echoColor purple "$(i18n warp_installed_hint)"
        fi
        echoColor green "$(i18n warp_install_prompt)"
        echoColor white "$(i18n warp_principle_line1)"
        echoColor white "$(i18n warp_principle_line2)"
        echoColor white "$(i18n warp_principle_line3)"
        echoColor white "$(i18n warp_principle_line4)"
        echoColor yellow "$(i18n warp_choice_skip)"
        echoColor yellow "$(i18n warp_choice_install)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r warpChoice
        if [ "${warpChoice}" == "2" ]; then
            echoColor purple "$(i18n warp_installing)"
            echoColor purple "$(i18n warp_select_global_mode)"
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh 2>/dev/null
            bash menu.sh d
            if [ -f "/etc/wireguard/warp.conf" ]; then
                current_mtu=$(grep -oP '^MTU = \K\d+' /etc/wireguard/warp.conf)
                if [ -n "${current_mtu}" ] && [ "${current_mtu}" -lt 1320 ]; then
                    sed -i "s/^MTU = ${current_mtu}/MTU = 1320/g" /etc/wireguard/warp.conf
                    echoColor purple "\n->$(i18n warp_mtu_adjusted ${current_mtu})"
                elif [ -n "${current_mtu}" ]; then
                    echoColor purple "\n->$(i18n warp_mtu_no_adjust ${current_mtu})"
                fi
                echoColor purple "$(i18n warp_enabling)"
                warp o
                sleep 3
                echoColor purple "$(i18n warp_reenabling)"
                warp o
                echoColor purple "$(i18n warp_install_done)"
            else
                echoColor red "$(i18n warp_install_fail)"
                echoColor red "$(i18n warp_manual_cmd)"
                echoColor red "$(i18n warp_install_fail_exit)"
                exit 1
            fi
        else
            echoColor purple "$(i18n warp_skip)"
        fi
    fi
    echoColor green "$(i18n cert_prompt_title)"
    echoColor yellow "$(i18n cert_choice_acme)"
    echoColor yellow "$(i18n cert_choice_local)"
    echoColor yellow "$(i18n cert_choice_selfsigned)"
    echoColor yellow "$(i18n cert_choice_dns)"
    echoColor green "$(i18n prompt_enter_number_or_default)"
    read -r certNum
    useAcme=false
    useLocalCert=false

    if [ -z "${certNum}" ] || [ "${certNum}" == "3" ]; then
        echoColor green "$(i18n selfsigned_domain_prompt)"
        read -r domain
        if [ -z "${domain}" ]; then
            domain="helloworld.com"
        fi
        echo -e "->$(i18n selfsigned_domain_label)$(echoColor red "${domain}")\n"
        if [ "${realmMode}" == "true" ]; then
            ip=""
            echo -e "\n->$(i18n realm_uri_label_with_cert)$(echoColor red "${realmURI}")\n"
        else
            ip=$(detectPublicIP || true)
            echoColor green "$(i18n public_ip_check)$(echoColor red "${ip}")\n"
            while true; do
                echoColor green "$(i18n prompt_choose)"
                echoColor yellow "$(i18n ip_correct_default)"
                echoColor yellow "$(i18n ip_incorrect)"
                echoColor green "$(i18n prompt_enter_number)"
                read -r ipNum
                if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                    break
                elif [ "${ipNum}" == "2" ]; then
                    echoColor green "$(i18n ip_prompt)"
                    read -r ip
                    if [ -z "${ip}" ]; then
                        echoColor red "$(i18n input_error_retry)"
                        continue
                    fi
                    break
                else
                    echoColor red "$(i18n input_error_please_retry)"
                fi
            done
        fi
        useAcme=false
        if [ "${realmMode}" == "true" ]; then
            echoColor purple "\n\n->$(i18n selfsigned_cert_summary_realm ${domain})$(echoColor red "${realmURI}")\n"
        else
            echoColor purple "\n\n->$(i18n selfsigned_cert_summary_ip ${domain})$(echoColor red "${ip}")\n"
        fi
        echo -e "\n"

    elif [ "${certNum}" == "2" ]; then
        echoColor green "$(i18n local_cert_path_prompt)"
        read -r local_cert
        while :; do
            if [ ! -f "${local_cert}" ]; then
                echoColor red "\n\n->$(i18n path_not_exist)"
                echoColor green "$(i18n local_cert_path_prompt)"
                read -r local_cert
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n local_cert_label)$(echoColor red "${local_cert}")\n"
        echoColor green "$(i18n local_key_path_prompt)"
        read -r local_key
        while :; do
            if [ ! -f "${local_key}" ]; then
                echoColor red "\n\n->$(i18n path_not_exist)"
                echoColor green "$(i18n local_key_path_prompt)"
                read -r local_key
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n local_key_label)$(echoColor red "${local_key}")\n"
        echoColor green "$(i18n local_cert_domain_prompt)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n local_cert_domain_prompt)"
                read -r domain
            else
                break
            fi
        done
        useAcme=false
        useLocalCert=true
        echoColor purple "\n\n->$(i18n local_cert_summary)$(echoColor red "${domain}")\n"
    elif [ "${certNum}" == "4" ]; then
        echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n domain_label)$(echoColor red "${domain}")\n"
        echoColor green "$(i18n dns_provider_prompt)"
        echoColor yellow "$(i18n dns_choice_cloudflare)"
        echoColor yellow "$(i18n dns_choice_duckdns)"
        echoColor yellow "$(i18n dns_choice_gandi)"
        echoColor yellow "$(i18n dns_choice_godaddy)"
        echoColor yellow "$(i18n dns_choice_namecom)"
        echoColor yellow "$(i18n dns_choice_vultr)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r dnsNum
        if [ -z "${dnsNum}" ] || [ "${dnsNum}" == "1" ]; then
            dns="cloudflare"
            echo -e "\n\n->$(i18n dns_selected_cloudflare)\n"
            echoColor green "$(i18n cloudflare_token_prompt)"
            while :; do
                read -r cloudflare_api_token
                if [ -z "${cloudflare_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n cloudflare_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "2" ]; then
            dns="duckdns"
            echo -e "\n\n->$(i18n dns_selected_duckdns)\n"
            echoColor green "$(i18n duckdns_token_prompt)"
            while :; do
                read -r duckdns_api_token
                if [ -z "${duckdns_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n duckdns_token_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n duckdns_override_prompt)"
            while :; do
                read -r duckdns_override_domain
                if [ -z "${duckdns_override_domain}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n duckdns_override_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "3" ]; then
            dns="gandi"
            echo -e "\n\n->$(i18n dns_selected_gandi)\n"
            echoColor green "$(i18n gandi_token_prompt)"
            while :; do
                read -r gandi_api_token
                if [ -z "${gandi_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n gandi_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "4" ]; then
            dns="godaddy"
            echo -e "\n\n->$(i18n dns_selected_godaddy)\n"
            echoColor green "$(i18n godaddy_token_prompt)"
            while :; do
                read -r godaddy_api_token
                if [ -z "${godaddy_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n godaddy_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "5" ]; then
            dns="namedotcom"
            echo -e "\n\n->$(i18n dns_selected_namecom)\n"
            echoColor green "$(i18n namecom_token_prompt)"
            while :; do
                read -r namedotcom_api_token
                if [ -z "${namedotcom_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_token_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n namecom_user_prompt)"
            while :; do
                read -r namedotcom_user
                if [ -z "${namedotcom_user}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_user_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n namecom_server_prompt)"
            while :; do
                read -r namedotcom_server
                if [ -z "${namedotcom_server}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_server_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "6" ]; then
            dns="vultr"
            echo -e "\n\n->$(i18n dns_selected_vultr)\n"
            echoColor green "$(i18n vultr_token_prompt)"
            while :; do
                read -r vultr_api_token
                if [ -z "${vultr_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n vultr_token_prompt)"
                else
                    break
                fi
            done
        else
            echoColor red "$(i18n input_error_please_retry)"
        fi
        ip=$(detectPublicIP || true)
        echoColor green "$(i18n public_ip_check)$(echoColor red "${ip}")\n"
        while true; do
            echoColor green "$(i18n prompt_choose)"
            echoColor yellow "$(i18n ip_correct_default)"
            echoColor yellow "$(i18n ip_incorrect)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r ipNum
            if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                break
            elif [ "${ipNum}" == "2" ]; then
                echoColor green "$(i18n ip_prompt)"
                read -r ip
                if [ -z "${ip}" ]; then
                    echoColor red "$(i18n input_error_retry)"
                    continue
                fi
                break
            else
                echoColor red "$(i18n input_error_please_retry)"
            fi
        done
        echo -e "\n\n->$(i18n dns_acme_summary)$(echoColor red "${domain}")\n"
        echo -e "\n ->$(i18n dns_method_label)$(echoColor red "${dns}")\n"
        echo -e "\n ->$(i18n public_ip_label)$(echoColor red "${ip}")\n"
        useAcme=true
        useDns=true
    else
        echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
            else
                break
            fi
        done
        while :; do
            echoColor purple "\n->$(i18n detecting_domain_dns ${domain})"
            ip_resolv=$(dig +short ${domain} A)
            if [ -z "${ip_resolv}" ]; then
                ip_resolv=$(dig +short ${domain} AAAA)
            fi
            if [ -z "${ip_resolv}" ]; then
                echoColor red "\n\n->$(i18n dns_resolution_failed)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
                continue
            fi
            remoteip=$(echo ${ip_resolv} | awk -F " " '{print $1}')
            v6str=":"
            result=$(echo ${remoteip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                localip=$(getPublicIP -6 || true)
            else
                localip=$(getPublicIP -4 || true)
            fi
            if [ -z "${localip}" ]; then
                localip=$(getPublicIP "" || true)
                if [ -z "${localip}" ]; then
                    echoColor red "\n\n->$(i18n local_ip_fetch_failed)"
                    exit 1
                fi
            fi
            if [ "${localip}" != "${remoteip}" ]; then
                echo -e " \n\n->$(i18n local_ip_label)$(echoColor red "${localip}") \n\n->$(i18n domain_ip_label)$(echoColor red "${remoteip}")\n"
                echoColor green "$(i18n self_assign_ip_prompt)"
                read -r isLocalip
                if [ "${isLocalip}" == "y" ]; then
                    echoColor green "$(i18n enter_local_ip)"
                    read -r localip
                    while :; do
                        if [ -z "${localip}" ]; then
                            echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                            echoColor green "$(i18n enter_local_ip)"
                            read -r localip
                        else
                            break
                        fi
                    done
                fi
                if [ "${localip}" != "${remoteip}" ]; then
                    echoColor red "\n\n->$(i18n domain_ip_mismatch)"
                    echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                    read -r domain
                    continue
                else
                    break
                fi
            else
                break
            fi
        done
        useAcme=true
        useDns=false
        echoColor purple "\n\n->$(i18n acme_summary)$(echoColor red "${domain}")\n"
    fi

    if [ "${realmMode}" == "true" ]; then
        port=""
        echoColor purple "\n->$(i18n realm_skip_port)\n"
    else
        while :; do
            echoColor green "\n$(i18n port_prompt)"
            echo "$(i18n port_hint)"
            read -r port
            if [ -z "${port}" ]; then
                port=$(getRandomFreeUdpPort)
                if [ -z "${port}" ]; then
                    echoColor red "$(i18n auto_port_busy)"
                    continue
                fi
                echo -e "\n->$(i18n random_port_label)$(echoColor red "udp/${port}")\n"
                break
            fi
            if ! isValidPort "${port}"; then
                echoColor red "$(i18n port_invalid_error)"
                continue
            fi
            echo -e "\n->$(i18n entered_port_label)$(echoColor red "udp/${port}")\n"
            pIDa=$(getUdpPortPid "${port}")
            if [ "$pIDa" != "" ]; then
                echoColor red "\n->$(i18n port_in_use ${port} ${pIDa} ${pIDa})"
            else
                break
            fi
        done
    fi

    if [ "${realmMode}" != "true" ]; then
        echoColor green "\n$(i18n port_hopping_prompt)"
        echoColor white "$(i18n port_hopping_intro)"
        echoColor white "$(i18n port_hopping_detail_url)"
        echoColor green "$(i18n prompt_choose)"
        echoColor yellow "$(i18n port_hopping_choice_enable)"
        echoColor yellow "$(i18n port_hopping_choice_skip)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r portHoppingStatus
        if [ -z "${portHoppingStatus}" ] || [ "${portHoppingStatus}" == "1" ]; then
            portHoppingStatus="true"
            echoColor purple "$(i18n port_hopping_enabled)"
            echoColor white "$(i18n port_hopping_range_hint)"
            while :; do
                echoColor green "$(i18n port_hopping_start)"
                read -r portHoppingStart
                if [ -z "${portHoppingStart}" ]; then
                    portHoppingStart=47000
                fi
                if ! isValidPort "${portHoppingStart}"; then
                    echoColor red "$(i18n port_invalid_error)"
                    continue
                fi
                echo -e "\n->$(i18n start_port_label)$(echoColor red "${portHoppingStart}")\n"
                echoColor green "$(i18n port_hopping_end)"
                read -r portHoppingEnd
                if [ -z "${portHoppingEnd}" ]; then
                    portHoppingEnd=48000
                fi
                if ! isValidPort "${portHoppingEnd}"; then
                    echoColor red "$(i18n port_invalid_error)"
                    continue
                fi
                echo -e "\n->$(i18n end_port_label)$(echoColor red "${portHoppingEnd}")\n"
                if [ ${portHoppingStart} -ge ${portHoppingEnd} ]; then
                    echoColor red "$(i18n start_port_greater_error)"
                else
                    break
                fi
            done
            echoColor green "$(i18n port_hopping_mode_prompt)"
            echoColor yellow "$(i18n port_hopping_mode_fixed)"
            echoColor yellow "$(i18n port_hopping_mode_random)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r portHoppingIntervalModeNum
            if [ -z "${portHoppingIntervalModeNum}" ] || [ "${portHoppingIntervalModeNum}" == "1" ]; then
                portHoppingIntervalMode="fixed"
                while :; do
                    echoColor green "$(i18n fixed_hop_interval_prompt)"
                    read -r portHoppingHopInterval
                    if [ -z "${portHoppingHopInterval}" ]; then
                        portHoppingHopInterval="30s"
                    fi
                    echo -e "\n->$(i18n fixed_hop_interval_label)$(echoColor red "${portHoppingHopInterval}")\n"
                    hopSeconds=$(echo "${portHoppingHopInterval}" | sed 's/s$//')
                    if ! isPositiveInt "${hopSeconds}" || [ "${hopSeconds}" -lt 5 ]; then
                        echoColor red "$(i18n fixed_hop_interval_error)"
                        continue
                    fi
                    portHoppingHopInterval="${hopSeconds}s"
                    break
                done
                portHoppingMinHopInterval=""
                portHoppingMaxHopInterval=""
            else
                portHoppingIntervalMode="random"
                portHoppingHopInterval=""
                while :; do
                    echoColor green "$(i18n min_hop_interval_prompt)"
                    read -r portHoppingMinHopInterval
                    if [ -z "${portHoppingMinHopInterval}" ]; then
                        portHoppingMinHopInterval="10s"
                    fi
                    echo -e "\n->$(i18n min_hop_interval_label)$(echoColor red "${portHoppingMinHopInterval}")\n"
                    minHopSeconds=$(echo "${portHoppingMinHopInterval}" | sed 's/s$//')
                    if ! isPositiveInt "${minHopSeconds}" || [ "${minHopSeconds}" -lt 5 ]; then
                        echoColor red "$(i18n min_hop_interval_error)"
                        continue
                    fi
                    portHoppingMinHopInterval="${minHopSeconds}s"
                    echoColor green "$(i18n max_hop_interval_prompt)"
                    read -r portHoppingMaxHopInterval
                    if [ -z "${portHoppingMaxHopInterval}" ]; then
                        portHoppingMaxHopInterval="30s"
                    fi
                    echo -e "\n->$(i18n max_hop_interval_label)$(echoColor red "${portHoppingMaxHopInterval}")\n"
                    maxHopSeconds=$(echo "${portHoppingMaxHopInterval}" | sed 's/s$//')
                    if ! isPositiveInt "${maxHopSeconds}" || [ "${maxHopSeconds}" -lt "${minHopSeconds}" ]; then
                        echoColor red "$(i18n max_hop_interval_error)"
                        continue
                    fi
                    portHoppingMaxHopInterval="${maxHopSeconds}s"
                    break
                done
            fi
            echo -e "\n->$(i18n port_hopping_range_label)$(echoColor red "${portHoppingStart}-${portHoppingEnd}")\n"
            if [ "${portHoppingIntervalMode}" == "fixed" ]; then
                echo -e "\n->$(i18n fixed_hop_interval_summary)$(echoColor red "${portHoppingHopInterval}")\n"
            else
                echo -e "\n->$(i18n random_hop_interval_summary)$(echoColor red "${portHoppingMinHopInterval}~${portHoppingMaxHopInterval}")\n"
            fi
        else
            portHoppingStatus="false"
            portHoppingIntervalMode=""
            portHoppingHopInterval=""
            portHoppingMinHopInterval=""
            portHoppingMaxHopInterval=""
            echoColor red "$(i18n port_hopping_disabled)"
        fi
    else
        portHoppingStatus="false"
        echoColor purple "\n->$(i18n realm_skip_port_hopping)\n"
    fi

    echoColor green "$(i18n congestion_title)"
    echoColor white "$(i18n congestion_reno_hint)"
    echoColor white "$(i18n congestion_bbr_hint)"
    echoColor white "$(i18n congestion_brutal_hint)"
    echoColor green "$(i18n prompt_choose)"
    echoColor yellow "$(i18n congestion_choice_reno)"
    echoColor yellow "$(i18n congestion_choice_bbr)"
    echoColor yellow "$(i18n congestion_choice_brutal)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r congestion_num
    if [ "${congestion_num}" == "1" ]; then
        congestion_mode="reno"
        congestion_type="reno"
        congestion_bbr_profile=""
        ignore_client_bandwidth="true"
        echo -e "\n->$(i18n congestion_selected_reno)\n"
    elif [ "${congestion_num}" == "2" ]; then
        congestion_mode="bbr"
        congestion_type="bbr"
        ignore_client_bandwidth="true"
        echoColor green "$(i18n bbr_profile_title)"
        echoColor white "$(i18n bbr_profile_conservative)"
        echoColor white "$(i18n bbr_profile_standard)"
        echoColor white "$(i18n bbr_profile_aggressive)"
        echoColor green "$(i18n bbr_profile_prompt)"
        echoColor yellow "$(i18n bbr_choice_conservative)"
        echoColor yellow "$(i18n bbr_choice_standard)"
        echoColor yellow "$(i18n bbr_choice_aggressive)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r bbr_profile_num
        case ${bbr_profile_num} in
            2) congestion_bbr_profile="conservative" ;;
            3) congestion_bbr_profile="aggressive" ;;
            *) congestion_bbr_profile="standard" ;;
        esac
        echo -e "\n->$(i18n congestion_selected_bbr)$(echoColor red "${congestion_bbr_profile}")\n"
    else
        congestion_mode="brutal"
        congestion_type=""
        congestion_bbr_profile=""
        ignore_client_bandwidth="false"
        echo -e "\n->$(i18n congestion_selected_brutal)\n"
    fi

    if [ "${congestion_mode}" == "brutal" ]; then
        while :; do
            echoColor green "$(i18n delay_prompt)"
            read -r delay
            if [ -z "${delay}" ]; then
                delay=200
            fi
            if ! isPositiveInt "${delay}" || [ "${delay}" -eq 0 ]; then
                echoColor red "$(i18n bandwidth_invalid_error)"
                continue
            fi
            break
        done
        echo -e "\n->$(i18n delay_label)$(echoColor red "${delay}")ms\n"
        echo -e "\n$(i18n bandwidth_expectation)$(echoColor red "Tips:")"
        while :; do
            echoColor green "$(i18n download_prompt)"
            read -r download
            if [ -z "${download}" ]; then
                download=50
            fi
            if ! isPositiveInt "${download}" || [ "${download}" -eq 0 ]; then
                echoColor red "$(i18n bandwidth_invalid_error)"
                continue
            fi
            break
        done
        echo -e "\n->$(i18n download_label)$(echoColor red "${download}")mbps\n"
        while :; do
            echoColor green "$(i18n upload_prompt)"
            read -r upload
            if [ -z "${upload}" ]; then
                upload=10
            fi
            if ! isPositiveInt "${upload}" || [ "${upload}" -eq 0 ]; then
                echoColor red "$(i18n bandwidth_invalid_error)"
                continue
            fi
            break
        done
        echo -e "\n->$(i18n upload_label)$(echoColor red "${upload}")mbps\n"
    else
        delay=""
        download=""
        upload=""
        echoColor lightYellow "$(i18n non_brutal_skip)"
    fi
    echoColor green "$(i18n auth_secret_prompt)"
    read -r auth_secret
    if [ -z "${auth_secret}" ]; then
        auth_secret=$(generate_uuid)
    fi
    echo -e "\n->$(i18n auth_secret_label)$(echoColor red "${auth_secret}")\n"
    echoColor white "$(i18n obfs_hint)"
    echoColor green "$(i18n obfs_prompt)"
    echoColor yellow "$(i18n obfs_choice_disable)"
    echoColor yellow "$(i18n obfs_choice_salamander)"
    echoColor yellow "$(i18n obfs_choice_gecko)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r obfs_num
    if [ -z "${obfs_num}" ] || [ "${obfs_num}" == "1" ]; then
        obfs_status="false"
        obfs_type=""
    elif [ "${obfs_num}" == "2" ]; then
        obfs_status="true"
        obfs_type="salamander"
        obfs_pass=${auth_secret}
    else
        obfs_status="true"
        obfs_type="gecko"
        obfs_pass=${auth_secret}
    fi
    if [ "${obfs_status}" == "true" ]; then
        echo -e "\n->$(i18n obfs_enabled ${obfs_type})\n"
    else
        echo -e "\n->$(i18n obfs_disabled)\n"
    fi
    if [ "${realmMode}" != "true" ]; then
        echoColor green "$(i18n masquerade_prompt)"
        echoColor yellow "$(i18n masquerade_choice_disable)"
        echoColor yellow "$(i18n masquerade_choice_string)"
        echoColor yellow "$(i18n masquerade_choice_proxy)"
        echoColor yellow "$(i18n masquerade_choice_file)"
        echoColor green "$(i18n prompt_enter_number_or_default)"
        read -r masquerade_choice
        case "${masquerade_choice}" in
            2)
                masquerade_status="true"
                masquerade_type="string"
                echoColor green "$(i18n masquerade_string_prompt)"
                read -r masquerade_string
                if [ -z "${masquerade_string}" ]; then
                    masquerade_string="HelloWorld"
                fi
                echo -e "\n->$(i18n masquerade_string_label)$(echoColor red "${masquerade_string}")\n"
                echoColor green "$(i18n masquerade_stuff_prompt)"
                read -r masquerade_stuff
                if [ -z "${masquerade_stuff}" ]; then
                    masquerade_stuff="HelloWorld"
                fi
                echo -e "\n->$(i18n masquerade_stuff_label)$(echoColor red "${masquerade_stuff}")\n"
                ;;
            3)
                masquerade_status="true"
                masquerade_type="proxy"
                echoColor green "$(i18n masquerade_proxy_prompt)"
                echoColor white "$(i18n masquerade_proxy_hint)"
                read -r masquerade_proxy
                if [ -z "${masquerade_proxy}" ]; then
                    masquerade_proxy="https://www.helloworld.org"
                fi
                echo -e "\n->$(i18n masquerade_proxy_label)$(echoColor red "${masquerade_proxy}")\n"
                echoColor green "$(i18n xforwarded_prompt)"
                echoColor yellow "$(i18n xforwarded_choice_enable)"
                echoColor yellow "$(i18n xforwarded_choice_disable)"
                echoColor green "$(i18n prompt_enter_number)"
                read -r masquerade_xforwarded
                if [ -z "${masquerade_xforwarded}" ] || [ "${masquerade_xforwarded}" == "1" ]; then
                    masquerade_xforwarded="true"
                else
                    masquerade_xforwarded="false"
                fi
                echo -e "\n->$(i18n xforwarded_label)$(echoColor red "${masquerade_xforwarded}")\n"
                ;;
            4)
                masquerade_status="true"
                masquerade_type="file"
                echoColor green "$(i18n masquerade_file_prompt)"
                echoColor white "$(i18n masquerade_file_hint)"
                read -r masquerade_file
                if [ -z "${masquerade_file}" ]; then
                    masquerade_file="/etc/hihy/file"
                fi
                echo -e "\n->$(i18n masquerade_file_label)$(echoColor red "${masquerade_file}")\n"
                ;;
            *)
                masquerade_status="false"
                masquerade_type=""
                echo -e "\n->$(i18n masquerade_disabled_selected)\n"
                ;;
        esac
        if [ "${masquerade_type}" != "proxy" ]; then
            masquerade_xforwarded="false"
        fi
        if [ "${masquerade_status}" == "true" ]; then
            echoColor green "$(i18n masquerade_tcp_prompt ${port})"
            echoColor lightYellow "$(i18n masquerade_tcp_hint1)"
            echoColor white "$(i18n masquerade_tcp_hint2)"
            echoColor green "$(i18n prompt_choose)"
            echoColor yellow "$(i18n masquerade_tcp_choice_enable)"
            echoColor yellow "$(i18n masquerade_tcp_choice_skip)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r masquerade_tcp
            if [ -z "${masquerade_tcp}" ] || [ "${masquerade_tcp}" == "1" ]; then
                masquerade_tcp="true"
                echo -e "\n->$(i18n masquerade_tcp_enabled ${port})\n"
            else
                masquerade_tcp="false"
                echo -e "\n->$(i18n masquerade_tcp_disabled ${port})\n"
            fi
        else
            masquerade_tcp="false"
        fi
    fi
    echoColor green "$(i18n block_http3_prompt)"
    echoColor lightYellow "$(i18n block_http3_hint1)"
    echoColor white "$(i18n block_http3_hint2)"
    echoColor green "$(i18n prompt_choose)"
    echoColor yellow "$(i18n block_http3_choice_enable)"
    echoColor yellow "$(i18n block_http3_choice_skip)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r block_http3
    if [ -z "${block_http3}" ] || [ "${block_http3}" == "2" ]; then
        block_http3="false"
        echo -e "\n->$(i18n block_http3_disabled)\n"
        echoColor lightYellow "$(i18n client_only_block_http3_tip)"
    else
        block_http3="true"
        echoColor red "$(i18n block_http3_enabled)"
    fi
    echoColor green "$(i18n remarks_prompt)"
    read -r remarks
    echoColor green "$(i18n config_input_done)"
}

# ---------- 一键模式:环境变量覆盖默认值 ----------
applyAutoOverrides() {
    if [ -n "${HIHY_AUTO_PORT:-}" ]; then
        if ! isValidPort "${HIHY_AUTO_PORT}"; then
            echoColor red "$(i18n auto_port_invalid "${HIHY_AUTO_PORT}")"
            return 1
        fi
        port="${HIHY_AUTO_PORT}"
    fi
    [ -n "${HIHY_AUTO_PASSWORD:-}" ] && auth_secret="${HIHY_AUTO_PASSWORD}"
    [ -n "${HIHY_AUTO_DOMAIN:-}" ] && domain="${HIHY_AUTO_DOMAIN}"
    [ -n "${HIHY_AUTO_IP:-}" ] && ip="${HIHY_AUTO_IP}"
    [ -n "${HIHY_AUTO_REMARKS:-}" ] && remarks="${HIHY_AUTO_REMARKS}"
    if [ -n "${HIHY_AUTO_MASQUERADE:-}" ]; then
        masquerade_status="true"
        masquerade_type="proxy"
        masquerade_proxy="${HIHY_AUTO_MASQUERADE}"
        masquerade_xforwarded="true"
    fi
    if [ "${HIHY_AUTO_PORT_HOPPING:-}" = "true" ] || [ "${HIHY_AUTO_PORT_HOPPING:-}" = "1" ]; then
        portHoppingStatus="true"
        portHoppingStart="${HIHY_AUTO_HOP_START:-47000}"
        portHoppingEnd="${HIHY_AUTO_HOP_END:-48000}"
        portHoppingIntervalMode="fixed"
        portHoppingHopInterval="30s"
        if ! isValidPort "${portHoppingStart}" || ! isValidPort "${portHoppingEnd}" \
            || [ "${portHoppingStart}" -ge "${portHoppingEnd}" ]; then
            echoColor red "$(i18n auto_hop_invalid "${portHoppingStart}" "${portHoppingEnd}")"
            return 1
        fi
    fi
    return 0
}

# ---------- 一键模式:零交互收集(默认值 + 环境变量 + 自动探测) ----------
autoHysteriaConfig() {
    setConfigDefaults
    echoColor yellowBlack "$(i18n auto_install_title)"
    echoColor gray "$(i18n auto_env_hint)"
    if ! applyAutoOverrides; then
        exit 1
    fi

    if [ -z "${ip}" ]; then
        ip=$(detectPublicIP || true)
        if [ -z "${ip}" ]; then
            echoColor red "$(i18n auto_ip_detect_failed)"
            exit 1
        fi
    fi

    if [ -z "${port}" ]; then
        port=$(getRandomFreeUdpPort)
        if [ -z "${port}" ]; then
            echoColor red "$(i18n auto_port_busy "random")"
            exit 1
        fi
    elif ! isUdpPortFree "${port}"; then
        echoColor red "$(i18n auto_port_busy "${port}")"
        exit 1
    fi

    [ -z "${auth_secret}" ] && auth_secret=$(generate_uuid)
    [ -z "${remarks}" ] && remarks="auto-${port}"

    echo -e ""
    echoColor purple "$(i18n auto_summary_title)"
    echo -e "  $(i18n auto_summary_port "$(echoColor red "udp/${port}")")"
    echo -e "  $(i18n auto_summary_password "$(echoColor red "${auth_secret}")")"
    echo -e "  $(i18n auto_summary_sni "$(echoColor red "${domain}")")"
    echo -e "  $(i18n auto_summary_cert)"
    echo -e "  $(i18n auto_summary_congestion)"
    if [ "${masquerade_status}" == "true" ]; then
        echo -e "  $(i18n auto_summary_masquerade_on "$(echoColor red "${masquerade_proxy}")")"
    else
        echo -e "  $(i18n auto_summary_masquerade_off)"
    fi
    if [ "${portHoppingStatus}" == "true" ]; then
        echo -e "  $(i18n auto_summary_hopping_on "$(echoColor red "${portHoppingStart}-${portHoppingEnd}")")"
    else
        echo -e "  $(i18n auto_summary_hopping_off)"
    fi
    echo -e ""

    writeHysteriaConfig
}

# ---------- 配置校验:轮询 debug 文件,返回 0=成功 1=超时 2=ACME失败 3=端口占用 ----------
waitForValidationOutcome() {
    local debug_file="$1"
    local timeout="$2"
    local elapsed=0
    local marker

    while [ "$elapsed" -lt "$timeout" ]; do
        marker=$(grep -m1 -oE "server up and running|failed to get a certificate with ACME|bind: address already in use" "$debug_file" 2>/dev/null)
        case "$marker" in
            "server up and running") return 0 ;;
            "failed to get a certificate with ACME") return 2 ;;
            "bind: address already in use") return 3 ;;
        esac
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

stopValidationProcess() {
    if ! command -v pkill >/dev/null 2>&1 && command -v apk >/dev/null 2>&1; then
        apk add --no-cache procps >/dev/null 2>&1
    fi
    killHysteriaProcess TERM
}

# 校验失败的统一善后:杀掉测试进程 -> 撤销防火墙 -> 清理本次生成的配置
cleanupFailedValidation() {
    local phase="$1"
    local details="$2"

    markInstallFailed "$phase" "$details"
    stopValidationProcess
    delHihyFirewallPort udp >/dev/null 2>&1 || true
    delHihyFirewallPort tcp >/dev/null 2>&1 || true
    rm -f /etc/hihy/conf/config.yaml /etc/hihy/conf/backup.yaml
    rm -f ./hihy_debug.info
}

# ---------- 配置写入 + 校验 + 收尾(原 setHysteriaConfig 后半段,向导/一键共用) ----------
writeHysteriaConfig() {
    mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert /etc/hihy/result /etc/hihy/acl/
    acl_file="/etc/hihy/acl/acl.txt"
    rm -f "${acl_file}"
    touch "${acl_file}"
    yaml_file="/etc/hihy/conf/config.yaml"
    rm -f "${yaml_file}"
    touch "${yaml_file}"

    echoColor yellowBlack "$(i18n config_executing)"
    max_CRW=0
    if [ "${congestion_mode}" == "brutal" ]; then
        download=$(($download + $download / 10))
        upload=$(($upload + $upload / 10))
        CRW=$(($delay * $download * 1000000 / 1000 * 2))
        SRW=$(($CRW / 5 * 2))
        max_CRW=$(($CRW * 3 / 2))
        max_SRW=$(($SRW * 3 / 2))
        server_upload=${download}
        server_download=${upload}
    fi

    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" "${realmURI}"
    elif [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" ":${port},${portHoppingStart}-${portHoppingEnd}"
    else
        addOrUpdateYaml "$yaml_file" "listen" ":${port}"
    fi
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "realm.stunServers[0]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunServers[1]" "global.stun.twilio.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.punchTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.heartbeatInterval" "30s"
        addOrUpdateYaml "$yaml_file" "realm.insecure" "false"
        addOrUpdateYaml "$yaml_file" "realm.ipMode" "dual"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.enabled" "true"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.timeout" "30s"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.lifetime" "10m"
    fi
    addOrUpdateYaml "$yaml_file" "auth.type" "password"
    addOrUpdateYaml "$yaml_file" "auth.password" "${auth_secret}"
    addOrUpdateYaml "$yaml_file" "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_mode}" != "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.type" "${congestion_type}"
    fi
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.bbrProfile" "${congestion_bbr_profile}"
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "obfs.type" "${obfs_type}"
        addOrUpdateYaml "$yaml_file" "obfs.${obfs_type}.password" "${obfs_pass}"
    fi
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "quic.initStreamReceiveWindow" "${SRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxStreamReceiveWindow" "${max_SRW}"
        addOrUpdateYaml "$yaml_file" "quic.initConnReceiveWindow" "${CRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxConnReceiveWindow" "${max_CRW}"
    fi
    addOrUpdateYaml "$yaml_file" "quic.maxIdleTimeout" "30s"
    addOrUpdateYaml "$yaml_file" "quic.maxIncomingStreams" "1024"
    addOrUpdateYaml "$yaml_file" "quic.disablePathMTUDiscovery" "false"
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "bandwidth.up" "${server_upload}mbps"
        addOrUpdateYaml "$yaml_file" "bandwidth.down" "${server_download}mbps"
    fi
    addOrUpdateYaml "$yaml_file" "acl.file" "${acl_file}"
    if [ "${masquerade_status}" == "true" ]; then
        case ${masquerade_type} in
            "string")
                addOrUpdateYaml "$yaml_file" "masquerade.type" "string"
                addOrUpdateYaml "$yaml_file" "masquerade.string.content" "${masquerade_string}"
                addOrUpdateYaml "$yaml_file" "masquerade.string.headers.content-type" "text/plain"
                addOrUpdateYaml "$yaml_file" "masquerade.string.headers.custom-stuff" "${masquerade_stuff}"
                addOrUpdateYaml "$yaml_file" "masquerade.string.statusCode" "200"
                ;;
            "proxy")
                addOrUpdateYaml "$yaml_file" "masquerade.type" "proxy"
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.url" "${masquerade_proxy}"
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.rewriteHost" "true"
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.insecure" "true"
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.xForwarded" "${masquerade_xforwarded}"
                ;;
            "file")
                addOrUpdateYaml "$yaml_file" "masquerade.type" "file"
                addOrUpdateYaml "$yaml_file" "masquerade.file.dir" "${masquerade_file}"
                if [ ! -d "${masquerade_file}" ]; then
                    mkdir -p "${masquerade_file}"
                    wget -q -O ./mikutap.tar.gz https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
                    tar -xzf ./mikutap.tar.gz -C "${masquerade_file}" --strip-components=1
                    rm -r ./mikutap.tar.gz
                fi
                ;;
        esac
        if [ "${realmMode}" != "true" ] && [ "${masquerade_tcp}" == "true" ]; then
            addOrUpdateYaml "$yaml_file" "masquerade.listenHTTPS" ":${port}"
        fi
    fi
    addOrUpdateYaml "$yaml_file" "speedTest" "true"
    pinSHA256=""
    if echo "${useAcme}" | grep -q "false"; then
        if echo "${useLocalCert}" | grep -q "false"; then
            v6str=":"
            result=$(echo ${ip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                ip="[${ip}]"
            fi
            u_host=${ip}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${ip}"
            fi
            insecure="0"
            days=3650
            mail="no-reply@qq.com"
            echoColor purple "$(i18n cert_generating_start)"
            echoColor green "$(i18n cert_ca_key)"
            openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048
            echoColor green "$(i18n cert_ca_cert)"
            openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt
            echoColor green "$(i18n cert_server_key_csr)"
            openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=${domain}" -out /etc/hihy/cert/${domain}.csr
            echoColor green "$(i18n cert_sign_server)"
            openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt
            echoColor green "$(i18n cert_cleanup)"
            rm -f /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr
            echoColor green "$(i18n cert_move_ca)"
            mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result
            echoColor purple "$(i18n cert_success)"
            pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in /etc/hihy/cert/${domain}.crt 2>/dev/null | sed 's/^.*=//')
            if [ -n "${pinSHA256}" ]; then
                echoColor green "$(i18n cert_sha256_label)$(echoColor red "${pinSHA256}")"
                echoColor purple "$(i18n cert_pinsha256_hint)"
            else
                echoColor yellow "$(i18n cert_fingerprint_fail)"
                insecure="1"
            fi
            addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt"
            addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key"
            if [ "${realmMode}" == "true" ]; then
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "disable"
            else
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
            fi
        else
            u_host=${domain}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${domain}"
            fi
            insecure="0"
            addOrUpdateYaml "$yaml_file" "tls.cert" "${local_cert}"
            addOrUpdateYaml "$yaml_file" "tls.key" "${local_key}"
            if [ "${realmMode}" == "true" ]; then
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "disable"
            else
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
            fi
        fi
    else
        u_host=${domain}
        u_domain=${domain}
        insecure="0"
        if [ -z "${remarks}" ]; then
            remarks="${domain}"
        fi
        addOrUpdateYaml "$yaml_file" "acme.domains" "${domain}"
        addOrUpdateYaml "$yaml_file" "acme.email" "pekora@${domain}"
        addOrUpdateYaml "$yaml_file" "acme.ca" "letsencrypt"
        addOrUpdateYaml "$yaml_file" "acme.dir" "/etc/hihy/cert"
        if [ "${useDns}" == "true" ]; then
            u_host=${ip}
            addOrUpdateYaml "$yaml_file" "acme.type" "dns"
            case ${dns} in
                "cloudflare")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "cloudflare"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.cloudflare_api_token" "${cloudflare_api_token}"
                    ;;
                "duckdns")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "duckdns"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_api_token" "${duckdns_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_override_domain" "${duckdns_override_domain}"
                    ;;
                "gandi")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "gandi"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.gandi_api_token" "${gandi_api_token}"
                    ;;
                "godaddy")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "godaddy"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.godaddy_api_token" "${godaddy_api_token}"
                    ;;
                "namedotcom")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "namedotcom"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_api_token" "${namedotcom_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_user" "${namedotcom_user}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_server" "${namedotcom_server}"
                    ;;
                "vultr")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "vultr"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.vultr_api_token" "${vultr_api_token}"
                    ;;
            esac
        else
            getPortBindMsg TCP 80
            allowPort tcp 80
            addOrUpdateYaml "$yaml_file" "acme.type" "http"
            addOrUpdateYaml "$yaml_file" "acme.listenHost" "0.0.0.0"
        fi
    fi
    if [ "${realmMode}" == "true" ]; then
        u_host="${realmURI}"
    fi

    addOrUpdateYaml "$yaml_file" "sniff.enabled" "true"
    addOrUpdateYaml "$yaml_file" "sniff.timeout" "2s"
    addOrUpdateYaml "$yaml_file" "sniff.rewriteDomain" "false"
    addOrUpdateYaml "$yaml_file" "sniff.tcpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "sniff.udpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "outbounds[0].name" "hihy" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.mode" "auto" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[1].name" "v4_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.mode" "4" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[2].name" "v6_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.mode" "6" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.fastOpen" "false" "bool"
    trafficPort=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
    if [ "$trafficPort" == "${port}" ]; then
        trafficPort=$((${port} + 1))
    fi
    addOrUpdateYaml "$yaml_file" "trafficStats.listen" "127.0.0.1:${trafficPort}"
    addOrUpdateYaml "$yaml_file" "trafficStats.secret" "${auth_secret}"
    if [ "${block_http3}" == "true" ]; then
        echo -e "reject(all, udp/443)" >${acl_file}
    fi
    if [ ${max_CRW} -gt 0 ]; then
        if sysctl -w net.core.rmem_max=${max_CRW} >/dev/null 2>&1 \
            && sysctl -w net.core.wmem_max=${max_CRW} >/dev/null 2>&1; then
            # 持久化,重启后依然生效(容器环境可能只读,失败仅提示)
            if mkdir -p /etc/sysctl.d 2>/dev/null; then
                printf 'net.core.rmem_max=%s\nnet.core.wmem_max=%s\n' "${max_CRW}" "${max_CRW}" \
                    >/etc/sysctl.d/99-hihy.conf 2>/dev/null || true
            fi
        else
            echoColor yellow "$(i18n sysctl_apply_failed)"
        fi
    fi
    local validation_timeout=15
    if [ "${useAcme}" == "true" ]; then
        validation_timeout=60
    fi
    echoColor purple "\n$(i18n test_config)\n"
    echoColor gray "$(i18n validation_waiting "${validation_timeout}")"
    startInstallValidationProcess "${yaml_file}" "./hihy_debug.info"
    waitForValidationOutcome "./hihy_debug.info" "${validation_timeout}"
    case $? in
        0)
            echoColor green "$(i18n test_success)"
            echoColor purple "$(i18n stop_test_program)"
            stopValidationProcess
            rm -f ./hihy_debug.info
            if [ "${realmMode}" != "true" ]; then
                allowPort udp ${port}
                if [ "${portHoppingStatus}" == "true" ]; then
                    allowPort udp "${portHoppingStart}:${portHoppingEnd}"
                fi
                if [ "${masquerade_tcp}" == "true" ]; then
                    getPortBindMsg TCP ${port}
                    allowPort tcp ${port}
                fi
            fi
            echoColor purple "$(i18n generating_config)"
            ;;
        2)
            echoColor red "$(i18n acme_cert_fail ${u_host})"
            cleanupFailedValidation "certificate" "failed to get a certificate with ACME"
            echoColor yellow "$(i18n acme_incomplete_state)"
            exit 1
            ;;
        3)
            cleanupFailedValidation "port-bind" "bind: address already in use"
            echoColor red "$(i18n port_bind_fail)"
            echoColor yellow "$(i18n acme_incomplete_state)"
            exit 1
            ;;
        *)
            echoColor red "$(i18n unknown_error)"
            echoColor yellow "$(i18n unknown_error_incomplete_state)"
            cat ./hihy_debug.info
            cleanupFailedValidation "config-test" "unknown error while validating generated config"
            exit 1
            ;;
    esac
    backup_file="/etc/hihy/conf/backup.yaml"
    rm -f "${backup_file}"
    touch "${backup_file}"
    addOrUpdateYaml ${backup_file} "remarks" "${remarks}"
    addOrUpdateYaml ${backup_file} "serverAddress" "${u_host}" "string"
    addOrUpdateYaml ${backup_file} "serverPort" "${port}"
    addOrUpdateYaml ${backup_file} "congestionMode" "${congestion_mode}"
    addOrUpdateYaml ${backup_file} "congestionType" "${congestion_type}"
    addOrUpdateYaml ${backup_file} "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml ${backup_file} "congestionBbrProfile" "${congestion_bbr_profile}"
    fi
    addOrUpdateYaml ${backup_file} "portHoppingStatus" "${portHoppingStatus}"
    addOrUpdateYaml ${backup_file} "portHoppingStart" "${portHoppingStart}"
    addOrUpdateYaml ${backup_file} "portHoppingEnd" "${portHoppingEnd}"
    addOrUpdateYaml ${backup_file} "portHoppingIntervalMode" "${portHoppingIntervalMode}"
    addOrUpdateYaml ${backup_file} "portHoppingHopInterval" "${portHoppingHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMinHopInterval" "${portHoppingMinHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMaxHopInterval" "${portHoppingMaxHopInterval}"
    addOrUpdateYaml ${backup_file} "domain" "${domain}"
    addOrUpdateYaml ${backup_file} "trafficPort" "${trafficPort}"
    addOrUpdateYaml ${backup_file} "socks5_status" "false"
    addOrUpdateYaml ${backup_file} "realmMode" "${realmMode}"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml ${backup_file} "realmURI" "${realmURI}"
        addOrUpdateYaml ${backup_file} "realmName" "${realmName}"
    fi
    addOrUpdateYaml ${backup_file} "masquerade_status" "${masquerade_status}"
    addOrUpdateYaml ${backup_file} "masquerade_xforwarded" "${masquerade_xforwarded}"
    addOrUpdateYaml ${backup_file} "masquerade_tcp" "${masquerade_tcp}"
    if [ "${insecure}" == "1" ]; then
        addOrUpdateYaml ${backup_file} "insecure" "true"
    else
        addOrUpdateYaml ${backup_file} "insecure" "false"
    fi
    if [ -n "${pinSHA256}" ]; then
        addOrUpdateYaml ${backup_file} "pinSHA256" "${pinSHA256}" "string"
    fi
    if ! installHihyLauncher; then
        markInstallFailed "launcher" "failed to install hihy launcher"
        echoColor red "$(i18n hihy_cmd_install_fail)"
        exit 1
    fi
    clearInstallFailureMarker
    echoColor greenWhite "$(i18n install_success)"
}

setHysteriaConfig() {
    setConfigDefaults
    collectHysteriaConfig
    writeHysteriaConfig
}
