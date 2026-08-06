#!/bin/bash
# 客户端配置生成测试:fixture 方式(HIHY_ROOT_DIR 指向临时目录 + mock yaml),
# 直接驱动 loadClientParams / parseRealmURI 及三个生成器。不依赖 mihomo/sing-box 二进制,
# 仅用 yq 校验产物可解析。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# 本地开发环境把 yq 放在 .devtools/;真实主机用系统 yq。
[ -x "$REPO_ROOT/.devtools/yq" ] && export PATH="$REPO_ROOT/.devtools:$PATH"

FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAIL=1; }

# 加载产物中的函数(source 整个脚本;dispatch 有 BASH_SOURCE 守卫,不会执行菜单)
load_funcs() { source "$REPO_ROOT/server/hy2.sh"; }

setup_fixture() {
    HIHY_ROOT_DIR="$(mktemp -d)"
    export HIHY_ROOT_DIR
    mkdir -p "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/result"
    cat > "$HIHY_ROOT_DIR/conf/config.yaml" <<'YML'
listen: :34567
auth:
  password: testpass-uuid
obfs:
  type: none
quic:
  initStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 134217728
  maxStreamReceiveWindow: 67108864
bandwidth:
  up: 50 mbps
  down: 200 mbps
YML
    cat > "$HIHY_ROOT_DIR/conf/backup.yaml" <<'YML'
remarks: testnode
serverAddress: 1.2.3.4
realmMode: false
domain: helloworld.com
insecure: true
pinSHA256: "AA:BB:CC"
congestionMode: brutal
portHoppingStatus: false
YML
}
teardown_fixture() { rm -rf "$HIHY_ROOT_DIR"; }

# ---------- loadClientParams ----------
(
    setup_fixture
    load_funcs
    loadClientParams
    [ "$HIHY_CP_remarks" = "testnode" ] && pass "loadClientParams remarks" || fail "loadClientParams remarks got '$HIHY_CP_remarks'"
    [ "$HIHY_CP_serverAddress" = "1.2.3.4" ] && pass "loadClientParams serverAddress" || fail "loadClientParams serverAddress got '$HIHY_CP_serverAddress'"
    [ "$HIHY_CP_auth" = "testpass-uuid" ] && pass "loadClientParams auth" || fail "loadClientParams auth got '$HIHY_CP_auth'"
    [ "$HIHY_CP_port" = "34567" ] && pass "loadClientParams port" || fail "loadClientParams port got '$HIHY_CP_port'"
    [ "$HIHY_CP_congestionMode" = "brutal" ] && pass "loadClientParams congestion" || fail "loadClientParams congestion got '$HIHY_CP_congestionMode'"
    [ "$HIHY_CP_obfsStatus" = "false" ] && pass "loadClientParams obfs off" || fail "loadClientParams obfs got '$HIHY_CP_obfsStatus'"
    [ "$HIHY_CP_down" = "50 mbps" ] && pass "loadClientParams down<-bandwidth.up" || fail "loadClientParams down got '$HIHY_CP_down'"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- loadClientParams: mimic_status ----------
(
    setup_fixture
    printf 'mimic_status: true\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs
    loadClientParams
    [ "$HIHY_CP_mimicStatus" = "true" ] && pass "loadClientParams mimic on" || fail "loadClientParams mimic got '$HIHY_CP_mimicStatus'"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- native: mimic.enabled written; hopping still off ----------
(
    setup_fixture
    # 需要服务脚本存在才会进入 generate_client_config 主体;这里直接测 yaml 写入路径
    printf 'mimic_status: true\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs
    cd "$HIHY_ROOT_DIR"
    loadClientParams
    cf="./Hy2-testnode-v2rayN.yaml"
    : > "$cf"
    if [ "${HIHY_CP_mimicStatus}" == "true" ]; then
        addOrUpdateYaml "$cf" "mimic.enabled" "true" "bool"
    fi
    if yq eval '.mimic.enabled' "$cf" | grep -q 'true'; then pass "native mimic.enabled true"
    else fail "native mimic.enabled missing"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- parseRealmURI ----------
(
    load_funcs
    parseRealmURI "realm://public@realm.hy2.io/abc-123"
    [ "$HIHY_REALM_SERVER_URL" = "https://realm.hy2.io" ] && pass "parseRealmURI server_url" || fail "parseRealmURI server_url got '$HIHY_REALM_SERVER_URL'"
    [ "$HIHY_REALM_TOKEN" = "public" ] && pass "parseRealmURI token" || fail "parseRealmURI token got '$HIHY_REALM_TOKEN'"
    [ "$HIHY_REALM_ID" = "abc-123" ] && pass "parseRealmURI realm_id" || fail "parseRealmURI realm_id got '$HIHY_REALM_ID'"
    parseRealmURI "realm+http://tok@host.example:8443/id9"
    [ "$HIHY_REALM_SERVER_URL" = "http://host.example:8443" ] && pass "parseRealmURI http scheme" || fail "parseRealmURI http got '$HIHY_REALM_SERVER_URL'"
    [ "$HIHY_REALM_SCHEME" = "http" ] && pass "parseRealmURI scheme http" || fail "parseRealmURI scheme got '$HIHY_REALM_SCHEME'"
    exit $FAIL
) || FAIL=1

# ---------- mihomo: BBR omits up/down (regression 5.2#1) ----------
(
    setup_fixture
    sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'congestionType: bbr\ncongestionBbrProfile: aggressive\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs
    cd "$HIHY_ROOT_DIR"
    loadClientParams; generateMihomoYaml 2>/dev/null
    mf="./Hy2-testnode-mihomo.yaml"
    if [ -f "$mf" ] && ! grep -qE '^\s+up:|^\s+down:' "$mf"; then pass "mihomo bbr omits up/down"
    else fail "mihomo bbr has up/down (should be omitted for BBR)"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: brutal outputs up/down ----------
(
    setup_fixture
    load_funcs
    cd "$HIHY_ROOT_DIR"
    loadClientParams; generateMihomoYaml 2>/dev/null
    mf="./Hy2-testnode-mihomo.yaml"
    if grep -qE '^\s+up:' "$mf" && grep -qE '^\s+down:' "$mf"; then pass "mihomo brutal has up/down"
    else fail "mihomo brutal missing up/down"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: yq-parseable ----------
(
    setup_fixture
    load_funcs
    cd "$HIHY_ROOT_DIR"
    loadClientParams; generateMihomoYaml 2>/dev/null
    mf="./Hy2-testnode-mihomo.yaml"
    if yq eval '.' "$mf" >/dev/null 2>&1; then pass "mihomo yq-parseable"
    else fail "mihomo yq parse failed"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: filename renamed to mihomo (not ClashMeta) ----------
(
    setup_fixture
    load_funcs
    cd "$HIHY_ROOT_DIR"
    loadClientParams; generateMihomoYaml 2>/dev/null
    mf="./Hy2-testnode-mihomo.yaml"
    if [ -f "$mf" ]; then pass "mihomo filename uses -mihomo suffix"
    else fail "mihomo filename wrong (expected Hy2-testnode-mihomo.yaml)"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: JSON parseable ----------
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    if python3 -m json.tool "$sf" >/dev/null 2>&1; then pass "singbox valid json"
    else fail "singbox json invalid"
    fi
    if yq -p json eval '.outbounds[0].type' "$sf" 2>/dev/null | grep -q hysteria2; then pass "singbox outbound type hysteria2"
    else fail "singbox outbound type wrong"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: BBR omits up_mbps/down_mbps ----------
(
    setup_fixture
    sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'congestionType: bbr\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    if ! grep -q 'up_mbps\|down_mbps' "$sf"; then pass "singbox bbr omits mbps"
    else fail "singbox bbr mbps present"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- 自签证书 + pinSHA256: 必须同时 insecure:true ----------
# hysteria 的 pinSHA256 只追加 VerifyPeerCertificate 回调,不关闭 Go 的标准链校验;
# 自签证书没有受信任的链,insecure:false 时握手直接失败,客户端根本连不上。
# 安全性不受影响:仍要求对端证书 SHA-256 与指纹逐字节一致。
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    # generate_client_config 需要服务脚本存在,这里只验证 tls 段的生成逻辑
    cf="./pin.yaml"; : > "$cf"
    if [ -n "$HIHY_CP_pinSHA256" ]; then
        addOrUpdateYaml "$cf" "tls.pinSHA256" "$HIHY_CP_pinSHA256" "string"
        addOrUpdateYaml "$cf" "tls.insecure" "true"
    fi
    grep -q 'insecure: true' "$cf" && pass "pinSHA256 pairs with insecure:true (fixture)" || fail "pin fixture wrong"
    teardown_fixture
    exit $FAIL
) || FAIL=1

(
    load_funcs
    src="$REPO_ROOT/server/src/72-client-native.sh"
    # 源码级断言:pinSHA256 分支后面紧跟的 insecure 必须是 true
    if awk '/tls.pinSHA256/{found=1} found && /tls.insecure/{print; exit}' "$src" | grep -q '"true"'; then
        pass "native generator writes insecure:true alongside pinSHA256"
    else
        fail "native generator still writes insecure:false with pinSHA256 -> client cannot connect"
    fi
    # 分享链接同理:pinSHA256 必须带 insecure=1
    if grep -q 'pinSHA256=\${pinSHA256}&insecure=1' "$src"; then
        pass "share link carries insecure=1 with pinSHA256"
    else
        fail "share link missing insecure=1 with pinSHA256 -> link cannot connect"
    fi
    exit $FAIL
) || FAIL=1

# ---------- sing-box: outbound 不得限制 network(限制成 udp 会拒绝所有 TCP 流量) ----------
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    net=$(yq -p json eval '.outbounds[0].network' "$sf" 2>/dev/null)
    if [ "$net" = "null" ] || [ -z "$net" ]; then pass "singbox outbound does not restrict network"
    else fail "singbox outbound has network=$net -> TCP traffic would be rejected"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: 自签 CA 必须逐行成为数组元素(拼成一行会让 sing-box 解析证书 panic) ----------
(
    setup_fixture
    # 造一份 CA 证书 fixture(sni 与 backup.yaml 中 domain 一致)
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=Test Root CA" \
        -keyout /dev/null -out "$HIHY_ROOT_DIR/result/helloworld.com.ca.crt" 2>/dev/null
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    n=$(yq -p json eval '.outbounds[0].tls.certificate | length' "$sf" 2>/dev/null)
    first=$(yq -p json eval '.outbounds[0].tls.certificate[0]' "$sf" 2>/dev/null)
    if [ "${n:-0}" -gt 2 ] && [ "$first" = "-----BEGIN CERTIFICATE-----" ]; then
        pass "singbox embeds CA as one PEM line per array element ($n lines)"
    else
        fail "singbox CA certificate array malformed (len=$n first='$first') -> sing-box panics at startup"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- ECH: keypair 生成结构正确(与 sing-box generate ech-keypair 等价) ----------
(
    load_funcs
    tmpdir=$(mktemp -d)
    if generateEchKeypair "$tmpdir/ech.pem" "decoy.example.net"; then
        pass "ech keypair generated"
    else
        fail "generateEchKeypair failed"
        rm -rf "$tmpdir"; exit $FAIL
    fi
    grep -q -- "-----BEGIN ECH KEYS-----" "$tmpdir/ech.pem" && grep -q -- "-----BEGIN ECH CONFIGS-----" "$tmpdir/ech.pem" \
        && pass "ech pem has both KEYS and CONFIGS blocks" || fail "ech pem missing PEM blocks"
    [ "$(stat -c %a "$tmpdir/ech.pem")" = "600" ] && pass "ech pem mode 600" || fail "ech pem mode $(stat -c %a "$tmpdir/ech.pem")"
    # ECHConfigList 结构: u16总长 + ECHConfig(0xfe0d + u16len + contents),且 public_name 内嵌
    # -A 必须带:ech_config 是不换行的长单行,openssl base64 -d 默认按 ≤64 字符行读,会静默解出空
    hex=$(printf '%s' "$ech_config" | openssl base64 -d -A 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ -n "$hex" ] && pass "ech config list decodes" || fail "ech config list decoded empty"
    [ "${hex:4:4}" = "fe0d" ] && pass "ech config list version 0xfe0d" || fail "ech version got '${hex:4:4}'"
    outer=$((0x${hex:0:4})); total=$(( ${#hex} / 2 ))
    [ "$outer" -eq $((total - 2)) ] && pass "ech outer length prefix consistent" || fail "ech outer len $outer vs $((total - 2))"
    name_hex=$(printf '%s' "decoy.example.net" | od -An -tx1 | tr -d ' \n')
    case "$hex" in *"$name_hex"*) pass "ech public name embedded" ;; *) fail "ech public name not embedded" ;; esac
    # PEM 中的 CONFIGS 块必须与导出的 base64 逐字节一致(客户端配置与服务端派生值必须一致)
    pem_cfg=$(awk '/BEGIN ECH CONFIGS/{f=1;next} /END ECH CONFIGS/{f=0} f' "$tmpdir/ech.pem" | tr -d '\n')
    [ "$pem_cfg" = "$ech_config" ] && pass "ech pem CONFIGS == exported base64" || fail "ech pem CONFIGS differs from exported value"
    rm -rf "$tmpdir"
    exit $FAIL
) || FAIL=1

# ---------- ECH: 三个生成器都携带 ECH 配置 ----------
(
    setup_fixture
    printf 'ech_status: true\nech_config: "AEz+DQBIAAAgACDtest=="\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    [ "$HIHY_CP_echStatus" = "true" ] && pass "loadClientParams ech status" || fail "ech status '$HIHY_CP_echStatus'"
    cd "$HIHY_ROOT_DIR"
    generateMihomoYaml 2>/dev/null
    mf="./Hy2-testnode-mihomo.yaml"
    if yq eval '.proxies[0].ech-opts.enable' "$mf" 2>/dev/null | grep -q true; then pass "mihomo ech-opts.enable"
    else fail "mihomo ech-opts.enable missing"
    fi
    yq eval '.proxies[0].ech-opts.config' "$mf" 2>/dev/null | grep -q 'AEz' && pass "mihomo ech-opts.config" || fail "mihomo ech-opts.config missing"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    python3 -m json.tool "$sf" >/dev/null 2>&1 && pass "singbox with ech still valid json" || fail "singbox with ech invalid json"
    if yq -p json eval '.outbounds[0].tls.ech.enabled' "$sf" 2>/dev/null | grep -q true; then pass "singbox tls.ech.enabled"
    else fail "singbox tls.ech.enabled missing"
    fi
    yq -p json eval '.outbounds[0].tls.ech.config[0]' "$sf" 2>/dev/null | grep -q 'BEGIN ECH CONFIGS' && pass "singbox ech config is PEM lines" || fail "singbox ech config not PEM"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: BBR 非默认 profile 输出 bbr-profile(mihomo 支持该字段) ----------
(
    setup_fixture
    sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'congestionType: bbr\ncongestionBbrProfile: aggressive\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateMihomoYaml >/dev/null 2>&1
    mf="./Hy2-testnode-mihomo.yaml"
    grep -q 'bbr-profile: aggressive' "$mf" && pass "mihomo emits bbr-profile" || fail "mihomo bbr-profile missing"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: realm 模式必须保留 port(删掉会让 mihomo 报 invalid port 拒载整份配置) ----------
(
    setup_fixture
    sed -i 's/realmMode: false/realmMode: true/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'realmURI: realm://public@realm.hy2.io/abc-123\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateMihomoYaml >/dev/null 2>&1
    mf="./Hy2-testnode-mihomo.yaml"
    port_val=$(yq eval '.proxies[0].port' "$mf" 2>/dev/null)
    if [ -n "$port_val" ] && [ "$port_val" != "null" ]; then pass "mihomo realm keeps port ($port_val)"
    else fail "mihomo realm dropped port -> mihomo would reject the whole config"
    fi
    yq eval '.proxies[0].realm-opts.enable' "$mf" 2>/dev/null | grep -q true && pass "mihomo realm-opts present" || fail "mihomo realm-opts missing"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- mihomo: 不得含 GEOIP 规则(强制下载 MMDB,失败即整份配置起不来) ----------
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateMihomoYaml >/dev/null 2>&1
    mf="./Hy2-testnode-mihomo.yaml"
    if grep -qE '^\s*-\s*GEOIP,' "$mf"; then fail "mihomo config still has GEOIP rule (forces MMDB download)"
    else pass "mihomo config has no GEOIP rule"
    fi
    grep -q 'RULE-SET,cncidr,DIRECT' "$mf" && pass "mihomo keeps cncidr rule as GEOIP,CN replacement" || fail "mihomo missing cncidr rule"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: 不得输出 bbr_profile(1.14+ 字段,1.14 仍无正式版) ----------
(
    setup_fixture
    sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'congestionType: bbr\ncongestionBbrProfile: aggressive\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson >/dev/null 2>&1
    sf="./Hy2-testnode-singbox.json"
    if grep -q 'bbr_profile' "$sf"; then fail "singbox emitted bbr_profile (stable sing-box rejects unknown field)"
    else pass "singbox omits 1.14-only bbr_profile"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: 必须有 default_domain_resolver(1.12 起要求,1.14 移除旧行为) ----------
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    yq -p json eval '.route.default_domain_resolver' "$sf" 2>/dev/null | grep -qv null \
        && pass "singbox has route.default_domain_resolver" || fail "singbox missing route.default_domain_resolver"
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: DNS 使用 1.12+ 新格式(旧格式已在 1.14 移除) ----------
(
    setup_fixture
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    if yq -p json eval '.dns.servers[0].type' "$sf" 2>/dev/null | grep -qE 'tls|https'; then pass "singbox dns uses new server type format"
    else fail "singbox dns still uses legacy address format"
    fi
    if yq -p json eval '.dns.servers[]|has("address")' "$sf" 2>/dev/null | grep -q true; then fail "singbox dns has legacy 'address' field"
    else pass "singbox dns has no legacy address field"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- sing-box: realm omits server_port ----------
(
    setup_fixture
    sed -i 's/realmMode: false/realmMode: true/' "$HIHY_ROOT_DIR/conf/backup.yaml"
    printf 'realmURI: realm://public@realm.hy2.io/abc-123\n' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    load_funcs; loadClientParams
    cd "$HIHY_ROOT_DIR"
    generateSingboxJson 2>/dev/null
    sf="./Hy2-testnode-singbox.json"
    if ! grep -q 'server_port' "$sf" && grep -q 'realm' "$sf"; then pass "singbox realm omits server_port, has realm"
    else fail "singbox realm missing realm block or has server_port"
    fi
    teardown_fixture
    exit $FAIL
) || FAIL=1

# ---------- 真实内核校验(可选):有 mihomo / sing-box 二进制时,让它们真正加载生成的配置 ----------
# CI 通过 HIHY_TEST_MIHOMO_BIN / HIHY_TEST_SINGBOX_BIN 指定路径;本地缺失则跳过。
# 单纯的 yq/json 可解析并不代表内核接受:未知字段、缺失必填项都会让整份配置被拒载。
real_core_check() { # $1 label, $2 congestionMode, $3 extra backup lines
    local label="$1"
    setup_fixture
    sed -i "s/congestionMode: brutal/congestionMode: $2/" "$HIHY_ROOT_DIR/conf/backup.yaml"
    # 用真实长度的 sha256 指纹:mihomo 会校验指纹长度
    sed -i 's|pinSHA256: "AA:BB:CC"|pinSHA256: "3E:AA:0D:DA:83:5C:91:55:3D:59:BA:31:59:A3:1D:D2:60:20:1F:E2:45:C6:F3:1F:DC:56:7A:3A:3B:F1:DD:D6"|' "$HIHY_ROOT_DIR/conf/backup.yaml"
    [ -n "${3:-}" ] && printf '%s\n' "$3" >> "$HIHY_ROOT_DIR/conf/backup.yaml"
    ( load_funcs; cd "$HIHY_ROOT_DIR"; loadClientParams
      generateMihomoYaml >/dev/null 2>&1; generateSingboxJson >/dev/null 2>&1 )

    if [ -x "${HIHY_TEST_MIHOMO_BIN:-}" ]; then
        local out
        out=$("$HIHY_TEST_MIHOMO_BIN" -t -d "$HIHY_ROOT_DIR" -f "$HIHY_ROOT_DIR/Hy2-testnode-mihomo.yaml" 2>&1)
        if echo "$out" | grep -q "test is successful"; then pass "real mihomo loads config [$label]"
        else fail "real mihomo rejects config [$label]: $(echo "$out" | grep -i error | head -1 | cut -c1-160)"
        fi
    fi
    if [ -x "${HIHY_TEST_SINGBOX_BIN:-}" ]; then
        local out
        out=$("$HIHY_TEST_SINGBOX_BIN" check -c "$HIHY_ROOT_DIR/Hy2-testnode-singbox.json" 2>&1)
        if echo "$out" | grep -qE 'FATAL|ERROR'; then
            # realm 需 sing-box 1.14+(尚无正式版),稳定版拒载是已知限制,脚本已向用户告警
            if [ "$label" = "realm" ] && echo "$out" | grep -q 'unknown field "realm"'; then
                echo "XFAIL: sing-box without 1.14 rejects realm field (documented, user is warned)"
            else
                fail "real sing-box rejects config [$label]: $(echo "$out" | grep -E 'FATAL|ERROR' | head -1 | cut -c1-160)"
            fi
        else
            pass "real sing-box loads config [$label]"
        fi
    fi
    teardown_fixture
}

if [ -x "${HIHY_TEST_MIHOMO_BIN:-}" ] || [ -x "${HIHY_TEST_SINGBOX_BIN:-}" ]; then
    (
        real_core_check "brutal" brutal
        real_core_check "bbr-standard" bbr "congestionType: bbr"
        real_core_check "bbr-aggressive" bbr $'congestionType: bbr\ncongestionBbrProfile: aggressive'
        real_core_check "port-hopping" bbr $'congestionType: bbr\nportHoppingStatus: true\nportHoppingStart: 47000\nportHoppingEnd: 48000\nportHoppingIntervalMode: fixed\nportHoppingHopInterval: 30s'
        real_core_check "ech" bbr $'congestionType: bbr\nech_status: true\nech_config: "AEz+DQBInwAgACDAdILFhGxjHg/B2KXIrS36NxKyII985eZZewdPSoJfCQAMAAEAAQABAAIAAQADABFkZWNveS5leGFtcGxlLm5ldAAA"'
        real_core_check "realm" bbr $'congestionType: bbr\nrealmMode: true\nrealmURI: realm://public@realm.hy2.io/abc-123'
        exit $FAIL
    ) || FAIL=1
else
    echo "SKIP: real-core validation (set HIHY_TEST_MIHOMO_BIN / HIHY_TEST_SINGBOX_BIN to enable)"
fi

if [ "$FAIL" -eq 0 ]; then echo "ALL client_config TESTS PASSED"; else echo "SOME client_config TESTS FAILED" >&2; exit 1; fi
