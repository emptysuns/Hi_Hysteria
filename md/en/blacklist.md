#### UDP-Throttling ISP Blacklist [Updated 2025/01/07]

The following ISPs are known to throttle or block UDP traffic, which severely impacts Hysteria2 (QUIC-based) performance:

- **China Mobile (中国移动)** — severe UDP QoS, especially on 5G networks
- **Some campus/enterprise networks** — often block UDP entirely
- **Certain IDCs** — restrict UDP to prevent DDoS

If you're on one of these networks, consider:
1. Using Hysteria2's port hopping feature to evade QoS
2. Using TCP masquerade mode
3. Switching to a different ISP or using a relay/VPS as intermediary

