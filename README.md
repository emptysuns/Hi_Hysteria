# Hi Hysteria

[English](README_en.md) | **中文** | [فارسی](README_fa.md) | [Русский](README_ru.md)

##### (2026/07/07) ver1.12

```
脚本模块化重构；i18n 多语言支持(en/zh/fa/ru)；mihomo 配置修复(拥塞控制/gecko 拦截/hop-interval/Realm)并改名；新增 sing-box 客户端配置生成
```


[realm p2p穿透打洞，内网使用hysteria2介绍，可以让hy2直接经过cloudflare中转](md/realm.md)



有问题，或者想交流使用经验，欢迎加入 TG 群：
[![Telegram](https://img.shields.io/badge/Telegram-HiHysteria-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://hihysteria.t.me)

[历史改进](md/logs.md)

[Hysteria V1版本](https://github.com/emptysuns/Hi_Hysteria/tree/v1)

## 一·简介

> Hysteria2 是一个功能丰富的，专为恶劣网络环境进行优化的网络工具（双边加速），比如卫星网络、拥挤的公共 Wi-Fi、在**中国连接国外服务器**等。 基于修改版的 QUIC 协议。
> 
它很好的解决了在搭建富强魔法服务器时最大的痛点——**线路拉跨**。

1. CT直连落地JP NTT机房+cloudflare warp,无任何优化163线路，20-23点晚高峰测试speedtest。:

~~由于测试机器为lxc容器，因性能拉跨，CPU已经跑满，无法继续努力~~

![image](imgs/speed.png)

2. 无对钟国大陆线路优化，洛杉矶shockhosting机房，1c128m ovznat 4k@p60：

![image](imgs/yt.jpg)

```
139783 Kbps
```

**本仓库仅作学习用途，研究一种高抖动、高延迟网络环境的优化办法和解决方案，禁止用于违法行为，请遵守您所在地的法律。**

由它所引起的任何问题，作者并不承担风险和任何法律责任，请遵守GPL开源协议。

可能会有一些bug，如果遇到请发issue，欢迎star，您的⭐是我维护的动力。


## 二、优点

<details>
<summary><b>点我展开查看完整功能列表</b></summary>

* 支持hysteria2提供的三种masquerade伪装模式，并提供高度自定义伪装内容
* 提供四种证书导入方式：
  * ACME HTTP挑战
  * ACME DNS
  * 自签任意域名证书
  * 本地证书
* 支持在ssh终端查看hysteria2 server统计信息：
  * 用户流量统计
  * 在线设备数量
  * 当前活跃的连接等信息
* 提供仅通过ACL实现的分流域名规则，以及屏蔽相应域名的请求
* 支持当前市面上所有主流的操作系统与架构：
  * 操作系统：Arch、Alpine、RHEL、Centos、AlamaLinux、Debian、Ubuntu、Rocky Linux等
  * 架构：x86_64、i386|i686、aarch64|arm64、armv7、s390x、ppc64le
* 支持对hy2分享链接生成二维码输出到终端，减少繁琐的复制粘贴过程
* 支持生成hysteria2 original client配置文件，保留最全的客户端参数
* 使用高优先级启动hysteria2进程，保持速度优先
* 端口跳跃与hysteria2的守护进程使用自启脚本管理，提供更强的拓展性与兼容性
* 保留提供hysteria v1的安装脚本，供用户选择
* 计算BDP（带宽延迟积）来调整quic参数，适应多种多样的需求场景
* 支持添加socks5出站，包括自动添加warp出站功能
* 支持lxc、openvz、kvm等现在的所有主流的虚拟化方式
* 支持Realm模式（P2P穿透），无需公网IP和端口转发即可建立连接
* 支持使用Realm穿透cloudflare warp, 使用warp ip连接hysteria2, 隐藏真实ip（变相套CF CDN）
* 更新及时，hysteria2更新后24h内完成适配

</details>

## 三·使用

### 第一次使用?

#### 1. [防火墙问题](md/firewall.md)

#### 2. [自签证书](md/certificate.md)

#### 3. [限制UDP的服务商排雷列表【2025/01/07更新】](md/blacklist.md)

#### 4. [如何设置我的延迟、上、下行速度？](md/speed.md)

#### 5. [支持的客户端](md/client.md)

#### 6. [常见问题](md/issues.md)

#### 7. [启动一个伪装网站](md/masquerade.md)

#### 8. [Realm模式 - P2P穿透](md/realm.md)

#### 9. [一键安装 - 零交互](md/onekey.md)

### 拉取安装

```
su - root #switch to root user.
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### 一键安装(零交互)

不想逐项回答配置问题？一条命令自动完成全部安装(随机端口 + UUID 密码 + 自签证书 pinSHA256 校验 + BBR，默认不启用伪装):

```
bash <(curl -fsSL https://git.io/hysteria.sh) --auto
```

已安装 hihy 后也可执行 `hihy autoinstall`(菜单选项 `16`)。支持环境变量定制(端口/密码/伪装等)，详见 [一键安装文档](md/onekey.md)。

### 配置过程

首次安装后: `hihy`命令调出菜单,如更新了hihy脚本，请执行选项 `9`获得最新的配置

支持通过数字序号直接调取相应功能，例如`hihy 5` 将会重启hysteria2

```
 ╭───────────────────────────────────────────╮
 │            Hi Hysteria ver1.13            │
 │ https://github.com/emptysuns/Hi_Hysteria  │
 ╰───────────────────────────────────────────╯
  ● 运行中 │ 内核: v2.9.1

 部署 ────────────────────────
   1) 安装 hysteria2（交互向导）
  16) 一键安装（零交互）
   2) 卸载

 服务 ────────────────────────
   3) 启动
   4) 停止
   5) 重启
   6) 运行状态

 配置 ────────────────────────
   8) 查看客户端配置
   9) 重新配置
  10) 切换 IPv4/IPv6 优先级
  12) ACL 域名分流
  15) SOCKS5 出站（支持 WARP）

 维护 ────────────────────────
   7) 更新 Hysteria 内核
  11) 更新 hihy 脚本
  13) 流量统计
  14) 实时日志

 ─────────────────────────────────────────
   0) 退出
 提示: 运行 hihy 命令再次执行本脚本.

请选择:
```

**脚本每次更新都可能会发生改变，请一定要展开并仔细参考演示过程，避免发生不必要的错误！**

<details>
  <summary>演示较长，点我查看</summary>
<pre><blockcode> 

请选择: 1
Ready to install.
 
The Latest hysteria version: app/v2.9.1 
Download...

Download completed. 
开始配置: 
(0/13)是否使用Realm模式(P2P穿透,无需公网IP):


Realm是Hysteria2的P2P穿透模式,通过牵手(rendezvous)服务器介绍双方进行UDP打洞,
打洞成功后流量直连,不经过牵手服务器。服务器无需公网IP、无需端口转发即可运行。
适用: NAT/家庭宽带/CGNAT/无公网IP环境。详情: https://hysteria.network/zh/docs/advanced/Realms/
⚠ 目前仅支持使用hysteria core直接运行

1、不使用(默认)
2、使用Realm模式

输入序号:
2

->您的Realm名(请勿泄露,知道此名称的人可以获得你的服务器ip地址): ab747d7f-03a7-4bf7-982c-79967bae7056 


请选择牵手(rendezvous)服务器: 
官方服务器地址为 realm.hy2.io, 使用默认密码 public 即可,无需修改
1、官方牵手服务器(默认): realm.hy2.io
2、自建牵手服务器

输入序号:
1

->牵手地址: realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056 


(可选)是否安装服务器全局WARP[fscarmen]通过Cloudflare WARP IP打洞连接Hysteria2? 
原理: WARP通过WireGuard协议接入Cloudflare全球边缘网络,为服务器分配WARP IP。
Hysteria2利用该WARP IP进行Realm打洞,客户端实际连接到Cloudflare边缘节点,
从而隐藏服务器真实IP,相当于变相在Cloudflare CDN上使用Hysteria2。
前提: 服务器需支持WireGuard内核模块,安装过程全自动。
注意: 安装后服务器出站流量将经过Cloudflare WARP,不影响Hysteria2入站。
1、安装WARP
2、跳过(默认)

输入序号:

1

->开始安装WARP,请稍候... 
请在WARP安装菜单中选择 [全局] 工作模式(出现菜单时手动选择全局) 
 
 Language:
 1. English (default) 
 2. 简体中文 

 Choose: 2

 所有依赖已存在，不需要额外安装 

 检查环境中…… 

 请选择 wireguard 方式:
 1. wireguard 内核 (默认)
 2. wireguard-go with reserved 

 请选择: 

 工作模式:
 1. 全局 (默认)
 2. 非全局 

 请选择: 1

 请选择优先级别:
 1. IPv4
 2. IPv6
 3. 使用 VPS 初始设置 (默认) 

 请选择: 

 进度 1/3: 安装系统依赖…… 


 进度 3/3: 寻找 MTU 最优值已完成 

 创建快捷 warp 指令成功 
 运行 WARP 
 后台获取 WARP IP 中,最大尝试5次……
 第1次尝试 
 已成功获取 WARP Free 网络, 工作模式: 全局 

==============================================================

 IPv4: 104.28.193.129 罗马尼亚  AS13335 Cloudflare, Inc. 
 IPv6: 2a09:bac1:6080:8::3cc:7 罗马尼亚  AS13335 Cloudflare, Inc. 
 恭喜！WARP Free 已开启 
 总耗时: 7秒，脚本当天运行次数: 1644，累计运行次数: 75059150 
 IPv6 优先 , 工作模式: 全局 

==============================================================

 再次运行用 warp [option] [lisence]，如 

 warp h (帮助菜单）
 warp n (获取 WARP IP)
 warp o (临时warp开关)
 warp u (卸载 WARP 网络接口和 Socks5 Client)
 warp b (升级内核、开启BBR及DD)
 warp v (同步脚本至最新版本)
 warp r (WARP Linux Client 开关)
 warp 4/6 (WARP IPv4/IPv6 单栈)
 warp d (WARP 双栈)
 warp c (安装 WARP Linux Client，开启 Socks5 代理模式)
 warp l (安装 WARP Linux Client，开启 WARP 模式)
 warp i (更换支持 Netflix 的IP)
 warp e (安装 Iptables + dnsmasq + ipset 解决方案)
 warp w (安装 WireProxy 解决方案)
 warp y (WireProxy socks5 开关)
 warp k (切换 wireguard 内核 / wireguard-go-reserved)
 warp g (切换 warp 全局 / 非全局)
 warp s 4/6/d (优先级: IPv4 / IPv6 / VPS default)
 

->当前MTU=1340,无需调整(≥1320) 

->正在开启WARP... 
 已暂停 WARP，再次开启可以用 warp o 

->正在重新开启WARP以确保连接稳定... 
 后台获取 WARP IP 中,最大尝试5次……
 第1次尝试 
 已成功获取 WARP Free 网络, 工作模式: 全局 
 IPv4:104.28.193.129 罗马尼亚 AS13335 Cloudflare, Inc.
 IPv6:2a09:bac1:60a0:8::3cc:5d 罗马尼亚 AS13335 Cloudflare, Inc. 

->WARP安装完成,Hysteria2将通过Cloudflare WARP IP打洞连接 
(1/11)请选择证书申请方式:

1、使用ACME申请(推荐,需打开tcp/80端口)
2、使用本地证书文件
3、自签证书
4、dns验证

输入序号:
3
请输入自签证书的域名(默认:helloworld.com): 

->自签证书域名为:helloworld.com 


->牵手地址: realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056 



->您已选择自签helloworld.com证书加密.牵手地址:realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056 



->Realm模式无需配置端口,跳过端口设置
 

->Realm模式无需端口跳跃,跳过此设置
 
(4/13)请选择拥塞控制模式: 
Reno: 更保守、更稳，适合优先考虑兼容性和稳定性的场景
BBR: 更积极，通常吞吐更高，适合追求速度的场景
Brutal: Hysteria 2 独享特色，固定速率模型，在恶劣网络环境下通常更值得优先尝试，尤其适合已知链路真实带宽、希望获得更强抗抖动和抢带宽能力的场景
请选择:

1、Reno(保守)
2、BBR(均衡)
3、Brutal(激进,默认)

输入序号:


->您选择的拥塞控制模式: Brutal 

(5/13)请输入您到此服务器的平均延迟,用于 Brutal 模式下估算 QUIC 窗口(默认200,单位:ms): 
200

->延迟:200 ms


期望速度,这是客户端在 Brutal 模式下使用的目标带宽。Tips:脚本会自动*1.10做冗余，带宽不要高于真实链路极限，否则反而可能更不稳定! 
(6/13)请输入客户端期望的下行速度:(默认50,单位:mbps): 
200

->客户端下行速度：200 mbps

(7/13)请输入客户端期望的上行速度(默认10,单位:mbps):
40

->客户端上行速度：40 mbps

(8/13)请输入认证口令(默认随机生成UUID作为密码,建议使用强密码): 


->认证口令:a754799f-ac2a-46ff-b82a-d6141b1a2769 

Tips: 如果使用obfs混淆,抗封锁能力更强,能被识别为未知udp流量。
但是会增加cpu负载导致峰值速度下降,如果您追求性能且未被针对封锁建议不使用
(9/13)是否使用流量混淆:

1、不使用(推荐)
2、salamander - 将数据包混淆为无特征随机字节
3、gecko(实验性) - 在salamander基础上额外拆分QUIC握手包，抗检测更强

输入序号:


->您将不使用混淆


(12/13)是否在服务器屏蔽http3流量(hysteria对udp流量拥塞控制无增强效果，导致访问youtube等使用QUIC连接的网站效果不佳): 
如果开启此选项，hysteria2将不会代理udp/443，无法使用QUIC连接访问网站，并且需要在客户端配置中禁用QUIC连接，否则会导致连接失败。
 
也可以仅在客户端屏蔽QUIC/HTTP3/UDP 443连接，服务器不做屏蔽，效果一样

请选择:

1、启用(推荐)
2、跳过(默认)

输入序号:
2

->您选择不屏蔽http3流量，这会导致访问使用QUIC连接的网站无hy2增强效果

Tip: 建议在客户端开启屏蔽QUIC/HTTP3/UDP 443此选项以获得更好的访问体验。
 
(13/13)请输入客户端名称备注(默认使用域名或IP区分,例如输入test,则名称为Hy2-test): 
roms

配置录入完成!
 
执行配置... 
开始生成自签名证书...
 
生成 CA 私钥... 
生成 CA 证书... 
生成服务器私钥和 CSR... 
使用 CA 签署服务器证书... 
Certificate request self-signature ok
subject=C=CN, ST=GuangDong, L=ShenZhen, O=PonyMa, OU=Tecent, emailAddress=no-reply@qq.com, CN=helloworld.com
清理临时文件... 
移动 CA 证书到结果目录... 
证书生成成功！
 
net.core.rmem_max = 132000000
net.core.wmem_max = 132000000

Test config...

⏰ 倒计时:  
✨ 完成!
Test success! 
Stop test program... 
Generating config... 
安装成功,请查看下方配置详细信息 
Starting hihy...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 生成客户端配置文件...

✨ 配置信息如下:

📌 当前hysteria2 server版本: app/v2.9.1 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌐 Realm模式 - 服务器通过P2P打洞连接,无需公网IP和端口 

🔗 1、牵手地址: 
  realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056 


⚠ 请确保您的客户端支持Hysteria2 Realm模式 
客户端配置中server字段使用上述牵手地址,认证密码为: a754799f-ac2a-46ff-b82a-d6141b1a2769 


🔗 2、[hysteria2+realm 分享链接] 适用于支持 Realm URI 的客户端: 
  hysteria2+realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056?auth=a754799f-ac2a-46ff-b82a-d6141b1a2769&pinSHA256=BA:88:45:17:A1...&obfs=salamander&obfs-password=...&sni=helloworld.com#Hy2-roms 

提示: Realm模式暂不支持ClashMeta配置,请使用上方分享链接或原生配置文件。 

📄 3、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: ./Hy2-roms-v2rayN.yaml  
客户端使用教程: https://github.com/emptysuns/Hi_Hysteria/blob/main/md/client.md 
↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 
server: realm://public@realm.hy2.io/ab747d7f-03a7-4bf7-982c-79967bae7056
auth: a754799f-ac2a-46ff-b82a-d6141b1a2769
tls:
  sni: helloworld.com
  insecure: false
  pinSHA256: BA:88:45:17:A1...
transport:
  type: udp
obfs:
  type: salamander
  salamander:
    password: null
quic:
  initStreamReceiveWindow: 35200000
  initConnReceiveWindow: 88000000
  maxConnReceiveWindow: 132000000
  maxStreamReceiveWindow: 52800000
  keepAlivePeriod: 60s
bandwidth:
  down: 220mbps
  up: 44mbps
fastOpen: true
lazy: true
socks5:
  listen: 127.0.0.1:20808
↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ 

✅ 配置生成完成!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


</blockcode></pre>

</details>

## 四·Todo

**如果您有好的功能建议，请不要忘记开个issue提出来～～～欢迎PR来添加Todo或纠正我的渣代码**

**我的爱好是写bug （￣▽￣）~**

![img](imgs/gugugu.gif)

* [ ] 多用户管理。包括踢用户下线、添加新的用户等等

## 五·结语

Hysteria2在高延迟，高丢包网络环境下表现良好，得益于它自创的暴力拥塞控制算法。

这为我们研究相应恶劣的网络环境做出了贡献，本仓库目的是在研究这种恶劣网络环境时给予各位研究人员配置hysteria2的方便，原则上所有hysteria2提供的功能，我们都会支持自定义配置，提供高度定制化内容。

如果您觉得对您学习shell有所帮助，请帮本仓库点一个小小的⭐来让更多人看到本仓库。

**不接受任何形式的打赏和广告赞助，请不要浪费issue的曝光机会**

![img](./imgs/stickerpack.png)

## 六·鸣谢

[@apernet/hysteria](https://github.com/HyNetwork/hysteria)

[@2dust/v2rayN](https://github.com/2dust/v2rayN)

[@MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)

[@fscarmen/warp](https://gitlab.com/fscarmen/warp)
