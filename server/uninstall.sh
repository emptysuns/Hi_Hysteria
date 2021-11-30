#!/bin/bash
systemctl stop hysteria
systemctl disable hysteria
rm -rf /etc/systemd/system/hysteria.service
systemctl daemon-reload
rm -rf /etc/hysteria/
crontab -l > ./crontab.tmp
sed -i '/0 4 \* \* \* systemctl restart hysteria/d' ./crontab.tmp
crontab ./crontab.tmp
rm -rf ./crontab.tmp
echo -e "\033[1;42;40mUninstall complete!\033[0m\n"
