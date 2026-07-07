#!/bin/bash
menu() {
    while true; do
        show_menu
        read -r -p "$(i18n menu_prompt_choice)" input
        case $input in
            1)
                install
                exit 0
                ;;
            2)
                uninstall
                exit 0
                ;;
            3)
                start
                wait_for_continue
                ;;
            4)
                stop
                wait_for_continue
                ;;
            5)
                restart
                wait_for_continue
                ;;
            6)
                checkStatus
                wait_for_continue
                ;;
            7)
                updateHysteriaCore
                exit 0
                ;;
            8)
                generate_client_config
                wait_for_continue
                ;;
            9)
                changeServerConfig
                exit 0
                ;;
            10)
                changeIp64
                exit 0
                ;;
            11)
                hihyUpdate
                exit 0
                ;;
            12)
                aclControl
                exit 0
                ;;
            13)
                getHysteriaTrafic
                wait_for_continue
                ;;
            14)
                checkLogs
                exit 0
                ;;
            15)
                addSocks5Outbound
                exit 0
                ;;
            0) exit 0 ;;
            *)
                echoColor red "$(i18n error_input_error)"
                wait_for_continue
                ;;
        esac
    done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    loadPersistedLanguage
    checkRoot
    case "$1" in
        install | 1)
            echoColor purple "$(i18n cmd_title_install)"
            install
            ;;
        uninstall | 2)
            echoColor purple "$(i18n cmd_title_uninstall)"
            uninstall
            ;;
        start | 3)
            echoColor purple "$(i18n cmd_title_start)"
            start
            ;;
        stop | 4)
            echoColor purple "$(i18n cmd_title_stop)"
            stop
            ;;
        restart | 5)
            echoColor purple "$(i18n cmd_title_restart)"
            restart
            ;;
        checkStatus | 6)
            echoColor purple "$(i18n cmd_title_status)"
            checkStatus
            ;;
        updateHysteriaCore | 7)
            echoColor purple "$(i18n cmd_title_update_core)"
            updateHysteriaCore
            ;;
        generate_client_config | 8)
            echoColor purple "$(i18n cmd_title_view_config)"
            generate_client_config
            ;;
        changeServerConfig | 9)
            echoColor purple "$(i18n cmd_title_reconfigure)"
            changeServerConfig
            ;;
        changeIp64 | 10)
            echoColor purple "$(i18n cmd_title_switch_ip_priority)"
            changeIp64
            ;;
        hihyUpdate | 11)
            echoColor purple "$(i18n cmd_title_update_hihy)"
            hihyUpdate
            ;;
        aclControl | 12)
            echoColor purple "$(i18n cmd_title_acl)"
            aclControl
            ;;
        getHysteriaTrafic | 13)
            echoColor purple "$(i18n cmd_title_traffic_stats)"
            getHysteriaTrafic
            ;;
        checkLogs | 14)
            echoColor purple "$(i18n cmd_title_logs)"
            checkLogs
            ;;
        addSocks5Outbound | 15)
            echoColor purple "$(i18n cmd_title_socks5)"
            addSocks5Outbound
            ;;
        cronTask) cronTask ;;
        *) menu ;;
    esac
fi
