#### 限制UDP的服务商排雷列表【2022/02/20更新】

究其原因只是一小部分IDC怕被D到怀疑人生，不得出次下文，请放心，**大部分服务商hysteria表现均正常**。而且下面列出的，是仅有不可用的“前科”，正常与否请自测为准（未在列表即可用），仅供参考：

日志表现为`[error:timeout: no recent network activity] Failed to initialize client`

* digitalocean : 有时可用，有时不可用，防火墙规则深不可测，它的floating ip有着更为严格的规则。
* vultr：和DigitalOcean表现一致
* virmach：曾同地区电信可用，移动不可用。
* aws: 当你使用ec2实例使用udp/wechat-video模式等udp模式时，会被aws认为是对外的udp攻击，收到警告邮件。