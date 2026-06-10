#### 自签证书

没有证据表明自签证书会被GFW所针对，不过不推荐自签某些特殊的域名，比如 `wechat.com`

特殊域名会被你本地运营商所阻断，如果自签请避开这些敏感域名，防止您的服务器遭受损失

自签证书时的**允许不安全连接(insecure)**会有 MITM(Man-in-the-middle attack, 中间人攻击)风险。

为此，脚本**默认不再开启不安全连接**，而是在生成自签证书后自动计算其 SHA-256 指纹，并通过 `pinSHA256` 让客户端校验证书指纹。这样即使是自签证书，客户端也能确认连接到的是你的服务器，从而**避免中间人攻击**。生成的分享链接与客户端配置都会自动带上该指纹，无需手动操作。

你可以随时用 openssl 查看证书指纹：

```
openssl x509 -noout -fingerprint -sha256 -in your_cert.crt
```

脚本生成的客户端配置等价于如下形式（`pinSHA256` 即上面命令输出 `=` 之后的部分）：

```
tls:
  sni: another.example.com
  insecure: false
  pinSHA256: BA:88:45:17:A1...
```

如果你更希望用 CA 校验，也可以改用 `ca` 字段，所需要的 ca 证书将在您用 hihy 配置完成自签证书之后放到 `/etc/hihy/result`：

```
tls:
  sni: another.example.com
  insecure: false
  ca: custom_ca.crt
```

> 注意：少数老旧客户端可能不支持 `pinSHA256`。若遇到此情况，可改用原生配置文件中的 `ca` 字段，或将 `tls.insecure` 手动设为 `true`（不推荐，存在中间人攻击风险）。
