#### Realm 模式（P2P 穿透）

Realm 是 Hysteria 2 的 P2P 穿透模式，允许服务器在**无公网 IP、无端口转发**的环境下运行。

##### 工作原理

1. 服务器通过 STUN 发现自己的公网 UDP 地址，将其注册到牵手（rendezvous）服务器
2. 客户端使用相同的 realm 名向牵手服务器请求连接
3. 牵手服务器交换双方的地址信息，双方同时向对方发送 UDP 包进行打洞
4. 打洞成功后，流量直接在服务器和客户端之间传输，**不经过牵手服务器**

##### 适用场景

- 家庭宽带 NAT 后（无公网 IP）
- CGNAT 环境
- 咖啡厅/酒店/热点网络
- 快速测试，无需配置 VPS

##### WARP 辅助打洞（适用于 NAT 严格环境）

当 NAT 类型较严格（如对称 NAT）导致直连打洞失败时，可借助 Cloudflare WARP 获取一个 CF 出口 IP 作为中转，提升打洞成功率：

1. 在 Realm 配置阶段，脚本会询问是否安装 WARP
2. 安装后，WARP 会为本机创建一个 Cloudflare Warp 虚拟网卡（如 `wgcf` 或 `CloudflareWARP`）
3. 服务器通过该虚拟网卡注册到牵手服务器，客户端通过 CF IP 进行连接
4. **退出 Realm 模式或卸载时，脚本会提示是否一并卸载 WARP**，避免残留虚拟网卡影响网络

> **注意**：WARP 会增加一层隧道转发，延迟和带宽可能受影响。建议仅在 NAT 严格导致直连失败时启用，打洞成功后流量仍然通过 Hysteria 2 加密直连。

##### 注意事项

- 官方公共牵手服务器地址为 `realm.hy2.io`，使用密码 `public`
- Realm 名使用随机 UUID 生成，**请勿泄露**，知道此名称的人可以获得你的服务器 IP 地址
- 现已支持 `hysteria2+realm://` 分享链接（适用于支持 Realm URI 的客户端），脚本会同时输出分享链接、二维码和原生配置文件；ClashMeta 配置暂不支持 Realm 模式
- Realm 模式下不需要配置端口、端口跳跃，无需操作防火墙
- 自签证书无需检测公网 IP，直接使用牵手地址连接；自签证书会通过 `pinSHA256` 指纹校验，默认不再开启不安全连接
- 支持自建牵手服务器（[hysteria-realm-server](https://github.com/apernet/hysteria-realm-server)），自建时需设置强密码
- Realm 模式自动跳过伪装（masquerade）配置，避免无效交互

##### 分享链接格式

```
hysteria2+realm://<牵手token>@<牵手服务器>[:port]/<realm名>?auth=<hysteria密码>&pinSHA256=<证书指纹>&sni=<域名>
```

- userinfo（`@` 之前）是**牵手服务器 token**（默认 `public`），**不是** Hysteria 密码
- Hysteria 验证密码放在 `auth` 参数中
- 自签证书使用 `pinSHA256` 指纹校验，无需 `insecure`
- 牵手服务器走 HTTPS；若走 HTTP 则协议头为 `hysteria2+realm+http://`

##### 客户端配置示例

```yaml
server: realm://public@realm.hy2.io/your-realm-name
auth: your-hysteria-password
tls:
  sni: your-domain.com
  insecure: false
  pinSHA256: BA:88:45:17:A1...
transport:
  type: udp
socks5:
  listen: 127.0.0.1:20808
```

> 详情参考：[Hysteria 2 Realms 官方文档](https://hysteria.network/zh/docs/advanced/Realms/)
