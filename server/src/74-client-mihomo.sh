#!/bin/bash
generateMetaYaml() {
    remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
    local metaFile="./Hy2-${remarks}-ClashMeta.yaml"
    if [ -f "${metaFile}" ]; then
        rm -f ${metaFile}
    fi
    touch ${metaFile}

    cat <<EOF >${metaFile}
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: true
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
  enhanced-mode: redir-host
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://223.5.5.5/dns-query
  fallback:
    - 114.114.114.114
    - 223.5.5.5
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400

  gfw:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400

  greatfire:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt"
    path: ./ruleset/greatfire.yaml
    interval: 86400

  tld-not-cn:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt"
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400

  telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

  cncidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400

  lancidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

  applications:
    type: http
    behavior: classical
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"
    path: ./ruleset/applications.yaml
    interval: 86400

rules:
  - RULE-SET,applications,DIRECT
  - DOMAIN,clash.razord.top,DIRECT
  - DOMAIN,yacd.haishan.me,DIRECT
  - DOMAIN,services.googleapis.cn,PROXY
  - RULE-SET,private,DIRECT
  - RULE-SET,reject,REJECT
  - RULE-SET,icloud,DIRECT
  - RULE-SET,apple,DIRECT
  - RULE-SET,google,DIRECT
  - RULE-SET,proxy,PROXY
  - RULE-SET,direct,DIRECT
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,cncidr,DIRECT
  - RULE-SET,telegramcidr,PROXY
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
    realmMode=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "realmMode" "false")
    serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
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
    download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
    download=$(echo ${download} | sed 's/[^0-9]//g')
    upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
    upload=$(echo ${upload} | sed 's/[^0-9]//g')
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingStart" "${port}")
        portHoppingEnd=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingEnd" "${port}")
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].name" "${remarks}"
    addOrUpdateYaml "${metaFile}" "proxies[0].type" "hysteria2"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}"
        yq eval 'del(.proxies[0].port)' -i "${metaFile}"
    else
        addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}"
        addOrUpdateYaml "${metaFile}" "proxies[0].port" "${port}"
        if [ "${portHoppingStatus}" == "true" ]; then
            addOrUpdateYaml "${metaFile}" "proxies[0].ports" "${portHoppingStart}-${portHoppingEnd}"
        fi
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].password" "${auth_secret}"
    addOrUpdateYaml "${metaFile}" "proxies[0].up" "${upload} Mbps"
    addOrUpdateYaml "${metaFile}" "proxies[0].down" "${download} Mbps"
    if [ -n "${pinSHA256}" ]; then
        # 通过证书指纹校验,Clash.Meta 使用 fingerprint 字段,无需跳过证书校验
        addOrUpdateYaml "${metaFile}" "proxies[0].skip-cert-verify" "false"
        addOrUpdateYaml "${metaFile}" "proxies[0].fingerprint" "${pinSHA256}" "string"
    else
        addOrUpdateYaml "${metaFile}" "proxies[0].skip-cert-verify" "${insecure}"
        yq eval 'del(.proxies[0].fingerprint)' -i "${metaFile}"
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs" "${obfs_type}"
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs-password" "${obfs_pass}"
    else
        yq eval 'del(.proxies[0].obfs, .proxies[0].obfs-password)' -i "${metaFile}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].sni" "${tls_sni}"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].type" "select"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].proxies" "[${remarks}]"
    echoColor purple "\n$(i18n client_config_clashmeta_file "$(echoColor green ${metaFile})")"
    if [ "${realmMode}" == "true" ]; then
        echoColor yellow "$(i18n client_config_clashmeta_realm_hint)"
    fi

}

