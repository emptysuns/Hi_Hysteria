#!/bin/sh
wget -O /tmp/uninstall.sh https://git.io/rmhysteria.sh && chmod +x /tmp/uninstall.sh && sh /tmp/uninstall.sh
echo "\033[41;37mUninstall Complete!\033[0m\n\n"
echo "\033[41;37mStart reinstall!\033[0m\n"
wget -O /tmp/install.sh https://git.io/hysteria.sh && chmod +x /tmp/install.sh && sh /tmp/install.sh
rm -rf /tmp/uninstall.sh /tmp/install.sh
echo "\033[41;37mReinstall Complete!\033[0m\n"
