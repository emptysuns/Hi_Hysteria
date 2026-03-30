## 启动一个伪装网站吧

如果您使用hihy安装hysteria2，那么在安装过程中，将强制您选择伪装模式

具体有三种模式： string、proxy、file

[https://v2.hysteria.network/zh/docs/advanced/Full-Server-Config/#masquerade](https://v2.hysteria.network/zh/docs/advanced/Full-Server-Config/#masquerade)

### string

返回一个固定的字符串。

```
content:hello HelloWorld
```

```
custom-stuff: HelloWorld
```

这两个选项均可自定义，或者您可以伪装的更加真实，将string返回content字符串设置为 `{"login: failed"}`

来模拟正常的接口请求行为

### proxy

作为一个反向代理，从另一个网站提供内容。

目标网站可以是https网站，比如 https://google.com

**但是无法替换网页内的域名**

### file

为一个静态文件服务器，从一个目录提供内容。

默认部署一个mikutap，您当然可以选择其他文件目录，如果想要默认加载主页，那目录里需要有index.html


### 同时监听TCP HTTPS 端口伪装

通常网站只是将HTTP/3作为一个升级选项，很少出现H3 Only的情况

> **注意：** 目前没有迹象表明有任何政府/商业防火墙在利用 "缺少 TCP HTTP/HTTPS" 这点来检测
> Hysteria 服务器。本功能仅为执着于 "做戏做全套" 的用户提供。既然要 "做戏做全套"，就没有理由将 HTTP/HTTPS 监听在
> 80/443 之外的自定义端口上（虽然 Hysteria 允许自定义监听地址）。

在 80/443 端口上也提供 TCP 的 HTTP/HTTPS。

如果希望模仿这种模式，可以使用该功能，**hihy默认是启动的，当然你在安装过程中可以选择关闭。**

这种情况下，不需要用上述特殊参数启动 Chrome，和普通的网站一样访问即可验证伪装。

如果不使用，那么你需要，通过特定参数启动 Chrome 以强制使用 QUIC，测试你的伪装配置：

```
chrome--origin-to-force-quic-on=your.site.com:443
```

> **注意：** 在用参数启动 Chrome 之前，请先确保完全退出了 Chrome，没有任何 Chrome 进程还在后台运行。否则参数可能不会生效。

然后访问 `https://your.site.com` 验证伪装是否生效。
