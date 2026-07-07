## FAQ / Troubleshooting

### Installation Issues
**Q: Download failed during installation?**
A: Check your network connection. The script uses both GitHub and jsdelivr CDN mirrors. Try switching networks or using a proxy.

**Q: Certificate generation fails?**
A: For ACME HTTP challenge, ensure TCP port 80 is accessible. For self-signed, this shouldn't fail.

### Connection Issues
**Q: Can't connect after successful installation?**
A: Check:
1. Firewall rules (run `hihy 6` to check status)
2. VPS provider's external firewall panel
3. ISP UDP throttling (see blacklist)

**Q: Slow speed / high latency?**
A: Try:
1. Switch congestion control mode (menu option 9 → option 4)
2. Adjust BDP parameters
3. Enable port hopping
4. Check ISP QoS on UDP

### Update Issues
**Q: Update fails or script breaks after update?**
A: Run `hihy 11` to re-download the latest script. If still broken, re-run the bootstrap installer.

**Q: Core update says "Text file busy"?**
A: Stop the service first (`hihy 4`), then update (`hihy 7`), then restart (`hihy 5`).

### Configuration
**Q: How to change settings after installation?**
A: Use `hihy 9` to reconfigure. This preserves your existing setup while allowing you to change specific options.

**Q: How to export mihomo or sing-box config?**
A: Use `hihy 8` to regenerate all client config files (native YAML + mihomo YAML + sing-box JSON).

### Realm Mode
**Q: Realm mode client can't connect?**
A: Check:
1. Both sides have UDP connectivity
2. STUN server reachability
3. NAT type (full-cone works best)
4. UPnP/NAT-PMP is enabled (on by default)

### Performance
**Q: YouTube is slow with Hysteria2?**
A: Enable HTTP/3 blocking (menu option 9 → option 12). This forces YouTube to use Hysteria2's accelerated path instead of QUIC.

**Q: High CPU usage?**
A: Try:
1. Disable obfuscation if not needed
2. Use Reno or BBR instead of Brutal
3. Reduce bandwidth targets

