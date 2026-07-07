## Supported Clients

### Hysteria2 Native Clients
- **v2rayN** (Windows) — full support, best compatibility
- **Nekoray** (Windows/Linux) — full support
- **NekoBox for Android** — full support
- **Shadowrocket** (iOS) — supports hy2:// share links
- **PassWall** (OpenWrt) — full support

### mihomo (Clash.Meta) Clients
- **Clash Verge Rev** (Windows/Mac/Linux)
- **FlClash** (Android)
- **ClashMeta for Android**
- **OpenClash** (OpenWrt)

Supports all Hysteria2 features except gecko obfuscation. Configuration file: `Hy2-<name>-mihomo.yaml`

### sing-box Clients
- **sing-box** (Universal — Windows/Mac/Linux/Android/iOS)
- **SFA / SFI / SFM / SFT** (sing-box Android GUI clients)

Requires sing-box 1.11+. Realm mode, gecko obfuscation, and bbr_profile require 1.14+. Configuration file: `Hy2-<name>-singbox.json`

### Import Methods
All generated config files support direct import:
- Copy the YAML/JSON content
- Import via client's "import from file/clipboard" function
- Click the share link (hy2:// or hysteria2+realm://) if the client supports URI schemes

