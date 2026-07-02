#!/bin/bash
hihyV="ver1.09"

# i18n 多语言支持
HIHY_I18N_SCHEMA=1
HIHY_I18N_DIR="${HIHY_I18N_DIR:-/etc/hihy/i18n}"
HIHY_I18N_CONF="${HIHY_I18N_CONF:-/etc/hihy/conf/i18n.conf}"
HIHY_LANG="${HIHY_LANG:-}"

loadPersistedLanguage() {
    if [ -f "$HIHY_I18N_CONF" ] && [ -z "$HIHY_LANG" ]; then
        HIHY_LANG=$(grep -E '^HIHY_LANG=' "$HIHY_I18N_CONF" | tail -n 1 | cut -d'=' -f2-)
    fi
    HIHY_LANG="${HIHY_LANG:-en}"
}

savePersistedLanguage() {
    mkdir -p "$(dirname "$HIHY_I18N_CONF")"
    printf 'HIHY_LANG=%s\n' "$HIHY_LANG" >"$HIHY_I18N_CONF"
}

detectRtlFromMeta() {
    local file="$1"
    grep '"rtl"' "$file" 2>/dev/null | grep -q 'true'
}

getI18nSchemaVersion() {
    local file="$1"
    local line
    line=$(grep -E '"schema_version"' "$file" | head -n 1)
    [ -z "$line" ] && echo "0" && return
    line="${line%%,*}"
    line="${line#*: }"
    printf '%s' "$line"
}

refreshI18nFile() {
    local lang="$1"
    local base_url="https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main"
    mkdir -p "$HIHY_I18N_DIR"
    local url="${base_url}/server/i18n/${lang}.json"
    local out="${HIHY_I18N_DIR}/hy2.sh.${lang}.json"
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$out" "$url" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$out" "$url" 2>/dev/null
    fi
}

# 按 key 读取 JSON 字符串；返回空表示未找到
i18nValueFromFile() {
    local file="$1"
    local key="$2"
    if [ ! -f "$file" ]; then
        return
    fi
    local line
    line=$(grep -E "^\s*\"${key}\":\s*\"" "$file" | head -n 1)
    [ -z "$line" ] && return
    # 提取第一个 "..." 之后的内容
    line="${line#*: \"}"
    line="${line%\"*}"
    printf '%s' "$line"
}

i18nLookup() {
    local key="$1"
    local lang_file="${HIHY_I18N_DIR}/hy2.sh.${HIHY_LANG}.json"
    local en_file="${HIHY_I18N_DIR}/hy2.sh.en.json"
    local value

    if [ -f "$lang_file" ]; then
        local schema
        schema=$(getI18nSchemaVersion "$lang_file")
        if [ "$schema" != "$HIHY_I18N_SCHEMA" ]; then
            # 异步静默更新语言文件
            (refreshI18nFile "$HIHY_LANG") >/dev/null 2>&1 &
            # 本次直接使用英文
            value=$(i18nValueFromFile "$en_file" "$key")
            [ -n "$value" ] && printf '%s' "$value" && return 0
            printf '%s' "$key"
            return 0
        fi
    fi

    value=$(i18nValueFromFile "$lang_file" "$key")
    if [ -n "$value" ]; then
        printf '%s' "$value"
        return 0
    fi

    if [ "$HIHY_LANG" != "en" ]; then
        value=$(i18nValueFromFile "$en_file" "$key")
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return 0
        fi
    fi

    printf '%s' "$key"
}

# Usage: i18n <key> [arg1] [arg2] ...
i18n() {
    local key="$1"
    shift
    local template
    template=$(i18nLookup "$key")
    # 简单模板插值：%s, %d, %%, 依次用 bash printf 填充
    printf "$template" "$@"
}
HIHY_ROOT_DIR="${HIHY_ROOT_DIR:-/etc/hihy}"
HIHY_BIN_LINK="${HIHY_BIN_LINK:-/usr/bin/hihy}"
HIHY_YQ_BIN="${HIHY_YQ_BIN:-/usr/bin/yq}"
HIHY_PID_FILE="${HIHY_PID_FILE:-/var/run/hihy.pid}"
HIHY_RC_LOCAL="${HIHY_RC_LOCAL:-/etc/rc.local}"
HIHY_REMOTE_SCRIPT_URL="${HIHY_REMOTE_SCRIPT_URL:-https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh}"
HIHY_REMOTE_SCRIPT_MIRROR_URL="${HIHY_REMOTE_SCRIPT_MIRROR_URL:-https://cdn.jsdelivr.net/gh/emptysuns/Hi_Hysteria@main/server/hy2.sh}"
HIHY_VERSION_STATUS_FILE="${HIHY_VERSION_STATUS_FILE:-$HIHY_ROOT_DIR/result/version-check.state}"
HIHY_VERSION_CHECK_LOCK_FILE="${HIHY_VERSION_CHECK_LOCK_FILE:-$HIHY_ROOT_DIR/result/version-check.lock}"
HIHY_VERSION_CHECK_TTL="${HIHY_VERSION_CHECK_TTL:-21600}"
HIHY_REMOTE_CONNECT_TIMEOUT="${HIHY_REMOTE_CONNECT_TIMEOUT:-2}"
HIHY_REMOTE_MAX_TIME="${HIHY_REMOTE_MAX_TIME:-5}"

installHihyLauncher() {
    local source_path="${1:-${BASH_SOURCE[0]}}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local bin_dir

    bin_dir="$(dirname "$bin_link")"
    mkdir -p "$bin_dir"

    if [ -f "$source_path" ] && [ "$source_path" != "$bin_link" ]; then
        cp "$source_path" "$bin_link"
    elif [ ! -f "$bin_link" ]; then
        wget -q -O "$bin_link" --no-check-certificate "$HIHY_REMOTE_SCRIPT_URL" 2>/dev/null
    fi

    if [ -f "$bin_link" ]; then
        chmod +x "$bin_link"
        return 0
    fi

    return 1
}

downloadToFile() {
    local url="$1"
    local output_path="$2"

    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$output_path" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$output_path" "$url"
    else
        return 1
    fi
}

startInstallValidationProcess() {
    local yaml_file="$1"
    local debug_file="${2:-./hihy_debug.info}"

    /etc/hihy/bin/appS -c "$yaml_file" server >"$debug_file" 2>&1 &
}

fetchRemoteBodyFromSources() {
    local url
    local response

    for url in "$@"; do
        if response=$(curl -fsSL --connect-timeout "$HIHY_REMOTE_CONNECT_TIMEOUT" --max-time "$HIHY_REMOTE_MAX_TIME" "$url" 2>/dev/null); then
            printf '%s' "$response"
            return 0
        fi
    done

    return 1
}

fetchRemoteHeadersFromSources() {
    local url
    local response

    for url in "$@"; do
        if response=$(curl -fsSI --connect-timeout "$HIHY_REMOTE_CONNECT_TIMEOUT" --max-time "$HIHY_REMOTE_MAX_TIME" "$url" 2>/dev/null); then
            printf '%s' "$response"
            return 0
        fi
    done

    return 1
}

getLatestHihyVersion() {
    local content

    content=$(fetchRemoteBodyFromSources "$HIHY_REMOTE_SCRIPT_URL" "$HIHY_REMOTE_SCRIPT_MIRROR_URL") || return 1
    printf '%s\n' "$content" | sed -n '2p' | cut -d '"' -f 2 | head -n 1
}

getLatestHysteriaVersion() {
    local headers

    headers=$(fetchRemoteHeadersFromSources "https://github.com/apernet/hysteria/releases/latest") || return 1
    printf '%s\n' "$headers" | grep -i '^location:' | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/\r//;s/ //g' | head -n 1
}

getLocalHysteriaVersion() {
    local core_bin="${1:-$HIHY_ROOT_DIR/bin/appS}"

    if [ ! -x "$core_bin" ]; then
        return 1
    fi

    local version
    version=$(echo app/$("$core_bin" version 2>/dev/null | grep Version: | awk '{print $2}' | head -n 1))
    if [ -z "$version" ] || [ "$version" = "app/" ]; then
        return 1
    fi

    printf '%s\n' "$version"
}

ensureVersionCheckStateDir() {
    mkdir -p "$(dirname "$HIHY_VERSION_STATUS_FILE")" "$(dirname "$HIHY_VERSION_CHECK_LOCK_FILE")"
}

readVersionCheckValue() {
    local file_path="$1"
    local key="$2"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    grep -E "^${key}=" "$file_path" 2>/dev/null | head -n 1 | cut -d '=' -f 2-
}

writeVersionCheckState() {
    local checked_at="$1"
    local hihy_status="$2"
    local hihy_remote="$3"
    local core_status="$4"
    local core_remote="$5"
    local state_file="$HIHY_VERSION_STATUS_FILE"
    local temp_file="${state_file}.tmp.$$"

    ensureVersionCheckStateDir
    cat >"$temp_file" <<EOF
checked_at=${checked_at}
hihy_status=${hihy_status}
hihy_remote=${hihy_remote}
core_status=${core_status}
core_remote=${core_remote}
EOF
    mv "$temp_file" "$state_file"
}

acquireVersionCheckLock() {
    local lock_file="$HIHY_VERSION_CHECK_LOCK_FILE"
    local lock_pid=""

    ensureVersionCheckStateDir

    if [ -f "$lock_file" ]; then
        lock_pid=$(readVersionCheckValue "$lock_file" "pid")
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        fi
        rm -f "$lock_file"
    fi

    cat >"$lock_file" <<EOF
pid=${BASHPID:-$$}
started_at=$(date +%s)
EOF
}

releaseVersionCheckLock() {
    rm -f "$HIHY_VERSION_CHECK_LOCK_FILE"
}

shouldStartVersionCheck() {
    local now
    local checked_at
    local lock_pid

    now=$(date +%s)

    if [ -f "$HIHY_VERSION_CHECK_LOCK_FILE" ]; then
        lock_pid=$(readVersionCheckValue "$HIHY_VERSION_CHECK_LOCK_FILE" "pid")
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        fi
        rm -f "$HIHY_VERSION_CHECK_LOCK_FILE"
    fi

    checked_at=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "checked_at")
    if [ -n "$checked_at" ] && [ $((now - checked_at)) -lt "$HIHY_VERSION_CHECK_TTL" ]; then
        return 1
    fi

    return 0
}

refreshVersionCheckState() {
    local checked_at
    local local_hihy_version="$hihyV"
    local remote_hihy_version=""
    local hihy_status="unknown"
    local local_core_version=""
    local remote_core_version=""
    local core_status="missing"

    if ! acquireVersionCheckLock; then
        return 0
    fi

    checked_at=$(date +%s)

    remote_hihy_version=$(getLatestHihyVersion || true)
    if [ -n "$remote_hihy_version" ]; then
        if [ "$local_hihy_version" != "$remote_hihy_version" ]; then
            hihy_status="update"
        else
            hihy_status="current"
        fi
    else
        hihy_status="error"
    fi

    local_core_version=$(getLocalHysteriaVersion || true)
    if [ -n "$local_core_version" ]; then
        remote_core_version=$(getLatestHysteriaVersion || true)
        if [ -n "$remote_core_version" ]; then
            if [ "$local_core_version" != "$remote_core_version" ]; then
                core_status="update"
            else
                core_status="current"
            fi
        else
            core_status="error"
        fi
    fi

    writeVersionCheckState "$checked_at" "$hihy_status" "$remote_hihy_version" "$core_status" "$remote_core_version"
    releaseVersionCheckLock
}

startBackgroundVersionCheck() {
    if ! shouldStartVersionCheck; then
        return 0
    fi

    (refreshVersionCheckState) >/dev/null 2>&1 &
}

displayCachedVersionNotifications() {
    local hihy_status
    local hihy_remote
    local core_status
    local core_remote
    local checked_at
    local now

    if [ ! -f "$HIHY_VERSION_STATUS_FILE" ]; then
        return 0
    fi

    checked_at=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "checked_at")
    now=$(date +%s)
    if [ -z "$checked_at" ] || [ $((now - checked_at)) -ge "$HIHY_VERSION_CHECK_TTL" ]; then
        return 0
    fi

    hihy_status=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "hihy_status")
    hihy_remote=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "hihy_remote")
    core_status=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "core_status")
    core_remote=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "core_remote")

    if [ "$hihy_status" = "update" ] && [ -n "$hihy_remote" ]; then
        echoColor purple "$(i18n notify_hihy_update ${hihy_remote})"
    fi

    if [ "$core_status" = "update" ] && [ -n "$core_remote" ]; then
        echoColor purple "$(i18n notify_core_update ${core_remote})"
    fi
}

# 检测虚拟化类型的函数
detectVirtualization() {
    local virt_type=""

    # 检查是否为 OpenVZ
    if [ -f "/proc/user_beancounters" ]; then
        virt_type="openvz"
    # 检查是否为 LXC
    elif [ -f "/proc/1/environ" ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        virt_type="lxc"
    # 检查 systemd-detect-virt（如果可用）
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        case "$detected" in
            "openvz") virt_type="openvz" ;;
            "lxc") virt_type="lxc" ;;
            "lxc-libvirt") virt_type="lxc" ;;
            *) virt_type="other" ;;
        esac
    # 检查 /proc/cpuinfo 中的虚拟化标识
    elif grep -q "flags.*hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="other"
    # 检查 cgroup 中的容器标识
    elif [ -f "/proc/1/cgroup" ]; then
        if grep -q ":/lxc/" /proc/1/cgroup 2>/dev/null; then
            virt_type="lxc"
        elif grep -q ":/docker/" /proc/1/cgroup 2>/dev/null; then
            virt_type="docker"
        else
            virt_type="unknown"
        fi
    else
        virt_type="unknown"
    fi

    echo "$virt_type"
}

# 获取启动命令前缀（是否使用 chrt）
getStartCommand() {
    local virt_type=$(detectVirtualization)
    local command_prefix=""

    case "$virt_type" in
        "openvz" | "lxc" | "docker")
            # OpenVZ、LXC 和 Docker 容器中不使用 chrt
            command_prefix=""
            ;;
        *)
            # 其他环境检查是否支持 chrt
            if command -v chrt >/dev/null 2>&1; then
                # 测试 chrt 是否可用
                if chrt -r 1 echo "test" >/dev/null 2>&1; then
                    command_prefix="chrt -r 99"
                else
                    command_prefix=""
                fi
            else
                command_prefix=""
            fi
            ;;
    esac

    echo "$command_prefix"
}

cronTask() {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        echo "" >/etc/hihy/logs/hihy.log
    fi
}
echoColor() {
    local printN="${printN:-}"
    case $1 in
        # 红色
        "red") echo -e "\033[31m${printN}$2 \033[0m" ;;
        # 天蓝色
        "skyBlue") echo -e "\033[1;36m${printN}$2 \033[0m" ;;
        # 绿色
        "green") echo -e "\033[32m${printN}$2 \033[0m" ;;
        # 白色
        "white") echo -e "\033[37m${printN}$2 \033[0m" ;;
        # 洋红色
        "magenta") echo -e "\033[35m${printN}$2 \033[0m" ;;
        # 黄色
        "yellow") echo -e "\033[33m${printN}$2 \033[0m" ;;
        # 紫色
        "purple") echo -e "\033[1;35m${printN}$2 \033[0m" ;;
        # 黑底黄字
        "yellowBlack") echo -e "\033[1;33;40m${printN}$2 \033[0m" ;;
        # 绿底白字
        "greenWhite") echo -e "\033[42;37m${printN}$2 \033[0m" ;;
        # 蓝色
        "blue") echo -e "\033[34m${printN}$2 \033[0m" ;;
        # 青色
        "cyan") echo -e "\033[36m${printN}$2 \033[0m" ;;
        # 黑色
        "black") echo -e "\033[30m${printN}$2 \033[0m" ;;
        # 灰色
        "gray") echo -e "\033[90m${printN}$2 \033[0m" ;;
        # 亮红色
        "lightRed") echo -e "\033[91m${printN}$2 \033[0m" ;;
        # 亮绿色
        "lightGreen") echo -e "\033[92m${printN}$2 \033[0m" ;;
        # 亮黄色
        "lightYellow") echo -e "\033[93m${printN}$2 \033[0m" ;;
        # 亮蓝色
        "lightBlue") echo -e "\033[94m${printN}$2 \033[0m" ;;
        # 亮洋红色
        "lightMagenta") echo -e "\033[95m${printN}$2 \033[0m" ;;
        # 亮青色
        "lightCyan") echo -e "\033[96m${printN}$2 \033[0m" ;;
        # 亮白色
        "lightWhite") echo -e "\033[97m${printN}$2 \033[0m" ;;
    esac
}

# 检测系统架构的函数
getArchitecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        i386 | i686)
            echo "386"
            ;;
        aarch64 | arm64)
            echo "arm64"
            ;;
        armv7*)
            echo "arm"
            ;;
        s390x)
            echo "s390x"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        loongarch64)
            echo "loong64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

checkSystemForUpdate() {
    local release=""
    local installType=""
    local updateNeeded=false
    local packageManager=""
    local requiredPackages=("wget" "curl" "lsof" "bash" "iptables" "bc")

    # 检测包管理器
    if command -v apt >/dev/null; then
        packageManager="apt"
        installType="apt -y -q install"
        upgrade="apt update"
    elif command -v yum >/dev/null; then
        packageManager="yum"
        installType="yum -y -q install"
        upgrade="yum update -y --skip-broken"
    elif command -v dnf >/dev/null; then
        packageManager="dnf"
        installType="dnf -y install"
        upgrade="dnf update -y"
    elif command -v pacman >/dev/null; then
        packageManager="pacman"
        installType="pacman -Sy --noconfirm"
        upgrade="pacman -Syy"
    elif command -v apk >/dev/null; then
        packageManager="apk"
        installType="apk add --no-cache"
        upgrade="apk update"
    else
        echoColor red "\n未检测到支持的包管理器，请将以下信息反馈给开发者："
        echoColor yellow "$(cat /etc/issue 2>/dev/null)"
        echoColor yellow "$(cat /proc/version 2>/dev/null)"
        exit 1
    fi

    # 检查必需的包
    for package in "${requiredPackages[@]}"; do
        if ! command -v "$package" >/dev/null; then
            echoColor green "*$package"
            updateNeeded=true
        fi
    done

    # 检查 dig 命令
    if ! command -v dig >/dev/null; then
        echoColor green "*dnsutils"
        updateNeeded=true
    fi

    # 检查 qrencode 包
    if ! command -v qrencode >/dev/null; then
        echoColor green "*qrencode"
        updateNeeded=true
    fi

    # 检查 qrencode 包
    if ! command -v crontab >/dev/null; then
        echoColor green "*crontab"
        updateNeeded=true
    fi

    # 检查 chrt 命令
    if ! command -v chrt >/dev/null; then
        echoColor green "*util-linux"
        updateNeeded=true
    fi

    # 仅在需要安装包时更新软件源
    if [ "$updateNeeded" = true ]; then
        echoColor purple "\n更新软件源..."
        ${upgrade}

        # 安装必需的包
        for package in "${requiredPackages[@]}"; do
            if ! command -v "$package" >/dev/null; then
                ${installType} "$package"
            fi
        done

        # 安装 dig
        if ! command -v dig >/dev/null; then
            case $packageManager in
                "apt") ${installType} "dnsutils" ;;
                "yum" | "dnf") ${installType} "bind-utils" ;;
                "pacman") ${installType} "bind-tools" ;;
                "apk") ${installType} "bind-tools" ;;
            esac
        fi

        # 安装 qrencode
        if ! command -v qrencode >/dev/null; then
            case $packageManager in
                "apt") ${installType} "qrencode" ;;
                "yum" | "dnf") ${installType} "qrencode" ;;
                "pacman") ${installType} "qrencode" ;;
                "apk") ${installType} "libqrencode-tools" ;;
            esac
        fi

        # 安装 util-linux
        if ! command -v chrt >/dev/null; then
            ${installType} "util-linux"
        fi

        # 确保有 pkill 命令
        if ! command -v pkill >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "procps" ;;
                "yum" | "dnf") ${installType} "procps" ;;
                "pacman") ${installType} "procps" ;;
                "apk") ${installType} "procps" ;;
            esac
        fi

        # 确保有 crontab 命令
        if ! command -v crontab >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "cron" ;;
                "yum" | "dnf") ${installType} "cron" ;;
                "pacman") ${installType} "cronie" ;;
                "apk") ${installType} "cronie" ;;
            esac
        fi

        echoColor purple "\n软件包安装完成."
    fi

    # 检查 yq 命令
    # 安装 yq
    if ! command -v yq >/dev/null; then
        arch=$(getArchitecture)
        echoColor purple "正在下载 yq (${arch})..."
        if ! downloadToFile "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" "$HIHY_YQ_BIN"; then
            if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
                echoColor red "下载 yq 失败：未找到 wget 或 curl"
            else
                echoColor red "下载 yq 失败：wget/curl 下载异常"
            fi
            exit 1
        fi
        chmod +x "$HIHY_YQ_BIN"
    fi
}

getPortBindMsg() {
    # $1 type UDP or TCP
    # $2 port
    local msg
    if [ "$1" == "UDP" ]; then
        msg=$(lsof -i "${1}:${2}")
    else
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    fi

    if [ -z "$msg" ]; then
        return
    fi

    local command pid name
    command=$(echo "$msg" | awk '{print $1}')
    pid=$(echo "$msg" | awk '{print $2}')
    name=$(echo "$msg" | awk '{print $9}')
    echoColor purple "Port: ${1}/${2} 已经被 ${command}(${name}) 占用,进程pid为: ${pid}."
    echoColor green "是否自动关闭端口占用?(y/N)"
    read -r bindP

    if [ -z "$bindP" ] || [[ ! "$bindP" =~ ^[yY]$ ]]; then
        echoColor red "由于端口被占用，退出安装。请手动关闭或者更换端口..."
        if [ "$1" == "TCP" ] && [ "$2" == "80" ]; then
            echoColor "如果需求上无法关闭 ${1}/${2}端口，请使用其他证书获取方式"
        fi
        exit
    fi

    pkill -f "/etc/hihy/bin/appS"
    echoColor purple "正在解绑..."
    sleep 3

    if [ "$1" == "TCP" ]; then
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    else
        msg=$(lsof -i "${1}:${2}")
    fi

    if [ -n "$msg" ]; then
        echoColor red "端口占用关闭失败,强制杀死进程后进程重启,请查看是否存在守护进程..."
        exit
    else
        echoColor green "端口解绑成功..."
    fi
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    else
        uuid=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32 | sed 's/\(.\{8\}\)/\1-/g;s/-$//')
    fi
    echo "$uuid"
}

getListenPrimaryPort() {
    local listen_value="$1"

    if [ -z "$listen_value" ] || [ "$listen_value" = "null" ]; then
        echo ""
        return
    fi

    listen_value=${listen_value#*:}
    listen_value=$(echo "$listen_value" | awk -F',' '{print $1}')
    echo "$listen_value" | awk -F'-' '{print $1}'
}

getListenRangePart() {
    local listen_value="$1"

    if [ -z "$listen_value" ] || [ "$listen_value" = "null" ]; then
        echo ""
        return
    fi

    listen_value=${listen_value#*:}
    if echo "$listen_value" | grep -q ','; then
        echo "$listen_value" | awk -F',' '{print $2}'
    else
        echo ""
    fi
}

getBackupValueOrDefault() {
    local file=$1
    local key=$2
    local default_value=$3
    local value

    value=$(getYamlValue "$file" "$key" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

cleanupLegacyPortHoppingNatIfPresent() {
    if command -v iptables-save >/dev/null 2>&1 && iptables-save 2>/dev/null | grep -q "PortHopping-hihysteria"; then
        delPortHoppingNat >/dev/null 2>&1 || true
        return
    fi

    if command -v ip6tables-save >/dev/null 2>&1 && ip6tables-save 2>/dev/null | grep -q "PortHopping-hihysteria"; then
        delPortHoppingNat >/dev/null 2>&1 || true
    fi
}

getInstallFailureMarker() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    echo "${root_dir}/result/install.failed"
}

getHihyServiceScriptPrimary() {
    echo "${1:-/etc/init.d/hihy}"
}

getHihyServiceScriptFallback() {
    echo "${1:-/etc/rc.d/hihy}"
}

classifyInstallState() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local service_primary="${3:-$(getHihyServiceScriptPrimary)}"
    local service_fallback="${4:-$(getHihyServiceScriptFallback)}"
    local failure_marker="${5:-$(getInstallFailureMarker "$root_dir")}"
    local owned_paths=(
        "$root_dir/bin/appS"
        "$root_dir/conf/config.yaml"
        "$root_dir/conf/backup.yaml"
        "$service_primary"
        "$service_fallback"
        "$bin_link"
    )
    local has_any_artifact="false"
    local has_core_assets="false"
    local has_service_assets="false"
    local path

    for path in "${owned_paths[@]}"; do
        if [ -e "$path" ]; then
            has_any_artifact="true"
            case "$path" in
                "$root_dir/bin/appS" | "$root_dir/conf/config.yaml" | "$root_dir/conf/backup.yaml")
                    has_core_assets="true"
                    ;;
                "$service_primary" | "$service_fallback")
                    has_service_assets="true"
                    ;;
            esac
        fi
    done

    if [ -f "$failure_marker" ]; then
        echo "partially-installed"
        return
    fi

    if [ "$has_core_assets" = "true" ] && [ "$has_service_assets" = "true" ] && [ -f "$bin_link" ]; then
        echo "installed"
        return
    fi

    if [ "$has_any_artifact" = "true" ]; then
        echo "partially-installed"
        return
    fi

    echo "not-installed"
}

markInstallFailed() {
    local phase="$1"
    local details="$2"
    local failure_marker

    failure_marker="$(getInstallFailureMarker)"
    mkdir -p "$(dirname "$failure_marker")"
    printf 'phase=%s\ndetails=%s\n' "$phase" "$details" >"$failure_marker"
}

clearInstallFailureMarker() {
    local failure_marker
    failure_marker="$(getInstallFailureMarker)"
    rm -f "$failure_marker"
}

recoverPartialInstallState() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local service_primary="${3:-$(getHihyServiceScriptPrimary)}"
    local service_fallback="${4:-$(getHihyServiceScriptFallback)}"
    local failure_marker="${5:-$(getInstallFailureMarker "$root_dir")}"
    local rc_local="${6:-$HIHY_RC_LOCAL}"
    local pid_file="${7:-$HIHY_PID_FILE}"

    rm -f "$service_primary" "$service_fallback" "$pid_file"
    rm -f "$root_dir/conf/config.yaml" "$root_dir/conf/backup.yaml"
    rm -f "$failure_marker"

    if [ -f "$rc_local" ]; then
        sed -i '/\/etc\/rc\.d\/hihy start/d' "$rc_local"
        sed -i '/\/etc\/rc\.d\/allow-port start/d' "$rc_local"
        sed -i '/\/etc\/rc\.d\/port-hopping start/d' "$rc_local"
    fi
}

addOrUpdateYaml() {
    local file=$1
    local keyPath=$2
    local value=$3
    local valueType=${4:-"auto"} # auto, string, number, bool

    # 检查文件是否存在，如果不存在则创建一个空文件
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi

    # 将值转换为 JSON 格式以避免解析错误
    local jsonValue
    if [[ $valueType == "auto" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "string" ]]; then
        jsonValue=$(echo "\"$value\"" | yq eval -o=json)
    elif [[ $valueType == "number" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "bool" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    else
        echo "Unsupported value type: $valueType"
        return 1
    fi

    # 使用 yq 修改 YAML 文件
    yq eval ".${keyPath} = ${jsonValue}" -i "$file"
}

getYamlValue() {
    local file=$1    # YAML文件路径
    local keyPath=$2 # 键路径，用点号分隔

    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件不存在"
        return 1
    fi

    # 使用 yq 读取 YAML 文件中的值
    value=$(yq eval ".${keyPath}" "$file")

    # 检查 yq 命令是否成功执行
    if [[ $? -ne 0 ]]; then
        echo "错误: 读取 YAML 文件失败"
        return 1
    fi

    echo "$value"
}

countdown() {
    local seconds=$1
    echo -ne "\033[32m⏰ 倒计时:\033[0m "

    while [ $seconds -gt 0 ]; do
        # 打印当前数字
        echo -ne "\033[31m$seconds\033[0m"
        sleep 1

        # 计算退格数量
        local digits=${#seconds}
        for ((i = 0; i < digits; i++)); do
            echo -ne "\b \b"
        done

        ((seconds--))
    done

    # 清除最后一个数字并显示完成消息
    echo -ne " " # 清除最后显示的数字
    echo -e "\n\033[32m✨ 完成!\033[0m"
}

setHysteriaConfig() {
    mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert /etc/hihy/result /etc/hihy/acl/
    acl_file="/etc/hihy/acl/acl.txt"
    if [ -f "${acl_file}" ]; then
        rm -f "${acl_file}"
    fi
    touch $acl_file
    echoColor yellowBlack "$(i18n config_start_title)"
    echoColor green "$(i18n realm_prompt_title)"
    echoColor white "$(i18n realm_intro_line1)"
    echoColor white "$(i18n realm_intro_line2)"
    echoColor white "$(i18n realm_intro_line3)"
    echoColor white "$(i18n realm_intro_line4)"
    echoColor yellow "$(i18n realm_warning_core_only)"
    echoColor yellow "$(i18n realm_choice_disable_default)"
    echoColor yellow "$(i18n realm_choice_enable)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r realmChoice
    if [ -z "${realmChoice}" ] || [ "${realmChoice}" == "1" ]; then
        realmMode="false"
    else
        realmMode="true"
        realmName=$(generate_uuid)
        echo -e "\n->$(i18n realm_name_label)"$(echoColor red ${realmName})"\n"
        echoColor green "$(i18n realm_server_prompt)"
        echoColor white "$(i18n realm_server_official_hint)"
        echoColor yellow "$(i18n realm_server_choice_official)"
        echoColor yellow "$(i18n realm_server_choice_custom)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r realmServerChoice
        if [ -z "${realmServerChoice}" ] || [ "${realmServerChoice}" == "1" ]; then
            realmAddress="realm.hy2.io"
            realmPassword="public"
        else
            echoColor green "$(i18n realm_address_prompt)"
            read -r realmAddressInput
            while [ -z "${realmAddressInput}" ]; do
                echoColor red "$(i18n realm_address_empty)"
                read -r realmAddressInput
            done
            realmAddress="${realmAddressInput}"
            echoColor green "$(i18n realm_password_prompt)"
            read -r realmPasswordInput
            if [ -z "${realmPasswordInput}" ]; then
                realmPassword="public"
            else
                realmPassword="${realmPasswordInput}"
            fi
        fi
        realmURI="realm://${realmPassword}@${realmAddress}/${realmName}"
        echo -e "\n->$(i18n realm_uri_label)"$(echoColor red ${realmURI})"\n"
        if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
            echoColor purple "$(i18n warp_installed_hint)"
        fi
        echoColor green "$(i18n warp_install_prompt)"
        echoColor white "$(i18n warp_principle_line1)"
        echoColor white "$(i18n warp_principle_line2)"
        echoColor white "$(i18n warp_principle_line3)"
        echoColor white "$(i18n warp_principle_line4)"
        echoColor yellow "$(i18n warp_choice_skip)"
        echoColor yellow "$(i18n warp_choice_install)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r warpChoice
        if [ "${warpChoice}" == "2" ]; then
            echoColor purple "$(i18n warp_installing)"
            echoColor purple "$(i18n warp_select_global_mode)"
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh 2>/dev/null
            bash menu.sh d
            if [ -f "/etc/wireguard/warp.conf" ]; then
                current_mtu=$(grep -oP '^MTU = \K\d+' /etc/wireguard/warp.conf)
                if [ -n "${current_mtu}" ] && [ "${current_mtu}" -lt 1320 ]; then
                    sed -i "s/^MTU = ${current_mtu}/MTU = 1320/g" /etc/wireguard/warp.conf
                    echoColor purple "\n->$(i18n warp_mtu_adjusted ${current_mtu})"
                elif [ -n "${current_mtu}" ]; then
                    echoColor purple "\n->$(i18n warp_mtu_no_adjust ${current_mtu})"
                fi
                echoColor purple "$(i18n warp_enabling)"
                warp o
                sleep 3
                echoColor purple "$(i18n warp_reenabling)"
                warp o
                warpEnabled="true"
                echoColor purple "$(i18n warp_install_done)"
            else
                echoColor red "$(i18n warp_install_fail)"
                echoColor red "$(i18n warp_manual_cmd)"
                echoColor red "$(i18n warp_install_fail_exit)"
                exit 1
            fi
        else
            warpEnabled="false"
            echoColor purple "$(i18n warp_skip)"
        fi
    fi
    echoColor green "$(i18n cert_prompt_title)"
    echoColor yellow "$(i18n cert_choice_acme)"
    echoColor yellow "$(i18n cert_choice_local)"
    echoColor yellow "$(i18n cert_choice_selfsigned)"
    echoColor yellow "$(i18n cert_choice_dns)"
    echoColor green "$(i18n prompt_enter_number_or_default)"
    read -r certNum
    useAcme=false
    useLocalCert=false
    yaml_file="/etc/hihy/conf/config.yaml"
    if [ -f "${yaml_file}" ]; then
        rm -f ${yaml_file}
    fi
    touch $yaml_file

    if [ -z "${certNum}" ] || [ "${certNum}" == "3" ]; then
        echoColor green "$(i18n selfsigned_domain_prompt)"
        read -r domain
        if [ -z "${domain}" ]; then
            domain="helloworld.com"
        fi
        echo -e "->$(i18n selfsigned_domain_label)"$(echoColor red ${domain})"\n"
        if [ "${realmMode}" == "true" ]; then
            ip=""
            echo -e "\n->$(i18n realm_uri_label_with_cert)"$(echoColor red ${realmURI})"\n"
        else
            ip=$(curl -4 -s -m 8 ip.sb)
            if [ -z "${ip}" ]; then
                ip=$(curl -s -m 8 ip.sb)
            fi
            echoColor green "$(i18n public_ip_check)"$(echoColor red ${ip})"\n"
            while true; do
                echoColor green "$(i18n prompt_choose)"
                echoColor yellow "$(i18n ip_correct_default)"
                echoColor yellow "$(i18n ip_incorrect)"
                echoColor green "$(i18n prompt_enter_number)"
                read -r ipNum
                if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                    break
                elif [ "${ipNum}" == "2" ]; then
                    echoColor green "$(i18n ip_prompt)"
                    read -r ip
                    if [ -z "${ip}" ]; then
                        echoColor red "$(i18n input_error_retry)"
                        continue
                    fi
                    break
                else
                    echoColor red "$(i18n input_error_please_retry)"
                fi
            done
        fi
        cert="/etc/hihy/cert/${domain}.crt"
        key="/etc/hihy/cert/${domain}.key"
        useAcme=false
        if [ "${realmMode}" == "true" ]; then
            echoColor purple "\n\n->$(i18n selfsigned_cert_summary_realm ${domain})"$(echoColor red ${realmURI})"\n"
        else
            echoColor purple "\n\n->$(i18n selfsigned_cert_summary_ip ${domain})"$(echoColor red ${ip})"\n"
        fi
        echo -e "\n"

    elif [ "${certNum}" == "2" ]; then
        echoColor green "$(i18n local_cert_path_prompt)"
        read -r local_cert
        while :; do
            if [ ! -f "${local_cert}" ]; then
                echoColor red "\n\n->$(i18n path_not_exist)"
                echoColor green "$(i18n local_cert_path_prompt)"
                read -r local_cert
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n local_cert_label)"$(echoColor red ${local_cert})"\n"
        echoColor green "$(i18n local_key_path_prompt)"
        read -r local_key
        while :; do
            if [ ! -f "${local_key}" ]; then
                echoColor red "\n\n->$(i18n path_not_exist)"
                echoColor green "$(i18n local_key_path_prompt)"
                read -r local_key
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n local_key_label)"$(echoColor red ${local_key})"\n"
        echoColor green "$(i18n local_cert_domain_prompt)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n local_cert_domain_prompt)"
                read -r domain
            else
                break
            fi
        done
        useAcme=false
        useLocalCert=true
        echoColor purple "\n\n->$(i18n local_cert_summary)"$(echoColor red ${domain})"\n"
    elif [ "${certNum}" == "4" ]; then
        echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
            else
                break
            fi
        done
        echo -e "\n\n->$(i18n domain_label)"$(echoColor red ${domain})"\n"
        echoColor green "$(i18n dns_provider_prompt)"
        echoColor yellow "$(i18n dns_choice_cloudflare)"
        echoColor yellow "$(i18n dns_choice_duckdns)"
        echoColor yellow "$(i18n dns_choice_gandi)"
        echoColor yellow "$(i18n dns_choice_godaddy)"
        echoColor yellow "$(i18n dns_choice_namecom)"
        echoColor yellow "$(i18n dns_choice_vultr)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r dnsNum
        if [ -z "${dnsNum}" ] || [ "${dnsNum}" == "1" ]; then
            dns="cloudflare"
            echo -e "\n\n->$(i18n dns_selected_cloudflare)\n"
            echoColor green "$(i18n cloudflare_token_prompt)"
            while :; do
                read -r cloudflare_api_token
                if [ -z "${cloudflare_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n cloudflare_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "2" ]; then
            dns="duckdns"
            echo -e "\n\n->$(i18n dns_selected_duckdns)\n"
            echoColor green "$(i18n duckdns_token_prompt)"
            while :; do
                read -r duckdns_api_token
                if [ -z "${duckdns_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n duckdns_token_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n duckdns_override_prompt)"
            while :; do
                read -r duckdns_override_domain
                if [ -z "${duckdns_override_domain}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n duckdns_override_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "3" ]; then
            dns="gandi"
            echo -e "\n\n->$(i18n dns_selected_gandi)\n"
            echoColor green "$(i18n gandi_token_prompt)"
            while :; do
                read -r gandi_api_token
                if [ -z "${gandi_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n gandi_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "4" ]; then
            dns="godaddy"
            echo -e "\n\n->$(i18n dns_selected_godaddy)\n"
            echoColor green "$(i18n godaddy_token_prompt)"
            while :; do
                read -r godaddy_api_token
                if [ -z "${godaddy_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n godaddy_token_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "5" ]; then
            dns="namedotcom"
            echo -e "\n\n->$(i18n dns_selected_namecom)\n"
            echoColor green "$(i18n namecom_token_prompt)"
            while :; do
                read -r namedotcom_api_token
                if [ -z "${namedotcom_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_token_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n namecom_user_prompt)"
            while :; do
                read -r namedotcom_user
                if [ -z "${namedotcom_user}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_user_prompt)"
                else
                    break
                fi
            done
            echoColor green "$(i18n namecom_server_prompt)"
            while :; do
                read -r namedotcom_server
                if [ -z "${namedotcom_server}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n namecom_server_prompt)"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "6" ]; then
            dns="vultr"
            echo -e "\n\n->$(i18n dns_selected_vultr)\n"
            echoColor green "$(i18n vultr_token_prompt)"
            while :; do
                read -r vultr_api_token
                if [ -z "${vultr_api_token}" ]; then
                    echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                    echoColor green "$(i18n vultr_token_prompt)"
                else
                    break
                fi
            done
        else
            echoColor red "$(i18n input_error_please_retry)"
        fi
        ip=$(curl -4 -s -m 8 ip.sb)
        if [ -z "${ip}" ]; then
            ip=$(curl -s -m 8 ip.sb)
        fi
        echoColor green "$(i18n public_ip_check)"$(echoColor red ${ip})"\n"
        while true; do
            echoColor green "$(i18n prompt_choose)"
            echoColor yellow "$(i18n ip_correct_default)"
            echoColor yellow "$(i18n ip_incorrect)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r ipNum
            if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                break
            elif [ "${ipNum}" == "2" ]; then
                echoColor green "$(i18n ip_prompt)"
                read -r ip
                if [ -z "${ip}" ]; then
                    echoColor red "$(i18n input_error_retry)"
                    continue
                fi
                break
            else
                echoColor red "$(i18n input_error_please_retry)"
            fi
        done
        echo -e "\n\n->$(i18n dns_acme_summary)"$(echoColor red ${domain})"\n"
        echo -e "\n ->$(i18n dns_method_label)"$(echoColor red ${dns})"\n"
        echo -e "\n ->$(i18n public_ip_label)"$(echoColor red ${ip})"\n"
        useAcme=true
        useDns=true
    else
        echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
            else
                break
            fi
        done
        while :; do
            echoColor purple "\n->$(i18n detecting_domain_dns ${domain})"
            ip_resolv=$(dig +short ${domain} A)
            if [ -z "${ip_resolv}" ]; then
                ip_resolv=$(dig +short ${domain} AAAA)
            fi
            if [ -z "${ip_resolv}" ]; then
                echoColor red "\n\n->$(i18n dns_resolution_failed)"
                echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                read -r domain
                continue
            fi
            remoteip=$(echo ${ip_resolv} | awk -F " " '{print $1}')
            v6str=":"
            result=$(echo ${remoteip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                localip=$(curl -6 -s -m 8 ip.sb)
            else
                localip=$(curl -4 -s -m 8 ip.sb)
            fi
            if [ -z "${localip}" ]; then
                localip=$(curl -s -m 8 ip.sb)
                if [ -z "${localip}" ]; then
                    echoColor red "\n\n->$(i18n local_ip_fetch_failed)"
                    exit 1
                fi
            fi
            if [ "${localip}" != "${remoteip}" ]; then
                echo -e " \n\n->$(i18n local_ip_label)"$(echoColor red ${localip})" \n\n->$(i18n domain_ip_label)"$(echoColor red ${remoteip})"\n"
                echoColor green "$(i18n self_assign_ip_prompt)"
                read -r isLocalip
                if [ "${isLocalip}" == "y" ]; then
                    echoColor green "$(i18n enter_local_ip)"
                    read -r localip
                    while :; do
                        if [ -z "${localip}" ]; then
                            echoColor red "\n\n->$(i18n this_option_cannot_be_empty)"
                            echoColor green "$(i18n enter_local_ip)"
                            read -r localip
                        else
                            break
                        fi
                    done
                fi
                if [ "${localip}" != "${remoteip}" ]; then
                    echoColor red "\n\n->$(i18n domain_ip_mismatch)"
                    echoColor green "$(i18n domain_prompt) $(i18n domain_requirement)"
                    read -r domain
                    continue
                else
                    break
                fi
            else
                break
            fi
        done
        useAcme=true
        useDns=false
        echoColor purple "\n\n->$(i18n acme_summary)"$(echoColor red ${domain})"\n"
    fi

    if [ "${realmMode}" == "true" ]; then
        port=""
        echoColor purple "\n->$(i18n realm_skip_port)\n"
    else
        while :; do
            echoColor green "\n$(i18n port_prompt)"
            echo "$(i18n port_hint)"
            read -r port
            if [ -z "${port}" ]; then
                port=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
                echo -e "\n->$(i18n random_port_label)"$(echoColor red udp/${port})"\n"
            else
                echo -e "\n->$(i18n entered_port_label)"$(echoColor red udp/${port})"\n"
            fi
            if [ "${port}" -gt 65535 ]; then
                echoColor red "$(i18n port_range_error)"
                continue
            fi
            pIDa=$(lsof -i udp:${port} | grep -v "PID" | awk '{print $2}')
            if [ "$pIDa" != "" ]; then
                echoColor red "\n->$(i18n port_in_use ${port} ${pIDa} ${pIDa})"
            else
                break
            fi
        done
    fi

    if [ "${realmMode}" != "true" ]; then
        echoColor green "\n$(i18n port_hopping_prompt)"
        echoColor white "$(i18n port_hopping_intro)"
        echoColor white "$(i18n port_hopping_detail_url)"
        echoColor green "$(i18n prompt_choose)"
        echoColor yellow "$(i18n port_hopping_choice_enable)"
        echoColor yellow "$(i18n port_hopping_choice_skip)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r portHoppingStatus
        if [ -z "${portHoppingStatus}" ] || [ "${portHoppingStatus}" == "1" ]; then
            portHoppingStatus="true"
            echoColor purple "$(i18n port_hopping_enabled)"
            echoColor white "$(i18n port_hopping_range_hint)"
            while :; do
                echoColor green "$(i18n port_hopping_start)"
                read -r portHoppingStart
                if [ -z "${portHoppingStart}" ]; then
                    portHoppingStart=47000
                fi
                if [ ${portHoppingStart} -gt 65535 ]; then
                    echoColor red "$(i18n port_range_error)"
                    continue
                fi
                echo -e "\n->$(i18n start_port_label)"$(echoColor red ${portHoppingStart})"\n"
                echoColor green "$(i18n port_hopping_end)"
                read -r portHoppingEnd
                if [ -z "${portHoppingEnd}" ]; then
                    portHoppingEnd=48000
                fi
                if [ ${portHoppingEnd} -gt 65535 ]; then
                    echoColor red "$(i18n port_range_error)"
                    continue
                fi
                echo -e "\n->$(i18n end_port_label)"$(echoColor red ${portHoppingEnd})"\n"
                if [ ${portHoppingStart} -ge ${portHoppingEnd} ]; then
                    echoColor red "$(i18n start_port_greater_error)"
                else
                    break
                fi
            done
            echoColor green "$(i18n port_hopping_mode_prompt)"
            echoColor yellow "$(i18n port_hopping_mode_fixed)"
            echoColor yellow "$(i18n port_hopping_mode_random)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r portHoppingIntervalModeNum
            if [ -z "${portHoppingIntervalModeNum}" ] || [ "${portHoppingIntervalModeNum}" == "1" ]; then
                portHoppingIntervalMode="fixed"
                while :; do
                    echoColor green "$(i18n fixed_hop_interval_prompt)"
                    read -r portHoppingHopInterval
                    if [ -z "${portHoppingHopInterval}" ]; then
                        portHoppingHopInterval="30s"
                    fi
                    echo -e "\n->$(i18n fixed_hop_interval_label)"$(echoColor red ${portHoppingHopInterval})"\n"
                    hopSeconds=$(echo "${portHoppingHopInterval}" | sed 's/s$//')
                    if ! echo "${hopSeconds}" | grep -Eq '^[0-9]+$' || [ "${hopSeconds}" -lt 5 ]; then
                        echoColor red "$(i18n fixed_hop_interval_error)"
                        continue
                    fi
                    break
                done
                portHoppingMinHopInterval=""
                portHoppingMaxHopInterval=""
            else
                portHoppingIntervalMode="random"
                portHoppingHopInterval=""
                while :; do
                    echoColor green "$(i18n min_hop_interval_prompt)"
                    read -r portHoppingMinHopInterval
                    if [ -z "${portHoppingMinHopInterval}" ]; then
                        portHoppingMinHopInterval="10s"
                    fi
                    echo -e "\n->$(i18n min_hop_interval_label)"$(echoColor red ${portHoppingMinHopInterval})"\n"
                    minHopSeconds=$(echo "${portHoppingMinHopInterval}" | sed 's/s$//')
                    if ! echo "${minHopSeconds}" | grep -Eq '^[0-9]+$' || [ "${minHopSeconds}" -lt 5 ]; then
                        echoColor red "$(i18n min_hop_interval_error)"
                        continue
                    fi
                    echoColor green "$(i18n max_hop_interval_prompt)"
                    read -r portHoppingMaxHopInterval
                    if [ -z "${portHoppingMaxHopInterval}" ]; then
                        portHoppingMaxHopInterval="30s"
                    fi
                    echo -e "\n->$(i18n max_hop_interval_label)"$(echoColor red ${portHoppingMaxHopInterval})"\n"
                    maxHopSeconds=$(echo "${portHoppingMaxHopInterval}" | sed 's/s$//')
                    if ! echo "${maxHopSeconds}" | grep -Eq '^[0-9]+$' || [ "${maxHopSeconds}" -lt "${minHopSeconds}" ]; then
                        echoColor red "$(i18n max_hop_interval_error)"
                        continue
                    fi
                    break
                done
            fi
            clientPort="${portHoppingStart}-${portHoppingEnd}"
            echo -e "\n->$(i18n port_hopping_range_label)"$(echoColor red ${portHoppingStart}-${portHoppingEnd})"\n"
            if [ "${portHoppingIntervalMode}" == "fixed" ]; then
                echo -e "\n->$(i18n fixed_hop_interval_summary)"$(echoColor red ${portHoppingHopInterval})"\n"
            else
                echo -e "\n->$(i18n random_hop_interval_summary)"$(echoColor red ${portHoppingMinHopInterval}~${portHoppingMaxHopInterval})"\n"
            fi
        else
            portHoppingStatus="false"
            portHoppingIntervalMode=""
            portHoppingHopInterval=""
            portHoppingMinHopInterval=""
            portHoppingMaxHopInterval=""
            echoColor red "$(i18n port_hopping_disabled)"
        fi
    else
        portHoppingStatus="false"
        echoColor purple "\n->$(i18n realm_skip_port_hopping)\n"
    fi

    echoColor green "$(i18n congestion_title)"
    echoColor white "$(i18n congestion_reno_hint)"
    echoColor white "$(i18n congestion_bbr_hint)"
    echoColor white "$(i18n congestion_brutal_hint)"
    echoColor green "$(i18n prompt_choose)"
    echoColor yellow "$(i18n congestion_choice_reno)"
    echoColor yellow "$(i18n congestion_choice_bbr)"
    echoColor yellow "$(i18n congestion_choice_brutal)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r congestion_num
    if [ "${congestion_num}" == "1" ]; then
        congestion_mode="reno"
        congestion_type="reno"
        congestion_bbr_profile=""
        ignore_client_bandwidth="true"
        echo -e "\n->$(i18n congestion_selected_reno)\n"
    elif [ "${congestion_num}" == "2" ]; then
        congestion_mode="bbr"
        congestion_type="bbr"
        ignore_client_bandwidth="true"
        echoColor green "$(i18n bbr_profile_title)"
        echoColor white "$(i18n bbr_profile_conservative)"
        echoColor white "$(i18n bbr_profile_standard)"
        echoColor white "$(i18n bbr_profile_aggressive)"
        echoColor green "$(i18n bbr_profile_prompt)"
        echoColor yellow "$(i18n bbr_choice_conservative)"
        echoColor yellow "$(i18n bbr_choice_standard)"
        echoColor yellow "$(i18n bbr_choice_aggressive)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r bbr_profile_num
        case ${bbr_profile_num} in
            2) congestion_bbr_profile="conservative" ;;
            3) congestion_bbr_profile="aggressive" ;;
            *) congestion_bbr_profile="standard" ;;
        esac
        echo -e "\n->$(i18n congestion_selected_bbr)"$(echoColor red ${congestion_bbr_profile})"\n"
    else
        congestion_mode="brutal"
        congestion_type=""
        congestion_bbr_profile=""
        ignore_client_bandwidth="false"
        echo -e "\n->$(i18n congestion_selected_brutal)\n"
    fi

    if [ "${congestion_mode}" == "brutal" ]; then
        echoColor green "$(i18n delay_prompt)"
        read -r delay
        if [ -z "${delay}" ]; then
            delay=200
        fi
        echo -e "\n->$(i18n delay_label)"$(echoColor red ${delay})"ms\n"
        echo -e "\n$(i18n bandwidth_expectation)"$(echoColor red "Tips:")
        echoColor green "$(i18n download_prompt)"
        read -r download
        if [ -z "${download}" ]; then
            download=50
        fi
        echo -e "\n->$(i18n download_label)"$(echoColor red ${download})"mbps\n"
        echoColor green "$(i18n upload_prompt)"
        read -r upload
        if [ -z "${upload}" ]; then
            upload=10
        fi
        echo -e "\n->$(i18n upload_label)"$(echoColor red ${upload})"mbps\n"
    else
        delay=""
        download=""
        upload=""
        echoColor lightYellow "$(i18n non_brutal_skip)"
    fi
    echoColor green "$(i18n auth_secret_prompt)"
    read -r auth_secret
    if [ -z "${auth_secret}" ]; then
        auth_secret=$(generate_uuid)
    fi
    echo -e "\n->$(i18n auth_secret_label)"$(echoColor red ${auth_secret})"\n"
    echoColor white "$(i18n obfs_hint)"
    echoColor green "$(i18n obfs_prompt)"
    echoColor yellow "$(i18n obfs_choice_disable)"
    echoColor yellow "$(i18n obfs_choice_salamander)"
    echoColor yellow "$(i18n obfs_choice_gecko)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r obfs_num
    if [ -z "${obfs_num}" ] || [ ${obfs_num} == "1" ]; then
        obfs_status="false"
        obfs_type=""
    elif [ ${obfs_num} == "2" ]; then
        obfs_status="true"
        obfs_type="salamander"
        obfs_pass=${auth_secret}
    else
        obfs_status="true"
        obfs_type="gecko"
        obfs_pass=${auth_secret}
    fi
    if [ "${obfs_status}" == "true" ]; then
        echo -e "\n->$(i18n obfs_enabled ${obfs_type})\n"
    else
        echo -e "\n->$(i18n obfs_disabled)\n"
    fi
    if [ "${realmMode}" != "true" ]; then
        echoColor green "$(i18n masquerade_prompt)"
        echoColor yellow "$(i18n masquerade_choice_string)"
        echoColor yellow "$(i18n masquerade_choice_proxy)"
        echoColor yellow "$(i18n masquerade_choice_file)"
        echoColor green "$(i18n prompt_enter_number)"
        read -r masquerade_type
        if [ -z "${masquerade_type}" ] || [ ${masquerade_type} == "1" ]; then
            masquerade_type="string"
            echoColor green "$(i18n masquerade_string_prompt)"
            read -r masquerade_string
            if [ -z "${masquerade_string}" ]; then
                masquerade_string="HelloWorld"
            fi
            echo -e "\n->$(i18n masquerade_string_label)"$(echoColor red ${masquerade_string})"\n"
            echoColor green "$(i18n masquerade_stuff_prompt)"
            read -r masquerade_stuff
            if [ -z "${masquerade_stuff}" ]; then
                masquerade_stuff="HelloWorld"
            fi
            echo -e "\n->$(i18n masquerade_stuff_label)"$(echoColor red ${masquerade_stuff})"\n"
        elif [ ${masquerade_type} == "2" ]; then
            masquerade_type="proxy"
            echoColor green "$(i18n masquerade_proxy_prompt)"
            echoColor white "$(i18n masquerade_proxy_hint)"
            read -r masquerade_proxy
            if [ -z "${masquerade_proxy}" ]; then
                masquerade_proxy="https://www.helloworld.org"
            fi
            echo -e "\n->$(i18n masquerade_proxy_label)"$(echoColor red ${masquerade_proxy})"\n"
            echoColor green "$(i18n xforwarded_prompt)"
            echoColor yellow "$(i18n xforwarded_choice_enable)"
            echoColor yellow "$(i18n xforwarded_choice_disable)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r masquerade_xforwarded
            if [ -z "${masquerade_xforwarded}" ] || [ "${masquerade_xforwarded}" == "1" ]; then
                masquerade_xforwarded="true"
            else
                masquerade_xforwarded="false"
            fi
            echo -e "\n->$(i18n xforwarded_label)"$(echoColor red ${masquerade_xforwarded})"\n"
        else
            masquerade_type="file"
            masquerade_xforwarded="false"
            echoColor green "$(i18n masquerade_file_prompt)"
            echoColor white "$(i18n masquerade_file_hint)"
            read -r masquerade_file
            if [ -z "${masquerade_file}" ]; then
                masquerade_file="/etc/hihy/file"
            fi
            echo -e "\n->$(i18n masquerade_file_label)"$(echoColor red ${masquerade_file})"\n"
        fi
        if [ "${masquerade_type}" != "proxy" ]; then
            masquerade_xforwarded="false"
        fi
        if [ "${realmMode}" == "true" ]; then
            masquerade_tcp="false"
            echoColor purple "$(i18n realm_skip_masquerade_tcp)"
        else
            echoColor green "$(i18n masquerade_tcp_prompt ${port})"
            echoColor lightYellow "$(i18n masquerade_tcp_hint1)"
            echoColor white "$(i18n masquerade_tcp_hint2)"
            echoColor green "$(i18n prompt_choose)"
            echoColor yellow "$(i18n masquerade_tcp_choice_enable)"
            echoColor yellow "$(i18n masquerade_tcp_choice_skip)"
            echoColor green "$(i18n prompt_enter_number)"
            read -r masquerade_tcp
            if [ -z "${masquerade_tcp}" ] || [ ${masquerade_tcp} == "1" ]; then
                masquerade_tcp="true"
                echo -e "\n->$(i18n masquerade_tcp_enabled ${port})\n"
            else
                masquerade_tcp="false"
                echo -e "\n->$(i18n masquerade_tcp_disabled ${port})\n"
            fi
        fi
    fi
    echoColor green "$(i18n block_http3_prompt)"
    echoColor lightYellow "$(i18n block_http3_hint1)"
    echoColor white "$(i18n block_http3_hint2)"
    echoColor green "$(i18n prompt_choose)"
    echoColor yellow "$(i18n block_http3_choice_enable)"
    echoColor yellow "$(i18n block_http3_choice_skip)"
    echoColor green "$(i18n prompt_enter_number)"
    read -r block_http3
    if [ -z "${block_http3}" ] || [ ${block_http3} == "2" ]; then
        block_http3="false"
        echo -e "\n->$(i18n block_http3_disabled)\n"
        echoColor lightYellow "$(i18n client_only_block_http3_tip)"
    else
        block_http3="true"
        echoColor red "$(i18n block_http3_enabled)"
    fi
    echoColor green "$(i18n remarks_prompt)"
    read -r remarks
    echoColor green "$(i18n config_input_done)"
    echoColor yellowBlack "$(i18n config_executing)"
    max_CRW=0
    if [ "${congestion_mode}" == "brutal" ]; then
        download=$(($download + $download / 10))
        upload=$(($upload + $upload / 10))
        CRW=$(($delay * $download * 1000000 / 1000 * 2))
        SRW=$(($CRW / 5 * 2))
        max_CRW=$(($CRW * 3 / 2))
        max_SRW=$(($SRW * 3 / 2))
        server_upload=${download}
        server_download=${upload}
    fi

    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" "${realmURI}"
    elif [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" ":${port},${portHoppingStart}-${portHoppingEnd}"
    else
        addOrUpdateYaml "$yaml_file" "listen" ":${port}"
    fi
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "realm.stunServers[0]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunServers[1]" "global.stun.twilio.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.punchTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.heartbeatInterval" "30s"
        addOrUpdateYaml "$yaml_file" "realm.insecure" "false"
        addOrUpdateYaml "$yaml_file" "realm.ipMode" "dual"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.enabled" "true"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.timeout" "30s"
        addOrUpdateYaml "$yaml_file" "realm.portMapping.lifetime" "10m"
    else
        yq eval 'del(.realm)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "auth.type" "password"
    addOrUpdateYaml "$yaml_file" "auth.password" "${auth_secret}"
    addOrUpdateYaml "$yaml_file" "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_mode}" != "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.type" "${congestion_type}"
    else
        yq eval 'del(.congestion)' -i "$yaml_file"
    fi
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.bbrProfile" "${congestion_bbr_profile}"
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "obfs.type" "${obfs_type}"
        addOrUpdateYaml "$yaml_file" "obfs.${obfs_type}.password" "${obfs_pass}"
    else
        yq eval 'del(.obfs)' -i "$yaml_file"
    fi
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "quic.initStreamReceiveWindow" "${SRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxStreamReceiveWindow" "${max_SRW}"
        addOrUpdateYaml "$yaml_file" "quic.initConnReceiveWindow" "${CRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxConnReceiveWindow" "${max_CRW}"
    else
        yq eval 'del(.quic.initStreamReceiveWindow, .quic.maxStreamReceiveWindow, .quic.initConnReceiveWindow, .quic.maxConnReceiveWindow)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "quic.maxIdleTimeout" "30s"
    addOrUpdateYaml "$yaml_file" "quic.maxIncomingStreams" "1024"
    addOrUpdateYaml "$yaml_file" "quic.disablePathMTUDiscovery" "false"
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "bandwidth.up" "${server_upload}mbps"
        addOrUpdateYaml "$yaml_file" "bandwidth.down" "${server_download}mbps"
    else
        yq eval 'del(.bandwidth)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "acl.file" "${acl_file}"
    case ${masquerade_type} in
        "string")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.content" "${masquerade_string}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.content-type" "text/plain"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.custom-stuff" "${masquerade_stuff}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.statusCode" "200"
            ;;
        "proxy")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "proxy"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.url" "${masquerade_proxy}"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.rewriteHost" "true"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.insecure" "true"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.xForwarded" "${masquerade_xforwarded}"
            ;;
        "file")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "file"
            addOrUpdateYaml "$yaml_file" "masquerade.file.dir" "${masquerade_file}"
            if [ ! -d "${masquerade_file}" ]; then
                mkdir -p ${masquerade_file}
                wget -q -O ./mikutap.tar.gz https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
                tar -xzf ./mikutap.tar.gz -C ${masquerade_file} --strip-components=1
                rm -r ./mikutap.tar.gz
            fi
            ;;
    esac
    if [ "${realmMode}" != "true" ] && [ "${masquerade_tcp}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "masquerade.listenHTTPS" ":${port}"
    fi
    addOrUpdateYaml "$yaml_file" "speedTest" "true"
    pinSHA256=""
    if echo "${useAcme}" | grep -q "false"; then
        if echo "${useLocalCert}" | grep -q "false"; then
            v6str=":"
            result=$(echo ${ip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                ip="[${ip}]"
            fi
            u_host=${ip}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${ip}"
            fi
            insecure="0"
            days=3650
            mail="no-reply@qq.com"
            echoColor purple "$(i18n cert_generating_start)"
            echoColor green "$(i18n cert_ca_key)"
            openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048
            echoColor green "$(i18n cert_ca_cert)"
            openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt
            echoColor green "$(i18n cert_server_key_csr)"
            openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=${domain}" -out /etc/hihy/cert/${domain}.csr
            echoColor green "$(i18n cert_sign_server)"
            openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt
            echoColor green "$(i18n cert_cleanup)"
            rm /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr
            echoColor green "$(i18n cert_move_ca)"
            mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result
            echoColor purple "$(i18n cert_success)"
            pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in /etc/hihy/cert/${domain}.crt 2>/dev/null | sed 's/^.*=//')
            if [ -n "${pinSHA256}" ]; then
                echoColor green "$(i18n cert_sha256_label)"$(echoColor red ${pinSHA256})
                echoColor purple "$(i18n cert_pinsha256_hint)"
            else
                echoColor yellow "$(i18n cert_fingerprint_fail)"
                insecure="1"
            fi
            addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt"
            addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key"
            if [ "${realmMode}" == "true" ]; then
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "disable"
            else
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
            fi
        else
            u_host=${domain}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${domain}"
            fi
            insecure="0"
            addOrUpdateYaml "$yaml_file" "tls.cert" "${local_cert}"
            addOrUpdateYaml "$yaml_file" "tls.key" "${local_key}"
            if [ "${realmMode}" == "true" ]; then
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "disable"
            else
                addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
            fi
        fi
    else
        u_host=${domain}
        u_domain=${domain}
        insecure="0"
        if [ -z "${remarks}" ]; then
            remarks="${domain}"
        fi
        addOrUpdateYaml "$yaml_file" "acme.domains" "${domain}"
        addOrUpdateYaml "$yaml_file" "acme.email" "pekora@${domain}"
        addOrUpdateYaml "$yaml_file" "acme.ca" "letsencrypt"
        addOrUpdateYaml "$yaml_file" "acme.dir" "/etc/hihy/cert"
        if [ "${useDns}" == "true" ]; then
            u_host=${ip}
            addOrUpdateYaml "$yaml_file" "acme.type" "dns"
            case ${dns} in
                "cloudflare")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "cloudflare"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.cloudflare_api_token" "${cloudflare_api_token}"
                    ;;
                "duckdns")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "duckdns"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_api_token" "${duckdns_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_override_domain" "${duckdns_override_domain}"
                    ;;
                "gandi")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "gandi"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.gandi_api_token" "${gandi_api_token}"
                    ;;
                "godaddy")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "godaddy"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.godaddy_api_token" "${godaddy_api_token}"
                    ;;
                "namedotcom")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "namedotcom"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_api_token" "${namedotcom_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_user" "${namedotcom_user}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_server" "${namedotcom_server}"
                    ;;
                "vultr")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "vultr"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.vultr_api_token" "${vultr_api_token}"
                    ;;
            esac
        else
            getPortBindMsg TCP 80
            allowPort tcp 80
            addOrUpdateYaml "$yaml_file" "acme.type" "http"
            addOrUpdateYaml "$yaml_file" "acme.listenHost" "0.0.0.0"
        fi
    fi
    if [ "${realmMode}" == "true" ]; then
        u_host="${realmURI}"
    fi

    addOrUpdateYaml "$yaml_file" "sniff.enabled" "true"
    addOrUpdateYaml "$yaml_file" "sniff.timeout" "2s"
    addOrUpdateYaml "$yaml_file" "sniff.rewriteDomain" "false"
    addOrUpdateYaml "$yaml_file" "sniff.tcpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "sniff.udpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "outbounds[0].name" "hihy" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.mode" "auto" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[1].name" "v4_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.mode" "4" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[2].name" "v6_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.mode" "6" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.fastOpen" "false" "bool"
    trafficPort=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
    if [ "$trafficPort" == "${port}" ]; then
        trafficPort=$((${port} + 1))
    fi
    addOrUpdateYaml "$yaml_file" "trafficStats.listen" "127.0.0.1:${trafficPort}"
    addOrUpdateYaml "$yaml_file" "trafficStats.secret" "${auth_secret}"
    if [ ${block_http3} == "true" ]; then
        echo -e "reject(all, udp/443)" >${acl_file}
    fi
    if [ ${max_CRW} -gt 0 ]; then
        sysctl -w net.core.rmem_max=${max_CRW}
        sysctl -w net.core.wmem_max=${max_CRW}
    fi
    if echo "${portHoppingStatus}" | grep -q "true"; then
        sysctl -w net.ipv4.ip_forward=1
        sysctl -w net.ipv6.conf.all.forwarding=1
    fi
    if [ ! -f "/etc/sysctl.conf" ]; then
        touch /etc/sysctl.conf
    fi
    sysctl -p
    echoColor purple "\n$(i18n test_config)\n"
    startInstallValidationProcess "${yaml_file}" "./hihy_debug.info"
    if [ "${useAcme}" == "true" ]; then
        countdown 20
    else
        countdown 10
    fi
    msg=$(cat ./hihy_debug.info)
    case ${msg} in
        *"failed to get a certificate with ACME"*)
            markInstallFailed "certificate" "failed to get a certificate with ACME"
            echoColor red "$(i18n acme_cert_fail ${u_host})"
            rm /etc/hihy/conf/config.yaml
            rm /etc/hihy/result/backup.yaml
            delHihyFirewallPort
            rm ./hihy_debug.info
            echoColor yellow "$(i18n acme_incomplete_state)"
            exit
            ;;
        *"bind: address already in use"*)
            markInstallFailed "port-bind" "bind: address already in use"
            rm /etc/hihy/conf/config.yaml
            rm /etc/hihy/result/backup.yaml
            delHihyFirewallPort
            echoColor red "$(i18n port_bind_fail)"
            rm ./hihy_debug.info
            echoColor yellow "$(i18n acme_incomplete_state)"
            exit
            ;;
        *"server up and running"*)
            echoColor green "$(i18n test_success)"
            echoColor purple "$(i18n stop_test_program)"
            pkill -f "/etc/hihy/bin/appS"
            rm ./hihy_debug.info
            if [ "${realmMode}" != "true" ]; then
                allowPort udp ${port}
                if [ "${portHoppingStatus}" == "true" ]; then
                    allowPort udp ${portHoppingStart}:${portHoppingEnd}
                fi
                if [ "${masquerade_tcp}" == "true" ]; then
                    getPortBindMsg TCP ${port}
                    allowPort tcp ${port}
                fi
            fi
            echoColor purple "$(i18n generating_config)"
            ;;
        *)
            markInstallFailed "config-test" "unknown error while validating generated config"
            if ! command -v pkill >/dev/null 2>&1; then
                apk add --no-cache procps
            fi
            pkill -f "/etc/hihy/bin/appS"
            echoColor red "$(i18n unknown_error)"
            echoColor yellow "$(i18n unknown_error_incomplete_state)"
            cat ./hihy_debug.info
            rm ./hihy_debug.info
            exit
            ;;
    esac
    if [ -f "/etc/hihy/conf/backup.yaml" ]; then
        rm /etc/hihy/conf/backup.yaml
    fi
    backup_file="/etc/hihy/conf/backup.yaml"
    touch ${backup_file}
    addOrUpdateYaml ${backup_file} "remarks" "${remarks}"
    addOrUpdateYaml ${backup_file} "serverAddress" "${u_host}" "string"
    addOrUpdateYaml ${backup_file} "serverPort" "${port}"
    addOrUpdateYaml ${backup_file} "congestionMode" "${congestion_mode}"
    addOrUpdateYaml ${backup_file} "congestionType" "${congestion_type}"
    addOrUpdateYaml ${backup_file} "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml ${backup_file} "congestionBbrProfile" "${congestion_bbr_profile}"
    fi
    addOrUpdateYaml ${backup_file} "portHoppingStatus" "${portHoppingStatus}"
    addOrUpdateYaml ${backup_file} "portHoppingStart" "${portHoppingStart}"
    addOrUpdateYaml ${backup_file} "portHoppingEnd" "${portHoppingEnd}"
    addOrUpdateYaml ${backup_file} "portHoppingIntervalMode" "${portHoppingIntervalMode}"
    addOrUpdateYaml ${backup_file} "portHoppingHopInterval" "${portHoppingHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMinHopInterval" "${portHoppingMinHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMaxHopInterval" "${portHoppingMaxHopInterval}"
    addOrUpdateYaml ${backup_file} "domain" "${domain}"
    addOrUpdateYaml ${backup_file} "trafficPort" "${trafficPort}"
    addOrUpdateYaml ${backup_file} "socks5_status" "false"
    addOrUpdateYaml ${backup_file} "realmMode" "${realmMode}"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml ${backup_file} "realmURI" "${realmURI}"
        addOrUpdateYaml ${backup_file} "realmName" "${realmName}"
    fi
    addOrUpdateYaml ${backup_file} "masquerade_xforwarded" "${masquerade_xforwarded}"
    if [ "$masquerade_tcp" == "true" ]; then
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "true"
    else
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "false"
    fi
    if [ ${insecure} == "1" ]; then
        addOrUpdateYaml ${backup_file} "insecure" "true"
    else
        addOrUpdateYaml ${backup_file} "insecure" "false"
    fi
    if [ -n "${pinSHA256}" ]; then
        addOrUpdateYaml ${backup_file} "pinSHA256" "${pinSHA256}" "string"
    fi
    if ! installHihyLauncher; then
        markInstallFailed "launcher" "failed to install hihy launcher"
        echoColor red "$(i18n hihy_cmd_install_fail)"
        exit 1
    fi
    clearInstallFailureMarker
    echoColor greenWhite "$(i18n install_success)"
}

downloadHysteriaCore() {
    local version
    version=$(getLatestHysteriaVersion)

    echo -e "The Latest hysteria version: $(echoColor red "${version}")\nDownload..."

    if [ -z "$version" ]; then
        echoColor red "[Network error]: Failed to get the latest version of hysteria in Github!"
        exit 1
    fi

    local arch=$(uname -m)
    local url_base="https://github.com/apernet/hysteria/releases/download/${version}/hysteria-linux-"
    local download_url=""

    case "$arch" in
        "x86_64")
            download_url="${url_base}amd64"
            ;;
        "aarch64")
            download_url="${url_base}arm64"
            ;;
        "mips64")
            download_url="${url_base}mipsle"
            ;;
        "s390x")
            download_url="${url_base}s390x"
            ;;
        "i686" | "i386")
            download_url="${url_base}386"
            ;;
        "loongarch64")
            download_url="${url_base}loong64"
            ;;
        *)
            echoColor yellowBlack "Error[OS Message]:${arch}\nPlease open an issue at https://github.com/emptysuns/Hi_Hysteria/issues !"
            exit 1
            ;;
    esac

    wget -q -O /etc/hihy/bin/appS --no-check-certificate "$download_url"

    if [ -f "/etc/hihy/bin/appS" ]; then
        chmod 755 /etc/hihy/bin/appS
        echoColor purple "\nDownload completed."
    else
        echoColor red "Network Error: Can't connect to Github!"
        exit 1
    fi
}

updateHysteriaCore() {
    if [ -f "/etc/hihy/bin/appS" ]; then
        local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
        local remoteV
        remoteV=$(getLatestHysteriaVersion || true)
        echo -e "Local core version: $(echoColor red "${localV}")"
        echo -e "Remote core version: $(echoColor red "${remoteV}")"
        if [ "${localV}" = "${remoteV}" ]; then
            echoColor green "Already the latest version. Ignore."
        else
            local was_running="false"
            if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
                if [ -f "/etc/rc.d/hihy" ]; then
                    msg=$(/etc/rc.d/hihy status)
                else
                    msg=$(/etc/init.d/hihy status)
                fi
                if [ "${msg}" == "hihy is running" ]; then
                    was_running="true"
                    stop
                    # 等待进程完全退出后再下载新二进制文件，避免 "Text file busy" 导致下载失败
                    local wait_count=0
                    while pgrep -f "/etc/hihy/bin/appS" >/dev/null 2>&1 && [ $wait_count -lt 10 ]; do
                        sleep 1
                        wait_count=$((wait_count + 1))
                    done
                fi
            fi

            downloadHysteriaCore
            # 清除版本检查缓存，确保下次运行重新检查（避免显示过时的"有新版本"通知）
            rm -f "$HIHY_VERSION_STATUS_FILE"

            if [ "${was_running}" == "true" ]; then
                start
            fi
            echoColor green "Hysteria Core update done."
        fi
    else
        echoColor red "Hysteria core not found."
        exit 1
    fi
}

hihy_update_notifycation() {
    displayCachedVersionNotifications
}

hihyUpdate() {
    localV=${hihyV}
    remoteV=$(getLatestHihyVersion || true)
    if [ -z $remoteV ]; then
        echoColor red "Network Error: Can't connect to Github!"
        exit
    fi
    if [ "${localV}" = "${remoteV}" ]; then
        echoColor green "Already the latest version.Ignore."
        # 清除版本检查缓存，防止因缓存过期而显示过时的"有新版本"通知
        rm -f "$HIHY_VERSION_STATUS_FILE"
    else
        rm -f "$HIHY_BIN_LINK"
        if ! installHihyLauncher /dev/null "$HIHY_BIN_LINK"; then
            echoColor red "hihy更新失败,请检查网络或写入权限."
            exit 1
        fi
        echoColor green "hihy更新完成."
        # 清除版本检查缓存，确保下次运行时重新检查并显示正确状态
        rm -f "$HIHY_VERSION_STATUS_FILE"
    fi

}

hyCore_update_notifycation() {
    displayCachedVersionNotifications
}

setup_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Setting up rc.local with systemd..."

        # 创建 /etc/systemd/system/rc-local.service 文件
        cat <<EOF | tee /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF
        # 启用 rc-local 服务
        systemctl enable rc-local

        echo "rc.local has been set up and started with systemd."
    fi
}

uninstall_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Uninstalling rc.local systemd service..."

        # 停止并禁用 rc-local 服务
        systemctl stop rc-local
        systemctl disable rc-local

        # 删除 /etc/systemd/system/rc-local.service 文件
        rm /etc/systemd/system/rc-local.service

        # 重新加载 systemd 配置
        systemctl daemon-reload

        echo "rc.local systemd service has been uninstalled."
    fi
}

install() {
    local install_state
    install_state=$(classifyInstallState)

    if [ "$install_state" = "installed" ]; then
        echoColor green "你已经成功安装hysteria,如需修改配置请使用选项9/12"
        exit 0
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "检测到未完成的安装残留，正在清理脚本管理的文件后继续安装..."
        cleanupLegacyPortHoppingNatIfPresent >/dev/null 2>&1 || true
        delHihyFirewallPort udp >/dev/null 2>&1 || true
        delHihyFirewallPort tcp >/dev/null 2>&1 || true
        recoverPartialInstallState
        echoColor purple "已完成部分安装状态恢复，继续执行安装。"
    fi

    # 创建必要目录
    mkdir -p /etc/hihy/{bin,conf,cert,result,logs}
    markInstallFailed "install-start" "installation started but not completed"
    echoColor purple "Ready to install.\n"

    # 尽早安装 hihy 启动器，确保即使后续步骤失败，用户仍可用 hihy 命令重试
    if ! installHihyLauncher; then
        markInstallFailed "launcher" "failed to install hihy launcher at start"
        echoColor red "hihy 命令安装失败,请检查网络或写入权限后重试."
        exit 1
    fi

    # 获取版本并下载核心
    version=$(getLatestHysteriaVersion || true)
    checkSystemForUpdate
    downloadHysteriaCore
    setHysteriaConfig

    # 获取启动命令前缀
    local start_cmd_prefix=$(getStartCommand)

    if [ -f "/etc/alpine-release" ]; then
        # 使用 OpenRC
        cat >/etc/init.d/hihy <<EOF
#!/sbin/openrc-run

name="hihy"
description="Hysteria Proxy Service"
supervisor="supervise-daemon"
command="${start_cmd_prefix} /etc/hihy/bin/appS"
command_args="--log-level info -c /etc/hihy/conf/config.yaml server"
command_background="yes"
pidfile="/var/run/hihy.pid"
output_log="/etc/hihy/logs/hihy.log"
error_log="/etc/hihy/logs/hihy.log"

extra_started_commands="log status"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /etc/hihy/logs
}

start() {
    if [ -f "\$pidfile" ] && kill -0 \$(cat "\$pidfile") 2>/dev/null; then
        eerror "hihy is already running"
        return 1
    fi

    ebegin "Starting hihy"
    mkdir -p \$(dirname "\$output_log")
    nohup \$command \$command_args > "\$output_log" 2>&1 &
    echo \$! > "\$pidfile"
    eend \$?
}

stop() {
    if [ ! -f "\$pidfile" ]; then
        eerror "hihy is not running"
        return 1
    fi

    ebegin "Stopping hihy"
    kill \$(cat "\$pidfile")
    rm -f "\$pidfile"
    eend \$?
}

restart() {
    stop
    sleep 2
    if [ -f "\$pidfile" ]; then
        eerror "Failed to stop hihy"
        return 1
    fi
    start
}

status() {
    if [ -f "\$pidfile" ] && kill -0 \$(cat "\$pidfile") 2>/dev/null; then
        einfo "hihy is running"
    else
        einfo "hihy is not running"
    fi
}

log() {
    tail -f "\$output_log"
}
EOF
        chmod +x /etc/init.d/hihy
        rc-update add hihy default
        rc-service hihy start

    else
        # 使用传统启动脚本
        mkdir -p /etc/rc.d
        cat >/etc/rc.d/hihy <<EOF
#!/bin/sh

HIHY_PATH="/etc/hihy"
PID_FILE="/var/run/hihy.pid"
LOG_FILE="\$HIHY_PATH/logs/hihy.log"
START_CMD_PREFIX="${start_cmd_prefix}"

start() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "hihy is already running"
        return 1
    fi

    echo "Starting hihy..."
    if [ -n "\$START_CMD_PREFIX" ]; then
        nohup \$START_CMD_PREFIX \$HIHY_PATH/bin/appS --log-level info -c \$HIHY_PATH/conf/config.yaml server > "\$LOG_FILE" 2>&1 &
    else
        nohup \$HIHY_PATH/bin/appS --log-level info -c \$HIHY_PATH/conf/config.yaml server > "\$LOG_FILE" 2>&1 &
    fi
    echo \$! > "\$PID_FILE"
}

stop() {
    if [ ! -f "\$PID_FILE" ]; then
        echo "hihy is not running"
        return 1
    fi

    echo "Stopping hihy..."
    kill \$(cat "\$PID_FILE")
    rm -f "\$PID_FILE"
}

restart() {
    stop
    sleep 2
    if [ -f "\$PID_FILE" ]; then
        echo "Failed to stop hihy"
        return 1
    fi
    start
}

status() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "hihy is running"
    else
        echo "hihy is not running"
    fi
}

log() {
    tail -f "\$LOG_FILE"
}

case "\$1" in
    start|stop|restart|status|log)
        \$1
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|log}"
        exit 1
        ;;
esac
EOF
        chmod +x /etc/rc.d/hihy

        # 尝试添加到现有的启动配置
        if [ -d "/etc/init.d" ]; then
            ln -sf /etc/rc.d/hihy /etc/init.d/hihy
        fi

        if [ ! -f "/etc/rc.local" ]; then
            touch /etc/rc.local
            echo "#!/bin/bash" >/etc/rc.local
            chmod +x /etc/rc.local
        fi
        if ! grep -q "/etc/rc.d/hihy start" /etc/rc.local; then
            echo "/etc/rc.d/hihy start" >>/etc/rc.local
        fi
        # 启动服务
        /etc/rc.d/hihy start
    fi

    # 添加定时任务
    crontab -l >./crontab.tmp 2>/dev/null || touch ./crontab.tmp
    echo "15 4 * * 1 hihy cronTask" >>./crontab.tmp
    crontab ./crontab.tmp
    rm ./crontab.tmp
    setup_rc_local_for_arch

    generate_client_config
    echoColor yellowBlack "安装完毕"
}

# 将 listen 中的范围端口格式 47000-48000 转换为防火墙规则使用的 47000:48000
formatFirewallPortSpec() {
    local port_spec="$1"
    echo "${port_spec//-/:}"
}

# 将防火墙命令输出按空白拆分成独立 token，再进行精确匹配
hasFirewallToken() {
    local token="$1"
    tr -s '[:space:]' '\n' | grep -Fxq "$token"
}

# 输出ufw端口开放状态
checkUFWAllowPort() {
    local port=$1
    if ufw status | hasFirewallToken "$port"; then
        echoColor purple "UFW OPEN: ${port}"
    else
        echoColor red "UFW OPEN FAIL: ${port}"
        exit 1
    fi
}

# 输出firewall-cmd端口开放状态
checkFirewalldAllowPort() {
    local port=$1
    local protocol=$2
    if firewall-cmd --list-ports --permanent | hasFirewallToken "${port}/${protocol}"; then
        echoColor purple "FIREWALLD OPEN: ${port}/${protocol}"
    else
        echoColor red "FIREWALLD OPEN FAIL: ${port}/${protocol}"
        exit 1
    fi
}

allowPort() {
    # 如果防火墙启动状态则添加相应的开放端口
    # $1 tcp/udp
    # $2 port

    # 检查是否为 Alpine Linux
    if [ -f /etc/alpine-release ]; then
        # Alpine 默认使用 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                echoColor purple "IPTABLES OPEN: ${1}/${2}"

                # 保存 iptables 规则
                if [ -d /etc/iptables ]; then
                    iptables-save >/etc/iptables/rules.v4
                else
                    mkdir -p /etc/iptables
                    iptables-save >/etc/iptables/rules.v4
                fi
            fi
            return 0
        fi

        # 如果没有 iptables，检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset >/etc/nftables.conf
            fi
            return 0
        fi
    else
        # 其他 Linux 发行版的处理逻辑
        # 检查 systemd
        if command -v systemctl >/dev/null 2>&1; then
            # 检查 netfilter-persistent
            if systemctl is-active --quiet netfilter-persistent; then
                if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                    iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                    echoColor purple "IPTABLES OPEN: ${1}/${2}"
                    netfilter-persistent save
                fi
                return 0
            fi

            # 检查 firewalld
            if systemctl is-active --quiet firewalld; then
                if ! firewall-cmd --list-ports --permanent | hasFirewallToken "${2}/${1}"; then
                    firewall-cmd --zone=public --add-port=${2}/${1} --permanent
                    echoColor purple "FIREWALLD OPEN: ${1}/${2}"
                    firewall-cmd --reload
                fi
                return 0
            fi
        fi

        # 检查 UFW
        if command -v ufw >/dev/null 2>&1; then
            if ufw status | hasFirewallToken "active"; then
                if ! ufw status | hasFirewallToken "${2}/${1}"; then
                    ufw allow ${2}/${1}
                    checkUFWAllowPort ${2}/${1}
                fi
                return 0
            fi
        fi

        # 检查 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                mkdir -p /etc/rc.d
                # 在没有netfilter的情况下持久化规则
                if [ ! -f "/etc/rc.d/allow-port" ]; then
                    cat >/etc/rc.d/allow-port <<EOF
#!/bin/sh
iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
EOF
                    chmod +x /etc/rc.d/allow-port
                else
                    if ! grep -q "allow ${1}/${2}(hihysteria)" /etc/rc.d/allow-port; then
                        echo "iptables -I INPUT -p ${1} --dport ${2} -m comment --comment \"allow ${1}/${2}(hihysteria)\" -j ACCEPT" >>/etc/rc.d/allow-port
                    fi
                fi

                if [ ! -f "/etc/rc.local" ]; then
                    touch /etc/rc.local
                    echo "#!/bin/bash" >/etc/rc.local
                    chmod +x /etc/rc.local
                fi
                if ! grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
                    echo "/etc/rc.d/allow-port start" >>/etc/rc.local
                fi
            fi

            echoColor purple "IPTABLES OPEN: ${1}/${2}"
            return 0
        fi

        # 检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset >/etc/nftables.conf
            fi
            return 0
        fi
    fi

    echoColor red "未检测到支持的防火墙工具，请手动开放端口 ${1}/${2}"
    return 1
}

addPortHoppingNat() {
    # $1 portHoppingStart
    # $2 portHoppingEnd
    # $3 portHoppingTarget

    # 检查必需命令
    if ! command -v iptables >/dev/null 2>&1; then
        echoColor red "未找到 iptables,请先安装"
        return 1
    fi
    iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
    ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
    if [ -f "/etc/alpine-release" ]; then
        # Alpine Linux: 使用 OpenRC
        # 确保加载必要模块
        modprobe ip_tables
        modprobe ip6_tables
        modprobe iptable_nat
        modprobe ip6table_nat

        # 创建并初始化 iptables 规则目录
        mkdir -p /etc/iptables

        # 创建基础规则
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -F

        ip6tables -P INPUT ACCEPT
        ip6tables -P FORWARD ACCEPT
        ip6tables -P OUTPUT ACCEPT
        ip6tables -F

        # 保存规则
        /etc/init.d/iptables save
        /etc/init.d/ip6tables save

        # 启动 iptables 服务
        rc-service iptables start
        rc-service ip6tables start

        # 确保服务开机启动
        rc-update add iptables default
        rc-update add ip6tables default

        # 创建 port-hopping 服务
        cat >/etc/init.d/port-hopping <<'EOF'
#!/sbin/openrc-run

description="Port Hopping NAT rules for Hysteria"
depend() {
    need net iptables ip6tables
    after firewall
}

start() {
    ebegin "Adding Port Hopping NAT rules"
EOF
        # 添加实际规则
        echo "    iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment \"NAT $1:$2 to $3 (PortHopping-hihysteria)\" -j DNAT --to-destination :$3" >>/etc/init.d/port-hopping
        echo "    ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment \"NAT $1:$2 to $3 (PortHopping-hihysteria)\" -j DNAT --to-destination :$3" >>/etc/init.d/port-hopping
        cat >>/etc/init.d/port-hopping <<'EOF'
    eend $?
}

stop() {
    ebegin "Removing Port Hopping NAT rules"
    iptables-save | grep -v "PortHopping-hihysteria" | iptables-restore
    ip6tables-save | grep -v "PortHopping-hihysteria" | ip6tables-restore
    eend $?
}
EOF
        chmod +x /etc/init.d/port-hopping

        # 添加到默认运行级别并启动
        rc-update add port-hopping default
        rc-service port-hopping start

    else
        # 其他 Linux 系统的处理保持不变
        mkdir -p /etc/rc.d
        cat >/etc/rc.d/port-hopping <<EOF
#!/bin/sh
iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
EOF
        chmod +x /etc/rc.d/port-hopping

        if [ ! -f "/etc/rc.local" ]; then
            touch /etc/rc.local
            echo "#!/bin/bash" >/etc/rc.local
            chmod +x /etc/rc.local
        fi
        if ! grep -q "/etc/rc.d/port-hopping start" /etc/rc.local; then
            echo "/etc/rc.d/port-hopping start" >>/etc/rc.local
        fi
    fi

    echoColor purple "Port Hopping NAT 规则已添加并持久化。"
}

delPortHoppingNat() {
    # 删除 OpenRC 服务（如果存在）
    if [ -f "/etc/alpine-release" ] && [ -f "/etc/init.d/port-hopping" ]; then
        rc-service port-hopping stop
        rc-update del port-hopping default
        rm -f /etc/init.d/port-hopping
    fi

    # 删除 port-hopping 规则
    if [ -f "/etc/rc.d/port-hopping" ]; then
        rm -f /etc/rc.d/port-hopping
    fi

    # 删除 rc.local port-hopping 规则（如果存在）
    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/port-hopping/d' /etc/rc.local
    fi

    # 删除所有 hihysteria 相关的 NAT 规则
    local nat_rules_v4=$(iptables-save | grep -E "PortHopping-hihysteria|hihysteria")
    local nat_rules_v6=$(ip6tables-save | grep -E "PortHopping-hihysteria|hihysteria")

    if [ -n "$nat_rules_v4" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            # 添加执行结果检查
            if eval "iptables $clean_rule 2>/dev/null" || ! iptables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                # 规则删除成功或规则已不存在都视为成功
                continue
            # else
            #     echoColor yellow "警告: 删除 IPv4 规则失败: $clean_rule"
            fi
        done <<<"$nat_rules_v4"
    fi

    if [ -n "$nat_rules_v6" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            # 添加执行结果检查
            if eval "ip6tables $clean_rule 2>/dev/null" || ! ip6tables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                # 规则删除成功或规则已不存在都视为成功
                continue
            # else
            #     echoColor yellow "警告: 删除 IPv6 规则失败: $clean_rule"
            fi
        done <<<"$nat_rules_v6"
    fi
    # 保存 iptables 规则
    if [ -d "/etc/iptables" ]; then
        iptables-save >/etc/iptables/rules.v4
        ip6tables-save >/etc/iptables/rules.v6
    fi

    echoColor purple "Port Hopping NAT 规则已清理完成"
}

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echoColor red "$(i18n error_root_required)"
        exit 1
    fi
}

uninstall() {
    local install_state
    install_state=$(classifyInstallState)
    portHoppingStatus=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingStatus" "false")
    if [ "$install_state" = "not-installed" ]; then
        echoColor red "Hysteria 未安装!"
        exit 1
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "检测到未完成的安装残留，正在按部分安装状态执行卸载清理..."
    fi

    # 停止服务
    if [ -f "/etc/alpine-release" ]; then
        if [ -f "/etc/init.d/hihy" ]; then
            rc-service hihy stop >/dev/null 2>&1 || true
            rc-update del hihy default >/dev/null 2>&1 || true
            rm -f /etc/init.d/hihy
        fi
    else
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop >/dev/null 2>&1 || true
            rm -f /etc/rc.d/hihy
        fi
    fi

    # 删除 iptables 规则
    if command -v iptables-save >/dev/null 2>&1 && command -v iptables-restore >/dev/null 2>&1; then
        iptables-save 2>/dev/null | grep -v "hihysteria" | iptables-restore >/dev/null 2>&1 || true
    fi
    if command -v ip6tables-save >/dev/null 2>&1 && command -v ip6tables-restore >/dev/null 2>&1; then
        ip6tables-save 2>/dev/null | grep -v "hihysteria" | ip6tables-restore >/dev/null 2>&1 || true
    fi

    # 保存 iptables 规则
    if [ -d "/etc/iptables" ]; then
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save >/etc/iptables/rules.v4
        fi
        if command -v ip6tables-save >/dev/null 2>&1; then
            ip6tables-save >/etc/iptables/rules.v6
        fi
    fi

    # 删除定时任务
    crontab -l 2>/dev/null | grep -v "hihy cronTask" | crontab -

    delHihyFirewallPort udp
    delHihyFirewallPort tcp
    cleanupLegacyPortHoppingNatIfPresent

    # 删除相关目录和文件
    rm -rf /etc/hihy
    rm -f /var/run/hihy.pid

    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/hihy start/d' /etc/rc.local
        if grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
            sed -i '/\/etc\/rc.d\/allow-port start/d' /etc/rc.local
        fi
    fi

    if [ -f "$HIHY_BIN_LINK" ]; then
        rm "$HIHY_BIN_LINK"
    fi

    # 检测并提示卸载WARP/WireProxy
    if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        echoColor purple "\n->检测到WARP/WireProxy安装"
        echoColor green "是否卸载WARP/WireProxy?"
        echo -e "\033[33m\033[01m1、卸载\n2、保留\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r warpUninstallChoice
        if [ -z "${warpUninstallChoice}" ] || [ "${warpUninstallChoice}" == "1" ]; then
            echoColor purple "\n->正在卸载WARP/WireProxy..."
            warp u || true
            echoColor purple "\n->WARP/WireProxy卸载完成"
        else
            echoColor purple "\n->保留WARP/WireProxy安装"
        fi
    fi
    clearInstallFailureMarker

    # 删除 Arch Linux 的 rc.local systemd 服务
    uninstall_rc_local_for_arch
    # 检查是否完全删除
    if [ ! -d "/etc/hihy" ]; then
        echoColor green "Hysteria 已完全卸载!"
    else
        echoColor red "卸载过程中发生错误，请检查是否有残留文件或进程。"
        exit 1
    fi
}

generate_qr() {
    local url=$1

    # 使用最小合法尺寸 1
    local qr_size=1
    local margin=1
    local level="L" # 使用最低纠错级别以减小大小
    # 生成并显示 QR 码
    # -l L: 使用最低级别的纠错
    # -m margin: 设置边距
    # -s 1: 使用最小合法尺寸
    qrencode -t ANSIUTF8 -o - -l "$level" -m "$margin" -s 1 "${url}"

    if [ $? -eq 0 ]; then
        echoColor green "\nQR code generated successfully."
    else
        echoColor red "\nFailed to generate QR code."
        return 1
    fi
}

generate_client_config() {
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "hysteria2 未安装!"
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
    echo -e "📝 生成客户端配置文件..."

    # 美化输出信息
    echo -e "\n✨ 配置信息如下:"
    local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
    echo -e "\n📌 当前hysteria2 server版本: $(echoColor red ${localV})"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "${realmMode}" != "true" ]; then
        if [ "${portHoppingStatus}" == "false" ]; then
            echo -e "⚠️  注意: 伪装并未监听tcp端口"
            echo -e "💡 您可能需要$(echoColor red 手动在浏览器添加h3)支持才能访问"
        fi

        if [ -n "${pinSHA256}" ]; then
            echo -e "\n🔐 安全提示:"
            echo -e "🔒 您使用自签证书,客户端已通过 $(echoColor red pinSHA256) 校验证书指纹,连接安全,无需开启不安全连接(insecure)。"
            echo -e "   证书指纹: $(echoColor red ${pinSHA256})"
            echo -e "   如需在浏览器访问伪装网站,可自行信任证书或设置 hosts 指向该域名。"
        elif [ "${insecure}" == "true" ]; then
            echo -e "\n⚠️  安全提示:"
            echo -e "🔒 您使用自签证书,如需要验证伪装网站:"
            echo -e "   1. 自行修改浏览器信任证书"
            echo -e "   2. 设置hosts使IP指向该域名"
        fi
        echoColor purple "\n🌐 1、伪装地址: $(echoColor red https://${tls_sni}:${port})"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n🌐 Realm模式 - 服务器通过P2P打洞连接,无需公网IP和端口"
        echoColor purple "\n🔗 1、牵手地址:"
        echoColor green "  ${realmURI}"
        echo -e "\n"
        echoColor yellow "⚠ 请确保您的客户端支持Hysteria2 Realm模式"
        echoColor yellow "客户端配置中server字段使用上述牵手地址,认证密码为: "$(echoColor red ${auth_secret})
        echo -e "\n"
        echoColor purple "\n🔗 2、[hysteria2+realm 分享链接] 适用于支持 Realm URI 的客户端:\n"
        echoColor green "${url}"
        echo -e "\n"
        generate_qr "${url}"
        echo -e "\n"
        echoColor yellow "提示: Realm模式暂不支持ClashMeta配置,请使用上方分享链接或原生配置文件。"
    else
        echoColor purple "\n🔗 2、[v2rayN-Windows/v2rayN-Andriod/nekobox/passwall/Shadowrocket]分享链接:\n"
        echoColor green "${url}"
        echo -e "\n"
        generate_qr "${url}"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n📄 2、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: $(echoColor green ${client_configfile})"
    else
        echoColor purple "\n📄 3、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: $(echoColor green ${client_configfile})"
    fi
    echoColor purple "客户端使用教程: https://github.com/emptysuns/Hi_Hysteria/blob/main/md/client.md"
    echoColor green "↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓"
    cat ${client_configfile}
    echoColor green "↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑"
    if [ "${realmMode}" != "true" ]; then
        generateMetaYaml
    fi

    echo -e "\n✅ 配置生成完成!"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

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
    echoColor purple "\n📱 4、[Clash.Mini/ClashX.Meta/Clash.Meta for Android/Clash.verge/openclash] ClashMeta配置。文件地址: $(echoColor green ${metaFile})"
    if [ "${realmMode}" == "true" ]; then
        echoColor yellow "⚠ Clash Meta可能不完全支持Realm模式,建议优先使用原生配置文件"
    fi

}

checkLogs() {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        tail -f /etc/hihy/logs/hihy.log
    else
        echoColor red "$(i18n logs_not_found)"
    fi
}
start() {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then

        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy start
        else
            /etc/init.d/hihy start
        fi
        if [ $? -eq 0 ]; then
            echoColor green "$(i18n service_start_success)"
        else
            echoColor red "$(i18n service_start_failure)"
        fi
    else
        echoColor red "$(i18n service_script_not_found)"
    fi
}
stop() {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop
        else
            /etc/init.d/hihy stop
        fi
        if [ $? -eq 0 ]; then
            echoColor green "$(i18n service_stop_success)"
        else
            echoColor red "$(i18n service_stop_failure)"
        fi
    else
        echoColor red "$(i18n service_script_not_found)"
    fi
}
restart() {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy restart
        else
            /etc/init.d/hihy restart
        fi
        if [ $? -eq 0 ]; then
            echoColor green "$(i18n service_restart_success)"
        else
            echoColor red "$(i18n service_restart_failure)"
        fi
    else
        echoColor red "$(i18n service_script_not_found)"
    fi
}
checkStatus() {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            msg=$(/etc/rc.d/hihy status)
        else
            msg=$(/etc/init.d/hihy status)
        fi
        if [ $? -ne 0 ]; then
            echoColor red "$(i18n service_status_failure)"
            exit 1
        fi

        if echo "$msg" | grep -q "is running"; then
            echoColor green "$(i18n service_running "hysteria")"
            version=$(/etc/hihy/bin/appS version | grep "^Version" | awk '{print $2}')
            echoColor purple "$(i18n service_current_version ${version})"
        else
            echoColor red "$(i18n service_not_running "hysteria")"
        fi
    else
        echoColor red "$(i18n service_script_not_found)"
    fi
}

# 定义格式化字节大小的函数
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "$(i18n unit_bytes ${bytes})"
    elif [ $bytes -lt $((1024 * 1024)) ]; then
        echo "$(i18n unit_kilobytes $(echo "scale=2; $bytes/1024" | bc))"
    elif [ $bytes -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(i18n unit_megabytes $(echo "scale=2; $bytes/(1024*1024)" | bc))"
    else
        echo "$(i18n unit_gigabytes $(echo "scale=2; $bytes/(1024*1024*1024)" | bc))"
    fi
}

getHysteriaTrafic() {
    local api_port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "trafficPort")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")

    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi

    echo "$(i18n traffic_server_status_title)"

    # 流量统计部分保持不变
    echoColor green "$(i18n traffic_stats_label)"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic" \
        | grep -oE '"[^"]+":{"tx":[0-9]+,"rx":[0-9]+}' \
        | while IFS=: read -r user stats; do
            tx=$(echo $stats | grep -oE '"tx":[0-9]+' | cut -d: -f2)
            rx=$(echo $stats | grep -oE '"rx":[0-9]+' | cut -d: -f2)
            user=$(echo $user | tr -d '"')
            tx_formatted=$(format_bytes $tx)
            rx_formatted=$(format_bytes $rx)
            printf "$(i18n traffic_stats_row)\n" "$user" "$tx_formatted" "$rx_formatted"
        done

    # 在线用户部分保持不变
    echoColor green "\n$(i18n traffic_online_users_label)"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online" \
        | grep -oE '"[^"]+":[0-9]+' \
        | while IFS=: read -r user count; do
            user=$(echo $user | tr -d '"')
            count=$(echo $count | tr -d ' ')
            printf "$(i18n traffic_online_users_row)\n" "$user" "$count"
        done

    echoColor green "\n$(i18n traffic_active_connections_label)"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")

    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "$(i18n traffic_no_active_connections)"
    else
        # 打印表头
        local _h_state _h_user _h_conn_id _h_flows _h_up _h_down _h_alive _h_last_active _h_req_addr _h_target_addr
        _h_state="$(i18n traffic_header_state)"
        _h_user="$(i18n traffic_header_user)"
        _h_conn_id="$(i18n traffic_header_conn_id)"
        _h_flows="$(i18n traffic_header_flows)"
        _h_up="$(i18n traffic_header_upload)"
        _h_down="$(i18n traffic_header_download)"
        _h_alive="$(i18n traffic_header_alive_time)"
        _h_last_active="$(i18n traffic_header_last_active)"
        _h_req_addr="$(i18n traffic_header_request_address)"
        _h_target_addr="$(i18n traffic_header_target_address)"
        printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
            "$_h_state" "$_h_user" "$_h_conn_id" "$_h_flows" "$_h_up" "$_h_down" "$_h_alive" "$_h_last_active" "$_h_req_addr" "$_h_target_addr"
        echo "----------|-----------------|------------|------|------------|------------|--------------|--------------|----------------------|----------------------"

        # 使用临时文件存储排序数据
        temp_file=$(mktemp)

        echo "$STREAMS_OUTPUT" | awk -v estab="$(i18n traffic_status_estab)" \
            -v closed="$(i18n traffic_status_closed)" \
            'BEGIN {
            status["ESTAB"]=estab
            status["CLOSED"]=closed
        }

        function format_bytes(bytes) {
            if (bytes < 1024) return bytes byte_suffix
            if (bytes < 1024*1024) return sprintf("%.2f%s", bytes/1024, kb_suffix)
            if (bytes < 1024*1024*1024) return sprintf("%.2f%s", bytes/(1024*1024), mb_suffix)
            return sprintf("%.2f%s", bytes/(1024*1024*1024), gb_suffix)
        }

        function format_time(time) {
            if (time == "-") return 0
            if (index(time, "ms") > 0) {
                gsub("ms", "", time)
                return time/1000
            }
            if (index(time, "s") > 0) {
                gsub("s", "", time)
                return time
            }
            if (index(time, "m") > 0) {
                gsub("m", "", time)
                return time * 60
            }
            if (index(time, "h") > 0) {
                gsub("h", "", time)
                return time * 3600
            }
            return time
        }

        function format_time_display(seconds) {
            if (seconds < 1) return sprintf("%.0f%s", seconds * 1000, ms_suffix)
            if (seconds < 60) return sprintf("%.1f%s", seconds, s_suffix)
            if (seconds < 3600) return sprintf("%.1f%s", seconds/60, m_suffix)
            return sprintf("%.1f%s", seconds/3600, h_suffix)
        }

        NR > 1 {
            last_active = format_time($8)
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9, $10
        }' -v byte_suffix="$(i18n unit_byte_literal)" \
            -v kb_suffix="$(i18n unit_kilobyte_literal)" \
            -v mb_suffix="$(i18n unit_megabyte_literal)" \
            -v gb_suffix="$(i18n unit_gigabyte_literal)" \
            -v ms_suffix="$(i18n unit_millisecond_literal)" \
            -v s_suffix="$(i18n unit_second_literal)" \
            -v m_suffix="$(i18n unit_minute_literal)" \
            -v h_suffix="$(i18n unit_hour_literal)" \
            | sort -t'|' -k8,8nr >"$temp_file"

        # 读取排序后的数据并格式化输出
        while IFS='|' read -r state user conn_id flows up down alive last_active req_addr target_addr; do
            printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
                "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display $last_active)" "$req_addr" "$target_addr"
        done <"$temp_file"

        rm -f "$temp_file"
    fi

    echo "$(i18n traffic_separator_line)"
}

# 辅助函数：格式化时间显示
format_time_display() {
    local seconds=$1

    # 处理毫秒级别
    if (($(echo "$seconds < 1" | bc -l))); then
        printf "$(i18n unit_milliseconds $(echo "$seconds * 1000" | bc -l))"
        return
    fi

    # 处理秒级别
    if (($(echo "$seconds < 60" | bc -l))); then
        printf "$(i18n unit_seconds $seconds)"
        return
    fi

    # 处理分钟级别
    if (($(echo "$seconds < 3600" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "$(i18n unit_minutes $minutes)"
        return
    fi

    # 处理小时级别
    local hours=$(echo "$seconds / 3600" | bc -l)
    # 如果小时数小于0.1，显示为分钟
    if (($(echo "$hours < 0.1" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "$(i18n unit_minutes $minutes)"
    else
        printf "$(i18n unit_hours $hours)"
    fi
}

delHihyFirewallPort() {
    # 如果防火墙启动状态则删除之前的规则
    local listen_value=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
    local port=$(getListenPrimaryPort "${listen_value}")
    local port_range=$(getListenRangePart "${listen_value}")
    local firewall_port_range=$(formatFirewallPortSpec "${port_range}")
    local protocol=$1

    # realm模式下listen值非端口号(为realm URI),跳过防火墙规则删除
    if [ -z "${port}" ] || ! echo "${port}" | grep -qE '^[0-9]+$'; then
        return 0
    fi
    # 检查并处理不同的防火墙管理工具
    if command -v ufw >/dev/null && ufw status | hasFirewallToken "active"; then
        if ufw status | hasFirewallToken "${port}/${protocol}"; then
            ufw delete allow "${port}/${protocol}" 2>/dev/null
            echoColor purple "$(i18n firewall_ufw_delete ${port}/${protocol})"
        # 兼容旧版本未带协议的 ufw 规则
        elif ufw status | hasFirewallToken "${port}"; then
            ufw delete allow "${port}" 2>/dev/null
            echoColor purple "$(i18n firewall_ufw_delete ${port})"
        fi
        if [ -n "${firewall_port_range}" ] && ufw status | hasFirewallToken "${firewall_port_range}/${protocol}"; then
            ufw delete allow "${firewall_port_range}/${protocol}" 2>/dev/null
            echoColor purple "$(i18n firewall_ufw_delete ${firewall_port_range}/${protocol})"
        fi
    elif command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
        if firewall-cmd --list-ports --permanent | hasFirewallToken "${port}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${port}/${protocol}" --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            echoColor purple "$(i18n firewall_firewalld_delete ${port}/${protocol})"
        fi
        if [ -n "${firewall_port_range}" ] && firewall-cmd --list-ports --permanent | hasFirewallToken "${firewall_port_range}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${firewall_port_range}/${protocol}" --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            echoColor purple "$(i18n firewall_firewalld_delete ${firewall_port_range}/${protocol})"
        fi
    elif command -v iptables >/dev/null; then
        iptables-save | sed -e "/hihysteria/d" | iptables-restore
        ip6tables-save | sed -e "/hihysteria/d" | ip6tables-restore
        if command -v systemctl >/dev/null 2>&1; then
            # 检查 netfilter-persistent
            if systemctl is-active --quiet netfilter-persistent; then
                netfilter-persistent save
            fi
        fi
        if [ -f "/etc/rc.d/allow-port" ]; then
            sed -i "/${protocol}\/${port}(hihysteria)/d" /etc/rc.d/allow-port
            if [ -n "${firewall_port_range}" ]; then
                local port_range_comment=$(echo "${firewall_port_range}" | sed 's/:/\\:/g')
                sed -i "/${protocol}\/${port_range_comment}(hihysteria)/d" /etc/rc.d/allow-port
            fi
        fi

        echoColor purple "$(i18n firewall_iptables_delete ${port}/${protocol})"
        if [ -n "${firewall_port_range}" ]; then
            echoColor purple "$(i18n firewall_iptables_delete ${firewall_port_range}/${protocol})"
        fi
    fi
}

changeIp64() {
    local socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
    local config_file="/etc/hihy/conf/config.yaml"
    if [ "${socks5_status}" == "true" ]; then
        echoColor red "当前已经开启socks5转发,不支持修改优先级,如需分流请使用ACL管理"
        exit 1
    fi
    mode_now=$(getYamlValue "$config_file" "outbounds[0].direct.mode")

    echoColor purple "当前模式: $(echoColor red ${mode_now})"
    echoColor yellow "1) ipv4优先"
    echoColor yellow "2) ipv6优先"
    echoColor yellow "3) 自动选择"
    echoColor yellow "0) 退出"
    read -r -p "请选择: " input
    case $input in
        1)
            if [ "${mode_now}" == "46" ]; then
                echoColor yellow "当前已经是ipv4优先模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "46"
                restart
                echoColor green "切换成功"
            fi

            ;;
        2)
            if [ "${mode_now}" == "64" ]; then
                echoColor yellow "当前已经是ipv6优先模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "64"
                restart
                echoColor green "切换成功"
            fi

            ;;

        3)
            if [ "${mode_now}" == "auto" ]; then
                echoColor yellow "当前已经是自动选择模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "auto"
                restart
                echoColor green "切换成功"
            fi
            ;;
        0) exit 0 ;;
        *)
            echoColor red "输入错误!"
            exit 1
            ;;
    esac
}

changeServerConfig() {
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "请先安装hysteria2,再去修改配置..."
        exit
    fi
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
        portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
    fi
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    stop
    cleanupLegacyPortHoppingNatIfPresent
    if [ "${masquerade_tcp}" == "true" ]; then
        delHihyFirewallPort tcp
        delHihyFirewallPort udp
    else
        delHihyFirewallPort udp
    fi
    updateHysteriaCore
    setHysteriaConfig
    start
    generate_client_config
    echoColor green "配置修改成功"

}

aclControl() {
    local acl_file="/etc/hihy/acl/acl.txt"
    if [ ! -f "${acl_file}" ]; then
        echoColor red "未找到acl文件"
        exit 1
    fi
    echoColor purple "请选择管理操作:"
    echoColor yellow "1) 添加"
    echoColor yellow "2) 删除"
    echoColor yellow "3) 查看"
    echoColor yellow "0) 退出"
    read -r -p "请选择: " input
    case $input in
        1)
            echoColor green "请选择ACL控制方式"
            echoColor yellow "1) 添加域名ipv4分流"
            echoColor yellow "2) 添加域名ipv6分流"
            echoColor yellow "3) 添加屏蔽域名"
            read -r -p "请选择: " input
            case $input in
                1)
                    read -r -p "请输入要分流ipv4的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v4_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v4_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                2)
                    read -r -p "请输入要分流ipv6的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v6_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v6_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                3)
                    read -r -p "请输入要屏蔽的域名: " rejectInput
                    if [ -z "${rejectInput}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "reject(suffix:${rejectInput})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "reject(suffix:${rejectInput})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                *)
                    echoColor red "输入错误!"
                    exit 1
                    ;;
            esac
            ;;
        2)
            read -r -p "请输入要删除的域名规则: " domain
            if [ -z "${domain}" ]; then
                echoColor red "域名不能为空"
                exit 1
            fi
            if grep -q "${domain}" "${acl_file}"; then
                sed -i "/${domain}/d" "${acl_file}"
                echoColor green "删除成功"
                restart
            else
                echoColor red "规则不存在"
            fi

            ;;
        3)
            echoColor purple "当前ACL列表:"
            cat "${acl_file}"
            ;;
        0) exit 0 ;;
        *)
            echoColor red "输入错误!"
            exit 1
            ;;
    esac

}

addSocks5Outbound() {
    if [ ! -f "/etc/hihy/conf/config.yaml" ]; then
        echoColor red "未找到配置文件"
        exit 1
    fi
    local server_config="/etc/hihy/conf/config.yaml"
    local backup_config="/etc/hihy/conf/backup.yaml"
    echo -e "Tip: WireProxy借助cloudflare warp提供免费好用的socks5代理,比起warp全局开销更小,建议性能不好的机器使用."
    echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、自动添加一个warp socks5接口作为hysteria2出站(默认,使用fscarmen WireProxy方案)\n2、自定义socks5地址\n3、卸载已经配置的outbound\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r num
    if [ -z "${num}" ] || [ ${num} == "1" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "当前已经开启socks5 outbound,请删除后再添加"
            exit 1
        fi
        local conf_file="/etc/wireguard/proxy.conf"
        if [ -f "$conf_file" ]; then
            echoColor green "找到WireProxy配置文件,使用当前配置"
        else
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh w
        fi

        if [ ! -f "$conf_file" ]; then
            echoColor red "未找到WireProxy配置文件,请保证正确安装WireProxy"
            exit 1
        fi
        local port=$(grep "BindAddress" "$conf_file" | grep -v "^#" | awk -F':' '{print $2}')
        echoColor purple "->本机WireProxy socks5端口: $(echoColor red ${port})"

        # 在数组开头插入新的outbound配置
        yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'"}}] + .outbounds' -i "${server_config}"

        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "添加warp outbound成功"

    elif [ ${num} == "2" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "当前已经开启socks5 outbound,请删除后再添加"
            exit 1
        fi
        read -r -p "请输入socks5地址(ip:端口): " socks5_addr
        if [ -z "${socks5_addr}" ]; then
            echoColor red "地址不能为空"
            exit 1
        fi
        read -r -p "请输入socks5用户名,如果没有鉴权直接留空: " socks5_user
        if [ -n "${socks5_user}" ]; then
            read -r -p "请输入socks5密码: " socks5_pass
            if [ -z "${socks5_pass}" ]; then
                echoColor red "密码不能为空"
                exit 1
            fi
        fi
        local server_config="/etc/hihy/conf/config.yaml"
        if [ -n "${socks5_user}" ]; then
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'", "username": "'$socks5_user'", "password": "'$socks5_pass'"}}] + .outbounds' -i "${server_config}"
        else
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'"}}] + .outbounds' -i "${server_config}"

        fi
        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "添加socks5 outbound成功"
    elif [ ${num} == "3" ]; then
        # 删除outbounds相关配置
        outbound_name=$(getYamlValue ${server_config} "outbounds[0].name")
        if [ "${outbound_name}" == "warp" ] || [ "${outbound_name}" == "custom" ]; then
            yq eval 'del(.outbounds[0])' -i "${server_config}"
            if [ "${outbound_name}" == "warp" ]; then
                warp u
            fi
            restart
            addOrUpdateYaml ${backup_config} "socks5_status" "false"
            echoColor green "卸载成功"
        else
            echoColor red "未找到socks5 outbound"
        fi

    else
        echoColor red "输入错误"
        exit 1
    fi

}

show_menu() {
    clear
    echo -e " -------------------------------------------"
    echo -e "|**********      $(i18n menu_title)       **********|"
    echo -e "|**********    Author: emptysuns   **********|"
    echo -e "|**********     $(i18n menu_version "$(echoColor red "${hihyV}")")    **********|"
    echo -e " -------------------------------------------"
    echo -e "$(i18n menu_hint_hihy_cmd "$(echoColor green "hihy")")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_install)")"
    echo -e "$(echoColor magenta "$(i18n menu_option_uninstall)")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_start)")"
    echo -e "$(echoColor magenta "$(i18n menu_option_stop)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_restart)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_status)")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "$(i18n menu_option_update_core)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_view_config)")"
    echo -e "$(echoColor red "$(i18n menu_option_reconfigure)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_switch_ip_priority)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_update_hihy)")"
    echo -e "$(echoColor lightMagenta "$(i18n menu_option_acl)")"
    echo -e "$(echoColor skyBlue "$(i18n menu_option_traffic_stats)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_logs)")"
    echo -e "$(echoColor yellow "$(i18n menu_option_socks5)")"

    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor magenta "$(i18n menu_option_exit)")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e ""
    hihy_update_notifycation
    echo -e "\n"
    startBackgroundVersionCheck
}

wait_for_continue() {
    echo -e "\n$(echoColor green "$(i18n menu_wait_continue)")"
    read -r -n 1 -s
}

menu() {
    while true; do
        show_menu
        read -r -p "$(i18n menu_prompt_choice)" input
        case $input in
            1)
                install
                exit 0
                ;;
            2)
                uninstall
                exit 0
                ;;
            3)
                start
                wait_for_continue
                ;;
            4)
                stop
                wait_for_continue
                ;;
            5)
                restart
                wait_for_continue
                ;;
            6)
                checkStatus
                wait_for_continue
                ;;
            7)
                updateHysteriaCore
                exit 0
                ;;
            8)
                generate_client_config
                wait_for_continue
                ;;
            9)
                changeServerConfig
                exit 0
                ;;
            10)
                changeIp64
                exit 0
                ;;
            11)
                hihyUpdate
                exit 0
                ;;
            12)
                aclControl
                exit 0
                ;;
            13)
                getHysteriaTrafic
                wait_for_continue
                ;;
            14)
                checkLogs
                exit 0
                ;;
            15)
                addSocks5Outbound
                exit 0
                ;;
            0) exit 0 ;;
            *)
                echoColor red "$(i18n error_input_error)"
                wait_for_continue
                ;;
        esac
    done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    loadPersistedLanguage
    checkRoot
    case "$1" in
        install | 1)
            echoColor purple "$(i18n cmd_title_install)"
            install
            ;;
        uninstall | 2)
            echoColor purple "$(i18n cmd_title_uninstall)"
            uninstall
            ;;
        start | 3)
            echoColor purple "$(i18n cmd_title_start)"
            start
            ;;
        stop | 4)
            echoColor purple "$(i18n cmd_title_stop)"
            stop
            ;;
        restart | 5)
            echoColor purple "$(i18n cmd_title_restart)"
            restart
            ;;
        checkStatus | 6)
            echoColor purple "$(i18n cmd_title_status)"
            checkStatus
            ;;
        updateHysteriaCore | 7)
            echoColor purple "$(i18n cmd_title_update_core)"
            updateHysteriaCore
            ;;
        generate_client_config | 8)
            echoColor purple "$(i18n cmd_title_view_config)"
            generate_client_config
            ;;
        changeServerConfig | 9)
            echoColor purple "$(i18n cmd_title_reconfigure)"
            changeServerConfig
            ;;
        changeIp64 | 10)
            echoColor purple "$(i18n cmd_title_switch_ip_priority)"
            changeIp64
            ;;
        hihyUpdate | 11)
            echoColor purple "$(i18n cmd_title_update_hihy)"
            hihyUpdate
            ;;
        aclControl | 12)
            echoColor purple "$(i18n cmd_title_acl)"
            aclControl
            ;;
        getHysteriaTrafic | 13)
            echoColor purple "$(i18n cmd_title_traffic_stats)"
            getHysteriaTrafic
            ;;
        checkLogs | 14)
            echoColor purple "$(i18n cmd_title_logs)"
            checkLogs
            ;;
        addSocks5Outbound | 15)
            echoColor purple "$(i18n cmd_title_socks5)"
            addSocks5Outbound
            ;;
        cronTask) cronTask ;;
        *) menu ;;
    esac
fi
