#!/bin/bash

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

