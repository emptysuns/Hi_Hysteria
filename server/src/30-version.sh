#!/bin/bash
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
hihy_update_notifycation() {
    displayCachedVersionNotifications
}

hyCore_update_notifycation() {
    displayCachedVersionNotifications
}

