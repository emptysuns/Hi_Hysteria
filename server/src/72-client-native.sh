#!/bin/bash
generate_client_config() {
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "$(i18n client_config_hysteria_not_installed)"
        exit 1
    fi
    remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
    serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
    realmMode=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "realmMode" "false")
    if [ "${realmMode}" == "true" ]; then
        realmURI=$(getYamlValue "/etc/hihy/conf/backup.yaml" "realmURI")
    fi
    listen_value=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
    port=$(getListenPrimaryPort "${listen_value}")
    auth_secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
    tls_sni=$(getYamlValue "/etc/hihy/conf/backup.yaml" "domain")
    insecure=$(getYamlValue "/etc/hihy/conf/backup.yaml" "insecure")
    pinSHA256=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "pinSHA256" "")
    if [ -z "${pinSHA256}" ] || [ "${pinSHA256}" == "null" ]; then
        pinSHA256=""
        # 向后兼容: 旧版自签安装只记录了 insecure 而未保存指纹,这里从证书文件实时计算,自动升级为 pinSHA256 校验
        cert_path=$(getYamlValue "/etc/hihy/conf/config.yaml" "tls.cert")
        if [ "${insecure}" == "true" ] && [ -n "${cert_path}" ] && [ "${cert_path}" != "null" ] && [ -f "${cert_path}" ]; then
            pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in "${cert_path}" 2>/dev/null | sed 's/^.*=//')
        fi
    fi
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    obfs_type=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.type")
    if [ "${obfs_type}" == "salamander" ] || [ "${obfs_type}" == "gecko" ]; then
        obfs_status="true"
        obfs_pass=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.${obfs_type}.password")
    else
        obfs_status="false"
        obfs_type=""
        obfs_pass=""
    fi
    SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initStreamReceiveWindow")
    CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxStreamReceiveWindow")
    if [ "${SRW}" = "null" ]; then
        SRW=""
    fi
    if [ "${CRW}" = "null" ]; then
        CRW=""
    fi
    if [ "${max_CRW}" = "null" ]; then
        max_CRW=""
    fi
    if [ "${max_SRW}" = "null" ]; then
        max_SRW=""
    fi
    congestion_mode=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "congestionMode" "brutal")
    congestion_type=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "congestionType" "")
    congestion_bbr_profile=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "congestionBbrProfile" "standard")
    download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
    upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
    if [ "${download}" = "null" ]; then
        download=""
    fi
    if [ "${upload}" = "null" ]; then
        upload=""
    fi
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingStart" "${port}")
        portHoppingEnd=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingEnd" "${port}")
        portHoppingIntervalMode=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingIntervalMode" "fixed")
        portHoppingHopInterval=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingHopInterval" "30s")
        portHoppingMinHopInterval=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingMinHopInterval" "10s")
        portHoppingMaxHopInterval=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingMaxHopInterval" "30s")
        serverPortRange="${portHoppingStart}-${portHoppingEnd}"
    fi
    client_configfile="./Hy2-${remarks}-v2rayN.yaml"
    if [ -f "${client_configfile}" ]; then
        rm -f "${client_configfile}"
    fi
    touch ${client_configfile}
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "server" "${realmURI}"
        addOrUpdateYaml "$client_configfile" "auth" "${auth_secret}"
    elif [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "server" "hysteria2://${auth_secret}@${serverAddress}:${port},${serverPortRange}/"
    else
        addOrUpdateYaml "$client_configfile" "server" "hysteria2://${auth_secret}@${serverAddress}:${port}/"
    fi
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "realm.stunServers[0]" "stun.chat.bilibili.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[1]" "stun.miwifi.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[2]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[3]" "global.stun.twilio.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunTimeout" "5s"
        addOrUpdateYaml "$client_configfile" "realm.punchTimeout" "5s"
        addOrUpdateYaml "$client_configfile" "realm.heartbeatInterval" "30s"
        addOrUpdateYaml "$client_configfile" "realm.insecure" "false"
        addOrUpdateYaml "$client_configfile" "realm.ipMode" "dual"
        addOrUpdateYaml "$client_configfile" "realm.portMapping.enabled" "true"
        addOrUpdateYaml "$client_configfile" "realm.portMapping.timeout" "30s"
        addOrUpdateYaml "$client_configfile" "realm.portMapping.lifetime" "10m"
    else
        yq eval 'del(.realm)' -i "$client_configfile"
    fi

    addOrUpdateYaml "$client_configfile" "tls.sni" "${tls_sni}"
    if [ -n "${pinSHA256}" ]; then
        # 通过证书指纹校验自签证书,安全且无需开启不安全连接
        addOrUpdateYaml "$client_configfile" "tls.pinSHA256" "${pinSHA256}" "string"
        addOrUpdateYaml "$client_configfile" "tls.insecure" "false"
    elif [ "${insecure}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "true"
    elif [ "${insecure}" == "false" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "false"
    fi
    addOrUpdateYaml "$client_configfile" "transport.type" "udp"
    if [ "${portHoppingStatus}" == "true" ]; then
        if [ "${portHoppingIntervalMode}" == "random" ]; then
            addOrUpdateYaml "$client_configfile" "transport.udp.minHopInterval" "${portHoppingMinHopInterval}"
            addOrUpdateYaml "$client_configfile" "transport.udp.maxHopInterval" "${portHoppingMaxHopInterval}"
            yq eval 'del(.transport.udp.hopInterval)' -i "$client_configfile"
        else
            addOrUpdateYaml "$client_configfile" "transport.udp.hopInterval" "${portHoppingHopInterval}"
            yq eval 'del(.transport.udp.minHopInterval, .transport.udp.maxHopInterval)' -i "$client_configfile"
        fi
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "obfs.type" "${obfs_type}"
        addOrUpdateYaml "$client_configfile" "obfs.${obfs_type}.password" "${obfs_pass}"
    else
        yq eval 'del(.obfs)' -i "$client_configfile"
    fi
    if [ "${congestion_mode}" != "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "congestion.type" "${congestion_type}"
        if [ "${congestion_type}" == "bbr" ]; then
            addOrUpdateYaml "$client_configfile" "congestion.bbrProfile" "${congestion_bbr_profile}"
        fi
    fi
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "quic.initStreamReceiveWindow" "${SRW}"
        addOrUpdateYaml "$client_configfile" "quic.initConnReceiveWindow" "${CRW}"
        addOrUpdateYaml "$client_configfile" "quic.maxConnReceiveWindow" "${max_CRW}"
        addOrUpdateYaml "$client_configfile" "quic.maxStreamReceiveWindow" "${max_SRW}"
    else
        yq eval 'del(.quic.initStreamReceiveWindow, .quic.initConnReceiveWindow, .quic.maxConnReceiveWindow, .quic.maxStreamReceiveWindow)' -i "$client_configfile"
    fi
    addOrUpdateYaml "$client_configfile" "quic.keepAlivePeriod" "60s"
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "bandwidth.down" "${download}"
        addOrUpdateYaml "$client_configfile" "bandwidth.up" "${upload}"
    else
        yq eval 'del(.bandwidth)' -i "$client_configfile"
    fi
    addOrUpdateYaml "$client_configfile" "fastOpen" "true"
    addOrUpdateYaml "$client_configfile" "lazy" "false"
    addOrUpdateYaml "$client_configfile" "socks5.listen" "127.0.0.1:20808"
    if [ "${realmMode}" == "true" ]; then
        # Realm 分享链接: hysteria2+realm://<token>@<牵手服务器>[:port]/<realm名>?auth=<密码>&...
        # 由存储的 realm:// URI 转换而来: 仅替换协议头,userinfo 是牵手 token,Hysteria 密码放入 auth 参数
        realmShare=$(echo "${realmURI}" | sed -E 's#^realm(\+http)?://#hysteria2+realm\1://#')
        url="${realmShare}?auth=${auth_secret}"
        if [ -n "${pinSHA256}" ]; then
            url="${url}&pinSHA256=${pinSHA256}"
        elif [ "${insecure}" == "true" ]; then
            url="${url}&insecure=1"
        fi
        if [ "${obfs_status}" == "true" ]; then
            url="${url}&obfs=${obfs_type}&obfs-password=${obfs_pass}"
        fi
        url="${url}&sni=${tls_sni}#Hy2-${remarks}"
    else
        url_base="hy2://${auth_secret}@${serverAddress}"

        if [ "${portHoppingStatus}" == "true" ]; then
            url_base="${url_base}:${port}/?mport=${serverPortRange}&"
        else
            url_base="${url_base}:${port}/?"
        fi

        if [ -n "${pinSHA256}" ]; then
            # 自签证书通过指纹校验,无需 insecure
            url_base="${url_base}pinSHA256=${pinSHA256}"
        elif [ "${insecure}" == "true" ]; then
            url_base="${url_base}insecure=1"
        else
            url_base="${url_base}insecure=0"
        fi

        if [ "${obfs_status}" == "true" ]; then
            url_base="${url_base}&obfs=${obfs_type}&obfs-password=${obfs_pass}"
        fi
        url="${url_base}&sni=${tls_sni}#Hy2-${remarks}"
    fi
    # 在生成配置前添加分隔线
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "$(i18n client_config_generating)"

    # 美化输出信息
    echo -e "\n$(i18n client_config_info_title)"
    local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
    echo -e "\n$(i18n client_config_server_version "$(echoColor red ${localV})")"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "${realmMode}" != "true" ]; then
        if [ "${portHoppingStatus}" == "false" ]; then
            echo -e "$(i18n client_config_masquerade_tcp_not_listened)"
            echo -e "$(i18n client_config_masquerade_h3_hint "$(echoColor red "$(i18n client_config_masquerade_h3_action)")")"
        fi

        if [ -n "${pinSHA256}" ]; then
            echo -e "\n$(i18n client_config_security_tip_title)"
            echo -e "$(i18n client_config_pinsha256_safe_hint "$(echoColor red pinSHA256)")"
            echo -e "   $(i18n client_config_fingerprint_label "$(echoColor red ${pinSHA256})")"
            echo -e "   $(i18n client_config_masquerade_trust_hint)"
        elif [ "${insecure}" == "true" ]; then
            echo -e "\n$(i18n client_config_security_warning_title)"
            echo -e "$(i18n client_config_selfsigned_verify_hint)"
            echo -e "   $(i18n client_config_selfsigned_verify_step1)"
            echo -e "   $(i18n client_config_selfsigned_verify_step2)"
        fi
        echoColor purple "\n$(i18n client_config_masquerade_address "$(echoColor red https://${tls_sni}:${port})")"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n$(i18n client_config_realm_mode_desc)"
        echoColor purple "\n$(i18n client_config_realm_rendezvous_label)"
        echoColor green "  ${realmURI}"
        echo -e "\n"
        echoColor yellow "$(i18n client_config_realm_client_support_warning)"
        echoColor yellow "$(i18n client_config_realm_server_password "$(echoColor red ${auth_secret})")"
        echo -e "\n"
        echoColor purple "\n$(i18n client_config_realm_share_link_title)"
        echoColor green "${url}"
        echo -e "\n"
        generate_qr "${url}"
        echo -e "\n"
        echoColor yellow "$(i18n client_config_realm_no_clashmeta_hint)"
    else
        echoColor purple "\n$(i18n client_config_share_link_title)"
        echoColor green "${url}"
        echo -e "\n"
        generate_qr "${url}"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n$(i18n client_config_native_file_realm "$(echoColor green ${client_configfile})")"
    else
        echoColor purple "\n$(i18n client_config_native_file_standard "$(echoColor green ${client_configfile})")"
    fi
    echoColor purple "$(i18n client_config_tutorial_link)"
    echoColor green "↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓$(i18n client_config_copy_marker)↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓"
    cat ${client_configfile}
    echoColor green "↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑$(i18n client_config_copy_marker)↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑"
    if [ "${realmMode}" != "true" ]; then
        generateMetaYaml
    fi

    echo -e "\n$(i18n client_config_done)"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

