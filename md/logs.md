# Hi Hysteria
##### (2026/08/02) ver1.16

```
修复流量统计与SOCKS5出站菜单问题;移除已不再受支持的 namedotcom ACME DNS 服务商。

1、修复:流量统计(菜单13)活跃连接表格的 awk 变量参数(-v)误写在程序之后,被 awk 当作输入文件名解析,报 "awk: cannot open -v" 且无法输出连接数据;现将全部 -v 参数移至程序之前
2、修复:SOCKS5 出站菜单(菜单15)在 i18n 迁移时丢失了选项展示,只剩提示语与"0) 退出";现恢复 1(自动添加warp)/2(自定义socks5)/3(卸载outbound)三个选项
3、移除 namedotcom ACME DNS 服务商:hysteria v2.11.0 起移除该服务商(其上游库未针对新 libdns API 更新),继续使用会导致服务端无法启动;菜单选项顺位前移(Vultr 由 6 改为 5),en/zh/fa/ru 四个语言文件同步
```

##### (2026/07/27) ver1.15

```
修复客户端配置在真实内核上无法使用的三个致命问题，新增 ECH 与 Brutal 速率补偿开关。

【客户端配置修复 —— 均已用真实 mihomo / sing-box / hysteria 内核跑通实际流量验证】
1、修复:自签证书(默认方式)下原生客户端配置与分享链接根本连不上。hysteria 的 pinSHA256 只是追加证书校验回调,并不会关闭标准证书链校验,而自签证书没有受信链,原先写的 insecure: false 必然握手失败(x509: certificate signed by unknown authority)。现改为 pinSHA256 + insecure: true —— 仍逐字节比对证书指纹,安全性不降低
2、修复:sing-box 配置内嵌自签 CA 时,整份 PEM 被拼成一行,导致 sing-box 启动即 panic(注意 sing-box check 只验 JSON 结构,查不出该问题)。现按每行一个数组元素输出
3、修复:sing-box outbound 误设 network: udp,该字段指的是被代理流量类型而非传输层,导致所有 TCP 流量被拒(日志 TCP is not supported by default outbound)。现不再限制
4、修复:sing-box DNS 仍用旧格式,最新稳定版 1.13 已拒绝加载(需环境变量),1.14 直接移除。现改用 1.12+ 新格式,并补上 route.default_domain_resolver
5、修复:sing-box 输出了 1.14 才有的 bbr_profile,而 1.14 至今仅有 beta —— 未知字段会让稳定版拒载整份配置。现不再输出,改为提示;realm 同为 1.14+ 字段,保留输出并明确告警
6、修复:mihomo 在 Realm 模式下被删掉了 port 字段,mihomo 无条件校验端口,导致整份配置以 invalid port 拒载。现保留占位端口
7、修复:mihomo 配置的 dns.fallback 会触发默认 fallback-filter 的 GeoIP,启动时强制下载 MMDB,下载失败则整份配置起不来;且原 fallback 与 nameserver 同为国内 DNS 本就无意义。现移除 fallback 与冗余的 GEOIP,CN 规则(已由 cncidr 规则集覆盖),并补上 proxy-server-nameserver 避免 DNS 环路

【新特性(hysteria v2.10.0)】
8、新增 ECH(加密 ClientHello)支持,可选开启。密钥对由脚本用 openssl 本地生成,不需要额外下载 sing-box 内核;产物与 sing-box generate ech-keypair 等价(已验证服务端派生的配置列表与脚本计算值逐字节一致)。服务端配置、三种客户端配置与分享链接全链路适配,一键安装支持 HIHY_AUTO_ECH / HIHY_AUTO_ECH_PUBLIC_NAME
9、Brutal 模式新增"是否关闭速率补偿"选项(bandwidth.disableLossCompensation),默认不关闭;内核低于 v2.10.0 时提示该选项暂不生效
10、内核版本低于 v2.10.0 时自动跳过 ECH 并提示,避免客户端 fail-closed 连不上

【测试】
11、客户端配置测试新增真实内核校验:CI 拉取最新稳定版 mihomo 与 sing-box,让它们真正加载生成的配置(仅靠 yq/json 可解析并不能发现未知字段、缺失必填项等问题)
```

##### (2026/07/27) ver1.14

```
修复重启后服务被 Ctrl+C 连带杀死、全新安装误报残留两个问题，并新增 CI/CD。

1、修复:从菜单启动/重启的服务进程与终端同处前台进程组,退出菜单按 Ctrl+C 时 SIGINT 广播会杀死刚启动的服务(表现为"重启后服务没有起来")。服务脚本 start 改用 setsid 让服务独立会话运行
2、修复:官方安装路径(install.sh 先落 hihy 启动器再执行安装)每次全新安装都误报"检测到残留"。启动器不再计入残留判定
3、修复:RHEL 系 /etc/rc.local 默认无执行位导致开机自启静默失效,现无条件补执行位
4、修复:卸载时 i18n 语言文件先于收尾提示被删除,导致输出退化为裸 key;现先快照语言目录
5、修复:卸载后 /etc/init.d/hihy 悬空软链未清理
6、加固:Alpine OpenRC 服务脚本 stop 等待进程真正退出(兜底 kill -9),start 增加 1s 存活校验,移除与自定义函数冲突的 supervise-daemon 声明
7、重新配置(菜单 9)时同步刷新服务脚本,老安装无需完全重装即可获得服务脚本层修复
8、新增 GitHub Actions CI(构建同步/shellcheck/i18n 校验/测试套件/容器 E2E)与 tag 发布流程
```

##### (2026/07/09) ver1.13

```
一键零交互安装、伪装改为可选、菜单重构、下载安全加固。

1、新增一键零交互安装(hihy autoinstall / install.sh --auto),支持 HIHY_AUTO_* 环境变量覆盖
2、伪装(masquerade)改为默认关闭、显式开启;backup.yaml 记录 masquerade_status
3、菜单重构:状态行(服务状态/内核版本)、功能分组、操作后返回菜单
4、下载安全:内核与脚本自更新走临时文件+内容校验+原子替换,失败不破坏现有可用文件
5、端口跳跃范围现在会真正在防火墙放行;firewalld/nft 使用连字符区间语法
6、配置校验改为轮询(成功提前退出,ACME 预算 60s),所有失败路径都会终止测试进程
```

##### (2026/07/07) ver1.12

```
脚本模块化重构(hy2.sh → server/src/ + build.sh)；i18n 多语言支持(en/zh/fa/ru, 合并自 feature/i18n-support)；mihomo(ClashMeta) 配置修复: 拥塞控制模式区分(仅 Brutal 输出 up/down)、gecko 混淆拦截、BBR profile 输出、端口跳跃 hop-interval、Realm realm-opts；新增 sing-box 客户端配置生成器(1.11+, 含 Realm/自签 CA 嵌入)；规则集镜像统一为 jsDelivr(HIHY_RULESET_MIRROR 可覆盖)
```

##### (2026/06/27) ver1.09

```
Realm 新增 UPnP/NAT-PMP 端口映射与 ipMode 支持，客户端默认关闭 lazy 连接。

1、Realm 模式新增 UPnP/NAT-PMP 端口映射支持，默认开启，加强 NAT 穿透能力
2、Realm 模式新增 ipMode 选项 (dual/ipv4/ipv6)，默认 dual 双栈模式
3、客户端 lazy 默认值改为 false（启动即建立连接，提高首次响应速度）
4、Realm 服务端与客户端配置均同步适配新字段
```

##### (2026/05/24) ver1.07

```
新增 Gecko 混淆方式支持。

1、obfs 混淆新增 Gecko（实验性）选项，可在 Salamander 和 Gecko 之间选择
2、Gecko 在 Salamander 基础上额外拆分 QUIC 握手包为随机分片，抗 DPI 检测能力更强
3、服务端、客户端原生配置、分享链接、ClashMeta 配置均已适配双混淆类型
```

##### (2026/05/12) ver1.06

```
Realm 模式 WARP 集成、obfs 配置修复、代码重构与多项优化。

1、Realm 模式新增 Cloudflare WARP 安装选项，通过 CF IP 隧道辅助打洞，无需公网 IP
2、Realm 模式下自动跳过防火墙操作和伪装（masquerade）配置段，避免无效交互
3、WARP 卸载改为交互式确认，Realm 阶段增加 WARP 检测，退出时自动清理
4、修复不使用 obfs 时配置残留字段问题，改为完全删除 obfs 段而非保留空值
5、Core 更新后清除版本缓存，防止过期更新通知反复提醒
6、代码重构：shfmt 格式化、MTU/WARP 默认值更新
```

##### (2026/05/10) ver1.05

```
新增 Realm 模式（P2P 穿透），移除 HYSTERIA_FIREWALL_BACKEND，调整拥塞控制排序。

1、新增 Realm 模式（P2P 穿透），无需公网 IP 和端口转发即可运行，通过牵手服务器进行 UDP 打洞后流量直连
2、Realm 模式下自动跳过端口配置、端口跳跃、TCP 伪装监听和防火墙操作
3、Realm 模式当前仅支持 hysteria core 直接运行，不支持分享链接与 ClashMeta 配置导出
4、证书申请前新增 Realm 模式选择，支持官方/自建牵手服务器，默认使用 realm.hy2.io
5、拥塞控制选项重新排序为 Reno(保守) / BBR(均衡) / Brutal(激进,默认)，空输入默认 Brutal
6、移除所有 HYSTERIA_FIREWALL_BACKEND="iptables" 环境变量，不再通过该变量指定防火墙后端
7、修复 Realm URI 构造错误（public@public@realm.hy2.io），牵手地址与密码分离设置
8、Realm 模式客户端配置补充独立的 auth 字段
```

##### (2026/04/18) ver1.04-c

```
修复防火墙端口范围放行与清理细节，重点解决 UFW 端口跳跃和 listen 端口范围回收问题。

1、修复 UFW 放行多端口/端口跳跃范围时遗漏协议，避免 `ufw allow 47000:48000` 直接报错
2、修复重配/卸载时组合 listen 中的 `47000-48000` 未转换回防火墙规则使用的 `47000:48000`，导致 UFW / firewalld / iptables 清理范围规则失败
3、菜单版本号同步更新为 ver1.04-c
```

##### (2026/03/30) ver1.04-a

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
