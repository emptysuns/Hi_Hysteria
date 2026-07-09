#!/bin/bash
hihyV="ver1.13"

# i18n 多语言支持
HIHY_I18N_SCHEMA=1
HIHY_I18N_DIR="${HIHY_I18N_DIR:-/etc/hihy/i18n}"
HIHY_I18N_CONF="${HIHY_I18N_CONF:-/etc/hihy/conf/i18n.conf}"
HIHY_LANG="${HIHY_LANG:-}"

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
HIHY_RULESET_MIRROR="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
