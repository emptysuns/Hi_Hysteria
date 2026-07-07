#### How to Set Latency / Upload / Download Speed

**Latency:** Measure the ping latency from your client to the server. If uncertain, the default 200ms works well in most cases.

**Download speed (server→client):** Set to your actual bandwidth or slightly below. The script automatically adds a 1.10× buffer. If using Brutal congestion control, do NOT set this higher than your actual link capacity — it will cause instability.

**Upload speed (client→server):** Usually much lower than download. The default 10 Mbps works for most use cases.

**Congestion control modes:**
- **Reno:** Conservative, stable — best for compatibility and reliability
- **BBR:** More aggressive, typically higher throughput — best for speed
- **Brutal** (default): Hysteria2's custom fixed-rate algorithm — best for harsh networks. Use when you know your real bandwidth and want maximum anti-jitter capability.

**For BBR/Reno modes**, `up`/`down` fields are omitted from mihomo and sing-box configs, allowing the client to use BBR natively. Only Brutal mode outputs explicit bandwidth values.

