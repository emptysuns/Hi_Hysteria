#!/bin/bash
echo -e "\033[1;42;40mStart Uninstall!\033[0m\n\n"
wget -O /tmp/uninstall.sh --no-check-certificate https://git.io/rmhysteria.sh && chmod +x /tmp/uninstall.sh && bash /tmp/uninstall.sh
echo -e "\033[1;42;40mStart reinstall!\033[0m\n"
wget -O /tmp/install.sh --no-check-certificate https://git.io/hysteria.sh && chmod +x /tmp/install.sh && bash /tmp/install.sh
rm -rf /tmp/uninstall.sh /tmp/install.sh
echo -e "\033[1;42;40mReinstall Complete!\033[0m\n"
