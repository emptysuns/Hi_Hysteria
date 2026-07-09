#!/bin/bash

# 从远端(主源+镜像)拉取 hihy 脚本到目标路径:临时文件 -> 内容校验(hihyV= 标记) -> 原子 mv。
# 目标可能正是正在执行的脚本,rename 只换 inode,运行中的进程不受影响。
installHihyScriptFromRemote() {
    local dest="$1"
    local dest_dir temp_path

    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir" || return 1
    temp_path="$(mktemp "$dest_dir/.hihy.tmp.XXXXXX")" || return 1

    if ! downloadToFile "$HIHY_REMOTE_SCRIPT_URL" "$temp_path" \
        && ! downloadToFile "$HIHY_REMOTE_SCRIPT_MIRROR_URL" "$temp_path"; then
        rm -f "$temp_path"
        return 1
    fi
    # 内容合法性校验:必须是带版本标记的 hihy 脚本,而非镜像返回的错误页
    if ! grep -q '^hihyV=' "$temp_path"; then
        rm -f "$temp_path"
        return 1
    fi
    chmod +x "$temp_path"
    mv "$temp_path" "$dest" || {
        rm -f "$temp_path"
        return 1
    }
}

installHihyLauncher() {
    local source_path="${1:-${BASH_SOURCE[0]}}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local bin_dir
    local temp_path

    bin_dir="$(dirname "$bin_link")"
    mkdir -p "$bin_dir"

    if [ -f "$source_path" ] && [ "$source_path" != "$bin_link" ]; then
        # 本地已有脚本文件:同目录临时文件 + mv(rename)落盘,避免原地截断
        temp_path="$(mktemp "$bin_dir/.hihy.tmp.XXXXXX")" || return 1
        if ! cp "$source_path" "$temp_path"; then
            rm -f "$temp_path"
            return 1
        fi
        chmod +x "$temp_path"
        mv "$temp_path" "$bin_link" || {
            rm -f "$temp_path"
            return 1
        }
    elif [ ! -f "$bin_link" ]; then
        installHihyScriptFromRemote "$bin_link" || return 1
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

# 多源探测公网 IP;$1 为 curl 地址族参数(-4/-6/空)
getPublicIP() {
    local family="${1:-}"
    local source detected
    for source in "https://ip.sb" "https://api64.ipify.org" "https://ifconfig.me"; do
        detected=$(curl ${family} -s -m 4 "$source" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$detected" ]; then
            printf '%s\n' "$detected"
            return 0
        fi
    done
    return 1
}

# 常用探测策略:先 IPv4,失败再不限地址族(唯一实现点,勿在调用处复制回退梯子)
detectPublicIP() {
    getPublicIP -4 || getPublicIP ""
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

    # 检查文件是否存在(错误走 stderr,避免污染调用方捕获的 stdout)
    if [[ ! -f "$file" ]]; then
        echo "getYamlValue: file not found: $file" >&2
        return 1
    fi

    # 使用 yq 读取 YAML 文件中的值
    value=$(yq eval ".${keyPath}" "$file")

    # 检查 yq 命令是否成功执行
    if [[ $? -ne 0 ]]; then
        echo "getYamlValue: failed to read $keyPath from $file" >&2
        return 1
    fi

    echo "$value"
}

