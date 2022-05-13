#!/bin/bash
hihyV="0.3.7"
function echoColor() {
	case $1 in
		# 红色
	"red")
		echo -e "\033[31m${printN}$2 \033[0m"
		;;
		# 天蓝色
	"skyBlue")
		echo -e "\033[1;36m${printN}$2 \033[0m"
		;;
		# 绿色
	"green")
		echo -e "\033[32m${printN}$2 \033[0m"
		;;
		# 白色
	"white")
		echo -e "\033[37m${printN}$2 \033[0m"
		;;
	"magenta")
		echo -e "\033[31m${printN}$2 \033[0m"
		;;
		# 黄色
	"yellow")
		echo -e "\033[33m${printN}$2 \033[0m"
		;;
        # 紫色
    "purple")
        echo -e "\033[1;;35m${printN}$2 \033[0m"
        ;;
        #
    "yellowBlack")
        # 黑底黄字
        echo -e "\033[1;33;40m${printN}$2 \033[0m"
        ;;
	esac
}

function checkSystemForUpdate() {
	if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
		mkdir -p /etc/yum.repos.d

		if [[ -f "/etc/centos-release" ]]; then
			centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')

			if [[ -z "${centosVersion}" ]] && grep </etc/centos-release -q -i "release 8"; then
				centosVersion=8
			fi
		fi

		release="centos"
		installType='yum -y -q install'
		removeType='yum -y -q remove'
		upgrade="yum update -y  --skip-broken"

	elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
		release="debian"
		installType='apt -y -q install'
		upgrade="apt update"
		updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
		removeType='apt -y -q autoremove'

	elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
		release="ubuntu"
		installType='apt -y -q install'
		upgrade="apt update"
		updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
		removeType='apt -y -q autoremove'
		if grep </etc/issue -q -i "16."; then
			release=
		fi
	fi

	if [[ -z ${release} ]]; then
		echoColor red "\n本脚本不支持此系统,请将下方日志反馈给开发者\n"
		echoColor yellow "$(cat /etc/issue)"
		echoColor yellow "$(cat /proc/version)"
		exit 0
	fi
    echoColor purple "\nUpdate.wait..."
    ${upgrade}
    echoColor purple "\nDone.\nInstall wget curl lsof"
	echoColor green "*wget"
	if ! [ -x "$(command -v wget)" ]; then
		${installType} "wget"
	else
		echoColor purple 'Installed.Ignore.' >&2
	fi
	echoColor green "*curl"
	if ! [ -x "$(command -v curl)" ]; then
		${installType} "curl"
	else
		echoColor purple 'Installed.Ignore.' >&2
	fi
	echoColor green "*lsof"
	if ! [ -x "$(command -v lsof)" ]; then
		${installType} "lsof"
	else
		echoColor purple 'Installed.Ignore.' >&2
	fi
    echoColor purple "\nDone."
    
}

function uninstall(){
    bash <(curl -fsSL https://git.io/rmhysteria.sh)
}

function reinstall(){
    bash <(curl -fsSL https://git.io/rehysteria.sh)
}

function printMsg(){
	cp -P /etc/hihy/result/hihyClient.json ./config.json
	echoColor yellowBlack "配置文件输出如下且已经在本目录生成(直接下载本目录生成的config.json[推荐]/自行复制粘贴到本地)"
	echoColor green "\nTips:客户端默认只开启http(8888)、socks5(8889)代理!其他方式请参照hysteria文档自行修改客户端config.json"
	echoColor purple "***********************************↓↓↓copy↓↓↓*******************************↓"
	cat ./config.json
	echoColor purple "↑***********************************↑↑↑copy↑↑↑*******************************↑\n"
	url=`cat /etc/hihy/result/url.txt`
	echo -e "Shadowrocket/Sagernet/Passwall一键链接:"
	echoColor green ${url}
	echo -e "\n"
}

function hihy(){
	if [ ! -f "/usr/bin/hihy" ]; then
  		wget -q -O /usr/bin/hihy --no-check-certificate https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/server/install.sh
		chmod +x /usr/bin/hihy
	fi	
}

function changeIp64(){
    if [ ! -f "/etc/hihy/conf/hihyServer.json" ]; then
  		echoColor red "未正常安装hihy!"
        exit
	fi 
	now=`cat /etc/hihy/conf/hihyServer.json | grep "resolve_preference"`
    case ${now} in 
		*"64"*)
			echoColor purple "当前ipv6优先"
            echoColor yellow " ->设置ipv4优先级高于ipv6?(Y/N,默认N)"
            read input
            if [ -z "${input}" ];then
                echoColor green "Ignore."
                exit
            else
                sed -i 's/"resolve_preference": "64"/"resolve_preference": "46"/g' /etc/hihy/conf/hihyServer.json
                systemctl restart hihy
                echoColor green "Done.Ipv4 first now."
            fi
            
		;;
		*"46"*)
			echoColor purple "当前ipv4优先"
            echoColor yellow " ->设置ipv6优先级高于ipv4?(Y/N,默认N)"
            read input
            if [ -z "${input}" ];then
                echoColor green "Ignore."
                exit
            else
                sed -i 's/"resolve_preference": "46",/"resolve_preference": "64",/g' /etc/hihy/conf/hihyServer.json
                systemctl restart hihy
                echoColor green "Done.Ipv6 first now."
            fi
        ;;
	esac
}

function setHysteriaConfig(){
	mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert  /etc/hihy/result /etc/hihy/acl
	echoColor yellowBlack "开始配置:"
	echo -e "\033[32m请选择证书申请方式:\n\n\033[0m\033[33m\033[01m1、使用ACME申请(推荐,需打开tcp 80/443)\n2、使用本地证书文件\n3、自签证书\033[0m\033[32m\n\n输入序号:\033[0m"
    read certNum
	useAcme=false
	useLocalCert=false
	if [ -z "${certNum}" ] || [ "${certNum}" == "3" ];then
		echoColor green "请输入自签证书的域名(默认:wechat.com):"
		read domain
		if [ -z "${domain}" ];then
			domain="wechat.com"
		fi
		ip=`curl -4 -s -m 8 ip.sb`
		cert="/etc/hihy/cert/${domain}.crt"
		key="/etc/hihy/cert/${domain}.key"
		useAcme=false
		echoColor purple "\n您已选择自签${domain}证书加密.公网ip:"`echoColor red ${ip}`"\n"
    elif [ "${certNum}" == "2" ];then
		echoColor green "请输入证书cert文件路径(需fullchain):"
		read cert
		while :
		do
			if [ ! -f "${cert}" ];then
				echoColor red "\n路径不存在,请重新输入!"
				echoColor green "请输入证书cert文件路径(需fullchain):"
				read  cert
			else
				break
			fi
		done
		echoColor green "请输入证书key文件路径:"
		read key
		while :
		do
			if [ ! -f "${key}" ];then
				echoColor red "\n路径不存在,请重新输入!"
				echoColor green "请输入证书key文件路径:"
				read  key
			else
				break
			fi
		done
		echoColor green "请输入所选证书域名:"
		read domain
		while :
		do
			if [ -z "${domain}" ];then
				echoColor red "\n此选项不能为空,请重新输入!"
				echoColor green "请输入所选证书域名:"
				read  domain
			else
				break
			fi
		done
		useAcme=false
		useLocalCert=true
		echoColor purple "\n您已选择使用本地${domain}证书加密.\n"
    else 
    	echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
		read domain
		while :
		do
			if [ -z "${domain}" ];then
				echoColor red "\n此选项不能为空,请重新输入!"
				echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
				read  domain
			else
				break
			fi
		done
		useAcme=true
		echoColor purple "\n您已选择使用ACME自动签发可信的${domain}证书加密.\n"
    fi

	while :
	do
		echoColor green "请输入你想要开启的端口,此端口是server端口,建议10000-65535.(默认随机)"
		read  port
		if [ -z "${port}" ];then
			port=$(($(od -An -N2 -i /dev/random) % (65534 - 10001) + 10001))
			echo -e "随机端口:"`echoColor red ${port}`"\n"
		fi
		pIDa=`lsof -i :${port}|grep -v "PID" | awk '{print $2}'`
		if [ "$pIDa" != "" ];
		then
			echoColor red "端口${port}被占用,PID:${pIDa}!请重新输入或者运行kill -9 ${pIDa}后重新安装!"
		else
			break
		fi
	done
    echo -e "\033[32m选择协议类型:\n\n\033[0m\033[33m\033[01m1、udp(QUIC)\n2、faketcp\n3、wechat-video(回车默认)\033[0m\033[32m\n\n输入序号:\033[0m"
    read protocol
	ut=
    if [ -z "${protocol}" ] || [ $protocol == "3" ];then
		protocol="wechat-video"
		ut="udp"
    elif [ $protocol == "2" ];then
		protocol="faketcp"
		ut="tcp"
    else 
    	protocol="udp"
		ut="udp"
    fi
    echo -e "传输协议:"`echoColor red ${protocol}`"\n"

    echoColor green "请输入您到此服务器的平均延迟,关系到转发速度(默认200,单位:ms):"
    read  delay
    if [ -z "${delay}" ];then
	delay=200
    echo -e "delay:`echoColor red ${delay}`ms\n"
    fi
    echo -e "\n期望速度,这是客户端的峰值速度,服务端默认不受限。"`echoColor red Tips:脚本会自动*1.25做冗余，您期望过低或者过高会影响转发效率,请如实填写!`
    echoColor green "请输入客户端期望的下行速度:(默认50,单位:mbps):"
    read  download
    if [ -z "${download}" ];then
        download=50
    echo -e "客户端下行速度："`echoColor red ${download}`"mbps\n"
    fi
    echo -e "\033[32m请输入客户端期望的上行速度(默认10,单位:mbps):\033[0m" 
    read  upload
    if [ -z "${upload}" ];then
        upload=10
    echo -e "客户端上行速度："`echoColor red ${download}`"mbps\n"
    fi
	auth_str=""
	echoColor green "请输入认证口令:"
	read  auth_str
	while :
	do
		if [ -z "${auth_str}" ];then
			echoColor red "\n此选项不能省略,请重新输入!"
			echoColor green "请输入认证口令:"
			read  auth_str
		else
			break
		fi
	done
    echoColor green "\n配置录入完成!\n"
    echoColor yellowBlack "执行配置..."
    download=$(($download + $download / 4))
    upload=$(($upload + $upload / 4))
    r_client=$(($delay * 2 * $download / 1000 * 1024 * 1024))
    r_conn=$(($r_client / 4))
	allowPort ${ut} ${port}
    if echo "${useAcme}" | grep -q "false";then
		if echo "${useLocalCert}" | grep -q "false";then
			v6str=":" #Is ipv6?
			result=$(echo ${ip} | grep ${v6str})
			if [ "${result}" != "" ];then
				ip="[${ip}]" 
			fi
			u_host=${ip}
			u_domain=${domain}
			sec="1"
			mail="admin@qq.com"
			days=36500
			echoColor purple "SIGN...\n"
			openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048
			openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt
			openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.csr
			openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt
			rm /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr
			mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result
			echoColor purple "SUCCESS.\n"
			cat <<EOF > /etc/hihy/result/hihyClient.json
{
"server": "${ip}:${port}",
"protocol": "${protocol}",
"up_mbps": ${upload},
"down_mbps": ${download},
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "${auth_str}",
"server_name": "${domain}",
"insecure": true,
"recv_window_conn": ${r_conn},
"recv_window": ${r_client},
"disable_mtu_discovery": true,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
EOF
		else
			u_host=${domain}
			u_domain=${domain}
			sec="0"
			cat <<EOF > /etc/hihy/result/hihyClient.json
{
"server": "${domain}:${port}",
"protocol": "${protocol}",
"up_mbps": ${upload},
"down_mbps": ${download},
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "${auth_str}",
"server_name": "${domain}",
"insecure": false,
"recv_window_conn": ${r_conn},
"recv_window": ${r_client},
"disable_mtu_discovery": true,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
EOF
		fi		
		cat <<EOF > /etc/hihy/conf/hihyServer.json
{
"listen": ":${port}",
"protocol": "${protocol}",
"disable_udp": false,
"cert": "${cert}",
"key": "${key}",
"auth": {
	"mode": "password",
	"config": {
	"password": "${auth_str}"
	}
},
"alpn": "h3",
"acl": "/etc/hihy/acl/hihyServer.acl",
"recv_window_conn": ${r_conn},
"recv_window_client": ${r_client},
"max_conn_client": 4096,
"disable_mtu_discovery": true,
"resolve_preference": "46",
"resolver": "8.8.8.8:53"
}
EOF

    else
		u_host=${domain}
		u_domain=${domain}
		sec="0"
		allowPort tcp 80
		allowPort tcp 443
		cat <<EOF > /etc/hihy/conf/hihyServer.json
{
"listen": ":${port}",
"protocol": "${protocol}",
"acme": {
    "domains": [
    "${domain}"
    ],
    "email": "pekora@${domain}"
},
"disable_udp": false,
"auth": {
    "mode": "password",
    "config": {
    "password": "${auth_str}"
    }
},
"alpn": "h3",
"acl": "/etc/hihy/acl/hihyServer.acl",
"recv_window_conn": ${r_conn},
"recv_window_client": ${r_client},
"max_conn_client": 4096,
"disable_mtu_discovery": true,
"resolve_preference": "46",
"resolver": "8.8.8.8:53"
}
EOF

		cat <<EOF > /etc/hihy/result/hihyClient.json
{
"server": "${domain}:${port}",
"protocol": "${protocol}",
"up_mbps": ${upload},
"down_mbps": ${download},
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "${auth_str}",
"server_name": "${domain}",
"insecure": false,
"recv_window_conn": ${r_conn},
"recv_window": ${r_client},
"disable_mtu_discovery": true,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
EOF
    fi

	echo -e "\033[1;;35m\nWait,test config...\n\033[0m"
	echo "block all udp/443" > /etc/hihy/acl/hihyServer.acl
	/etc/hihy/bin/appS -c /etc/hihy/conf/hihyServer.json server > /tmp/hihy_debug.info 2>&1 &
	sleep 10
	msg=`cat /tmp/hihy_debug.info`
	case ${msg} in 
		*"Failed to get a certificate with ACME"*)
			echoColor red "域名:${u_host},申请证书失败!请查看服务器提供的面板防火墙是否开启(TCP:80,443)\n或者域名是否正确解析到此ip(不要开CDN!)\n如果无法满足以上两点,请重新安装使用自签证书."
			rm /etc/hihy/conf/hihyServer.json
			rm /etc/hihy/result/hihyClient.json
			rm /etc/systemd/system/hihy.service
			exit
			;;
		*"bind: address already in use"*)
			echoColor red "端口被占用,请更换端口!"
			exit
			;;
		*"Server up and running"*) 
			echoColor purple "Test success."
			pIDa=`lsof -i :${port}|grep -v "PID" | awk '{print $2}'`
			kill -9 ${pIDa} > /dev/null 2>&1
			;;
		*) 	
			pIDa=`lsof -i :${port}|grep -v "PID" | awk '{print $2}'`
			kill -9 ${pIDa} > /dev/null 2>&1
			echoColor red "未知错误:请手动运行:`echoColor green "/etc/hihy/bin/appS -c /etc/hihy/conf/hihyServer.json server"`"
			echoColor red "查看错误日志,反馈到issue!"
			exit
			;;
	esac
	rm /tmp/hihy_debug.info
	url="hysteria://${u_host}:${port}?protocol=${protocol}&auth=${auth_str}&peer=${u_domain}&insecure=${sec}&upmbps=${upload}&downmbps=${download}&alpn=h3#Hys-${u_host}"
	echo ${url} > /etc/hihy/result/url.txt
	#clear
}

function downloadHysteriaCore(){
	version=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
	echo -e "The Latest hysteria version:"`echoColor red "${version}"`"\nDownload..."
    get_arch=`arch`
    if [ $get_arch = "x86_64" ];then
        wget -q -O /etc/hihy/bin/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/${version}/hysteria-linux-amd64
    elif [ $get_arch = "aarch64" ];then
        wget -q -O /etc/hihy/bin/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/${version}/hysteria-linux-arm64
    elif [ $get_arch = "mips64" ];then
        wget -q -O /etc/hihy/bin/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/${version}/hysteria-linux-mipsle
	elif [ $get_arch = "s390x" ];then
		wget -q -O /etc/hihy/bin/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/${version}/hysteria-tun-linux-s390x
    else
        echoColor yellowBlack "Error[OS Message]:${get_arch}\nPlease open a issue to https://github.com/emptysuns/Hi_Hysteria !"
        exit
    fi
	chmod 755 /etc/hihy/bin/appS
	echoColor purple "\nDownload completed."
}

function updateHysteriaCore(){
	if [ -f "/etc/hihy/bin/appS" ]; then
		localV=`/etc/hihy/bin/appS -v | cut -d " " -f 3`
		remoteV=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
		echo -e "Local core version:"`echoColor red "${localV}"`
		echo -e "Remote core version:"`echoColor red "${remoteV}"`
		if [ "${localV}" = "${remoteV}" ];then
			echoColor green "Already the latest version.Ignore."
		else
			status=`systemctl is-active hihy`
			if [ "${status}" = "active" ];then #如果是正常运行情况下将先停止守护进程再自动更新后重启，否则只负责更新
				systemctl stop hihy
				downloadHysteriaCore
				systemctl start hihy
			else
				downloadHysteriaCore
			fi
			echoColor green "Hysteria Core update done."
		fi
	else
		echoColor red "hysteria core not found."
		exit
	fi
}

function changeServerConfig(){
	if [ ! -f "/etc/systemd/system/hihy.service" ]; then
		echoColor red "请先安装hysteria,再去修改配置..."
		exit
	fi
	systemctl stop hihy
	delHihyFirewallPort
	updateHysteriaCore
	setHysteriaConfig
	systemctl start hihy
	printMsg
	echoColor yellowBlack "重新配置完成."
	
}

function hihyUpdate(){
	localV=${hihyV}
	remoteV=`curl -fsSL https://git.io/hysteria.sh | sed  -n 2p | cut -d '"' -f 2`
	if [ "${localV}" = "${remoteV}" ];then
		echoColor green "Already the latest version.Ignore."
	else
		wget -q -O /usr/bin/hihy --no-check-certificate https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/server/install.sh
		chmod +x /usr/bin/hihy
		echoColor green "Done."
	fi

}

function hihyNotify(){
	localV=${hihyV}
	remoteV=`curl -fsSL https://git.io/hysteria.sh | sed  -n 2p | cut -d '"' -f 2`
	if [ "${localV}" != "${remoteV}" ];then
		echoColor yellowBlack "[Update] hihy有更新,version:v${remoteV},建议更新并查看日志: https://github.com/emptysuns/Hi_Hysteria"
	fi

}

function hyCoreNotify(){
	if [ -f "/etc/hihy/bin/appS" ]; then
  		localV=`/etc/hihy/bin/appS -v | cut -d " " -f 3`
		remoteV=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
		if [ "${localV}" != "${remoteV}" ];then
			echoColor purple "[Update] hysteria有更新,version:${remoteV}. detail: https://github.com/HyNetwork/hysteria/blob/master/CHANGELOG.md"
		fi
	fi
}


function checkStatus(){
	status=`systemctl is-active hihy`
    if [ "${status}" = "active" ];then
		echoColor green "hysteria正常运行"
	else
		echoColor red "Dead!hysteria未正常运行!"
	fi
}

function install()
{	
	if [ -f "/etc/systemd/system/hihy.service" ]; then
		echoColor green "你已经成功安装hysteria,如需修改配置请使用选项9/12"
		exit
	fi
	mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert  /etc/hihy/result
    echoColor purple "Ready to install.\n"
    version=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
    checkSystemForUpdate
	downloadHysteriaCore
	setHysteriaConfig
    cat <<EOF >/etc/systemd/system/hihy.service
[Unit]
Description=hysteria:Hello World!
After=network.target

[Service]
Type=simple
PIDFile=/run/hihy.pid
ExecStart=/etc/hihy/bin/appS --log-level warn -c /etc/hihy/conf/hihyServer.json server
#Restart=on-failure
#RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
    sysctl -w net.core.rmem_max=8000000
    sysctl -p
    chmod 644 /etc/systemd/system/hihy.service
    systemctl daemon-reload
    systemctl enable hihy
    systemctl start hihy
	crontab -l > /tmp/crontab.tmp
	echo  "0 4 * * * systemctl restart hihy" >> /tmp/crontab.tmp
	crontab /tmp/crontab.tmp
	rm /tmp/crontab.tmp
	printMsg
	echoColor yellowBlack "安装完毕"
}


# 输出ufw端口开放状态
function checkUFWAllowPort() {
	if ufw status | grep -q "$1"; then
		echoColor purple "UFW OPEN: ${1}"
	else
		echoColor red "UFW OPEN FAIL: ${1}"
		exit 0
	fi
}

# 输出firewall-cmd端口开放状态
function checkFirewalldAllowPort() {
	if firewall-cmd --list-ports --permanent | grep -q "$1"; then
		echoColor purple "FIREWALLD OPEN: ${1}/${2}"
	else
		echoColor red "FIREWALLD OPEN FAIL: ${1}/${2}"
		exit 0
	fi
}

function allowPort() {
	# 如果防火墙启动状态则添加相应的开放端口
	# $1 tcp/udp
	# $2 port
	if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
		local updateFirewalldStatus=
		if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
			updateFirewalldStatus=true
			iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT 2> /dev/null
			echoColor purple "IPTABLES OPEN: ${1}/${2}"
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			netfilter-persistent save 2>/dev/null
		fi
	elif [[ `ufw status 2>/dev/null | grep "Status: " | awk '{print $2}'` = "active" ]]; then
		if ! ufw status | grep -q ${2}; then
			sudo ufw allow ${2} 2>/dev/null
			checkUFWAllowPort ${2}
		fi
	elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
		local updateFirewalldStatus=
		if ! firewall-cmd --list-ports --permanent | grep -qw "${2}/${1}"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --add-port=${2}/${1} --permanent 2>/dev/null
			checkFirewalldAllowPort ${2}
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload
		fi
	fi
}

function delHihyFirewallPort() {
	# 如果防火墙启动状态则删除之前的规则
	if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
		local updateFirewalldStatus=
		if iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
			updateFirewalldStatus=true
			iptables-save |  sed -e '/hihysteria/d' | iptables-restore
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			netfilter-persistent save 2> /dev/null
		fi
	elif [[ `ufw status 2>/dev/null | grep "Status: " | awk '{print $2}'` = "active" ]]; then
		port=`cat /etc/hihy/conf/hihyServer.json | grep "listen" | awk '{print $2}' | tr -cd "[0-9]"`
		if ufw status | grep -q ${port}; then
			sudo ufw delete allow ${port} 2> /dev/null
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
		if firewall-cmd --list-ports --permanent | grep -qw "${port}/${ut}"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --remove-port=${port}/${ut} 2> /dev/null
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload 2> /dev/null
		fi
	fi
}

function checkRoot(){
	user=`whoami`
	if [ ! "${user}" = "root" ];then
		echoColor red "Please run as root user!"
		exit 0
	fi
}

function changeMode(){
	if [ ! -f "/etc/hihy/conf/hihyServer.json" ]; then
		echoColor red "配置文件不存在,exit..."
		exit
	fi
	protocol=`cat /etc/hihy/conf/hihyServer.json  | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
	echoColor yellow "当前使用协议为:"
	echoColor purple "${protocol}"
	port=`cat /etc/hihy/conf/hihyServer.json | grep "listen" | awk '{print $2}' | tr -cd "[0-9]"`
	if [ "${protocol}" = "udp" ];then
		echo -e "\033[32m\n请选择修改的协议类型:\n\n\033[0m\033[33m\033[01m1、faketcp\n2、wechat-video\033[0m\033[32m\n\n输入序号:\033[0m"
    	read pNum
		if [ -z "${pNum}" ] || [ "${pNum}" == "1" ];then
			echoColor purple "选择修改协议类型为faketcp."
			sed -i 's/"protocol": "udp"/"protocol": "faketcp"/g' /etc/hihy/conf/hihyServer.json
			delHihyFirewallPort
			allowPort "tcp" ${port}
		else
			echoColor purple "选择修改协议类型为wechat-video."
			sed -i 's/"protocol": "udp"/"protocol": "wechat-video"/g' /etc/hihy/conf/hihyServer.json
		fi
	elif [ "${protocol}" = "faketcp" ];then
		delHihyFirewallPort
		allowPort "udp" ${port}
		echo -e "\033[32m\n请选择修改的协议类型:\n\n\033[0m\033[33m\033[01m1、udp\n2、wechat-video\033[0m\033[32m\n\n输入序号:\033[0m"
    	read pNum
		if [ -z "${pNum}" ] || [ "${pNum}" == "1" ];then
			echoColor purple "选择修改协议类型为udp."
			sed -i 's/"protocol": "faketcp"/"protocol": "udp"/g' /etc/hihy/conf/hihyServer.json
		else
			echoColor purple "选择修改协议类型为wechat-video."
			sed -i 's/"protocol": "faketcp"/"protocol": "wechat-video"/g' /etc/hihy/conf/hihyServer.json
		fi
	elif [ "${protocol}" = "wechat-video" ];then
		echo -e "\033[32m\n请选择修改的协议类型:\n\n\033[0m\033[33m\033[01m1、udp\n2、faketcp\033[0m\033[32m\n\n输入序号:\033[0m"
    	read pNum
		if [ -z "${pNum}" ] || [ "${pNum}" == "1" ];then
			echoColor purple "选择修改协议类型为udp."
			sed -i 's/"protocol": "wechat-video"/"protocol": "udp"/g' /etc/hihy/conf/hihyServer.json
		else
			delHihyFirewallPort
			allowPort "tcp" ${port}
			echoColor purple "选择修改协议类型为faketcp."
			sed -i 's/"protocol": "wechat-video"/"protocol": "faketcp"/g' /etc/hihy/conf/hihyServer.json
		fi
	else
		echoColor red "无法识别协议类型!"
		exit
	fi
	systemctl restart hihy
	echoColor green "修改成功"
}



function menu()
{
hihy
clear
cat << EOF
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns ************|
|**********     Version: `echoColor red "${hihyV}"`    **********|
 -------------------------------------------
Tips:`echoColor green "hihy"`命令再次运行本脚本.
`echoColor skyBlue "............................................."`
`echoColor purple "###############################"`

`echoColor skyBlue "....................."`
`echoColor yellow "1)  安装 hysteria"`
`echoColor magenta "2)  卸载 hysteria"`
`echoColor skyBlue "....................."`
`echoColor yellow "3)  启动 hysteria"`
`echoColor magenta "4)  暂停 hysteria"`
`echoColor yellow "5)  重新启动 hysteria"`
`echoColor yellow "6)  运行状态"`
`echoColor skyBlue "....................."`
`echoColor yellow "7)  更新hysteria core"`
`echoColor yellow "8)  查看当前配置"`
`echoColor skyBlue "9)  重新配置hysteria"`
`echoColor yellow "10) 切换ipv4/ipv6优先级"`
`echoColor yellow "11) 更新hihy"`
`echoColor red "12) 完全重置所有配置"`
`echoColor skyBlue "13) 修改当前协议类型"`

`echoColor purple "###############################"`
`hihyNotify`
`hyCoreNotify`

`echoColor magenta "0)退出"`
`echoColor skyBlue "............................................."`
EOF
read -p "请选择:" input
case $input in
	1)	
		install
	;;
	2)
		uninstall
	;;
	3)
		systemctl start hihy
		echoColor green "启动成功"
	;;
	4)
		systemctl stop hihy
		echoColor green "暂停成功"
	;;
    5)
        systemctl restart hihy
		echoColor green "重启成功"

    ;;
    6)
        checkStatus
	;;
	7)
		updateHysteriaCore
	;;
	8)
		printMsg
    ;;
    9)
        changeServerConfig
    ;;
	10)
        changeIp64
    ;;
	11)
        hihyUpdate
    ;;
	12)
        reinstall
	;;
	13)
        changeMode
    ;;
	0)
		exit
	;;
	*)
		echoColor red "Input Error ,Please again !!!"
		exit 1
	;;
    esac
}

checkRoot
menu
