#!/bin/bash
# 客户端配置公共参数层:一次性读取 backup/config.yaml,供 native/mihomo/singbox 三个生成器共用。
# 所有路径经 $HIHY_ROOT_DIR(默认 /etc/hihy),便于 fixture 测试。

# 解析 realm URI: realm://<token>@<host>[:port]/<realm-id> 或 realm+http://...
# 导出 HIHY_REALM_SCHEME / HIHY_REALM_SERVER_URL / HIHY_REALM_TOKEN / HIHY_REALM_ID
parseRealmURI() {
    local uri="$1"
    local rest hostport
    if [[ "$uri" == realm+http://* ]]; then
        HIHY_REALM_SCHEME="http"
        rest="${uri#realm+http://}"
    else
        HIHY_REALM_SCHEME="https"
        rest="${uri#realm://}"
    fi
    HIHY_REALM_TOKEN="${rest%%@*}"
    rest="${rest#*@}"
    hostport="${rest%%/*}"
    HIHY_REALM_ID="${rest#*/}"
    HIHY_REALM_SERVER_URL="${HIHY_REALM_SCHEME}://${hostport}"
    export HIHY_REALM_SCHEME HIHY_REALM_SERVER_URL HIHY_REALM_TOKEN HIHY_REALM_ID
}

# 读取全部客户端参数,导出 HIHY_CP_* 前缀变量。
loadClientParams() {
    local root="${HIHY_ROOT_DIR:-/etc/hihy}"
    local backup="$root/conf/backup.yaml"
    local config="$root/conf/config.yaml"

    HIHY_CP_remarks=$(getYamlValue "$backup" "remarks")
    HIHY_CP_serverAddress=$(getYamlValue "$backup" "serverAddress")
    HIHY_CP_realmMode=$(getBackupValueOrDefault "$backup" "realmMode" "false")
    HIHY_CP_realmURI=""
    if [ "$HIHY_CP_realmMode" = "true" ]; then
        HIHY_CP_realmURI=$(getYamlValue "$backup" "realmURI")
    fi

    local listen_value
    listen_value=$(getYamlValue "$config" "listen")
    HIHY_CP_port=$(getListenPrimaryPort "$listen_value")
    HIHY_CP_auth=$(getYamlValue "$config" "auth.password")
    HIHY_CP_sni=$(getYamlValue "$backup" "domain")
    HIHY_CP_insecure=$(getYamlValue "$backup" "insecure")
    HIHY_CP_pinSHA256=$(getBackupValueOrDefault "$backup" "pinSHA256" "")
    if [ -z "$HIHY_CP_pinSHA256" ] || [ "$HIHY_CP_pinSHA256" = "null" ]; then
        HIHY_CP_pinSHA256=""
        # 向后兼容:旧版自签只存了 insecure,从证书文件实时计算指纹,自动升级为 pinSHA256 校验
        local cert_path
        cert_path=$(getYamlValue "$config" "tls.cert")
        if [ "$HIHY_CP_insecure" = "true" ] && [ -n "$cert_path" ] && [ "$cert_path" != "null" ] && [ -f "$cert_path" ]; then
            HIHY_CP_pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in "$cert_path" 2>/dev/null | sed 's/^.*=//')
        fi
    fi

    HIHY_CP_obfsType=$(getYamlValue "$config" "obfs.type")
    if [ "$HIHY_CP_obfsType" = "salamander" ] || [ "$HIHY_CP_obfsType" = "gecko" ]; then
        HIHY_CP_obfsStatus="true"
        HIHY_CP_obfsPass=$(getYamlValue "$config" "obfs.${HIHY_CP_obfsType}.password")
    else
        HIHY_CP_obfsStatus="false"
        HIHY_CP_obfsType=""
        HIHY_CP_obfsPass=""
    fi

    HIHY_CP_srw=$(getYamlValue "$config" "quic.initStreamReceiveWindow"); [ "$HIHY_CP_srw" = "null" ] && HIHY_CP_srw=""
    HIHY_CP_crw=$(getYamlValue "$config" "quic.initConnReceiveWindow"); [ "$HIHY_CP_crw" = "null" ] && HIHY_CP_crw=""
    HIHY_CP_maxCrw=$(getYamlValue "$config" "quic.maxConnReceiveWindow"); [ "$HIHY_CP_maxCrw" = "null" ] && HIHY_CP_maxCrw=""
    HIHY_CP_maxSrw=$(getYamlValue "$config" "quic.maxStreamReceiveWindow"); [ "$HIHY_CP_maxSrw" = "null" ] && HIHY_CP_maxSrw=""

    HIHY_CP_congestionMode=$(getBackupValueOrDefault "$backup" "congestionMode" "brutal")
    HIHY_CP_congestionType=$(getBackupValueOrDefault "$backup" "congestionType" "")
    HIHY_CP_bbrProfile=$(getBackupValueOrDefault "$backup" "congestionBbrProfile" "standard")

    # 注意:原生配置里 down 取 bandwidth.up、up 取 bandwidth.down(既有约定,保持不变)
    HIHY_CP_down=$(getYamlValue "$config" "bandwidth.up"); [ "$HIHY_CP_down" = "null" ] && HIHY_CP_down=""
    HIHY_CP_up=$(getYamlValue "$config" "bandwidth.down"); [ "$HIHY_CP_up" = "null" ] && HIHY_CP_up=""

    HIHY_CP_phStatus=$(getYamlValue "$backup" "portHoppingStatus")
    HIHY_CP_phStart=""; HIHY_CP_phEnd=""; HIHY_CP_phIntervalMode="fixed"
    HIHY_CP_phHopInterval="30s"; HIHY_CP_phMinHopInterval="10s"; HIHY_CP_phMaxHopInterval="30s"
    if [ "$HIHY_CP_phStatus" = "true" ]; then
        HIHY_CP_phStart=$(getBackupValueOrDefault "$backup" "portHoppingStart" "$HIHY_CP_port")
        HIHY_CP_phEnd=$(getBackupValueOrDefault "$backup" "portHoppingEnd" "$HIHY_CP_port")
        HIHY_CP_phIntervalMode=$(getBackupValueOrDefault "$backup" "portHoppingIntervalMode" "fixed")
        HIHY_CP_phHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingHopInterval" "30s")
        HIHY_CP_phMinHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingMinHopInterval" "10s")
        HIHY_CP_phMaxHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingMaxHopInterval" "30s")
    fi
}
