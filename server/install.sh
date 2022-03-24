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
		echoContent red "\n本脚本不支持此系统,请将下方日志反馈给开发者\n"
		echoContent yellow "$(cat /etc/issue)"
		echoContent yellow "$(cat /proc/version)"
		exit 0
	fi
    echoColor purple "\nUpdate.wait..."
    ${upgrade}
    echoColor purple "\nDone.\nInstall wget curl netfilter-persistent"
	echoColor green "*wget"
	${installType} "wget"
	echoColor green "*curl"
	${installType} "curl"
	echoColor green "*netfilter-persistent"
	${installType} "netfilter-persistent"
    echoColor purple "\nDone."
    
}

function uninstall(){
    bash <(curl -fsSL https://git.io/rmhysteria.sh)
}

function reinstall(){
    bash <(curl -fsSL https://git.io/rehysteria.sh)
}

function printMsg(){
	echoColor yellowBlack "配置文件输出如下且已经在本目录生成(可自行复制粘贴到本地)"
	echoColor green "\n\nTips:客户端默认只开启http(8888)、socks5(8889)代理!其他方式请参照文档自行修改客户端config.json"
	echoColor purple "***********************************↓↓↓copy↓↓↓*******************************↓"
	cat ./config.json
	echoColor purple "↑***********************************↑↑↑copy↑↑↑*******************************↑\n"
	url=`cat /etc/hihy/url.txt`
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

function menu()
{
hihy
clear
cat << EOF
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns ************|
|**********     Version: `echoColor red "0.3.1"`    **********|
 -------------------------------------------

Tips:`echoColor green "hihy"`命令再次运行本脚本.
`echoColor skyBlue "............................................."`

`echoColor purple "###############################"`

`echoColor skyBlue "....................."`
`echoColor yellow "1)安装 hysteria"`
`echoColor red "2)卸载 hysteria"`

`echoColor skyBlue "....................."`
`echoColor yellow "3)启动 hysteria"`
`echoColor red "4)暂停 hysteria"`
`echoColor yellow "5)重新启动 hysteria"`
`echoColor yellow "6)检测 hysteria运行状态"`

`echoColor skyBlue "....................."`
`echoColor yellow "7)查看当前配置"`
`echoColor skyBlue "8)重新安装/升级"`

`echoColor purple "###############################"`


`echoColor red "0)退出"`
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
		printMsg
	;;
	8)
		reinstall
    ;;
	0)
		exit
	;;
	*)
		echo "Input Error ,Please again !!!"
		exit 1
	;;
    esac
}


function checkStatus(){
	status=`systemctl is-active hihy`
    if [ "${status}" = "active" ];then
		echoColor green "hysteria正常运行"
	else
		echoColor red "dead!hysteria未正常运行!"
	fi
}

function install()
{	
    echoColor purple "Ready to install.\n"
    mkdir -p /etc/hihy
    version=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`
    echo -e "The Latest hysteria version:"`echoColor red "${version}"`"\nDownload..."
    get_arch=`arch`
    if [ $get_arch = "x86_64" ];then
        wget -q -O /etc/hihy/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/$version/hysteria-linux-amd64
    elif [ $get_arch = "aarch64" ];then
        wget -q -O /etc/hihy/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/$version/hysteria-linux-arm64
    elif [ $get_arch = "mips64" ];then
        wget -q -O /etc/hihy/appS --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/$version/hysteria-linux-mipsle
    else
        echoColor yellowBlack "Error[OS Message]:${get_arch}\nPlease open a issue to https://github.com/emptysuns/Hi_Hysteria !"
        exit
    fi
	echoColor purple "\nDownload completed."
	checkSystemForUpdate
    chmod 755 /etc/hihy/appS
    echoColor yellowBlack "开始配置:"
    echoColor green "请输入您的域名(不输入回车,则默认自签wechat.com证书,不推荐):"
    read  domain
    if [ -z "${domain}" ];then
        domain="wechat.com"
    ip=`curl -4 -s ip.sb`
    echo -e "您选择自签wechat证书.公网ip:"`echoColor red ${ip}`"\n"
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
			echoColor red "端口被占用!请重新输入!"
		else
			break
		fi
	done
    echo -e "\033[32m选择协议类型:\n\n\033[0m\033[33m\033[01m1、udp(QUIC)\n2、faketcp\n3、wechat-video(回车默认)\033[0m\033[32m\n\n输入序号:\033[0m"
    read protocol
    if [ -z "${protocol}" ] || [ $protocol == "3" ];then
    protocol="wechat-video"
    iptables -I INPUT -p udp --dport ${port} -m comment --comment "allow udp(hihysteria)" -j ACCEPT
    elif [ $protocol == "2" ];then
    protocol="faketcp"
    iptables -I INPUT -p tcp --dport ${port}  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
    else 
    protocol="udp"
    iptables -I INPUT -p udp --dport ${port} -m comment --comment "allow udp(hihysteria)" -j ACCEPT
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

    if [ "$domain" = "wechat.com" ];then
		u_host=${ip}
		u_domain="wechat.com"
		sec="1"
        mail="admin@qq.com"
        days=36500

        echoColor purple "SIGN...\n"
        openssl genrsa -out /etc/hihy/$domain.ca.key 2048

        openssl req -new -x509 -days $days -key /etc/hihy/$domain.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=$mail/CN=Tencent Root CA" -out /etc/hihy/$domain.ca.crt

        openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/$domain.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=$mail/CN=Tencent Root CA" -out /etc/hihy/$domain.csr

        openssl x509 -req -extfile <(printf "subjectAltName=DNS:$domain,DNS:$domain") -days $days -in /etc/hihy/$domain.csr -CA /etc/hihy/$domain.ca.crt -CAkey /etc/hihy/$domain.ca.key -CAcreateserial -out /etc/hihy/$domain.crt

        rm /etc/hihy/${domain}.ca.key /etc/hihy/${domain}.ca.srl /etc/hihy/${domain}.csr
        echoColor purple "OK.\n"

cat <<EOF > /etc/hihy/config.json
{
"listen": ":$port",
"protocol": "$protocol",
"disable_udp": false,
"cert": "/etc/hihy/$domain.crt",
"key": "/etc/hihy/$domain.key",
"auth": {
	"mode": "password",
	"config": {
	"password": "$auth_str"
	}
},
"alpn": "h3",
"recv_window_conn": $r_conn,
"recv_window_client": $r_client,
"max_conn_client": 4096,
"disable_mtu_discovery": false,
"resolver": "8.8.8.8:53"
}
EOF

        v6str=":"
        result=$(echo $ip | grep ${v6str})
        if [ "$result" != "" ];then
            ip="[$ip]" #ipv6? check
        fi

cat <<EOF > config.json
{
"server": "$ip:$port",
"protocol": "$protocol",
"up_mbps": $upload,
"down_mbps": $download,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "$auth_str",
"server_name": "$domain",
"insecure": true,
"recv_window_conn": $r_conn,
"recv_window": $r_client,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
EOF

    else
		u_host=${domain}
		u_domain=${domain}
		sec="0"
        iptables -I INPUT -p tcp --dport 80  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
        iptables -I INPUT -p tcp --dport 443  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
		cat <<EOF > /etc/hihy/config.json
{
"listen": ":$port",
"protocol": "$protocol",
"acme": {
    "domains": [
    "$domain"
    ],
    "email": "pekora@$domain"
},
"disable_udp": false,
"auth": {
    "mode": "password",
    "config": {
    "password": "$auth_str"
    }
},
"alpn": "h3",
"recv_window_conn": $r_conn,
"recv_window_client": $r_client,
"max_conn_client": 4096,
"disable_mtu_discovery": false,
"resolver": "8.8.8.8:53"
}
EOF

		cat <<EOF > config.json
{
"server": "$domain:$port",
"protocol": "$protocol",
"up_mbps": $upload,
"down_mbps": $download,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "$auth_str",
"server_name": "$domain",
"insecure": false,
"recv_window_conn": $r_conn,
"recv_window": $r_client,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
EOF
    fi

	cat <<EOF >/etc/systemd/system/hihy.service
[Unit]
Description=hysteria:Hello World!
After=network.target

[Service]
Type=simple
PIDFile=/run/hihy.pid
ExecStart=/etc/hihy/appS --log-level warn -c /etc/hihy/config.json server
#Restart=on-failure
#RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
	echo -e "\033[1;;35m\nwait,test config...\n\033[0m"
	/etc/hihy/appS -c /etc/hihy/config.json server > /tmp/hihy_debug.info 2>&1 &
	sleep 10
	msg=`cat /tmp/hihy_debug.info`
	case ${msg} in 
		*"Failed to get a certificate with ACME"*)
			echoColor red "域名:${u_host},申请证书失败!请查看服务器提供的面板防火墙是否开启(TCP:80,443)\n或者域名是否正确解析到此ip(不要开CDN!)\n如果无法满足以上两点,请重新安装使用自签证书."
			rm /etc/hihy/config.json
			rm ./config.json
			rm /etc/systemd/system/hihy.service
			exit
			;;
		*"bind: address already in use"*)
			echoColor red "端口被占用,请更换端口!"
			exit
			;;
		*"Server up and running"*) 
			echoColor purple "Test ok."
			pIDa=`lsof -i :${port}|grep -v "PID" | awk '{print $2}'`
			kill -9 ${pIDa}
			;;
		*) 
			echoColor red "未知错误:请手动运行:`echoColor green "/etc/hihy/appS -c /etc/hihy/config.json server"`"
			echoColor red "查看错误日志,反馈到issue!"
			exit
			;;
	esac
	rm /tmp/hihy_debug.info
	netfilter-persistent save
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
	url="hysteria://${u_host}:${port}?protocol=${protocol}&auth=${auth_str}&peer=${u_domain}&insecure=${sec}&upmbps=${upload}&downmbps=${download}&alpn=h3#Hys-${u_host}"
	echo ${url} > /etc/hihy/url.txt
	#clear
	printMsg
	echoColor yellowBlack "安装完毕"
}

menu