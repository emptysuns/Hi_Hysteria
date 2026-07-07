#### Firewall Issues

**If you cannot connect after installation, the first thing to check is whether the firewall has opened the correct ports.**

The script automatically configures the firewall during installation. However, some VPS providers have external firewall panels (e.g. Alibaba Cloud, Tencent Cloud security groups) that also need to be configured.

Run this command to check if the port is open:
```
hihy 6
```

If the status shows "running" but you still can't connect, please check:
1. Whether the VPS provider's external firewall panel has opened the corresponding port
2. Whether `ufw` or `firewalld` has allow rules for the port

