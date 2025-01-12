#!/bin/bash
hihyV="1.0.0"

cronTask(){

    if [ -f "/etc/hihy/logs/hihy.log" ];then
        rm /etc/hihy/logs/hihy.log
        touch /etc/hihy/logs/hihy.log
    fi
}
echoColor() {
    case $1 in
        # 红色
        "red") echo -e "\033[31m${printN}$2 \033[0m" ;;
        # 天蓝色
        "skyBlue") echo -e "\033[1;36m${printN}$2 \033[0m" ;;
        # 绿色
        "green") echo -e "\033[32m${printN}$2 \033[0m" ;;
        # 白色
        "white") echo -e "\033[37m${printN}$2 \033[0m" ;;
        # 洋红色
        "magenta") echo -e "\033[35m${printN}$2 \033[0m" ;;
        # 黄色
        "yellow") echo -e "\033[33m${printN}$2 \033[0m" ;;
        # 紫色
        "purple") echo -e "\033[1;35m${printN}$2 \033[0m" ;;
        # 黑底黄字
        "yellowBlack") echo -e "\033[1;33;40m${printN}$2 \033[0m" ;;
        # 绿底白字
        "greenWhite") echo -e "\033[42;37m${printN}$2 \033[0m" ;;
        # 蓝色
        "blue") echo -e "\033[34m${printN}$2 \033[0m" ;;
        # 青色
        "cyan") echo -e "\033[36m${printN}$2 \033[0m" ;;
        # 黑色
        "black") echo -e "\033[30m${printN}$2 \033[0m" ;;
        # 灰色
        "gray") echo -e "\033[90m${printN}$2 \033[0m" ;;
        # 亮红色
        "lightRed") echo -e "\033[91m${printN}$2 \033[0m" ;;
        # 亮绿色
        "lightGreen") echo -e "\033[92m${printN}$2 \033[0m" ;;
        # 亮黄色
        "lightYellow") echo -e "\033[93m${printN}$2 \033[0m" ;;
        # 亮蓝色
        "lightBlue") echo -e "\033[94m${printN}$2 \033[0m" ;;
        # 亮洋红色
        "lightMagenta") echo -e "\033[95m${printN}$2 \033[0m" ;;
        # 亮青色
        "lightCyan") echo -e "\033[96m${printN}$2 \033[0m" ;;
        # 亮白色
        "lightWhite") echo -e "\033[97m${printN}$2 \033[0m" ;;
    esac
}


# 检测系统架构的函数
getArchitecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*)
            echo "arm"
            ;;
        s390x)
            echo "s390x"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}


checkSystemForUpdate() {
    local release=""
    local installType=""
    local updateNeeded=false
    local packageManager=""
    local requiredPackages=("wget" "curl" "lsof" "bash" "iptables" "bc")

    # 检测包管理器
    if command -v apt >/dev/null; then
        packageManager="apt"
        installType="apt -y -q install"
        upgrade="apt update"
    elif command -v yum >/dev/null; then
        packageManager="yum"
        installType="yum -y -q install"
        upgrade="yum update -y --skip-broken"
    elif command -v dnf >/dev/null; then
        packageManager="dnf"
        installType="dnf -y install"
        upgrade="dnf update -y"
    elif command -v pacman >/dev/null; then
        packageManager="pacman"
        installType="pacman -Sy --noconfirm"
        upgrade="pacman -Syy"
    elif command -v apk >/dev/null; then
        packageManager="apk"
        installType="apk add --no-cache"
        upgrade="apk update"
    else
        echoColor red "\n未检测到支持的包管理器，请将以下信息反馈给开发者："
        echoColor yellow "$(cat /etc/issue 2>/dev/null)"
        echoColor yellow "$(cat /proc/version 2>/dev/null)"
        exit 1
    fi

    # 检查必需的包
    for package in "${requiredPackages[@]}"; do
        if ! command -v "$package" >/dev/null; then
            echoColor green "*$package"
            updateNeeded=true
        fi
    done

    # 检查 dig 命令
    if ! command -v dig >/dev/null; then
        echoColor green "*dnsutils"
        updateNeeded=true
    fi

    # 检查 qrencode 包
    if ! command -v qrencode >/dev/null; then
        echoColor green "*qrencode"
        updateNeeded=true
    fi

    # 检查 yq 命令
    # 安装 yq
    if ! command -v yq >/dev/null; then
        arch=$(getArchitecture)
        echoColor purple "正在下载 yq (${arch})..."
        wget "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" -O /usr/bin/yq
        if [ $? -ne 0 ]; then
            echoColor red "下载 yq 失败"
            exit 1
        fi
        chmod +x /usr/bin/yq
    fi

    # 检查 chrt 命令
    if ! command -v chrt >/dev/null; then
        echoColor green "*util-linux"
        updateNeeded=true
    fi

    # 仅在需要安装包时更新软件源
    if [ "$updateNeeded" = true ]; then
        echoColor purple "\n更新软件源..."
        ${upgrade}

        # 安装必需的包
        for package in "${requiredPackages[@]}"; do
            if ! command -v "$package" >/dev/null; then
                ${installType} "$package"
            fi
        done

        # 安装 dig
        if ! command -v dig >/dev/null; then
            case $packageManager in
                "apt") ${installType} "dnsutils" ;;
                "yum"|"dnf") ${installType} "bind-utils" ;;
                "pacman") ${installType} "bind-tools" ;;
                "apk") ${installType} "bind-tools" ;;
            esac
        fi

        # 安装 qrencode
        if ! command -v qrencode >/dev/null; then
            case $packageManager in
                "apt") ${installType} "qrencode" ;;
                "yum"|"dnf") ${installType} "qrencode" ;;
                "pacman") ${installType} "qrencode" ;;
                "apk") ${installType} "libqrencode-tools" ;;
            esac
        fi

        # 安装 util-linux
        if ! command -v chrt >/dev/null; then
            ${installType} "util-linux"
        fi

        # 确保有 pkill 命令
        if ! command -v pkill >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "procps" ;;
                "yum"|"dnf") ${installType} "procps" ;;
                "pacman") ${installType} "procps" ;;
                "apk") ${installType} "procps" ;;
            esac
        fi

         # 确保有 crontab 命令
        if ! command -v pkill >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "cron" ;;
                "yum"|"dnf") ${installType} "cron" ;;
                "pacman") ${installType} "cronie" ;;
                "apk") ${installType} "cronie" ;;
            esac
        fi

        echoColor purple "\n软件包安装完成."
    fi
}

getPortBindMsg() {
    # $1 type UDP or TCP
    # $2 port
    local msg
    if [ "$1" == "UDP" ]; then
        msg=$(lsof -i "${1}:${2}")
    else
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    fi

    if [ -z "$msg" ]; then
        return
    fi

    local command pid name
    command=$(echo "$msg" | awk '{print $1}')
    pid=$(echo "$msg" | awk '{print $2}')
    name=$(echo "$msg" | awk '{print $9}')
    echoColor purple "Port: ${1}/${2} 已经被 ${command}(${name}) 占用,进程pid为: ${pid}."
    echoColor green "是否自动关闭端口占用?(y/N)"
    read -r bindP

    if [ -z "$bindP" ] || [[ ! "$bindP" =~ ^[yY]$ ]]; then
        echoColor red "由于端口被占用，退出安装。请手动关闭或者更换端口..."
        if [ "$1" == "TCP" ] && [ "$2" == "80" ]; then
            echoColor "如果需求上无法关闭 ${1}/${2}端口，请使用其他证书获取方式"
        fi
        exit
    fi

    pkill -f "/etc/hihy/bin/appS"
    echoColor purple "正在解绑..."
    sleep 3

    if [ "$1" == "TCP" ]; then
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    else
        msg=$(lsof -i "${1}:${2}")
    fi

    if [ -n "$msg" ]; then
        echoColor red "端口占用关闭失败,强制杀死进程后进程重启,请查看是否存在守护进程..."
        exit
    else
        echoColor green "端口解绑成功..."
    fi
}

generate_uuid() {
    if command -v uuidgen > /dev/null 2>&1; then
        uuid=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    else
        uuid=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32 | sed 's/\(.\{8\}\)/\1-/g;s/-$//')
    fi
    echo "$uuid"
}


addOrUpdateYaml() {
    local file=$1
    local keyPath=$2
    local value=$3
    local valueType=${4:-"auto"} # auto, string, number, bool

    # 检查文件是否存在，如果不存在则创建一个空文件
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi

    # 将值转换为 JSON 格式以避免解析错误
    local jsonValue
    if [[ $valueType == "auto" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "string" ]]; then
        jsonValue=$(echo "\"$value\"" | yq eval -o=json)
    elif [[ $valueType == "number" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "bool" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    else
        echo "Unsupported value type: $valueType"
        return 1
    fi

    # 使用 yq 修改 YAML 文件
    yq eval ".${keyPath} = ${jsonValue}" -i "$file"
}

getYamlValue() {
    local file=$1    # YAML文件路径
    local keyPath=$2 # 键路径，用点号分隔

    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件不存在"
        return 1
    fi

    # 使用 yq 读取 YAML 文件中的值
    value=$(yq eval ".${keyPath}" "$file")

    # 检查 yq 命令是否成功执行
    if [[ $? -ne 0 ]]; then
        echo "错误: 读取 YAML 文件失败"
        return 1
    fi

    echo "$value"
}

countdown() {
    local seconds=$1
    echo -ne "\033[32m⏰ 倒计时:\033[0m "
    
    while [ $seconds -gt 0 ]; do
        # 打印当前数字
        echo -ne "\033[31m$seconds\033[0m"
        sleep 1
        
        # 计算退格数量
        local digits=${#seconds}
        for ((i=0; i<digits; i++)); do
            echo -ne "\b \b"
        done
        
        ((seconds--))
    done
    
    # 清除最后一个数字并显示完成消息
    echo -ne " "  # 清除最后显示的数字
    echo -e "\n\033[32m✨ 完成!\033[0m"
}


setHysteriaConfig(){
	mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert  /etc/hihy/result /etc/hihy/acl/
    acl_file="/etc/hihy/acl/acl.txt"
    if [ -f "${acl_file}" ];then
        rm -r ${acl_file}
        
    fi
    touch $acl_file
	echoColor yellowBlack "开始配置:"
	echo -e "\033[32m(1/11)请选择证书申请方式:\n\n\033[0m\033[33m\033[01m1、使用ACME申请(推荐,需打开tcp 80/443)\n2、使用本地证书文件\n3、自签证书\n4、dns验证\033[0m\033[32m\n\n输入序号:\033[0m"
    read certNum
	useAcme=false
	useLocalCert=false
	yaml_file="/etc/hihy/conf/config.yaml"
	if [ -f "${yaml_file}" ];then
		rm -f ${yaml_file}
	fi
	touch $yaml_file
	

	if [ -z "${certNum}" ] || [ "${certNum}" == "3" ];then
		echoColor green "请输入自签证书的域名(默认:apple.com):"
		read domain
		if [ -z "${domain}" ];then
			domain="apple.com"
		fi
		echo -e "->自签证书域名为:"`echoColor red ${domain}`"\n"
		ip=`curl -4 -s -m 8 ip.sb`
		if [ -z "${ip}" ];then
			ip=`curl -s -m 8 ip.sb`
		fi
		echoColor green "判断客户端连接所使用的地址是否正确?公网ip:"`echoColor red ${ip}`"\n"
		while true
		do	
			echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、正确(默认)\n2、不正确,手动输入ip\033[0m\033[32m\n\n输入序号:\033[0m"
			read ipNum
			if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ];then
				break
			elif [ "${ipNum}" == "2" ];then
				echoColor green "请输入正确的公网ip(ipv6地址不需要加[]):"
				read ip
				if [ -z "${ip}" ];then
					echoColor red "输入错误,请重新输入..."
					continue
				fi
				break
			else
				echoColor red "\n->输入错误,请重新输入:"
			fi
		done		
		cert="/etc/hihy/cert/${domain}.crt"
		key="/etc/hihy/cert/${domain}.key"
		useAcme=false
		echoColor purple "\n\n->您已选择自签${domain}证书加密.公网ip:"`echoColor red ${ip}`"\n"
		echo -e "\n"

    elif [ "${certNum}" == "2" ];then
		echoColor green "请输入证书cert文件路径(需fullchain cert,提供完整证书链):"
		read cert
		while :
		do
			if [ ! -f "${cert}" ];then
				echoColor red "\n\n->路径不存在,请重新输入!"
				echoColor green "请输入证书cert文件路径:"
				read  cert
			else
				break
			fi
		done
		echo -e "\n\n->cert文件路径: "`echoColor red ${cert}`"\n"
		echoColor green "请输入证书key文件路径:"
		read key
		while :
		do
			if [ ! -f "${key}" ];then
				echoColor red "\n\n->路径不存在,请重新输入!"
				echoColor green "请输入证书key文件路径:"
				read  key
			else
				break
			fi
		done
		echo -e "\n\n->key文件路径: "`echoColor red ${key}`"\n"
		echoColor green "请输入所选证书域名:"
		read domain
		while :
		do
			if [ -z "${domain}" ];then
				echoColor red "\n\n->此选项不能为空,请重新输入!"
				echoColor green "请输入所选证书域名:"
				read  domain
			else
				break
			fi
		done
		useAcme=false
		useLocalCert=true
		echoColor purple "\n\n->您已选择本地证书加密.域名:"`echoColor red ${domain}`"\n"
    elif [ "${certNum}" == "4" ];then
        echoColor green "请输入域名:"
        read domain
        while :
        do
            if [ -z "${domain}" ];then
                echoColor red "\n\n->此选项不能为空,请重新输入!"
                echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
                read  domain
            else
                break
            fi
        done
        echo -e "\n\n->域名: "`echoColor red ${domain}`"\n"
        echo -e "\033[32m请选择DNS服务商:\n\n\033[0m\033[33m\033[01m1、Cloudflare(默认)\n2、Duck DNS\n3、Gandi.net\n4、Godaddy\n5、Name.com\n6、Vultr\033[0m\033[32m\n\n输入序号:\033[0m"
        read dnsNum
        if [ -z "${dnsNum}" ] || [ "${dnsNum}" == "1" ];then
            dns="cloudflare"
            echo -e "\n\n->您选择Cloudflare DNS验证\n"
            echoColor green "请输入cloudflare_api_token:"
            
            while :
            do
                read cloudflare_api_token
                if [ -z "${cloudflare_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入cloudflare_api_token:"
                else
                    break
                fi
            done
                    
        elif [ "${dnsNum}" == "2" ];then
            dns="duckdns"
            echo -e "\n\n->您选择Duck DNS DNS验证\n"
            echoColor green "请输入Duck DNS duckdns_api_token:"
            while :
            do
                read duckdns_api_token
                if [ -z "${duckdns_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Duck DNS duckdns_api_token:"
                else
                    break
                fi
            done
            echoColor green "请输入Duck DNS duckdns_override_domain:"
            while :
            do
                read duckdns_override_domain
                if [ -z "${duckdns_override_domain}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Duck DNS duckdns_override_domain:"
                    break
                fi
            done

        elif [ "${dnsNum}" == "3" ];then
            dns="gandi"
            echo -e "\n\n->您选择Gandi.net DNS验证\n"
            echoColor green "请输入Gandi gandi_api_token:"
            while :
            do
                read gandi_api_token
                if [ -z "${gandi_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Gandi gandi_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "4" ];then
            dns="godaddy"
            echo -e "\n\n->您选择Godaddy DNS验证\n"
            echoColor green "请输入Godaddy godaddy_api_token:"
            while :
            do
                read godaddy_api_token
                if [ -z "${godaddy_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入 Godaddy godaddy_api_token:"
                else
                    break
                fi 
            done
        elif [ "${dnsNum}" == "5" ];then
            dns="namedotcom"
            echo -e "\n\n->您选择Name.com DNS验证\n"
            echoColor green "请输入Name.com namedotcom_api_token:"
            while :
            do
                read namedotcom_api_token
                if [ -z "${namedotcom_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Name.com namedotcom_api_token:"
                else
                    break
                fi
            done
            echoColor green "请输入Name.com namedotcom_user:"
            
            while :
            do
                read namedotcom_user
                if [ -z "${namedotcom_user}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Name.com namedotcom_user:"
                else
                    break
                fi
            done

            echoColor green "请输入Name.com namedotcom_server:"
            while :
            do
                read namedotcom_server
                if [ -z "${namedotcom_server}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Name.com namedotcom_server:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "6" ];then
            dns="vultr"
            echo -e "\n\n->您选择Vultr DNS验证\n"
            echoColor green "请输入Vultr vultr_api_token:"
            while :
            do
                read vultr_api_token
                if [ -z "${vultr_api_token}" ];then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Vultr vultr_api_token:"
                else
                    break
                fi
            done
        else
            echoColor red "\n->输入错误,请重新输入:"
        fi
        ip=`curl -4 -s -m 8 ip.sb`
		if [ -z "${ip}" ];then
			ip=`curl -s -m 8 ip.sb`
		fi
		echoColor green "判断客户端连接所使用的地址是否正确?公网ip:"`echoColor red ${ip}`"\n"
		while true
		do	
			echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、正确(默认)\n2、不正确,手动输入ip\033[0m\033[32m\n\n输入序号:\033[0m"
			read ipNum
			if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ];then
				break
			elif [ "${ipNum}" == "2" ];then
				echoColor green "请输入正确的公网ip(ipv6地址不需要加[]):"
				read ip
				if [ -z "${ip}" ];then
					echoColor red "输入错误,请重新输入..."
					continue
				fi
				break
			else
				echoColor red "\n->输入错误,请重新输入:"
			fi
		done		
        echo -e "\n\n->您选择使用acme dns验证申请证书: "`echoColor red ${domain}`"\n"
        echo -e "\n ->dns验证方式: "`echoColor red ${dns}`"\n"
        echo -e "\n ->公网ip: "`echoColor red ${ip}`"\n"
        useAcme=true
        useDns=true
    else 
    	echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
		read domain
		while :
		do
			if [ -z "${domain}" ];then
				echoColor red "\n\n->此选项不能为空,请重新输入!"
				echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
				read  domain
			else
				break
			fi
		done
		while :
		do	
			echoColor purple "\n->检测${domain},DNS解析..."
			ip_resolv=`dig +short ${domain} A`
			if [ -z "${ip_resolv}" ];then
				ip_resolv=`dig +short ${domain} AAAA`
			fi
			if [ -z "${ip_resolv}" ];then
				echoColor red "\n\n->域名解析失败,没有获得任何dns记录(A/AAAA),请检查域名是否正确解析到本机!"
				echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
				read  domain
				continue
			fi
			remoteip=`echo ${ip_resolv} | awk -F " " '{print $1}'`
			v6str=":" #Is ipv6?
			result=$(echo ${remoteip} | grep ${v6str})
			if [ "${result}" != "" ];then
				localip=`curl -6 -s -m 8 ip.sb`
			else
				localip=`curl -4 -s -m 8 ip.sb`
			fi
			if [ -z "${localip}" ];then
				localip=`curl -s -m 8 ip.sb` #如果上面的ip.sb都失败了,最后检测一次
				if [ -z "${localip}" ];then
					echoColor red "\n\n->获取本机ip失败,请检查网络连接!curl -s -m 8 ip.sb"
					exit 1
				fi
			fi
			if [ "${localip}" != "${remoteip}" ];then
				echo -e " \n\n->本机ip: "`echoColor red ${localip}`" \n\n->域名ip: "`echoColor red ${remoteip}`"\n"
				echoColor green "多ip或者dns未生效时可能检测失败,如果你确定正确解析到了本机,是否自己指定本机ip? [y/N]:"
				read isLocalip
				if [ "${isLocalip}" == "y" ];then
					echoColor green "请自行输入本机ip:"
					read localip
					while :
					do
						if [ -z "${localip}" ];then
							echoColor red "\n\n->此选项不能为空,请重新输入!"
							echoColor green "请输入本机ip:"
							read  localip
						else
							break
						fi
					done
				fi
				if [ "${localip}" != "${remoteip}" ];then
					echoColor red "\n\n->域名解析到的ip与本机ip不一致,请重新输入!"
					echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
					read  domain
					continue
				else
					break
				fi
			else
				break
			fi
		done
		useAcme=true
        useDns=false
		echoColor purple "\n\n->解析正确,使用hysteria内置ACME申请证书.域名:"`echoColor red ${domain}`"\n"
    fi

	while :
	do
		echoColor green "\n(2/11)请输入你想要开启的端口,此端口是server端口,推荐443.(默认随机10000-65535)"
		echo "并没有证据表明非udp/443的端口会被阻断,它仅仅是可能有更好的伪装一种措施,`echoColor red "如果你使用端口跳跃的话，这里建议使用随机端口"`"
		read  port
		if [ -z "${port}" ];then
			port=$(($(od -An -N2 -i /dev/random) % (65534 - 10001) + 10001))
			echo -e "\n->使用随机端口:"`echoColor red udp/${port}`"\n"
		else
			echo -e "\n->您输入的端口:"`echoColor red udp/${port}`"\n"

		fi
		if [ "${port}" -gt 65535 ];then
			echoColor red "端口范围错误,请重新输入!"
			continue
		fi
		if [ "${ut}" != "udp" ];then
			pIDa=`lsof -i ${ut}:${port} | grep "LISTEN" | grep -v "PID" | awk '{print $2}'`
		else
			pIDa=`lsof -i ${ut}:${port} | grep -v "PID" | awk '{print $2}'`
		fi
		if [ "$pIDa" != "" ];
		then
			echoColor red "\n->端口${port}被占用,PID:${pIDa}!请重新输入或者运行kill -9 ${pIDa}后重新安装!"
		else
			break
		fi
		
	done
	

	echoColor green "\n->(3/11)是否使用端口跳跃(Port Hopping),推荐使用"
	echo -e "Tip: 长时间单端口 UDP 连接容易被运营商封锁/QoS/断流,启动此功能可以有效避免此问题."
	echo -e "更加详细介绍请参考: https://v2.hysteria.network/zh/docs/advanced/Port-Hopping/\n"
	echo -e "\033[32m选择是否启用:\n\n\033[0m\033[33m\033[01m1、启用(默认)\n2、跳过\033[0m\033[32m\n\n输入序号:\033[0m"
	read portHoppingStatus
	if [ -z "${portHoppingStatus}" ] || [ $portHoppingStatus == "1" ];then
		portHoppingStatus="true"
		echoColor purple "\n->您选择启用端口跳跃/多端口(Port Hopping)功能"
		echo -e "端口跳跃/多端口(Port Hopping)功能需要占用多个端口,请保证这些端口没有监听其他服务\nTip: 端口选择数量不宜过多,推荐1000个左右,范围1-65535,建议选择连续的端口范围.\n"
		while :
		do
			echoColor green "请输入起始端口(默认47000):"
			read  portHoppingStart
			if [ -z "${portHoppingStart}" ];then
				portHoppingStart=47000
			fi
			if [ $portHoppingStart -gt 65535 ];then
				echoColor red "\n->端口范围错误,请重新输入!"
				continue
			fi
			echo -e "\n->起始端口:"`echoColor red ${portHoppingStart}`"\n"
			echoColor green "请输入结束端口(默认48000):"
			read  portHoppingEnd
			if [ -z "${portHoppingEnd}" ];then
				portHoppingEnd=48000
			fi
			if [ $portHoppingEnd -gt 65535 ];then
				echoColor red "\n->端口范围错误,请重新输入!"
				continue
			fi
			echo -e "\n->结束端口:"`echoColor red ${portHoppingEnd}`"\n"
			if [ $portHoppingStart -ge $portHoppingEnd ];then
				echoColor red "\n->起始端口必须小于结束端口,请重新输入!"
			else
				break
			fi
		done
		clientPort="${port},${portHoppingStart}-${portHoppingEnd}"
		echo -e "\n->您选择的端口跳跃/多端口(Port Hopping)参数为: "`echoColor red ${portHoppingStart}:${portHoppingEnd}`"\n"
	else
		portHoppingStatus="false"
		echoColor red "\n->您选择不使用端口跳跃功能"
	fi

    echoColor green "(4/11)请输入您到此服务器的平均延迟,关系到转发速度(默认200,单位:ms):"
    read  delay
    if [ -z "${delay}" ];then
		delay=200
    fi
	echo -e "\n->延迟:`echoColor red ${delay}`ms\n"
    echo -e "\n期望速度,这是客户端的峰值速度,服务端默认不受限。"`echoColor red Tips:脚本会自动*1.10做冗余，您期望过低或者过高会影响速度,请如实填写!`
    echoColor green "(5/11)请输入客户端期望的下行速度:(默认50,单位:mbps):"
    read  download
    if [ -z "${download}" ];then
        download=50
    fi
	echo -e "\n->客户端下行速度："`echoColor red ${download}`"mbps\n"
    echo -e "\033[32m(6/11)请输入客户端期望的上行速度(默认10,单位:mbps):\033[0m" 
    read  upload
    if [ -z "${upload}" ];then
        upload=10
    fi
	echo -e "\n->客户端上行速度："`echoColor red ${upload}`"mbps\n"
	echoColor green "(7/11)请输入认证口令(默认随机生成UUID作为密码,建议使用强密码):"
	read auth_secret
	if [ -z "${auth_secret}" ]; then
    	auth_secret=$(generate_uuid)
    fi
    echo -e "\n->认证口令:"`echoColor red ${auth_secret}`"\n"
	echo -e "Tips: 如果使用obfs混淆,抗封锁能力更强,能被识别为未知udp流量。\n但是会增加cpu负载导致峰值速度下降,如果您追求性能且未被针对封锁建议不使用"
	echo -e "\033[32m(8/11)是否使用salamander进行流量混淆:\n\n\033[0m\033[33m\033[01m1、不使用(推荐)\n2、使用\033[0m\033[32m\n\n输入序号:\033[0m"
	read obfs_num
	if [ -z "${obfs_num}" ] || [ ${obfs_num} == "1" ];then
		obfs_status="false"
	else
		obfs_status="true"
		obfs_pass=${auth_secret}
	fi

    if [ "${obfs_status}" == "true" ];then
        echo -e "\n->您将使用salamander混淆加密流量\n"
    else
        echo -e "\n->您将不使用混淆\n"
    fi

    echo -e "\033[32m(9/11)请选择伪装类型:\n\n\033[0m\033[33m\033[01m1、string(默认、返回一个固定的字符串)\n2、proxy(作为一个反向代理，从另一个网站提供内容。)\n3、file(作为一个静态文件服务器，从一个目录提供内容。目录内必须含有index.html)\033[0m\033[32m\n\n输入序号:\033[0m"
	read masquerade_type
    if [ -z "${masquerade_type}" ] || [ ${masquerade_type} == "1" ];then
        masquerade_type="string"
        echo -e "请输入伪装字符串(默认:HelloWorld):"
        read masquerade_string
        if [ -z "${masquerade_string}" ];then
            masquerade_string="HelloWorld"
        fi
        echo -e "\n->伪装字符串:`echoColor red ${masquerade_string}`\n"
        echo -e "请输入http伪装标头content-stuff(默认:HelloWorld):"
        read masquerade_stuff
        if [ -z "${masquerade_stuff}" ];then
            masquerade_stuff="HelloWorld"
        fi
        echo -e "\n->http伪装标头content-stuff:`echoColor red ${masquerade_stuff}`\n"
    elif [ ${masquerade_type} == "2" ];then
        masquerade_type="proxy"
        echoColor green "请输入伪装代理地址(默认:https://www.helloworld.org):"
        echo -e "反代该网址但不会替换网页内域名"
        read masquerade_proxy
        if [ -z "${masquerade_proxy}" ];then
            masquerade_proxy="https://www.helloworld.org"
        fi
        echo -e "\n->伪装代理地址:"`echoColor red ${masquerade_proxy}`"\n"
    else
        masquerade_type="file"
        echoColor green "请输入伪装网站文件目录(默认:/etc/hihy/file,将自动下载mikutap部署):"
        echo -e "默认预览: https://hfiprogramming.github.io/mikutap/"
        read masquerade_file
        if [ -z "${masquerade_file}" ];then
            masquerade_file="/etc/hihy/file"
        fi
        echo -e "\n->伪装网站文件目录:"`echoColor red ${masquerade_file}`"\n"
    fi

    echoColor green "(10/11)是否同时监听tcp/${port}端口来增强伪装行为(做戏做全套):"
    echoColor lightYellow "通常网站支持 HTTP/3 的只是将其作为一个升级选项"
    echo -e "监听一个tcp端口来提供伪装内容,使伪装更加自然,如果不启用此选项,浏览器将在不启用H3功能下访问不了伪装内容"

    echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、启用(默认)\n2、跳过\033[0m\033[32m\n\n输入序号:\033[0m"
    read masquerade_tcp
    if [ -z "${masquerade_tcp}" ] || [ ${masquerade_tcp} == "1" ];then
        masquerade_tcp="true"
        echo -e "\n->您选择同时监听`echoColor red tcp/${port}`端口\n"
    else
        masquerade_tcp="false"
        echo -e "\n->您选择不监听tcp/${port}端口\n"
    fi

    echoColor green "(11/11)请输入客户端名称备注(默认使用域名或IP区分,例如输入test,则名称为Hys-test):"
	read remarks
    echoColor green "\n配置录入完成!\n"
    echoColor yellowBlack "执行配置..."
    download=$(($download + $download / 10))
    upload=$(($upload + $upload / 10))
    CRW=$(($delay * $download * 1000000 / 1000 / 8))
    SRW=$(($CRW / 5 * 2))
    max_CRW=$(($CRW * 3 / 2))
    max_SRW=$(($SRW * 3 / 2))

    server_upload=${download}
    server_download=${upload}
    
	addOrUpdateYaml "$yaml_file" "listen" ":${port}"
    addOrUpdateYaml "$yaml_file" "auth.type" "password"
	addOrUpdateYaml "$yaml_file" "auth.password" "${auth_secret}"
    if [ "${obfs_status}" == "true" ];then
        addOrUpdateYaml "$yaml_file" "obfs.type" "salamander"
        addOrUpdateYaml "$yaml_file" "obfs.salamander.password" "${obfs_pass}"
    fi
	addOrUpdateYaml "$yaml_file" "quic.initStreamReceiveWindow" "${SRW}"
	addOrUpdateYaml "$yaml_file" "quic.maxStreamReceiveWindow" "${max_SRW}"
	addOrUpdateYaml "$yaml_file" "quic.initConnReceiveWindow" "${CRW}"
	addOrUpdateYaml "$yaml_file" "quic.maxConnReceiveWindow" "${max_CRW}"
	addOrUpdateYaml "$yaml_file" "quic.maxIdleTimeout" "30s"
	addOrUpdateYaml "$yaml_file" "quic.maxIncomingStreams" "1024"
	addOrUpdateYaml "$yaml_file" "quic.disablePathMTUDiscovery" "false"
	addOrUpdateYaml "$yaml_file" "bandwidth.up" "${server_upload}mbps"
	addOrUpdateYaml "$yaml_file" "bandwidth.down" "${server_download}mbps"
    addOrUpdateYaml "$yaml_file" "acl.file" "${acl_file}"
    case ${masquerade_type} in 
        "string")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.content" "${masquerade_string}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.content-type" "text/plain"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.custom-stuff" "${masquerade_stuff}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.statusCode" "200"
        ;;
        "proxy")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "proxy"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.url" "${masquerade_proxy}"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.rewriteHost" "true"

        ;;
        "file")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "file"
            addOrUpdateYaml "$yaml_file" "masquerade.file.dir" "${masquerade_file}"
            if [ ! -d "${masquerade_file}" ];then
                mkdir -p ${masquerade_file}
                wget -q -O ./mikutap.tar.gz https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
                tar -xzf ./mikutap.tar.gz -C ${masquerade_file} --strip-components=1
                rm -r ./mikutap.tar.gz
            fi
        ;;
    esac

    if [ "${masquerade_tcp}" == "true" ];then
        addOrUpdateYaml "$yaml_file" "masquerade.listenHTTPS" ":${port}"
    fi
    addOrUpdateYaml "$yaml_file" "speedTest" "true"
    if echo "${useAcme}" | grep -q "false";then
		if echo "${useLocalCert}" | grep -q "false";then
			v6str=":" #Is ipv6?
			result=$(echo ${ip} | grep ${v6str})
			if [ "${result}" != "" ];then
				ip="[${ip}]" 
			fi
			u_host=${ip}
			u_domain=${domain}
			if [ -z "${remarks}" ];then
				remarks="${ip}"
			fi
			insecure="1"
            days=3650  # 替换为实际的有效天数
            mail="no-reply@qq.com"

            # 开始生成证书
            echoColor purple "开始生成自签名证书...\n"

            # 生成 CA 私钥
            echoColor green "生成 CA 私钥..."
            openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048

            # 生成 CA 证书
            echoColor green "生成 CA 证书..."
            openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt

            # 生成服务器私钥和 CSR
            echoColor green "生成服务器私钥和 CSR..."
            openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=${domain}" -out /etc/hihy/cert/${domain}.csr

            # 使用 CA 签署服务器证书
            echoColor green "使用 CA 签署服务器证书..."
            openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt

            # 清理临时文件
            echoColor green "清理临时文件..."
            rm /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr

            # 移动 CA 证书到结果目录
            echoColor green "移动 CA 证书到结果目录..."
            mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result

            # 完成
            echoColor purple "证书生成成功！\n"
			addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt"
			addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
		else
			u_host=${domain}
			u_domain=${domain}
			if [ -z "${remarks}" ];then
				remarks="${domain}"
			fi
			insecure="0"
			addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt"
			addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
		fi		


    else
		u_host=${domain}
		u_domain=${domain}
		insecure="0"
		if [ -z "${remarks}" ];then
			remarks="${domain}"
		fi
        addOrUpdateYaml "$yaml_file" "acme.domains" "${domain}"
        addOrUpdateYaml "$yaml_file" "acme.email" "pekora@${domain}"
        addOrUpdateYaml "$yaml_file" "acme.ca" "letsencrypt"
        addOrUpdateYaml "$yaml_file" "acme.dir" "/etc/hihy/cert"
        if [ "${useDns}" == "true" ];then
            u_host=${ip}
            addOrUpdateYaml "$yaml_file" "acme.type" "dns"
            case ${dns} in 
                "cloudflare")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "cloudflare"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.cloudflare_api_token" "${cloudflare_api_token}"
                ;;
                "duckdns")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "duckdns"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_api_token" "${duckdns_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_override_domain" "${duckdns_override_domain}"
                ;;
                "gandi")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "gandi"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.gandi_api_token" "${gandi_api_token}"
                ;;
                "godaddy")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "godaddy"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.godaddy_api_token" "${godaddy_api_token}"
                ;;
                "namedotcom")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "namedotcom"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_api_token" "${namedotcom_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_user" "${namedotcom_user}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_server" "${namedotcom_server}"
                ;;
                "vultr")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "vultr"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.vultr_api_token" "${vultr_api_token}"
                ;;
            esac
        else
            getPortBindMsg TCP 80
		    allowPort tcp 80
            addOrUpdateYaml "$yaml_file" "acme.type" "http"
            addOrUpdateYaml "$yaml_file" "acme.listenHost" "0.0.0.0"

        fi
		
    fi
    addOrUpdateYaml "$yaml_file" "outbounds[0].name" "hihy" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.mode" "auto" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].name" "v4_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.mode" "4" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[2].name" "v6_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.mode" "6" "number"
    trafficPort=$(($(od -An -N2 -i /dev/random) % (65534 - 10001) + 10001))
    if [ "$trafficPort" == "${port}" ];then
        trafficPort=$(${port} + 1)
    fi
    addOrUpdateYaml "$yaml_file" "trafficStats.listen" "127.0.0.1:${trafficPort}"
    addOrUpdateYaml "$yaml_file" "trafficStats.secret" "${auth_secret}"
    echo -e "reject(all, udp/443)" > ${acl_file}
	sysctl -w net.core.rmem_max=${max_CRW}
    sysctl -w net.core.wmem_max=${max_CRW}
	if echo "${portHoppingStatus}" | grep -q "true";then
		sysctl -w net.ipv4.ip_forward=1
		sysctl -w net.ipv6.conf.all.forwarding=1
	fi
    if [ ! -f "/etc/sysctl.conf" ]; then
        touch /etc/sysctl.conf
    fi
    sysctl -p
	echo -e "\033[1;;35m\nTest config...\n\033[0m"
	/etc/hihy/bin/appS -c ${yaml_file} server > ./hihy_debug.info 2>&1 &

    if [ "${useAcme}" == "true" ];then
        countdown 20
    else
        countdown 5
    fi
	
	
	msg=`cat ./hihy_debug.info`
    case ${msg} in 
        *"failed to get a certificate with ACME"*)
            echoColor red "域名:${u_host},申请证书失败!请重新安装使用自签证书."
            rm /etc/hihy/conf/config.yaml
            rm /etc/hihy/result/backup.yaml
            delHihyFirewallPort
            if echo ${portHoppingStatus} | grep -q "true";then
                delPortHoppingNat
            fi
            rm ./hihy_debug.info
            exit
            ;;
        *"bind: address already in use"*)
            rm /etc/hihy/conf/config.yaml
            rm /etc/hihy/result/backup.yaml
            delHihyFirewallPort
            if echo ${portHoppingStatus} | grep -q "true";then
                delPortHoppingNat
            fi
            echoColor red "端口被占用,请更换端口!"
            rm ./hihy_debug.info
            exit
            ;;
        *"server up and running"*)
            echoColor green "Test success!"
            if echo ${portHoppingStatus} | grep -q "true";then
                addPortHoppingNat ${portHoppingStart} ${portHoppingEnd} ${port}
            fi
            allowPort udp ${port}
            allowPort tcp ${port}
            echoColor purple "Generating config..."
            # 使用 pkill 终止进程
            pkill -f "/etc/hihy/bin/appS"
            rm ./hihy_debug.info
            ;;
        *) 	
            # 确保有 pkill 命令
            if ! command -v pkill >/dev/null 2>&1; then
                apk add --no-cache procps
            fi
            # 使用 pkill 终止进程
            pkill -f "/etc/hihy/bin/appS"
            echoColor red "未知错误: 请查看下方错误信息,并提交issue到github"
            cat ./hihy_debug.info
            rm ./hihy_debug.info
            rm -r /etc/hihy/
            exit
            ;;
    esac
	if [ -f "/etc/hihy/conf/backup.yaml" ]; then
		rm /etc/hihy/conf/backup.yaml
	fi
	backup_file="/etc/hihy/conf/backup.yaml"
	touch ${backup_file}
	addOrUpdateYaml ${backup_file} "remarks" "${remarks}"
	addOrUpdateYaml ${backup_file} "serverAddress" "${u_host}" "string"
	addOrUpdateYaml ${backup_file} "serverPort" "${port}"
	addOrUpdateYaml ${backup_file} "portHoppingStatus" "${portHoppingStatus}"
	addOrUpdateYaml ${backup_file} "portHoppingStart" "${portHoppingStart}"
	addOrUpdateYaml ${backup_file} "portHoppingEnd" "${portHoppingEnd}"
	addOrUpdateYaml ${backup_file} "domain" "${domain}"
    addOrUpdateYaml ${backup_file} "trafficPort" "${trafficPort}"
    if [ "$masquerade_tcp" == "true" ];then
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "true"
    else
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "false"
    fi
	if [ $insecure == "1" ];then
		addOrUpdateYaml ${backup_file} "insecure" "true"
	else
		addOrUpdateYaml ${backup_file} "insecure" "false"
	fi
	echoColor greenWhite "安装成功,请查看下方配置详细信息"
}

downloadHysteriaCore(){
    local version=`curl --silent --head https://github.com/apernet/hysteria/releases/latest | grep -i location | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/ //g'`
    
    echo -e "The Latest hysteria version: $(echoColor red "${version}")\nDownload..."
    
    if [ -z "$version" ]; then
        echoColor red "[Network error]: Failed to get the latest version of hysteria in Github!"
        exit 1
    fi
    
    local arch=$(uname -m)
    local url_base="https://github.com/apernet/hysteria/releases/download/${version}/hysteria-linux-"
    local download_url=""
    
    case "$arch" in
        "x86_64")
            download_url="${url_base}amd64"
            ;;
        "aarch64")
            download_url="${url_base}arm64"
            ;;
        "mips64")
            download_url="${url_base}mipsle"
            ;;
        "s390x")
            download_url="${url_base}s390x"
            ;;
        "i686" | "i386")
            download_url="${url_base}386"
            ;;
        *)
            echoColor yellowBlack "Error[OS Message]:${arch}\nPlease open an issue at https://github.com/emptysuns/Hi_Hysteria/issues !"
            exit 1
            ;;
    esac

    wget -q -O /etc/hihy/bin/appS --no-check-certificate "$download_url"
    
    if [ -f "/etc/hihy/bin/appS" ]; then
        chmod 755 /etc/hihy/bin/appS
        echoColor purple "\nDownload completed."
    else
        echoColor red "Network Error: Can't connect to Github!"
        exit 1
    fi
}

updateHysteriaCore(){
    if [ -f "/etc/hihy/bin/appS" ]; then
        local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
        local remoteV=`curl --silent --head https://github.com/apernet/hysteria/releases/latest | grep -i location | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/ //g'`
        echo -e "Local core version: $(echoColor red "${localV}")"
        echo -e "Remote core version: $(echoColor red "${remoteV}")"
        if [ "${localV}" = "${remoteV}" ]; then
            echoColor green "Already the latest version. Ignore."
        else
            if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
                if [ -f "/etc/rc.d/hihy" ]; then
                    msg=$(/etc/rc.d/hihy status)
                else
                    msg=$(/etc/init.d/hihy status)
                fi
                if [ "${msg}" == "hihy is running" ]; then
                    stop
                    downloadHysteriaCore
                    start
                else
                    echoColor red "hysteria未运行"
                fi
                
            else
                echoColor red "未找到启动脚本!"
            fi
            echoColor green "Hysteria Core update done."
        fi
    else
        echoColor red "Hysteria core not found."
        exit 1
    fi
}

hihy_update_notifycation(){
	localV=${hihyV}
	remoteV=`curl -fsSL https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh | sed  -n 2p | cut -d '"' -f 2`
	if [ -z $remoteV ];then
		echoColor red "Network Error: Can't connect to Github for checking hihy version!"
	else
		if [ "${localV}" != "${remoteV}" ];then
			echoColor purple "[☺] hihy需更新,version:v${remoteV},建议更新并查看日志: https://github.com/emptysuns/Hi_Hysteria/"
		fi
	fi
}

hihyUpdate(){
	localV=${hihyV}
	remoteV=`curl -fsSL https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh | sed  -n 2p | cut -d '"' -f 2`
	if [ -z $remoteV ];then
		echoColor red "Network Error: Can't connect to Github!"
		exit
	fi
	if [ "${localV}" = "${remoteV}" ];then
		echoColor green "Already the latest version.Ignore."
	else
		rm /usr/bin/hihy
		wget -q -O /usr/bin/hihy --no-check-certificate https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh 2>/dev/null
		chmod +x /usr/bin/hihy
		echoColor green "hihy更新完成."
	fi

}

hyCore_update_notifycation(){
	if [ -f "/etc/hihy/bin/appS" ]; then
  		local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
        local remoteV=`curl --silent --head https://github.com/apernet/hysteria/releases/latest | grep -i location | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/ //g'`
		if [ -z $remoteV ];then
			echoColor red "Network Error: Can't connect to Github for checking the hysteria version!"
		else
			if [ "${localV}" != "${remoteV}" ];then
				echoColor purple "[☻] hysteria2更新,version:app/${remoteV}. 日志: https://v2.hysteria.network/docs/Changelog/"
			fi
		fi
		
	fi
}

setup_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Setting up rc.local with systemd..."

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

        echo "rc.local has been set up and started with systemd."
    fi
}


uninstall_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Uninstalling rc.local systemd service..."

        # 停止并禁用 rc-local 服务
        systemctl stop rc-local
        systemctl disable rc-local

        # 删除 /etc/systemd/system/rc-local.service 文件
        rm /etc/systemd/system/rc-local.service

        # 重新加载 systemd 配置
        systemctl daemon-reload

        echo "rc.local systemd service has been uninstalled."
    fi
}


install() {
    if [ -f "/etc/init.d/hihy" ] || [ -f "/etc/rc.d/hihy" ]; then
        echoColor green "你已经成功安装hysteria,如需修改配置请使用选项9/12"
        exit 0
    fi

    # 创建必要目录
    mkdir -p /etc/hihy/{bin,conf,cert,result,logs}
    echoColor purple "Ready to install.\n"

    # 获取版本并下载核心
    version=$(curl --silent --head https://github.com/apernet/hysteria/releases/latest | grep -i location | grep -o 'tag/[^[:space:]]*' | sed 's/tag\///;s/ //g')
    checkSystemForUpdate
    downloadHysteriaCore
    setHysteriaConfig

    
    if [ -f "/etc/alpine-release" ]; then
        # 使用 OpenRC
        cat > /etc/init.d/hihy << 'EOF'
#!/sbin/openrc-run

name="hihy"
description="Hysteria Proxy Service"
supervisor="supervise-daemon"
command="chrt -r 99 /etc/hihy/bin/appS"
command_args="--log-level info -c /etc/hihy/conf/config.yaml server"
command_background="yes"
pidfile="/var/run/hihy.pid"
output_log="/etc/hihy/logs/hihy.log"
error_log="/etc/hihy/logs/hihy.log"

extra_started_commands="log status"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /etc/hihy/logs
}

start() {
    if [ -f "$pidfile" ] && kill -0 $(cat "$pidfile") 2>/dev/null; then
        eerror "hihy is already running"
        return 1
    fi
    
    ebegin "Starting hihy"
    mkdir -p $(dirname "$output_log")
    nohup $command $command_args > "$output_log" 2>&1 &
    echo $! > "$pidfile"
    eend $?
}

stop() {
    if [ ! -f "$pidfile" ]; then
        eerror "hihy is not running"
        return 1
    fi
    
    ebegin "Stopping hihy"
    kill $(cat "$pidfile")
    rm -f "$pidfile"
    eend $?
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if [ -f "$pidfile" ] && kill -0 $(cat "$pidfile") 2>/dev/null; then
        einfo "hihy is running"
    else
        einfo "hihy is not running"
    fi
}

log() {
    tail -f "$output_log"
}
EOF
        chmod +x /etc/init.d/hihy
        rc-update add hihy default
        rc-service hihy start

    else
        # 使用传统启动脚本
        mkdir -p /etc/rc.d
        cat > /etc/rc.d/hihy << 'EOF'
#!/bin/sh

HIHY_PATH="/etc/hihy"
PID_FILE="/var/run/hihy.pid"
LOG_FILE="$HIHY_PATH/logs/hihy.log"

start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "hihy is already running"
        return 1
    fi
    
    echo "Starting hihy..."
    nohup chrt -r 99 $HIHY_PATH/bin/appS --log-level info -c $HIHY_PATH/conf/config.yaml server > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "hihy is not running"
        return 1
    fi
    
    echo "Stopping hihy..."
    kill $(cat "$PID_FILE")
    rm -f "$PID_FILE"
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "hihy is running"
    else
        echo "hihy is not running"
    fi
}

log() {
    tail -f "$LOG_FILE"
}

case "$1" in
    start|stop|restart|status|log)
        $1
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log}"
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
            echo "#!/bin/bash" > /etc/rc.local
            chmod +x /etc/rc.local
        fi
        if ! grep -q "/etc/rc.d/hihy start" /etc/rc.local; then
            echo "/etc/rc.d/hihy start" >> /etc/rc.local
        fi
    fi

    # 配置防火墙
    port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverPort")
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    allowPort udp ${port}
    if [ "${masquerade_tcp}" == "true" ];then
        getPortBindMsg TCP ${port}
        allowPort tcp ${port}
    fi
    
    # 启动服务
    /etc/rc.d/hihy start

    # 添加定时任务
    crontab -l > ./crontab.tmp 2>/dev/null || touch ./crontab.tmp
    echo "15 4 * * 1 hihy cronTask" >> ./crontab.tmp
    crontab ./crontab.tmp
    rm ./crontab.tmp
    setup_rc_local_for_arch

    generate_client_config
    echoColor yellowBlack "安装完毕"
}

# 输出ufw端口开放状态
checkUFWAllowPort() {
    local port=$1
    if ufw status | grep -qw "$port"; then
        echoColor purple "UFW OPEN: ${port}"
    else
        echoColor red "UFW OPEN FAIL: ${port}"
        exit 1
    fi
}

# 输出firewall-cmd端口开放状态
checkFirewalldAllowPort() {
    local port=$1
    local protocol=$2
    if firewall-cmd --list-ports --permanent | grep -qw "${port}/${protocol}"; then
        echoColor purple "FIREWALLD OPEN: ${port}/${protocol}"
    else
        echoColor red "FIREWALLD OPEN FAIL: ${port}/${protocol}"
        exit 1
    fi
}

allowPort() {
    # 如果防火墙启动状态则添加相应的开放端口
    # $1 tcp/udp
    # $2 port
    
    # 检查是否为 Alpine Linux
    if [ -f /etc/alpine-release ]; then
        # Alpine 默认使用 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                echoColor purple "IPTABLES OPEN: ${1}/${2}"
                
                # 保存 iptables 规则
                if [ -d /etc/iptables ]; then
                    iptables-save > /etc/iptables/rules.v4
                else
                    mkdir -p /etc/iptables
                    iptables-save > /etc/iptables/rules.v4
                fi
            fi
            return 0
        fi
        
        # 如果没有 iptables，检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset > /etc/nftables.conf
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
                    echoColor purple "IPTABLES OPEN: ${1}/${2}"
                    netfilter-persistent save
                fi
                return 0
            fi
            
            # 检查 firewalld
            if systemctl is-active --quiet firewalld; then
                if ! firewall-cmd --list-ports --permanent | grep -qw "${2}/${1}"; then
                    firewall-cmd --zone=public --add-port=${2}/${1} --permanent
                    echoColor purple "FIREWALLD OPEN: ${1}/${2}"
                    firewall-cmd --reload
                fi
                return 0
            fi
        fi
        
        # 检查 UFW
        if command -v ufw >/dev/null 2>&1; then
            if ufw status | grep -qw "active"; then
                if ! ufw status | grep -qw "${2}"; then
                    ufw allow ${2}
                    checkUFWAllowPort ${2}
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
                    cat > /etc/rc.d/allow-port << EOF
#!/bin/sh
iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
EOF
                    chmod +x /etc/rc.d/allow-port
                else
                    if ! grep -q "allow ${1}/${2}(hihysteria)" /etc/rc.d/allow-port; then
                        echo "iptables -I INPUT -p ${1} --dport ${2} -m comment --comment \"allow ${1}/${2}(hihysteria)\" -j ACCEPT" >> /etc/rc.d/allow-port
                    fi
                fi

                if [ ! -f "/etc/rc.local" ]; then
                    touch /etc/rc.local
                    echo "#!/bin/bash" > /etc/rc.local
                    chmod +x /etc/rc.local
                fi
                if ! grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
                    echo "/etc/rc.d/allow-port start" >> /etc/rc.local
                fi
            fi

                echoColor purple "IPTABLES OPEN: ${1}/${2}"
                return 0
        fi
        
        # 检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset > /etc/nftables.conf
            fi
            return 0
        fi
    fi
    
    echoColor red "未检测到支持的防火墙工具，请手动开放端口 ${1}/${2}"
    return 1
}

addPortHoppingNat() {
    # $1 portHoppingStart
    # $2 portHoppingEnd
    # $3 portHoppingTarget

    # 检查必需命令
    if ! command -v iptables >/dev/null 2>&1; then
        echoColor red "未找到 iptables,请先安装"
        return 1
    fi
    iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
    ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
    if [ -f "/etc/alpine-release" ]; then
        # Alpine Linux: 使用 OpenRC
        # 确保加载必要模块
        modprobe ip_tables
        modprobe ip6_tables
        modprobe iptable_nat
        modprobe ip6table_nat

        # 创建并初始化 iptables 规则目录
        mkdir -p /etc/iptables

        # 创建基础规则
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -F

        ip6tables -P INPUT ACCEPT
        ip6tables -P FORWARD ACCEPT
        ip6tables -P OUTPUT ACCEPT
        ip6tables -F

        # 保存规则
        /etc/init.d/iptables save
        /etc/init.d/ip6tables save

        # 启动 iptables 服务
        rc-service iptables start
        rc-service ip6tables start

        # 确保服务开机启动
        rc-update add iptables default
        rc-update add ip6tables default

        # 创建 port-hopping 服务
        cat > /etc/init.d/port-hopping << 'EOF'
#!/sbin/openrc-run

description="Port Hopping NAT rules for Hysteria"
depend() {
    need net iptables ip6tables
    after firewall
}

start() {
    ebegin "Adding Port Hopping NAT rules"
EOF
        # 添加实际规则
        echo "    iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment \"NAT $1:$2 to $3 (PortHopping-hihysteria)\" -j DNAT --to-destination :$3" >> /etc/init.d/port-hopping
        echo "    ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment \"NAT $1:$2 to $3 (PortHopping-hihysteria)\" -j DNAT --to-destination :$3" >> /etc/init.d/port-hopping
        cat >> /etc/init.d/port-hopping << 'EOF'
    eend $?
}

stop() {
    ebegin "Removing Port Hopping NAT rules"
    iptables-save | grep -v "PortHopping-hihysteria" | iptables-restore
    ip6tables-save | grep -v "PortHopping-hihysteria" | ip6tables-restore
    eend $?
}
EOF
        chmod +x /etc/init.d/port-hopping
        
        # 添加到默认运行级别并启动
        rc-update add port-hopping default
        rc-service port-hopping start

    else
        # 其他 Linux 系统的处理保持不变
        mkdir -p /etc/rc.d
        cat > /etc/rc.d/port-hopping << EOF
#!/bin/sh
iptables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
ip6tables -t nat -A PREROUTING -p udp --dport $1:$2 -m comment --comment "NAT $1:$2 to $3 (PortHopping-hihysteria)" -j DNAT --to-destination :$3
EOF
        chmod +x /etc/rc.d/port-hopping
     

        if [ ! -f "/etc/rc.local" ]; then
            touch /etc/rc.local
            echo "#!/bin/bash" > /etc/rc.local
            chmod +x /etc/rc.local
        fi
        if ! grep -q "/etc/rc.d/port-hopping start" /etc/rc.local; then
            echo "/etc/rc.d/port-hopping start" >> /etc/rc.local
        fi
    fi

    echoColor purple "Port Hopping NAT 规则已添加并持久化。"
}

delPortHoppingNat() {
    # 删除 OpenRC 服务（如果存在）
    if [ -f "/etc/alpine-release" ] && [ -f "/etc/init.d/port-hopping" ]; then
        rc-service port-hopping stop
        rc-update del port-hopping default
        rm -f /etc/init.d/port-hopping
    fi

    # 删除 port-hopping 规则
    if [ -f "/etc/rc.d/port-hopping" ]; then
        rm -f /etc/rc.d/port-hopping
    fi

    # 删除 rc.local port-hopping 规则（如果存在）
    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/port-hopping/d' /etc/rc.local
    fi

    # 删除所有 hihysteria 相关的 NAT 规则
    local nat_rules_v4=$(iptables-save | grep -E "PortHopping-hihysteria|hihysteria")
    local nat_rules_v6=$(ip6tables-save | grep -E "PortHopping-hihysteria|hihysteria")

    if [ -n "$nat_rules_v4" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            # 添加执行结果检查
            if eval "iptables $clean_rule 2>/dev/null" || ! iptables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                # 规则删除成功或规则已不存在都视为成功
                continue
            # else
            #     echoColor yellow "警告: 删除 IPv4 规则失败: $clean_rule"
            fi
        done <<< "$nat_rules_v4"
    fi

    if [ -n "$nat_rules_v6" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            # 添加执行结果检查
            if eval "ip6tables $clean_rule 2>/dev/null" || ! ip6tables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                # 规则删除成功或规则已不存在都视为成功
                continue
            # else
            #     echoColor yellow "警告: 删除 IPv6 规则失败: $clean_rule"
            fi
        done <<< "$nat_rules_v6"
    fi
    # 保存 iptables 规则
    if [ -d "/etc/iptables" ]; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    fi


    echoColor purple "Port Hopping NAT 规则已清理完成"
}

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echoColor red "Please run this script with root privileges!"
        exit 1
    fi
}

uninstall() {
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ ! -f "/etc/hihy/bin/appS" ]; then
        echoColor red "Hysteria 未安装!"
        exit 1
    fi

    # 停止服务
    if [ -f "/etc/alpine-release" ]; then
        if [ -f "/etc/init.d/hihy" ]; then
            rc-service hihy stop
            rc-update del hihy default
            rm -f /etc/init.d/hihy
        fi
    else
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop
            rm -f /etc/rc.d/hihy
        fi
    fi

    # 删除 iptables 规则
    iptables-save | grep -v "hihysteria" | iptables-restore
    ip6tables-save | grep -v "hihysteria" | ip6tables-restore

    # 保存 iptables 规则
    if [ -d "/etc/iptables" ]; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    fi

    # 删除定时任务
    crontab -l 2>/dev/null | grep -v "hihy cronTask" | crontab -

    delHihyFirewallPort udp
    delHihyFirewallPort tcp
    if echo ${portHoppingStatus} | grep -q "true"; then
        delPortHoppingNat
    fi

    # 删除相关目录和文件
    rm -rf /etc/hihy
    rm -f /var/run/hihy.pid

    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/hihy start/d' /etc/rc.local
        if grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
            sed -i '/\/etc\/rc.d\/allow-port start/d' /etc/rc.local
        fi
    fi

    if [ -f "/usr/bin/hihy" ]; then
        rm /usr/bin/hihy
    fi
    # 删除 Arch Linux 的 rc.local systemd 服务
    uninstall_rc_local_for_arch
    # 检查是否完全删除
    if [ ! -d "/etc/hihy" ]; then
        echoColor green "Hysteria 已完全卸载!"
    else
        echoColor red "卸载过程中发生错误，请检查是否有残留文件或进程。"
        exit 1
    fi
}

generate_qr() {
    local url=$1
    
    # 使用最小合法尺寸 1
    local qr_size=1
    local margin=1
    local level="L"  # 使用最低纠错级别以减小大小
    # 生成并显示 QR 码
    # -l L: 使用最低级别的纠错
    # -m margin: 设置边距
    # -s 1: 使用最小合法尺寸
    qrencode -t ANSIUTF8 -o - -l "$level" -m "$margin" -s 1 "${url}"
    
    if [ $? -eq 0 ]; then
        echoColor green "\nQR code generated successfully."
    else
        echoColor red "\nFailed to generate QR code."
        return 1
    fi
}

generate_client_config(){	
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "hysteria2 未安装!"
        exit 1
    fi
	remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
	serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
	port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
	auth_secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
	tls_sni=$(getYamlValue "/etc/hihy/conf/backup.yaml" "domain")
	insecure=$(getYamlValue "/etc/hihy/conf/backup.yaml" "insecure")
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
	obfs_pass=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.salamander.password")
	if [ "${obfs_pass}" == "" ];then
		obfs_status="true"
	fi
	SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initStreamReceiveWindow")
	CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxStreamReceiveWindow")
	download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
	upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
	port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
	portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
	if [ "${portHoppingStatus}" == "true" ];then
		portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
		portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
	fi
	client_configfile="./Hy2-${remarks}-v2rayN.yaml"
	if [ -f "${client_configfile}" ]; then
		rm -r ${client_configfile}
	fi
	touch ${client_configfile}
	if [ "${portHoppingStatus}" == "true" ];then
		addOrUpdateYaml "$client_configfile" "server" "hysteria2://${auth_secret}@${serverAddress}${port},${portHoppingStart}-${portHoppingEnd}/"
	fi
	
	addOrUpdateYaml "$client_configfile" "tls.sni" "${tls_sni}"
	if [ "${insecure}" == "true" ];then
		addOrUpdateYaml "$client_configfile" "tls.insecure" "true"
	elif [ "${insecure}" == "false" ];then
		addOrUpdateYaml "$client_configfile" "tls.insecure" "false"
	fi
	addOrUpdateYaml  "$client_configfile" "transport.type" "udp"
	addOrUpdateYaml  "$client_configfile" "transport.udp.hopInterval" "120s"
	if [ "${obfs_status}" == "true" ];then
		addOrUpdateYaml "$client_configfile" "obfs.type" "salamander"
		addOrUpdateYaml "$client_configfile" "obfs.salamander.password" "${obfs_pass}"
	fi
	addOrUpdateYaml "$client_configfile" "quic.initStreamReceiveWindow" "${SRW}"
	addOrUpdateYaml "$client_configfile" "quic.initConnReceiveWindow" "${CRW}"
    addOrUpdateYaml "$client_configfile" "quic.maxConnReceiveWindow" "${max_CRW}"
    addOrUpdateYaml "$client_configfile" "quic.maxStreamReceiveWindow" "${max_SRW}"
	addOrUpdateYaml "$client_configfile" "quic.keepAlivePeriod" "60s"
	addOrUpdateYaml	"$client_configfile" "bandwidth.download " "${download}"
	addOrUpdateYaml	"$client_configfile" "bandwidth.upload" "${upload}"
	addOrUpdateYaml "$client_configfile" "fastOpen" "true"
	addOrUpdateYaml "$client_configfile" "socks5.listen" "127.0.0.1:20808"
	url_base="hy2://${auth_secret}@${serverAddress}"
    
	
	if [ "${portHoppingStatus}" == "true" ];then
		url_base="${url_base}${port}/?mport=${portHoppingStart}-${portHoppingEnd}&"
	else
		url_base="${url_base}${port}/?"
	fi
	
	if [ "${insecure}" == "true" ];then
		url_base="${url_base}insecure=1"
	else
		url_base="${url_base}insecure=0"
	fi
	
	if [ "${obfs_status}" == "true" ];then
		url_base="${url_base}&obfs=salamander&obfs-password=${obfs_pass}"
	fi
	url="${url_base}&sni=${tls_sni}#Hy2-${remarks}"
	 # 在生成配置前添加分隔线
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📝 生成客户端配置文件..."
    
    # 美化输出信息
    echo -e "\n✨ 配置信息如下:"
    local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
    echo -e "\n📌 当前hysteria2 server版本: `echoColor red ${localV}`"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "${portHoppingStatus}" == "false" ];then
        echo -e "⚠️  注意: 伪装并未监听tcp端口"
        echo -e "💡 您可能需要`echoColor red 手动在浏览器添加h3`支持才能访问"
    fi
    
    if [ "${insecure}" == "true" ];then
        echo -e "\n⚠️  安全提示:"
        echo -e "🔒 您使用自签证书,如需要验证伪装网站:"
        echo -e "   1. 自行修改浏览器信任证书"
        echo -e "   2. 设置hosts使IP指向该域名"

    fi
    echoColor purple "\n🌐 1、伪装地址: `echoColor red https://${tls_sni}${port}`"

    echoColor purple "\n🔗 2、[v2rayN-Windows/v2rayN-Andriod/nekobox/passwall/Shadowrocket]分享链接:\n"
    echoColor green "${url}"
    echo -e "\n"
    generate_qr "${url}"

    echoColor purple "\n📄 3、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: `echoColor green ${client_configfile}`"
    echoColor green "↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓"
    cat ${client_configfile}
    echoColor green "↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑"
    generateMetaYaml
    
    echo -e "\n✅ 配置生成完成!"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

generateMetaYaml(){
    remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
    local metaFile="./Hy2-${remarks}-ClashMeta.yaml"
    if [ -f "${metaFile}" ]; then
        rm -f ${metaFile}
    fi
    touch ${metaFile}

	cat <<EOF > ${metaFile}
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: true
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
  enhanced-mode: redir-host
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://223.5.5.5/dns-query
  fallback:
    - 114.114.114.114
    - 223.5.5.5
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400

  gfw:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400

  greatfire:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt"
    path: ./ruleset/greatfire.yaml
    interval: 86400

  tld-not-cn:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt"
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400

  telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

  cncidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400

  lancidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

  applications:
    type: http
    behavior: classical
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"
    path: ./ruleset/applications.yaml
    interval: 86400

rules:
  - RULE-SET,applications,DIRECT
  - DOMAIN,clash.razord.top,DIRECT
  - DOMAIN,yacd.haishan.me,DIRECT
  - DOMAIN,services.googleapis.cn,PROXY
  - RULE-SET,private,DIRECT
  - RULE-SET,reject,REJECT
  - RULE-SET,icloud,DIRECT
  - RULE-SET,apple,DIRECT
  - RULE-SET,google,DIRECT
  - RULE-SET,proxy,PROXY
  - RULE-SET,direct,DIRECT
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,cncidr,DIRECT
  - RULE-SET,telegramcidr,PROXY
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
	serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
	port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
	auth_secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
	tls_sni=$(getYamlValue "/etc/hihy/conf/backup.yaml" "domain")
	insecure=$(getYamlValue "/etc/hihy/conf/backup.yaml" "insecure")
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
	obfs_pass=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.salamander.password")
	if [ "${obfs_pass}" == "" ];then
		obfs_status="true"
	fi
	SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initStreamReceiveWindow")
	CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxStreamReceiveWindow")
	download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
    download=$(echo ${download} | sed 's/[^0-9]//g')
	upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
    upload=$(echo ${upload} | sed 's/[^0-9]//g')
	port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
	portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    addOrUpdateYaml "${metaFile}" "proxies[0].name" "${remarks}"
    addOrUpdateYaml "${metaFile}" "proxies[0].type" "hysteria2"
    addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}"
    addOrUpdateYaml "${metaFile}" "proxies[0].port" "${port}"
    if [ "${portHoppingStatus}" == "true" ];then
        addOrUpdateYaml "${metaFile}" "proxies[0].ports" "${portHoppingStart}-${portHoppingEnd}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].password" "${auth_secret}"
    addOrUpdateYaml "${metaFile}" "proxies[0].up" "${upload} Mbps"
    addOrUpdateYaml "${metaFile}" "proxies[0].down" "${download} Mbps"
    addOrUpdateYaml "${metaFile}" "proxies[0].skip-cert-verify" "${insecure}" 
    if [ "${obfs_status}" == "true" ];then
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs" "salamander"
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs-password" "${obfs_pass}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].sni" "${tls_sni}"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].type" "select"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].proxies" "[${remarks}]"
    echoColor purple "\n📱 4、[Clash.Mini/ClashX.Meta/Clash.Meta for Android/Clash.verge/openclash] ClashMeta配置。文件地址: `echoColor green ${metaFile}`"

}


checkLogs () {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        tail -f /etc/hihy/logs/hihy.log
    else
        echoColor red "日志文件不存在!"
    fi
}
start () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy start
        else
            /etc/init.d/hihy start
        fi
        if [ $? -eq 0 ]; then
            echoColor green "启动成功!"
        else
            echoColor red "启动失败!"
        fi
    else
        echoColor red "未找到启动脚本!"
    fi
}
stop () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop
        else
            /etc/init.d/hihy stop
        fi
        if [ $? -eq 0 ]; then
            echoColor green "停止成功!"
        else
            echoColor red "停止失败!"
        fi
    else
        echoColor red "未找到启动脚本!"
    fi
}
restart () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy restart
        else
            /etc/init.d/hihy restart
        fi
        if [ $? -eq 0 ]; then
            echoColor green "重启成功!"
        else
            echoColor red "重启失败!"
        fi
    else
        echoColor red "未找到启动脚本!"
    fi
}
checkStatus () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            msg=$(/etc/rc.d/hihy status)
        else
            msg=$(/etc/init.d/hihy status)
        fi
        if [ "${msg}" == "hihy is running" ]; then
            echoColor green "hysteria正在运行"
            version=$(/etc/hihy/bin/appS version | grep "^Version" | awk '{print $2}')
            echoColor purple "当前版本: `echoColor red ${version}`"
        else
            echoColor red "hysteria未运行"
        fi
        
    else
        echoColor red "未找到启动脚本!"
    fi
}

# 定义格式化字节大小的函数
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt $((1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    elif [ $bytes -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/(1024*1024)" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes/(1024*1024*1024)" | bc)GB"
    fi
}

getHysteriaTrafic() {
    local api_port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "trafficPort")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
    
    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi
    
    echo "=========== Hysteria 服务器状态 ==========="
    
    # 流量统计部分保持不变
    echoColor green "【流量统计】"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic" | \
    grep -oE '"[^"]+":{"tx":[0-9]+,"rx":[0-9]+}' | \
    while IFS=: read -r user stats; do
        tx=$(echo $stats | grep -oE '"tx":[0-9]+' | cut -d: -f2)
        rx=$(echo $stats | grep -oE '"rx":[0-9]+' | cut -d: -f2)
        user=$(echo $user | tr -d '"')
        tx_formatted=$(format_bytes $tx)
        rx_formatted=$(format_bytes $rx)
        printf "用户: %-20s 上传: %8s  下载: %8s\n" "$user" "$tx_formatted" "$rx_formatted"
    done
    
    # 在线用户部分保持不变
    echoColor green "\n【在线用户】"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online" | \
    grep -oE '"[^"]+":[0-9]+' | \
    while IFS=: read -r user count; do
        user=$(echo $user | tr -d '"')
        count=$(echo $count | tr -d ' ')
        printf "用户: %-20s 设备数: %d\n" "$user" "$count"
    done
    
    echoColor green "\n【活动连接】"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")
    
    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "当前没有活动连接"
    else
        # 打印表头
        printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
            "状态" "用户" "连接ID" "流数" "上传" "下载" "存活时间" "最后活动" "请求地址" "目标地址"
        echo "----------|-----------------|------------|------|------------|------------|--------------|--------------|----------------------|----------------------"
        
        # 使用临时文件存储排序数据
        temp_file=$(mktemp)
        
        echo "$STREAMS_OUTPUT" | awk 'BEGIN {
            status["ESTAB"]="已建立"
            status["CLOSED"]="已关闭"
        }
        
        function format_bytes(bytes) {
            if (bytes < 1024) return bytes "B"
            if (bytes < 1024*1024) return sprintf("%.2fKB", bytes/1024)
            if (bytes < 1024*1024*1024) return sprintf("%.2fMB", bytes/(1024*1024))
            return sprintf("%.2fGB", bytes/(1024*1024*1024))
        }
        
        function format_time(time) {
            if (time == "-") return 0
            if (index(time, "ms") > 0) {
                gsub("ms", "", time)
                return time/1000
            }
            if (index(time, "s") > 0) {
                gsub("s", "", time)
                return time
            }
            if (index(time, "m") > 0) {
                gsub("m", "", time)
                return time * 60
            }
            if (index(time, "h") > 0) {
                gsub("h", "", time)
                return time * 3600
            }
            return time
        }
        
        function format_time_display(seconds) {
            if (seconds < 1) return sprintf("%.0fms", seconds * 1000)
            if (seconds < 60) return sprintf("%.1f秒", seconds)
            if (seconds < 3600) return sprintf("%.1f分钟", seconds/60)
            return sprintf("%.1f小时", seconds/3600)
        }
        
        NR > 1 {
            last_active = format_time($8)
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9, $10
        }' | sort -t'|' -k8,8nr > "$temp_file"
        
        # 读取排序后的数据并格式化输出
        while IFS='|' read -r state user conn_id flows up down alive last_active req_addr target_addr; do
            printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
                "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display $last_active)" "$req_addr" "$target_addr"
        done < "$temp_file"
        
        rm -f "$temp_file"
    fi

    echo "========================================"
}

# 辅助函数：格式化时间显示
format_time_display() {
    local seconds=$1
    
    # 处理毫秒级别
    if (( $(echo "$seconds < 1" | bc -l) )); then
        printf "%.0f毫秒" $(echo "$seconds * 1000" | bc -l)
        return
    fi
    
    # 处理秒级别
    if (( $(echo "$seconds < 60" | bc -l) )); then
        printf "%.1f秒" "$seconds"
        return
    fi
    
    # 处理分钟级别
    if (( $(echo "$seconds < 3600" | bc -l) )); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f分钟" "$minutes"
        return
    fi
    
    # 处理小时级别
    local hours=$(echo "$seconds / 3600" | bc -l)
    # 如果小时数小于0.1，显示为分钟
    if (( $(echo "$hours < 0.1" | bc -l) )); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f分钟" "$minutes"
    else
        printf "%.1f小时" "$hours"
    fi
}

delHihyFirewallPort() {
    # 如果防火墙启动状态则删除之前的规则
    local port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen" | awk '{gsub(/^:/, ""); print}')
    local protocol=$1

    # 检查并处理不同的防火墙管理工具
    if command -v ufw > /dev/null && ufw status | grep -qw "active"; then
        if ufw status | grep -qw "${port}"; then
            ufw delete allow "${port}" 2> /dev/null
            echoColor purple "UFW DELETE: ${port}"
        fi
    elif command -v firewall-cmd > /dev/null && systemctl is-active --quiet firewalld; then
        if firewall-cmd --list-ports --permanent | grep -qw "${port}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${port}/${protocol}" --permanent 2> /dev/null
            firewall-cmd --reload 2> /dev/null
            echoColor purple "FIREWALLD DELETE: ${port}/${protocol}"
        fi
    elif command -v iptables > /dev/null; then
        iptables-save | sed -e "/hihysteria/d" | iptables-restore
        ip6tables-save | sed -e "/hihysteria/d" | ip6tables-
        if command -v systemctl >/dev/null 2>&1; then
            # 检查 netfilter-persistent
            if systemctl is-active --quiet netfilter-persistent; then
                netfilter-persistent save
            fi
        fi
        if [ -f "/etc/rc.d/allow-port" ]; then
            sed -i "/${protocol}\/${port}(hihysteria)/d" /etc/rc.d/allow-port
        fi

        echoColor purple "IPTABLES DELETE: ${port}/${protocol}"
    fi
}

changeIp64(){
    mode_now=$(getYamlValue "config.yaml" "outbounds[0].direct.mode")
    echoColor purple "当前模式: `echoColor red ${mode_now}`"
    echoColor yellow "1) ipv4优先"
    echoColor yellow "2) ipv6优先"
    echoColor yellow "3) 自动选择"
    echoColor yellow "0) 退出"
    read -p "请选择: " input
    case $input in
        1)
            if [ "${mode_now}" == "46" ];then
                echoColor yellow "当前已经是ipv4优先模式"
            else
                addOrUpdateYaml "/etc/hihy/conf/config.yaml" "outbounds[0].direct.mode" "46"
                restart
                echoColor green "切换成功"
            fi
        
        ;;
        2) 
            if [ "${mode_now}" == "64" ];then
                echoColor yellow "当前已经是ipv6优先模式"
            else
                addOrUpdateYaml "/etc/hihy/conf/config.yaml" "outbounds[0].direct.mode" "64"
                restart
                echoColor green "切换成功"
            fi
        
        ;;

        3) 
            if [ "${mode_now}" == "auto" ];then
                echoColor yellow "当前已经是自动选择模式"
            else
                addOrUpdateYaml "/etc/hihy/conf/config.yaml" "outbounds[0].direct.mode" "auto"
                restart
                echoColor  "切换成功"
            fi
        ;;
        0) exit 0 ;;
        *) echoColor red "输入错误!"; exit 1 ;;
    esac
}

changeServerConfig(){
	if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
		echoColor red "请先安装hysteria2,再去修改配置..."
		exit
	fi
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ];then
        portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
        portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
    fi
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
	stop
    if [ "${portHoppingStatus}" == "true" ];then
        delPortHoppingNat
    fi
    if [ "${masquerade_tcp}" == "true" ];then
        delHihyFirewallPort tcp
        delHihyFirewallPort udp
    else
        delHihyFirewallPort udp
    fi
	updateHysteriaCore
	setHysteriaConfig
    start
	generate_client_config
    echoColor green "配置修改成功"
	
}

aclControl(){
    local acl_file="/etc/hihy/acl/acl.txt"
    if [ ! -f "${acl_file}" ]; then
        echoColor red "未找到acl文件"
        exit 1
    fi
    echoColor purple "请选择管理操作:"
    echoColor yellow "1) 添加"
    echoColor yellow "2) 删除"
    echoColor yellow "3) 查看"
    echoColor yellow "0) 退出"
    read -p "请选择: " input
    case $input in
        1)
            echoColor green "请选择ACL控制方式"
            echoColor yellow "1) 添加域名ipv4分流"
            echoColor yellow "2) 添加域名ipv6分流"
            echoColor yellow "3) 添加屏蔽域名"
            read -p "请选择: " input
            case $input in
                1)
                    read -p "请输入要分流ipv4的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v4_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v4_only(suffix:${domain})" >> "${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                ;;
                2)
                    read -p "请输入要分流ipv6的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v6_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v6_only(suffix:${domain})" >> "${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                ;;
                3)
                    read -p "请输入要屏蔽的域名: " rejectInput
                    if [ -z "${rejectInput}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "reject(suffix:${rejectInput})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "reject(suffix:${rejectInput})" >> "${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                ;;
                *) echoColor red "输入错误!"; exit 1 ;;
            esac
        ;;
        2)
            read -p "请输入要删除的域名规则: " domain
            if [ -z "${domain}" ]; then
                echoColor red "域名不能为空"
                exit 1
            fi
            if grep -q "${domain}" "${acl_file}"; then
                sed -i "/${domain}/d" "${acl_file}"
                echoColor green "删除成功"
                restart
            else
                echoColor red "规则不存在"
            fi
          
        ;;
        3)
            echoColor purple "当前ACL列表:"
            cat "${acl_file}"
        ;;
        0) exit 0 ;;
        *) echoColor red "输入错误!"; exit 1 ;;
    esac

   
}

 menu() {
    clear
    echo -e " -------------------------------------------"
    echo -e "|**********      Hi Hysteria       **********|"
    echo -e "|**********    Author: emptysuns   **********|"
    echo -e "|**********     Version: $(echoColor red "${hihyV}")    **********|"
    echo -e " -------------------------------------------"
    echo -e "Tips: $(echoColor green "hihy") 命令再次运行本脚本."
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "1)  安装 hysteria2")"
    echo -e "$(echoColor magenta "2)  卸载")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "3)  启动")"
    echo -e "$(echoColor magenta "4)  暂停")"
    echo -e "$(echoColor yellow "5)  重新启动")"
    echo -e "$(echoColor yellow "6)  运行状态")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "7)  更新Core")"
    echo -e "$(echoColor yellow "8)  查看当前配置")"
    echo -e "$(echoColor skyBlue "9)  重新配置")"
    echo -e "$(echoColor yellow "10) 切换ipv4/ipv6优先级")"
    echo -e "$(echoColor yellow "11) 更新hihy")"
    echo -e "$(echoColor lightMagenta "12) 域名分流/ACL管理")"
    echo -e "$(echoColor skyBlue "13) 查看hysteria2统计信息")"
    echo -e "$(echoColor yellow "14) 查看实时日志")"

    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor magenta "0) 退出")"
    echo -e "$(echoColor skyBlue ".............................................")"

    read -p "请选择: " input
    case $input in
        1) install ;;
        2) uninstall ;;
        3) start ;;
        4) stop ;;
        5) restart ;;
        6) checkStatus ;;
        7) updateHysteriaCore ;;
        8) generate_client_config ;;
        9) changeServerConfig ;;
        10) changeIp64 ;;
        11) hihyUpdate ;;
        12) aclControl ;;
        13) getHysteriaTrafic ;;
        14) checkLogs ;;
        0) exit 0 ;;
        *) echoColor red "Input Error !!!"; exit 1 ;;
    esac
}

checkRoot
hihy_update_notifycation
hyCore_update_notifycation
case "$1" in
    install|1) echoColor purple "-> 1) 安装 hysteria"; install ;;
    uninstall|2) echoColor purple "-> 2) 卸载 hysteria"; uninstall ;;
    start|3) echoColor purple "-> 3) 启动 hysteria"; start ;;
    stop|4) echoColor purple "-> 4) 暂停 hysteria"; stop ;;
    restart|5) echoColor purple "-> 5) 重新启动 hysteria"; restart ;;
    checkStatus|6) echoColor purple "-> 6) 运行状态"; checkStatus ;;
    updateHysteriaCore|7) echoColor purple "-> 7) 更新Core"; updateHysteriaCore ;;
    generate_client_config|8) echoColor purple "-> 8) 查看当前配置"; generate_client_config ;;
    changeServerConfig|9) echoColor purple "-> 9) 重新配置"; changeServerConfig ;;
    changeIp64|10) echoColor purple "-> 10) 切换ipv4/ipv6优先级"; changeIp64 ;;
    hihyUpdate|11) echoColor purple "-> 11) 更新hihy"; hihyUpdate ;;
    aclControl|12) echoColor purple "-> 12) ACL管理"; aclControl ;;
    getHysteriaTrafic|13) echoColor purple "-> 13) 查看hysteria统计信息"; getHysteriaTrafic ;;
    checkLogs|14) echoColor purple "-> 14) 查看实时日志"; checkLogs ;;
    cronTask) cronTask ;;
    *) menu ;;
esac
