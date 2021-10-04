#!/bin/sh
rm -rf /etc/systemd/system/hysteria.serive
rm -rf /etc/hysteria/
rm -rf /root/install.sh
rm -rf /root/config.json
systemctl daemon-reload
echo "Uninstall complete!"