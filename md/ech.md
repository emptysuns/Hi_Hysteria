# ECH（加密 ClientHello）

`ver1.15` 新增，需要 Hysteria2 内核 **v2.10.0 及以上**。

## 这是什么

不使用 ECH 时，TLS 握手里的 SNI（你的真实域名）是**明文**传输的，中间设备可以据此探测、针对性屏蔽。

开启 ECH 后，真实 SNI 被加密封装，链路上只能看到一个用作幌子的**公开域名**（public name，例如 `www.microsoft.com`）。

## 要不要开

| 场景 | 建议 |
|---|---|
| 未开启混淆（obfs），走标准 QUIC 握手 | **建议开启**。此时 SNI 是最主要的明文特征 |
| 已开启混淆（salamander / gecko） | 收益不大。整条连接本就无法被识别为 QUIC，不存在暴露的 SNI |
| Realm 模式 | 暂不适用（脚本在 Realm 模式下不询问 ECH） |

## 怎么开

**交互安装**：向导会在混淆之后询问「是否启用 ECH」，选 `2` 启用，然后输入公开域名（回车用默认 `www.microsoft.com`）。

**一键安装**：

```bash
HIHY_AUTO_ECH=true HIHY_AUTO_ECH_PUBLIC_NAME=www.microsoft.com hihy autoinstall
```

**已装机器**：`hihy 9` 重新配置即可。

公开域名**不必是你自己的域名**，选一个看起来无害、合理的即可——它只是握手时对外显示的幌子。

## 密钥怎么来的

Hysteria 官方文档推荐用 `sing-box generate ech-keypair` 生成密钥对。本脚本**不下载 sing-box**——多装一个内核只为生成一次密钥并不划算。脚本用 `openssl` 直接生成等价的密钥对：

- 私钥（X25519）留在服务端 `/etc/hihy/cert/ech.pem`（权限 600）
- 配置列表（ECHConfigList）自动写入所有客户端配置

产物与 `sing-box generate ech-keypair` 逐字节等价，已用真实 v2.10.0 内核验证：服务端加载后自行派生出的配置列表与脚本计算的完全一致。

## 客户端支持

| 客户端 | 支持情况 |
|---|---|
| Hysteria2 原生（v2rayN / Nekoray / NekoBox） | ✅ 配置里的 `tls.ech`，分享链接里的 `ech=` 参数 |
| mihomo | ✅ `ech-opts.enable` + `ech-opts.config` |
| sing-box | ✅ `tls.ech`（1.12+） |

三种配置文件脚本都会自动带上，无需手动填。

## 注意事项

- **向后兼容**：服务端开了 ECH，不带 ECH 的老客户端仍能正常连接（照旧明文发 SNI）。所以可以先在服务端开启，再逐步更新客户端。
- **Fail-closed**：反过来不行。客户端配了 ECH 而服务端不接受（比如换了服务端、内核降级），连接会**直接失败**。
- **`insecure` 对 ECH 错误无效**：ECH 被拒时 TLS 栈会对公开域名做强制证书校验，忽略 `insecure`。自签证书测试时如果服务端没接受 ECH，会看到证书校验错误。
- **内核版本**：脚本会检查本地内核版本，低于 v2.10.0 时自动跳过 ECH 并提示——先用 `hihy 7` 更新内核，再用 `hihy 9` 重新配置。

## 参考

- [Hysteria 官方 ECH 文档](https://hysteria.network/zh/docs/advanced/ECH/)
