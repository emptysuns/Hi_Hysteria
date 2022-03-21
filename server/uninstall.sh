#!/bin/bash
systemctl stop hihys
systemctl disable hihys
rm -r /etc/systemd/system/hihys.service
systemctl daemon-reload
rm -r /etc/hihys/
rm /usr/bin/hihys
crontab -l > ./crontab.tmp
sed -i '/0 4 \* \* \* systemctl restart hysteria/d' ./crontab.tmp
crontab ./crontab.tmp
rm ./crontab.tmp
iptables-save |  sed -e '/hihysteria/d' | iptables-restore
netfilter-persistent save
echo -e "\033[1;33;40mUninstall complete!\033[0m\n"