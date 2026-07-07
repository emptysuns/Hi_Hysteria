#!/bin/bash
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
    fi
}

