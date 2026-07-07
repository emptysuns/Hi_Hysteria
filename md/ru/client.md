## Поддерживаемые клиенты

### Нативные клиенты Hysteria2
- **v2rayN** (Windows) — полная поддержка, лучшая совместимость
- **Nekoray** (Windows/Linux) — полная поддержка
- **NekoBox for Android** — полная поддержка
- **Shadowrocket** (iOS) — поддерживает ссылки hy2://
- **PassWall** (OpenWrt) — полная поддержка

### Клиенты mihomo (Clash.Meta)
- **Clash Verge Rev** (Windows/Mac/Linux)
- **FlClash** (Android)
- **ClashMeta for Android**
- **OpenClash** (OpenWrt)

Поддерживает все функции Hysteria2, кроме обфускации gecko. Файл конфигурации: `Hy2-<name>-mihomo.yaml`

### Клиенты sing-box
- **sing-box** (Универсальный — Windows/Mac/Linux/Android/iOS)
- **SFA / SFI / SFM / SFT** (GUI-клиенты sing-box для Android)

Требуется sing-box 1.11+. Режим Realm, обфускация gecko и bbr_profile требуют 1.14+. Файл конфигурации: `Hy2-<name>-singbox.json`

### Способы импорта
Все сгенерированные файлы конфигурации поддерживают прямой импорт:
- Скопируйте содержимое YAML/JSON
- Импортируйте через функцию клиента "импорт из файла/буфера обмена"
- Нажмите на ссылку (hy2:// или hysteria2+realm://), если клиент поддерживает схемы URI

