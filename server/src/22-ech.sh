#!/bin/bash
# ECH (Encrypted Client Hello) 密钥对生成 —— 纯 openssl + od + printf 实现,
# 与 `sing-box generate ech-keypair <public_name>` 输出等价,无需额外下载任何二进制。
#
# 结构规范(hysteria app/internal/utils/ech.go 的解析逻辑即权威):
#   "ECH KEYS"    PEM = u16len|X25519私钥(32B) + u16len|ECHConfig     (服务端持有)
#   "ECH CONFIGS" PEM = ECHConfigList = u16len( ECHConfig... )        (发给客户端)
#   ECHConfig  = 版本 0xfe0d + u16len(contents)
#   contents   = config_id(1B) + kem_id 0x0020(X25519-HKDF-SHA256)
#              + u16len+公钥(32B) + u16len+HPKE套件列表
#              + max_name_length(1B=0) + u8len+public_name + 扩展 u16len=0
# 已用真实 hysteria v2.10.0 内核验证:服务端加载成功,派生 configList 与本实现逐字节一致,
# 客户端携带该 configList 可完成 ECH 握手。

echHexLen2() { printf '%04x' $(( ${#1} / 2 )); }
echHexToBin() { printf '%b' "$(printf '%s' "$1" | sed 's/../\\x&/g')"; }

# 生成 ECH 密钥对文件并导出客户端配置。
# $1 = 输出 pem 路径(0600)  $2 = public_name(明文幌子域名)
# 成功: 返回 0,并设置全局 ech_config 为 ECHConfigList 的 base64(客户端 tls.ech 取值)
generateEchKeypair() {
    local out_path="$1" public_name="$2"
    local priv_pem priv_hex pub_hex config_id name_hex suites contents config config_list keys_blob

    if ! command -v openssl >/dev/null 2>&1; then
        return 1
    fi
    priv_pem=$(openssl genpkey -algorithm X25519 2>/dev/null) || return 1
    priv_hex=$(printf '%s\n' "$priv_pem" | openssl pkey -outform DER 2>/dev/null | tail -c 32 | od -An -tx1 | tr -d ' \n')
    pub_hex=$(printf '%s\n' "$priv_pem" | openssl pkey -pubout -outform DER 2>/dev/null | tail -c 32 | od -An -tx1 | tr -d ' \n')
    # X25519 原始密钥固定 32 字节;取不到说明 openssl 过旧(<1.1.1)或输出异常
    if [ ${#priv_hex} -ne 64 ] || [ ${#pub_hex} -ne 64 ]; then
        return 1
    fi

    config_id=$(printf '%02x' "$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')")
    name_hex=$(printf '%s' "$public_name" | od -An -tx1 | tr -d ' \n')
    # HPKE 套件:HKDF-SHA256 × (AES-128-GCM / AES-256-GCM / ChaCha20-Poly1305),Go 标准库支持的全集
    suites="000100010001000200010003"

    contents="${config_id}0020$(echHexLen2 "$pub_hex")${pub_hex}$(echHexLen2 "$suites")${suites}00$(printf '%02x' $(( ${#name_hex} / 2 )))${name_hex}0000"
    config="fe0d$(echHexLen2 "$contents")${contents}"
    config_list="$(echHexLen2 "$config")${config}"
    keys_blob="0020${priv_hex}$(echHexLen2 "$config")${config}"

    mkdir -p "$(dirname "$out_path")"
    {
        echo "-----BEGIN ECH KEYS-----"
        echHexToBin "$keys_blob" | openssl base64
        echo "-----END ECH KEYS-----"
        echo "-----BEGIN ECH CONFIGS-----"
        echHexToBin "$config_list" | openssl base64
        echo "-----END ECH CONFIGS-----"
    } >"$out_path"
    chmod 600 "$out_path"

    ech_config=$(echHexToBin "$config_list" | openssl base64 -A)
    [ -n "$ech_config" ]
}

# base64 值用于 URL 查询参数时的百分号编码(+ / = 三个字符)
echUrlEncodeB64() {
    local s="$1"
    s="${s//+/%2B}"
    s="${s//\//%2F}"
    s="${s//=/%3D}"
    printf '%s' "$s"
}
