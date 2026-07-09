#!/bin/bash
# 一键安装(autoinstall)配置层测试:默认值、环境变量覆盖、校验轮询。
# 纯变量/文件级断言,不需要 root、不启动真实内核。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -x "$REPO_ROOT/.devtools/yq" ] && export PATH="$REPO_ROOT/.devtools:$PATH"

FAIL=0
pass() { echo "PASS: $1"; }
fail() {
    echo "FAIL: $1" >&2
    FAIL=1
}

load_funcs() { source "$REPO_ROOT/server/hy2.sh"; }

# ---------- setConfigDefaults: 关键默认值 ----------
(
    load_funcs
    setConfigDefaults
    [ "$masquerade_status" = "false" ] && pass "defaults: masquerade off" || fail "defaults masquerade_status='$masquerade_status'"
    [ "$congestion_mode" = "bbr" ] && pass "defaults: congestion bbr" || fail "defaults congestion_mode='$congestion_mode'"
    [ "$congestion_bbr_profile" = "standard" ] && pass "defaults: bbr standard" || fail "defaults bbr_profile='$congestion_bbr_profile'"
    [ "$realmMode" = "false" ] && pass "defaults: realm off" || fail "defaults realmMode='$realmMode'"
    [ "$portHoppingStatus" = "false" ] && pass "defaults: hopping off" || fail "defaults portHoppingStatus='$portHoppingStatus'"
    [ "$block_http3" = "false" ] && pass "defaults: block_http3 off" || fail "defaults block_http3='$block_http3'"
    [ "$masquerade_xforwarded" = "false" ] && pass "defaults: xforwarded set" || fail "defaults masquerade_xforwarded='$masquerade_xforwarded'"
    exit $FAIL
) || FAIL=1

# ---------- applyAutoOverrides: 环境变量覆盖 ----------
(
    load_funcs
    setConfigDefaults
    HIHY_AUTO_PORT=4443
    HIHY_AUTO_PASSWORD="secret-pass"
    HIHY_AUTO_DOMAIN="cdn.example.com"
    HIHY_AUTO_MASQUERADE="https://www.example.org"
    HIHY_AUTO_PORT_HOPPING="true"
    HIHY_AUTO_HOP_START=50000
    HIHY_AUTO_HOP_END=51000
    applyAutoOverrides || fail "applyAutoOverrides returned error for valid input"
    [ "$port" = "4443" ] && pass "override: port" || fail "override port='$port'"
    [ "$auth_secret" = "secret-pass" ] && pass "override: password" || fail "override auth_secret='$auth_secret'"
    [ "$domain" = "cdn.example.com" ] && pass "override: domain" || fail "override domain='$domain'"
    [ "$masquerade_status" = "true" ] && [ "$masquerade_type" = "proxy" ] \
        && [ "$masquerade_proxy" = "https://www.example.org" ] \
        && pass "override: masquerade proxy" || fail "override masquerade '$masquerade_status/$masquerade_type/$masquerade_proxy'"
    [ "$portHoppingStatus" = "true" ] && [ "$portHoppingStart" = "50000" ] && [ "$portHoppingEnd" = "51000" ] \
        && pass "override: port hopping range" || fail "override hopping '$portHoppingStatus/$portHoppingStart/$portHoppingEnd'"
    exit $FAIL
) || FAIL=1

# ---------- applyAutoOverrides: 非法输入拒绝 ----------
(
    load_funcs
    setConfigDefaults
    HIHY_AUTO_PORT="99999"
    if applyAutoOverrides 2>/dev/null; then
        fail "invalid port 99999 accepted"
    else
        pass "invalid port 99999 rejected"
    fi
    setConfigDefaults
    HIHY_AUTO_PORT=""
    HIHY_AUTO_PORT_HOPPING="true"
    HIHY_AUTO_HOP_START=48000
    HIHY_AUTO_HOP_END=47000
    if applyAutoOverrides 2>/dev/null; then
        fail "inverted hop range accepted"
    else
        pass "inverted hop range rejected"
    fi
    exit $FAIL
) || FAIL=1

# ---------- 输入校验辅助 ----------
(
    load_funcs
    isValidPort 1 && isValidPort 65535 && pass "isValidPort bounds" || fail "isValidPort bounds"
    if isValidPort 0 || isValidPort 65536 || isValidPort abc || isValidPort ""; then
        fail "isValidPort accepts invalid input"
    else
        pass "isValidPort rejects invalid input"
    fi
    exit $FAIL
) || FAIL=1

# ---------- waitForValidationOutcome: 标记识别与超时 ----------
(
    load_funcs
    tmp=$(mktemp)
    echo "... server up and running ..." >"$tmp"
    waitForValidationOutcome "$tmp" 3
    [ $? -eq 0 ] && pass "validation: success marker" || fail "validation success marker rc"
    echo "failed to get a certificate with ACME" >"$tmp"
    waitForValidationOutcome "$tmp" 3
    [ $? -eq 2 ] && pass "validation: acme failure marker" || fail "validation acme marker rc"
    echo "bind: address already in use" >"$tmp"
    waitForValidationOutcome "$tmp" 3
    [ $? -eq 3 ] && pass "validation: bind failure marker" || fail "validation bind marker rc"
    echo "nothing interesting" >"$tmp"
    waitForValidationOutcome "$tmp" 1
    [ $? -eq 1 ] && pass "validation: timeout" || fail "validation timeout rc"
    rm -f "$tmp"
    exit $FAIL
) || FAIL=1

if [ "$FAIL" -eq 0 ]; then echo "ALL auto_config TESTS PASSED"; else
    echo "SOME auto_config TESTS FAILED" >&2
    exit 1
fi
