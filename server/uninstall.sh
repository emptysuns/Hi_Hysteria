#!/bin/bash

function rmhy(){
    n=$1
    systemctl stop ${n}
    systemctl disable ${n}
    rm /etc/systemd/system/${n}.service
    rm -r /etc/${n}
    rm /usr/bin/${n}
    crontab -l > /tmp/crontab.tmp
    sed -i '/0 4 \* \* \* systemctl restart ${n}/d' /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
}

function delHihyFirewallPort() {
	# 如果防火墙启动状态则删除之前的规则
	if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
		local updateFirewalldStatus=
		if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
			updateFirewalldStatus=true
			iptables-save |  sed -e '/hihysteria/d' | iptables-restore
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			netfilter-persistent save
		fi
	elif systemctl status ufw 2>/dev/null | grep -q "active (exited)"; then
		port=`cat /etc/hihy/conf/hihyServer.json | grep "listen" | awk '{print $2}' | tr -cd "[0-9]"`
		if ! ufw status | grep -q ${port}; then
			sudo ufw delete allow ${port}
		fi
	elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
		local updateFirewalldStatus=
		port=`cat /etc/hihy/conf/hihyServer.json | grep "listen" | awk '{print $2}' | tr -cd "[0-9]"`
		isFaketcp=`cat /etc/hihy/conf/hihyServer.json | grep "faketcp"`
		if [ -z "${isFaketcp}" ];then
			ut="udp"
		else
			ut="tcp"
		fi
		if ! firewall-cmd --list-ports --permanent | grep -qw "${port}/${ut}"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --remove-port=${port}/${ut}
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload
		fi
	fi
}

delHihyFirewallPort
if [ -f "/etc/systemd/system/hihys.service" ]; then
  rmhy "hihys"
fi

if [ -f "/etc/systemd/system/hysteria.service" ]; then
  rmhy "hysteria"
fi

if [ -f "/etc/systemd/system/hihy.service" ]; then
  rmhy "hihy"
fi
systemctl daemon-reload

echo -e "\033[1;33;40mUninstall completed!\033[0m\n"