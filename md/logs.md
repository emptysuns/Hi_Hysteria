##### (2026/03/30) 1.0.4

```
兼容 hysteria2 最新 advanced 配置更新，重点补齐拥塞控制、端口跳跃和客户端导出逻辑。

1、服务端新增拥塞控制模式选择，支持 Brutal / Reno / BBR，并补充中文说明
2、BBR 新增初级 / 中级 / 高级三档预设说明，对应 conservative / standard / aggressive
3、Brutal 模式说明强化，标注为 Hysteria 2 独享特色，更推荐在恶劣网络环境下优先尝试
4、非 Brutal 模式下跳过延时和上下行带宽输入，只保留真正生效的拥塞控制配置
5、端口跳跃改为支持主端口 + 跳跃范围组合监听，服务端 listen 使用 :主端口,范围格式
6、端口跳跃时间新增固定 / 随机两种模式，默认固定跳跃时间
7、固定跳跃时间导出为 hopInterval，随机跳跃时间导出为 minHopInterval / maxHopInterval
8、分享链接与原生客户端配置统一修复为主端口,跳跃范围格式，避免重复拼接端口
9、伪装 proxy 模式新增 xForwarded 交互与配置写入
10、防火墙逻辑改为直接放行端口跳跃范围的 UDP 端口，不再依赖旧的 NAT 持久化思路
11、兼容组合 listen 格式下的主端口解析、卸载、重配和导出逻辑
```

##### (2025/06/09) 1.0.3

```
兼容hysteria 2.6.2更新，新版本特性对tls ClientHello进行分片，抗封锁，不会再根据域名被UDP QoS

1、兼容支持lxc与openvz虚拟化的服务器使用hihy安装hy2
2、修复本地证书路径错误
3、修复使用arch时hy2状态检测错误
4、使用sniff嗅探域名来防止acl分流失败
5、mode auto出站时禁用fastOpen, 会导致ipv4 only无法解析到v4的ip
```

##### (2025/02/04) 1.0.2

```
1、outbound type:direct添加fastopen
2、增加龙芯loongarch64架构适配。未测试，找不到相应的测试服务器...
3、伪装proxy模式下，回源默认禁用 TLS 验证
```

##### (2025/01/07) 1.0.0

```
脚本1.0.0之后从默认hysteria v1迁移到v2，v1的hihy不会再进行功能更新，仅作安全维护

1、新增查看hysteria2统计信息。包括当前在线用户、活动设备数量、用户所使用的流量统计、以及当前活跃链接等等信息
2、结果URL将会自动在终端输出一个QR CODE（二维码）方便用户保存使用，减少繁琐的复制粘贴过程
3、hysteria v2新增伪装功能，hihy提供三种模式（proxy、file、string），每种模式都有默认值，供用户选择与定制
4、和旧版相比支持alpine、Arch、Rockylinux、Alamalinux等所有主流的操作系统；x86_64、 i386|i686、aarch64|arm64、armv7、s390x、ppc64le架构，拥有更高的兼容性
5、修改port hopping规则持久化方式，放弃传统防火墙软件使用rc.d/init.d脚本控制，更广泛的兼容各类系统
6、支持域名ACL管理，能主动添加删除ipv4/ipv6分流域名，和屏蔽某一个域名，比如google.com
7、默认开启服务器端速度测试功能，可用客户端直接对server进行速度测试
8、新增ACME DNS支持。支持: Cloudflare、Duck DNS、Gandi.net、Godaddy、Name.com、Vultr
9、优化QUIC参数的计算方法，采用hysteria官方推荐流和连接接收窗口的2:5取代之前的1:4
10、使用自启脚本取代systemd守护进程，增加兼容性以及可拓展性
11、使用chrt调整高优先级启动hysteria2，最大程度的保证转发速度
12、修改自签证书默认域名，wechat.com -> apple.com(前者会被针对)
13、美化结果输出。现在打印结果时会更加美观和整齐。
```

##### (2023/06/12) 0.4.8:

```
hysteria update to v1.3.5:
v1.3.5修复了一个socks5对域名解析的bug,支持了windows cmd下的彩色字符,并没有重要功能更新

Q:  hy 1.x版本不会再有重大的功能更新？
A：Hysteria 1.x 将继续推出 bug 和安全修复，现在开发重心在hy2，目前hy1的功能已经很完善了，速度上hy1和hy2没区别，区别在于hy2更看重流量和http/3流量相同，能够实现类似xray的回落到web的功能，但并不能保证不会被封锁udp流量，所以目前正在测试阶段，实际效果还有待观察

Q: 关于hihy什么时候支持hy2?
A:  hy2目前处于测试状态，很多hy1有的功能hy2暂不支持，而且客户端只能用命令行使用，等hy2发布第一个完整的公开版，再考虑适配

1. 修复由于服务器ip太黑无法获得正确hysteria版本号问题
2. matsuri也不会再推出重大功能更新，建议安卓用户选择它的“升级版”nekobox
https://github.com/MatsuriDayo/NekoBoxForAndroid
```

##### (2023/03/15) 0.4.7

```
hysteria update to 1.3.4 : 修复了一些bug，更新依赖，客户端提供lazy_start选项，当传入数据时才连接服务端，客户端功能

1. 客户端增加配置lazy_start，目前仅支持v2rayN这种使用core直接运行的客户端，其他等待后续它的版本打包后再加
2. 增大net.core.rmem_max
3. 加长5s等待配置测试时间，由于ACME申请证书可能有延迟，防止配置检测失败
4. 完善了一下client介绍文档

Tips: 观察到开启lazy_start后会频繁触发运营商UDP QoS规则，为了安全所以0.4.7.a之后暂时默认关闭
如果需要测试请手动添加客户端选项`"lazy_start": true`,后续会跟进
```

##### (2023/02/17) 0.4.6

```
hysteria update to 1.3.3 : 修复了一些bug，更新依赖提升些许性能

1. 修复在不使用PortHopping时,生成链接出现-字符，导致导入异常的问题
2. 取消server配置resovler选项，默认使用系统dns地址
3. V2rayN选择使用6.0以上版本
4. 兼容clash.meta 端口跳跃和TCP快速打开
```

##### (2022/12/11) 0.4.5.b

```
1. 支持配置obfs,如果使用自签证书请尽量使用obfs混淆
2. 修复随机密码乱码问题
3. 增加命令直达功能，映射数字序号，比如hihy 5将重启服务端, hihy 14将打印日志
4. 修复结果打印错误，增加clashMeta脚本导出
5. hy2 暂未支持，此版本仍为 hysteria 1.x 时代日志
```

> 更早的历史版本内容可继续参考旧日志整理记录，如需我继续合并完整历史，我也可以接着补全。
