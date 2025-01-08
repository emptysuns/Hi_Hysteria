#!/bin/bash
echo -e "\033[32m请选择安装的hysteria版本:\n\n\033[0m\033[33m\033[01m1、hysteria2(推荐,LTS性能更好)\n2、hysteria1(NLTS,未来无功能更新,但支持faketcp.被UDP QoS可以选择)\033[0m\033[32m\n\n输入序号:\033[0m"
read -p "" hysteria_version
if [ "$hysteria_version" = "1" ] || [ -z "$hysteria_version" ]; then
    hysteria_version="hysteria2"
elif [ "$hysteria_version" = "2" ]; then
    hysteria_version="hysteria1"
else
    echo -e "\033[31m输入错误,请重新运行脚本\033[0m"
    exit 1
fi
echo -e "-> 您选择的hysteria版本为: \033[32m$hysteria_version\033[0m"
echo -e "Downloading hihy..."

if [ "$hysteria_version" = "hysteria2" ]; then
    wget -q --no-check-certificate -O /usr/bin/hihy https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh && chmod +x /usr/bin/hihy
else
    wget -q --no-check-certificate -O /usr/bin/hihy https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/install.sh && chmod +x /usr/bin/hihy
fi
/usr/bin/hihy
