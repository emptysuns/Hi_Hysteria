#!/bin/bash
setup_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "$(i18n arch_detected_setup)"

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

        echo "$(i18n arch_rc_local_setup_done)"
    fi
}

uninstall_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "$(i18n arch_detected_uninstall)"

        # 停止并禁用 rc-local 服务
        systemctl stop rc-local
        systemctl disable rc-local

        # 删除 /etc/systemd/system/rc-local.service 文件
        rm /etc/systemd/system/rc-local.service

        # 重新加载 systemd 配置
        systemctl daemon-reload

        echo "$(i18n arch_rc_local_uninstall_done)"
    fi
}

# 写入服务管理脚本(OpenRC 或传统 rc.d)并接好开机自启。
# 关键点:
#   1. setsid 让服务进程脱离调用者的会话/前台进程组 —— 否则从菜单启动的服务会留在
#      终端前台进程组里,用户按 Ctrl+C 退出菜单时 SIGINT 广播会连带杀死刚启动的服务
#      (nohup 只挡 SIGHUP;hysteria 通过 signal.Notify 接管 SIGINT,bash 的后台 SIG_IGN 挡不住)
#   2. stop 等待进程真正退出(最多 5s,兜底 kill -9),避免 restart 时新进程抢不到端口
#   3. start 后校验进程存活 1s,启动失败立即报错而不是假装成功
#   4. rc.local 无条件补执行位:RHEL 系 /etc/rc.local 默认无执行位,rc-local.service
#      的 ConditionFileIsExecutable 不满足,开机自启会静默失效
installServiceScript() {
    local start_cmd_prefix
    start_cmd_prefix=$(getStartCommand)

    if [ -f "/etc/alpine-release" ]; then
        # 使用 OpenRC
        mkdir -p /etc/init.d
        cat >/etc/init.d/hihy <<EOF
#!/sbin/openrc-run

name="hihy"
description="Hysteria Proxy Service"
command="${start_cmd_prefix} /etc/hihy/bin/appS"
command_args="--log-level info -c /etc/hihy/conf/config.yaml server"
pidfile="/var/run/hihy.pid"
output_log="/etc/hihy/logs/hihy.log"
error_log="/etc/hihy/logs/hihy.log"

extra_started_commands="log"

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
    DAEMON_WRAP=""
    if command -v setsid >/dev/null 2>&1; then
        DAEMON_WRAP="setsid"
    fi
    nohup \$DAEMON_WRAP \$command \$command_args > "\$output_log" 2>&1 &
    echo \$! > "\$pidfile"
    sleep 1
    if ! kill -0 \$(cat "\$pidfile") 2>/dev/null; then
        rm -f "\$pidfile"
        eend 1 "hihy failed to start, check \$output_log"
        return 1
    fi
    eend 0
}

stop() {
    if [ ! -f "\$pidfile" ]; then
        eerror "hihy is not running"
        return 1
    fi

    PID=\$(cat "\$pidfile")
    ebegin "Stopping hihy"
    kill "\$PID" 2>/dev/null
    n=0
    while [ \$n -lt 5 ]; do
        if ! kill -0 "\$PID" 2>/dev/null; then
            break
        fi
        sleep 1
        n=\$((n + 1))
    done
    if kill -0 "\$PID" 2>/dev/null; then
        kill -9 "\$PID" 2>/dev/null
    fi
    rm -f "\$pidfile"
    eend 0
}

restart() {
    stop
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
        rc-update add hihy default >/dev/null 2>&1 || true
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
    DAEMON_WRAP=""
    if command -v setsid >/dev/null 2>&1; then
        DAEMON_WRAP="setsid"
    fi
    if [ -n "\$START_CMD_PREFIX" ]; then
        nohup \$DAEMON_WRAP \$START_CMD_PREFIX \$HIHY_PATH/bin/appS --log-level info -c \$HIHY_PATH/conf/config.yaml server > "\$LOG_FILE" 2>&1 &
    else
        nohup \$DAEMON_WRAP \$HIHY_PATH/bin/appS --log-level info -c \$HIHY_PATH/conf/config.yaml server > "\$LOG_FILE" 2>&1 &
    fi
    echo \$! > "\$PID_FILE"
    sleep 1
    if ! kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "hihy failed to start, check \$LOG_FILE"
        rm -f "\$PID_FILE"
        return 1
    fi
}

stop() {
    if [ ! -f "\$PID_FILE" ]; then
        echo "hihy is not running"
        return 1
    fi

    PID=\$(cat "\$PID_FILE")
    echo "Stopping hihy..."
    kill "\$PID" 2>/dev/null
    n=0
    while [ \$n -lt 5 ]; do
        if ! kill -0 "\$PID" 2>/dev/null; then
            break
        fi
        sleep 1
        n=\$((n + 1))
    done
    if kill -0 "\$PID" 2>/dev/null; then
        kill -9 "\$PID" 2>/dev/null
    fi
    rm -f "\$PID_FILE"
}

restart() {
    stop
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
        fi
        chmod +x /etc/rc.local 2>/dev/null || true
        if ! grep -q "/etc/rc.d/hihy start" /etc/rc.local; then
            echo "/etc/rc.d/hihy start" >>/etc/rc.local
        fi
    fi
}

install() {
    local mode="${1:-}"
    local install_state
    install_state=$(classifyInstallState)

    if [ "$install_state" = "installed" ]; then
        echoColor green "$(i18n already_installed)"
        return 0
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "$(i18n partial_install_cleanup)"
        killHysteriaProcess KILL
        delHihyFirewallPort udp >/dev/null 2>&1 || true
        delHihyFirewallPort tcp >/dev/null 2>&1 || true
        cleanupHysteria2Iptables >/dev/null 2>&1 || true
        recoverPartialInstallState
        echoColor purple "$(i18n partial_install_recovered)"
    fi

    # 创建必要目录
    mkdir -p /etc/hihy/{bin,conf,cert,result,logs}
    markInstallFailed "install-start" "installation started but not completed"
    echoColor purple "$(i18n install_ready)"

    # 尽早安装 hihy 启动器，确保即使后续步骤失败，用户仍可用 hihy 命令重试
    if ! installHihyLauncher; then
        markInstallFailed "launcher" "failed to install hihy launcher at start"
        echoColor red "$(i18n hihy_cmd_install_fail)"
        exit 1
    fi

    checkSystemForUpdate
    if ! downloadHysteriaCore; then
        markInstallFailed "core-download" "failed to download hysteria core"
        exit 1
    fi
    if [ "$mode" = "auto" ]; then
        autoHysteriaConfig
    else
        setHysteriaConfig
    fi

    # 写入服务脚本并启动(独立函数,重新配置时也会刷新服务脚本)
    installServiceScript
    if [ -f "/etc/alpine-release" ]; then
        rc-service hihy start
    else
        /etc/rc.d/hihy start
    fi

    # 添加定时任务(先去重,避免重装时重复堆积)
    crontab -l >./crontab.tmp 2>/dev/null || touch ./crontab.tmp
    if ! grep -q "hihy cronTask" ./crontab.tmp; then
        echo "15 4 * * 1 hihy cronTask" >>./crontab.tmp
        crontab ./crontab.tmp
    fi
    rm -f ./crontab.tmp
    setup_rc_local_for_arch

    generate_client_config
    echoColor yellowBlack "$(i18n install_done)"
}

# 将 listen 中的范围端口格式 47000-48000 转换为防火墙规则使用的 47000:48000
checkLogs() {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        echoColor gray "$(i18n logs_follow_hint)"
        # 父进程捕获 INT:Ctrl+C 只结束 tail,脚本本身回到菜单
        trap ':' INT
        tail -f /etc/hihy/logs/hihy.log
        trap - INT
        echo ""
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
