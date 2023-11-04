#!/bin/bash

function rmhy(){
	msg=`cat /etc/hihy/conf/hihy.conf | grep "remarks"`
	remarks=${msg#*:}
	portHoppingStatus=`cat /etc/hihy/conf/hihy.conf | grep "portHopping" | awk -F ":" '{print $2}'`
	portHoppingStart=`cat /etc/hihy/conf/hihy.conf | grep "portHoppingStart" | awk -F ":" '{print $2}'`
	portHoppingEnd=`cat /etc/hihy/conf/hihy.conf | grep "portHoppingEnd" | awk -F ":" '{print $2}'`
	serverPort=`cat /etc/hihy/conf/hihy.conf | grep "serverPort" | awk -F ":" '{print $2}'`
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
	if echo "${portHoppingStatus}" | grep -q "true";then
		delPortHoppingNat ${portHoppingStart} ${portHoppingEnd} ${serverPort}
	fi
    crontab -l > /tmp/crontab.tmp
    sed -i '/0 4 \* \* \* systemctl restart ${n}/d' /tmp/crontab.tmp
	sed -i '/15 4 \* \* 1,4 hihy cronTask/d' /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
}

function delPortHoppingNat(){
	# $1 portHoppingStart
	# $2 portHoppingEnd
	# $3 portHoppingTarget
	if systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
		firewall-cmd --permanent --remove-forward-port=port=$1-$2:proto=udp:toport=$3 2>/dev/null
		firewall-cmd --reload 2>/dev/null
	else
		iptables -t nat -F PREROUTING  2>/dev/null
		ip6tables -t nat -F PREROUTING  2>/dev/null
		if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
			netfilter-persistent save 2> /dev/null
		fi

	fi
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
			firewall-cmd --zone=public --remove-port=${port}/${ut} --permanent 2> /dev/null
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload 2> /dev/null
		fi
	elif systemctl status netfilter-persistent 2> /dev/null | grep -q "active (exited)"; then
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
exit 0