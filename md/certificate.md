#### 自签证书

没有证据表明自签证书会被GFW所针对，不过不推荐自签某些特殊的域名，比如 `wechat.com`

特殊域名会被你本地运营商所阻断，如果自签请避开这些敏感域名，防止您的服务器遭受损失

自签证书时的**允许不安全连接(insecure)**会有 MITM(Man-in-the-middle attack, 中间人攻击)风险。

为此，脚本在生成自签证书后自动计算其 SHA-256 指纹，并通过 `pinSHA256` 让客户端**校验证书指纹**（证书钉扎 / pinning）。这样即使是自签证书，客户端也能确认连接到的确实是你的服务器，从而**避免中间人攻击**。生成的分享链接与客户端配置都会自动带上该指纹，无需手动操作。

你可以随时用 openssl 查看证书指纹：

```
openssl x509 -noout -fingerprint -sha256 -in your_cert.crt
```

脚本生成的客户端配置等价于如下形式（`pinSHA256` 即上面命令输出 `=` 之后的部分）：

```
tls:
  sni: another.example.com
  insecure: true
  pinSHA256: BA:88:45:17:A1...
```

**为什么这里是 `insecure: true`？**

Hysteria 的 `pinSHA256` 只是在标准校验之外**追加**一个指纹比对回调，并不会替代它。自签证书没有受信任的证书链，若 `insecure: false`，握手会先在标准链校验上失败（`x509: certificate signed by unknown authority`），客户端根本连不上。

`insecure: true` 关闭的是"证书链 + 域名"这套校验，而 `pinSHA256` 要求对端证书的 SHA-256 与你服务器上那一份**逐字节相同**——攻击者必须持有该证书的私钥才能冒充，这比"信任任意一家 CA 签发的证书"更严格。所以**两者搭配使用时安全性不降反升**，请勿手动把 `insecure` 改回 `false`。

> ver1.15 之前的版本这里错写成 `insecure: false`，会导致自签证书下客户端无法连接。如果你还在用旧配置，执行 `hihy 8` 重新生成即可。

如果你更希望用 CA 校验，也可以改用 `ca` 字段（此时不需要 `insecure`），所需要的 ca 证书将在您用 hihy 配置完成自签证书之后放到 `/etc/hihy/result`：

```
tls:
  sni: another.example.com
  ca: custom_ca.crt
```

生成的 sing-box 配置就是走的这条路线——它不支持 `pinSHA256`，脚本改为把 CA 证书内容直接内嵌进配置的 `certificate` 字段。

> 注意：少数老旧客户端可能不支持 `pinSHA256`。若遇到此情况，可改用原生配置文件中的 `ca` 字段。
