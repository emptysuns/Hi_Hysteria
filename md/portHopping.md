#### [端口跳跃/多端口](Port Hopping)介绍

**BETA测试中，如果有问题请发issue询问**

hysteria在1.3.0版本引入了Port Hopping功能，意在改善**种花恭贺国**用户反馈长时间单端口 UDP 连接容易被运营商封锁/QoS 的问题。

经测试效果**非常明显，但**是**仅仅UDP协议支持**，其他协议**不支持**开启

鉴于此次改动幅度对配置影响较大，**很多诸如nekoray/clash_meta/passwall的客户端都没有很好的支持这一功能**，目前仅使用V2rayN这种

**直接使用hysteria core运行的方式**得到了支持，但是需要升级双端（服务端、客户端）

**目前无法通过一键链接导入**

而且此监听多端口功能，并非服务端hysteria直接监听端口，而是通过iptables NAT的方式，将某些端口转发到监听端口上。

您可以从如上信息看出，这个功能目前很**新**，各种地方都没有很好的适配，hihy目前对这个功能的适配处于摸索阶段，如果有什么好的建议请在issue提出

参考https://hysteria.network/docs/port-hopping/
