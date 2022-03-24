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
iptables-save |  sed -e '/hihysteria/d' | iptables-restore
netfilter-persistent save
echo -e "\033[1;33;40mUninstall completed!\033[0m\n"