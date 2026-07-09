#!/bin/bash
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
        echoColor purple "$(i18n firewall_ufw_open ${port})"
    else
        echoColor red "$(i18n firewall_ufw_open_fail ${port})"
        exit 1
    fi
}

# 输出firewall-cmd端口开放状态
checkFirewalldAllowPort() {
    local port=$1
    local protocol=$2
    if firewall-cmd --list-ports --permanent | hasFirewallToken "${port}/${protocol}"; then
        echoColor purple "$(i18n firewall_firewalld_open ${port} ${protocol})"
    else
        echoColor red "$(i18n firewall_firewalld_open_fail ${port} ${protocol})"
        exit 1
    fi
}

allowPort() {
    # 如果防火墙启动状态则添加相应的开放端口
    # $1 tcp/udp
    # $2 port 或端口范围(start:end)
    # 端口范围各后端语法不同:iptables/ufw 用 47000:48000,firewalld/nft 用 47000-48000
    local dash_port="${2//:/-}"

    # 检查是否为 Alpine Linux
    if [ -f /etc/alpine-release ]; then
        # Alpine 默认使用 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                echoColor purple "$(i18n firewall_iptables_open ${1} ${2})"

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
                nft add rule inet filter input ip protocol ${1} dport ${dash_port} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "$(i18n firewall_nftables_open ${1} ${2})"
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
                    echoColor purple "$(i18n firewall_iptables_open ${1} ${2})"
                    netfilter-persistent save
                fi
                return 0
            fi

            # 检查 firewalld
            if systemctl is-active --quiet firewalld; then
                if ! firewall-cmd --list-ports --permanent | hasFirewallToken "${dash_port}/${1}"; then
                    firewall-cmd --zone=public --add-port=${dash_port}/${1} --permanent
                    echoColor purple "$(i18n firewall_firewalld_open ${1} ${2})"
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

            echoColor purple "$(i18n firewall_iptables_open ${1} ${2})"
            return 0
        fi

        # 检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${dash_port} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "$(i18n firewall_nftables_open ${1} ${2})"
                nft list ruleset >/etc/nftables.conf
            fi
            return 0
        fi
    fi

    echoColor red "$(i18n no_supported_firewall ${1} ${2})"
    return 1
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
        # firewalld 的范围规则用 47000-48000 语法(listen 字段原生格式,勿转冒号)
        if [ -n "${port_range}" ] && firewall-cmd --list-ports --permanent | hasFirewallToken "${port_range}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${port_range}/${protocol}" --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            echoColor purple "$(i18n firewall_firewalld_delete ${port_range}/${protocol})"
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

