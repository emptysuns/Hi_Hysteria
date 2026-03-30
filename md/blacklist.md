#### 限制UDP的服务商排雷列表【2025/01/07更新】

究其原因只是一小部分IDC怕被D到怀疑人生，不得出次下文，请放心，**大部分服务商hysteria2表现均正常**。而且下面列出的，是仅有不可用的“前科”，正常与否请自测为准（未在列表即默认可用），仅供参考：

日志表现为 `[error:timeout: no recent network activity] Failed to initialize client`

* digitalocean : 有时可用，有时不可用，防火墙规则深不可测，它的floating ip有着更为严格的规则。
* vultr：和DigitalOcean表现一致
* aws: 当你使用ec2实例使用udp/wechat-video模式等udp模式时，会被aws认为是对外的udp攻击，收到警告邮件。但实际使用过程中从未出现此现象，可能是随着h3的普及，减少了误判
* RackNerd: 很多人反映它的洛杉矶地区无法使用udp/wechat-video等udp类型的协议
