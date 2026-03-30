#### 自签证书

没有证据表明自签证书会被GFW所针对，不过不推荐自签某些特殊的域名，比如 `wechat.com`

特殊域名会被你本地运营商所阻断，如果自签请避开这些敏感域名，防止您的服务器遭受损失

自签证书时的**允许不安全连接**时会有MIMT(Man-in-the-middle attack, 中间人攻击)风险。现在脚本默认情况下允许不安全连接(~~我反正觉得被攻击的概率极小，自己判断吧~~

如果你想防止中间人攻击，请参考:

```
tls:
  sni: another.example.com 
  insecure: false 
  pinSHA256: BA:88:45:17:A1... 
  ca: custom_ca.crt
```

添加 ca字段，所需要的ca证书将在您用hihy配置完成自签证书之后放到`/etc/hihy/result`
