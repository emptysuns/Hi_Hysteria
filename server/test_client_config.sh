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
    if grep -q 'bbr-profile: aggressive' "$mf"; then pass "mihomo bbr aggressive profile"
    else fail "mihomo bbr-profile aggressive missing"
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

if [ "$FAIL" -eq 0 ]; then echo "ALL client_config TESTS PASSED"; else echo "SOME client_config TESTS FAILED" >&2; exit 1; fi
