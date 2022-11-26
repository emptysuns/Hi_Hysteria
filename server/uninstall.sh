#!/bin/bash

function rmhy(){
	remarks=`cat /etc/hihy/conf/hihy.conf | grep 'remarks' | awk -F ':' '{print $2}'`
    n=$1
    systemctl stop ${n}
    systemctl disable ${n}
    rm /etc/systemd/system/${n}.service
    rm -r /etc/${n}
    rm /usr/bin/${n}
	if [ -f "./Hys-${remarks}(v2rayN).json" ];then
		rm ./Hys-${remarks}\(v2rayN\).json
	fi
	if [ -f "./Hys-${remarks}(clashMeta).yaml" ];then
		rm ./Hys-${remarks}\(clashMeta\).yaml
	fi
    crontab -l > /tmp/crontab.tmp
    sed -i '/0 4 \* \* \* systemctl restart ${n}/d' /tmp/crontab.tmp
	sed -i '/15 4 \* \* 1,4 hihy cronTask/d' /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
	iptables -t nat -F PREROUTING
	ip6tables -t nat -F PREROUTING
}

function delHihyFirewallPort() {
	# 如果防火墙启动状态则删除之前的规则
	port=`cat /etc/hihy/conf/hihyServer.json | grep "listen" | awk '{print $2}' | tr -cd "[0-9]"`
	if [[ `ufw status 2>/dev/null | grep "Status: " | awk '{print $2}'` = "active" ]]	; then
		if ufw status | grep -q ${port}; then
			sudo ufw delete allow ${port} 2> /dev/null
		fi
	elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
		local updateFirewalldStatus=
		isFaketcp=`cat /etc/hihy/conf/hihyServer.json | grep "faketcp"`
		if [ -z "${isFaketcp}" ];then
			ut="udp"
		else
			ut="tcp"
		fi
		if firewall-cmd --list-ports --permanent | grep -qw "${port}/${ut}"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --remove-port=${port}/${ut} 2> /dev/null
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload 2> /dev/null
		fi
	elif systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
		updateFirewalldStatus=true
		iptables-save |  sed -e '/hihysteria/d' | iptables-restore
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			netfilter-persistent save 2> /dev/null
		fi
	fi
}

iptables -t nat -F PREROUTING
ip6tables -t nat -F PREROUTING
if [ -x "$(command -v netfilter-persistent)" ]; then
	netfilter-persistent save 2> /dev/null
fi
delHihyFirewallPort
if [ -f "/etc/systemd/system/hihy.service" ]; then
  rmhy "hihy"
fi
systemctl daemon-reload

echo -e "\033[1;33;40mUninstall completed!\033[0m\n"