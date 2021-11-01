#!/bin/sh
echo "\033[42;37mStart Uninstall!\033[0m\n\n"
wget -O /tmp/uninstall.sh --no-check-certificate https://git.io/rmhysteria.sh && chmod +x /tmp/uninstall.sh && sh /tmp/uninstall.sh
echo "\033[42;37mUninstall Complete!\033[0m\n\n"
echo "\033[42;37mStart reinstall!\033[0m\n"
wget -O /tmp/install.sh --no-check-certificate https://git.io/install_no.sh && chmod +x /tmp/install.sh && sh /tmp/install.sh
rm -rf /tmp/uninstall.sh /tmp/install.sh
echo "\033[42;37mReinstall Complete!\033[0m\n"