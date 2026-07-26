#!/bin/bash
# sing-box 客户端配置生成(基线 1.12+,旧版 DNS 格式已在 sing-box 1.14 移除;
# realm/gecko/bbr_profile/hop_interval_max 需 1.14+)
# 字段映射对照 sing-box.sagernet.org hysteria2 outbound + shared TLS
#
# 注意 outbound 的 network 字段指的是"被代理流量"的类型(tcp/udp),不是 QUIC 传输层。
# 缺省即两者都启用;若误写成 "udp",所有 TCP 流量都会被拒绝
# (日志: "TCP is not supported by default outbound"),等于整个代理不可用。
generateSingboxJson() {
    loadClientParams
    local remarks="$HIHY_CP_remarks"
    local root="${HIHY_ROOT_DIR:-/etc/hihy}"
    local mirror="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
    local outFile="./Hy2-${remarks}-singbox.json"
    [ -f "$outFile" ] && rm -f "$outFile"

    # ---------- ECH(可选,附着到 tls 块): config 取 PEM 行数组(sing-box 要求 PEM 格式) ----------
    local ech_member=""
    if [ "$HIHY_CP_echStatus" = "true" ]; then
        local ech_b64_lines
        ech_b64_lines=$(printf '%s' "$HIHY_CP_echConfig" | fold -w 64 | awk '{printf "\"%s\", ", $0}')
        ech_member=",
        \"ech\": {
          \"enabled\": true,
          \"config\": [\"-----BEGIN ECH CONFIGS-----\", ${ech_b64_lines}\"-----END ECH CONFIGS-----\"]
        }"
    fi

    # ---------- TLS: 自签内嵌 CA PEM;否则按 insecure ----------
    local tls_block ca_file pem_lines
    ca_file="$root/result/${HIHY_CP_sni}.ca.crt"
    if [ -n "$HIHY_CP_pinSHA256" ] && [ -f "$ca_file" ]; then
        # 自签证书:sing-box 不支持 pinSHA256,用内嵌 CA PEM 校验。
        # certificate 必须是"每行 PEM 一个数组元素";把整份 PEM 拼成一个长字符串会让
        # sing-box 解析证书失败并直接 panic(注意 `sing-box check` 只验 JSON 结构,查不出来)。
        pem_lines=$(awk '{gsub(/[\r"]/,""); printf "%s\"%s\"", sep, $0; sep=", "}' "$ca_file")
        tls_block=$(cat <<JSON
"tls": {
        "enabled": true,
        "server_name": "${HIHY_CP_sni}",
        "insecure": false,
        "certificate": [${pem_lines}]${ech_member}
      }
JSON
)
    else
        local insec="false"; [ "$HIHY_CP_insecure" = "true" ] && insec="true"
        tls_block=$(cat <<JSON
"tls": {
        "enabled": true,
        "server_name": "${HIHY_CP_sni}",
        "insecure": ${insec}${ech_member}
      }
JSON
)
    fi

    # ---------- 服务端连接 ----------
    local server_block
    if [ "$HIHY_CP_realmMode" = "true" ]; then
        parseRealmURI "$HIHY_CP_realmURI"
        # realm 模式:省 server/server_port,出 realm 块(sing-box 文档明确冲突)
        server_block=$(cat <<JSON
"realm": {
        "server_url": "${HIHY_REALM_SERVER_URL}",
        "token": "${HIHY_REALM_TOKEN}",
        "realm_id": "${HIHY_REALM_ID}",
        "stun_servers": [
          "stun.nextcloud.com:3478",
          "global.stun.twilio.com:3478"
        ]
      }
JSON
)
    elif [ "$HIHY_CP_phStatus" = "true" ]; then
        local hop_block
        hop_block="\"hop_interval\": \"${HIHY_CP_phHopInterval}\""
        if [ "$HIHY_CP_phIntervalMode" = "random" ]; then
            hop_block="\"hop_interval\": \"${HIHY_CP_phMinHopInterval}\", \"hop_interval_max\": \"${HIHY_CP_phMaxHopInterval}\""
        fi
        server_block=$(cat <<JSON
"server": "${HIHY_CP_serverAddress}",
      "server_ports": ["${HIHY_CP_phStart}:${HIHY_CP_phEnd}"],
      ${hop_block}
JSON
)
    else
        server_block=$(cat <<JSON
"server": "${HIHY_CP_serverAddress}",
      "server_port": ${HIHY_CP_port}
JSON
)
    fi

    # ---------- 拥塞控制 ----------
    # 省略 up_mbps/down_mbps 即自动使用 BBR。
    # bbr_profile 是 sing-box 1.14+ 字段,而 1.14 目前仍是 beta:JSON 解析是严格模式,
    # 未知字段会让整份配置直接加载失败,所以不输出,仅提示该 profile 只对原生客户端生效。
    local cc_block=""
    if [ "$HIHY_CP_congestionMode" = "brutal" ]; then
        local up_num down_num
        up_num=$(echo "$HIHY_CP_up" | tr -dc '0-9')
        down_num=$(echo "$HIHY_CP_down" | tr -dc '0-9')
        cc_block=$(cat <<JSON
      "up_mbps": ${up_num},
      "down_mbps": ${down_num}
JSON
)
    fi

    # ---------- 混淆 ----------
    local obfs_block=""
    if [ "$HIHY_CP_obfsStatus" = "true" ]; then
        obfs_block="      \"obfs\": { \"type\": \"${HIHY_CP_obfsType}\", \"password\": \"${HIHY_CP_obfsPass}\" }"
    fi

    # ---------- 组装:写出首版再经 yq 整理 JSON ----------
    # 先用 heredoc 生成(可选块按需插入);然后用 yq eval 保证合法+缩进统一
    cat > "$outFile" <<JSON
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "tls", "tag": "google", "server": "8.8.8.8", "detour": "PROXY" },
      { "type": "https", "tag": "local", "server": "223.5.5.5", "detour": "direct" }
    ],
    "rules": [
      { "rule_set": "geosite-cn", "server": "local" }
    ],
    "final": "google"
  },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 20808 }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "PROXY",
      ${server_block},
      "password": "${HIHY_CP_auth}",
      ${tls_block}
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "default_domain_resolver": "local",
    "rule_set": [
      { "type": "remote", "tag": "geosite-cn", "format": "binary", "url": "${mirror}/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs", "download_detour": "PROXY" },
      { "type": "remote", "tag": "geoip-cn", "format": "binary", "url": "${mirror}/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs", "download_detour": "PROXY" }
    ],
    "rules": [
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": ["geosite-cn", "geoip-cn"], "outbound": "direct" }
    ],
    "final": "PROXY"
  },
  "experimental": {
    "clash_api": { "external_controller": "127.0.0.1:9090" },
    "cache_file": { "enabled": true }
  }
}
JSON

    # 注入拥塞控制 / 混淆可选块:用 yq 以 JSON 模式精确赋值,
    # 后写序列化保证合法(空 cc_block/obfs_block 直接跳过)。
    if [ -n "${cc_block}" ]; then
        # cc_block 形如 '"up_mbps": 50,\n      "down_mbps": 200' —
        # 用临时方式合并:先转单行 JSON 添加字段
        yq -p json -o json eval ".outbounds[0] += {${cc_block}}" "$outFile" > "${outFile}.tmp" 2>/dev/null \
            && mv "${outFile}.tmp" "$outFile"
    fi
    if [ -n "${obfs_block}" ]; then
        yq -p json -o json eval ".outbounds[0] += {${obfs_block}}" "$outFile" > "${outFile}.tmp" 2>/dev/null \
            && mv "${outFile}.tmp" "$outFile"
    fi

    # 最终序列化:清理多余空行 + 统一缩进
    command -v yq >/dev/null 2>&1 && yq -p json -o json eval '.' "$outFile" > "${outFile}.tmp" 2>/dev/null \
        && mv "${outFile}.tmp" "$outFile"

    echoColor purple "\n$(i18n client_singbox_file_hint "$(echoColor green "${outFile}")")"
    echoColor yellow "$(i18n client_singbox_version_hint)"
    # realm 是 1.14+ 字段,而 1.14 尚未发布正式版:稳定版 sing-box 会直接拒载整份配置
    if [ "$HIHY_CP_realmMode" = "true" ]; then
        echoColor yellow "$(i18n client_singbox_realm_beta_warning)"
    fi
    if [ "$HIHY_CP_congestionMode" != "brutal" ] && [ "$HIHY_CP_congestionMode" = "bbr" ] \
        && [ -n "$HIHY_CP_bbrProfile" ] && [ "$HIHY_CP_bbrProfile" != "standard" ]; then
        echoColor lightYellow "$(i18n client_singbox_bbr_profile_note "${HIHY_CP_bbrProfile}")"
    fi
}
