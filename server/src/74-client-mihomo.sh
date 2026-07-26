#!/bin/bash
# mihomo (Clash.Meta) 客户端配置生成
# 修复说明(对照 wiki.metacubex.one hysteria2 proxy):
#   1. 仅 brutal 模式才输出 up/down;BBR/Reno 省略(=BBR,与原生语义对齐)
#   2. BBR 时输出 bbr-profile(standard 省略)
#   3. 端口跳跃输出 hop-interval(random 模式用 min-max 区间)
#   4. Realm 模式输出 realm-opts(enable/server-url/token/realm-id/stun-servers),并保留 port 占位
#   5. 规则镜像改用 jsdelivr(HIHY_RULESET_MIRROR 可覆盖)
#   6. 删除 GEOIP 规则:LAN 由 lancidr 覆盖;CN 由 cncidr 覆盖,且 GEOIP 会强制下载 MMDB,
#      下载失败会让整份配置启动失败
#   7. gecko 混淆:由调用方拦住,不走到此函数
generateMihomoYaml() {
    loadClientParams
    local remarks="$HIHY_CP_remarks"
    local metaFile="./Hy2-${remarks}-mihomo.yaml"
    local mirror="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
    [ -f "$metaFile" ] && rm -f "$metaFile"
    touch "$metaFile"

    # ---------- 静态头: general / dns / rule-providers / rules ----------
    cat >"$metaFile" <<EOF
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
  # 不配置 fallback:mihomo 的默认 fallback-filter 带 geoip,会在启动时强制下载 MMDB
  # (下载失败则整份配置起不来);且原先的 fallback 与 nameserver 同为国内 DNS,本就无意义。
  # proxy-server-nameserver 用于解析节点域名,避免 DNS 请求绕回代理形成环路。
  proxy-server-nameserver:
    - https://223.5.5.5/dns-query
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400

  gfw:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400

  greatfire:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/greatfire.txt"
    path: ./ruleset/greatfire.yaml
    interval: 86400

  tld-not-cn:
    type: http
    behavior: domain
    url: "${mirror}/Loyalsoldier/clash-rules@release/tld-not-cn.txt"
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400

  telegramcidr:
    type: http
    behavior: ipcidr
    url: "${mirror}/Loyalsoldier/clash-rules@release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

  cncidr:
    type: http
    behavior: ipcidr
    url: "${mirror}/Loyalsoldier/clash-rules@release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400

  lancidr:
    type: http
    behavior: ipcidr
    url: "${mirror}/Loyalsoldier/clash-rules@release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

  applications:
    type: http
    behavior: classical
    url: "${mirror}/Loyalsoldier/clash-rules@release/applications.txt"
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
  - MATCH,PROXY
EOF

    # ---------- 动态 proxies[0] ----------
    addOrUpdateYaml "$metaFile" "proxies[0].name" "${remarks}"
    addOrUpdateYaml "$metaFile" "proxies[0].type" "hysteria2"

    if [ "$HIHY_CP_realmMode" = "true" ]; then
        parseRealmURI "$HIHY_CP_realmURI"
        # realm 模式仍必须保留 server + port:mihomo 无条件校验端口,删掉 port 会让整份配置
        # 以 "proxy 0: invalid port" 拒载(已用 mihomo v1.19.29 实测)。实际地址由牵手服务
        # 打洞后确定,这里的 443 只是占位,与官方示例保持同一形状。
        addOrUpdateYaml "$metaFile" "proxies[0].server" "${HIHY_CP_serverAddress}"
        addOrUpdateYaml "$metaFile" "proxies[0].port" "443"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.enable" "true"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.server-url" "${HIHY_REALM_SERVER_URL}"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.token" "${HIHY_REALM_TOKEN}"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.realm-id" "${HIHY_REALM_ID}" "string"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.stun-servers[0]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.stun-servers[1]" "global.stun.twilio.com:3478"
    else
        addOrUpdateYaml "$metaFile" "proxies[0].server" "${HIHY_CP_serverAddress}"
        addOrUpdateYaml "$metaFile" "proxies[0].port" "${HIHY_CP_port}"
        if [ "$HIHY_CP_phStatus" = "true" ]; then
            addOrUpdateYaml "$metaFile" "proxies[0].ports" "${HIHY_CP_phStart}-${HIHY_CP_phEnd}"
            local hi_num hi_min hi_max
            if [ "$HIHY_CP_phIntervalMode" = "random" ]; then
                hi_min=$(echo "$HIHY_CP_phMinHopInterval" | tr -dc '0-9')
                hi_max=$(echo "$HIHY_CP_phMaxHopInterval" | tr -dc '0-9')
                addOrUpdateYaml "$metaFile" "proxies[0].hop-interval" "${hi_min}-${hi_max}" "string"
            else
                hi_num=$(echo "$HIHY_CP_phHopInterval" | tr -dc '0-9')
                addOrUpdateYaml "$metaFile" "proxies[0].hop-interval" "${hi_num}"
            fi
        fi
    fi

    addOrUpdateYaml "$metaFile" "proxies[0].password" "${HIHY_CP_auth}"

    # 拥塞:仅 brutal 输出 up/down;BBR 输出 bbr-profile(standard 省略,与默认值一致)
    if [ "$HIHY_CP_congestionMode" = "brutal" ]; then
        local up_num down_num
        up_num=$(echo "$HIHY_CP_up" | tr -dc '0-9')
        down_num=$(echo "$HIHY_CP_down" | tr -dc '0-9')
        addOrUpdateYaml "$metaFile" "proxies[0].up" "${up_num} Mbps"
        addOrUpdateYaml "$metaFile" "proxies[0].down" "${down_num} Mbps"
    else
        yq eval 'del(.proxies[0].up, .proxies[0].down)' -i "$metaFile"
        if [ "$HIHY_CP_congestionMode" = "bbr" ] && [ "$HIHY_CP_bbrProfile" != "" ] && [ "$HIHY_CP_bbrProfile" != "standard" ]; then
            addOrUpdateYaml "$metaFile" "proxies[0].bbr-profile" "${HIHY_CP_bbrProfile}"
        fi
    fi

    # 证书
    if [ -n "$HIHY_CP_pinSHA256" ]; then
        addOrUpdateYaml "$metaFile" "proxies[0].skip-cert-verify" "false"
        addOrUpdateYaml "$metaFile" "proxies[0].fingerprint" "${HIHY_CP_pinSHA256}" "string"
    else
        addOrUpdateYaml "$metaFile" "proxies[0].skip-cert-verify" "${HIHY_CP_insecure}"
        yq eval 'del(.proxies[0].fingerprint)' -i "$metaFile"
    fi

    # 混淆:仅 salamander 输出(gecko 由调用方拦住,不走到此函数)
    if [ "$HIHY_CP_obfsStatus" = "true" ] && [ "$HIHY_CP_obfsType" = "salamander" ]; then
        addOrUpdateYaml "$metaFile" "proxies[0].obfs" "salamander"
        addOrUpdateYaml "$metaFile" "proxies[0].obfs-password" "${HIHY_CP_obfsPass}"
    else
        yq eval 'del(.proxies[0].obfs, .proxies[0].obfs-password)' -i "$metaFile"
    fi

    addOrUpdateYaml "$metaFile" "proxies[0].sni" "${HIHY_CP_sni}"
    if [ "$HIHY_CP_echStatus" = "true" ]; then
        addOrUpdateYaml "$metaFile" "proxies[0].ech-opts.enable" "true"
        addOrUpdateYaml "$metaFile" "proxies[0].ech-opts.config" "${HIHY_CP_echConfig}" "string"
    fi
    addOrUpdateYaml "$metaFile" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "$metaFile" "proxy-groups[0].type" "select"
    addOrUpdateYaml "$metaFile" "proxy-groups[0].proxies" "[${remarks}]"

    echoColor purple "\n$(i18n client_mihomo_file_hint "$(echoColor green ${metaFile})")"
}
