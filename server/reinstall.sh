#!/bin/bash
echo -e "\033[1;33;40mStart Uninstall!\033[0m\n\n"
wget -O /tmp/uninstall.sh --no-check-certificate https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/uninstall.sh && chmod +x /tmp/uninstall.sh && bash /tmp/uninstall.sh
echo -e "\033[1;33;40mStart reinstall!\033[0m\n"
wget -O /tmp/install.sh --no-check-certificate https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/install.sh && chmod +x /tmp/install.sh && bash /tmp/install.sh
rm -rf /tmp/uninstall.sh /tmp/install.sh
echo -e "\033[1;33;40mReinstall Complete!\033[0m\n"
