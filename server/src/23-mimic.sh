#!/bin/bash
# Mimic(hack3ric/mimic)自动下载安装。
# 官方 release 只发 Debian 系 .deb(bookworm/noble/trixie × amd64/arm64):
#   mimic.deb      -> /usr/sbin/mimic(纯 Go 静态二进制,零依赖)
#   mimic-dkms.deb -> /usr/src/mimic-<ver>/(内核模块源码,DKMS 编译,内核 >= 6.1)
# 策略:
#   1. Debian/Ubuntu(有 apt-get):apt 整装,自动拉 dkms/linux-headers 依赖并触发 DKMS 编译
#   2. 其他发行版:解包 .deb 提取静态二进制;有 dkms 命令则手动 add/build/install 编译模块
#   3. 模块最终必须 modprobe 成功;任一步失败 -> 返回非零,调用方回退关闭 mimic
# 装好后 hysteria 会自动启动并管理 mimic,无需 systemd 服务或手动配置文件。
HIHY_MIMIC_BIN_DIR="${HIHY_MIMIC_BIN_DIR:-/usr/sbin}"
HIHY_DKMS_SRC_DIR="${HIHY_DKMS_SRC_DIR:-/usr/src}"
MIMIC_RELEASE_URL="${MIMIC_RELEASE_URL:-https://github.com/hack3ric/mimic/releases/latest}"
# 三套 deb 的二进制同源(纯 Go),bookworm 兼容面最广;dkms 包是源码,与发行版无关
MIMIC_DEB_SUITE="${MIMIC_DEB_SUITE:-bookworm}"
MIMIC_VERSION_FALLBACK="${MIMIC_VERSION_FALLBACK:-v0.7.1}"

getLatestMimicVersion() {
    local headers
    headers=$(fetchRemoteHeadersFromSources "$MIMIC_RELEASE_URL") || return 1
    printf '%s\n' "$headers" | grep -i '^location:' | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/\r//;s/ //g' | head -n 1
}

# 下载 deb 与 sha256 校验文件并比对;失败清理残留
downloadMimicDeb() {
    local url="$1" out="$2"
    if ! downloadToFile "$url" "$out" || [ ! -s "$out" ]; then
        rm -f "$out"
        return 1
    fi
    if ! downloadToFile "${url}.sha256" "${out}.sha256" || [ ! -s "${out}.sha256" ]; then
        rm -f "$out" "${out}.sha256"
        return 1
    fi
    # 期望格式:两列 "<hash>  <filename>"
    local expect actual
    expect=$(awk '{print $1}' "${out}.sha256" | head -n 1)
    actual=$(sha256sum "$out" | awk '{print $1}')
    if [ -z "$expect" ] || [ "$expect" != "$actual" ]; then
        echoColor red "$(i18n mimic_download_fail)"
        rm -f "$out" "${out}.sha256"
        return 1
    fi
    rm -f "${out}.sha256"
    return 0
}

# 解包 deb 到 $2 目录:dpkg-deb 优先,回退 ar + tar
extractMimicDeb() {
    local deb="$1" dest="$2"
    if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb -x "$deb" "$dest"
    elif command -v ar >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp -d) || return 1
        (cd "$tmp" && ar x "$deb" && tar xf data.tar.* -C "$dest")
        local rc=$?
        rm -rf "$tmp"
        return $rc
    else
        return 1
    fi
}

# Debian/Ubuntu 整装路径:apt 解析依赖(dkms/linux-headers)并触发 DKMS 自动编译
installMimicViaApt() {
    command -v apt-get >/dev/null 2>&1 || return 1
    echo -e "$(i18n mimic_installing)"
    if apt-get install -y --no-install-recommends "$1" "$2" >/dev/null 2>&1; then
        return 0
    fi
    # apt 失败(源不可用/锁)时清掉半装状态,走手动路径
    dpkg -r mimic mimic-dkms >/dev/null 2>&1 || true
    return 1
}

# 通用路径:解包静态二进制;有 dkms 则编译内核模块
installMimicManual() {
    local tmpdir="$1" ver="$2"
    local root="$tmpdir/root"
    mkdir -p "$root"
    if ! extractMimicDeb "$tmpdir/mimic.deb" "$root" || [ ! -f "$root/usr/sbin/mimic" ]; then
        echoColor yellow "$(i18n mimic_extract_fail)"
        return 1
    fi
    # 注意:不能用 install 命令——脚本内已有 install() 函数,同名函数优先于外部命令
    cp "$root/usr/sbin/mimic" "$HIHY_MIMIC_BIN_DIR/mimic"
    chmod 755 "$HIHY_MIMIC_BIN_DIR/mimic"
    if ! command -v dkms >/dev/null 2>&1; then
        echoColor yellow "$(i18n mimic_module_manual_hint)"
        return 1
    fi
    if ! extractMimicDeb "$tmpdir/mimic-dkms.deb" "$root" || [ ! -d "$root/usr/src/mimic-${ver}" ]; then
        echoColor yellow "$(i18n mimic_module_manual_hint)"
        return 1
    fi
    local src_dir="$HIHY_DKMS_SRC_DIR/mimic-${ver}"
    rm -rf "$src_dir"
    mkdir -p "$HIHY_DKMS_SRC_DIR"
    cp -r "$root/usr/src/mimic-${ver}" "$src_dir"
    if dkms add -m mimic -v "$ver" >/dev/null 2>&1 \
        && dkms build -m mimic -v "$ver" >/dev/null 2>&1 \
        && dkms install -m mimic -v "$ver" >/dev/null 2>&1; then
        return 0
    fi
    dkms remove -m mimic -v "$ver" --all >/dev/null 2>&1 || true
    rm -rf "$src_dir"
    echoColor yellow "$(i18n mimic_module_manual_hint)"
    return 1
}

enableMimicBootModule() {
    local modules_dir="$1"
    if [ ! -f "$modules_dir/mimic.conf" ]; then
        mkdir -p "$modules_dir"
        echo 'mimic' > "$modules_dir/mimic.conf" 2>/dev/null || true
    fi
}

# 自动下载安装 mimic(程序 + 内核模块);失败返回非零,由调用方回退关闭 mimic
installMimic() {
    local modules_dir="${HIHY_MODULES_LOAD_DIR:-/etc/modules-load.d}"
    # 已装且可用:直接复用
    if command -v mimic >/dev/null 2>&1 && modprobe mimic 2>/dev/null; then
        enableMimicBootModule "$modules_dir"
        return 0
    fi
    local arch
    arch=$(getArchitecture)
    case "$arch" in
        amd64 | arm64) ;;
        *)
            echoColor yellow "$(i18n mimic_unsupported_arch "$(uname -m)")"
            return 1
            ;;
    esac
    local tag ver base tmpdir
    tag=$(getLatestMimicVersion || true)
    [ -z "$tag" ] && tag="$MIMIC_VERSION_FALLBACK"
    ver="${tag#v}"
    base="https://github.com/hack3ric/mimic/releases/download/${tag}"
    tmpdir=$(mktemp -d) || return 1
    local ok=1
    if downloadMimicDeb "${base}/${MIMIC_DEB_SUITE}_mimic_${ver}-1_${arch}.deb" "$tmpdir/mimic.deb" \
        && downloadMimicDeb "${base}/${MIMIC_DEB_SUITE}_mimic-dkms_${ver}-1_${arch}.deb" "$tmpdir/mimic-dkms.deb"; then
        if installMimicViaApt "$tmpdir/mimic.deb" "$tmpdir/mimic-dkms.deb" \
            || installMimicManual "$tmpdir" "$ver"; then
            ok=0
        fi
    fi
    rm -rf "$tmpdir"
    [ "$ok" -ne 0 ] && return 1
    if ! modprobe mimic 2>/dev/null; then
        echoColor yellow "$(i18n mimic_module_load_fail)"
        return 1
    fi
    echoColor green "$(i18n mimic_installed "$tag")"
    enableMimicBootModule "$modules_dir"
    return 0
}
