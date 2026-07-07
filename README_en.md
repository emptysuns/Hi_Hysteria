# Hi Hysteria

**English** | [中文](README.md) | [فارسی](README_fa.md) | [Русский](README_ru.md)

##### (2026/07/07) ver1.12

```
Modular refactor; i18n multi-language (en/zh/fa/ru); mihomo config fixes (congestion/gecko/hop-interval/Realm) + rename; new sing-box client config generator
```


[Realm P2P hole-punching — use Hysteria2 behind NAT, even relay through Cloudflare](md/realm.md)



Questions or want to share tips? Join our Telegram group:
[![Telegram](https://img.shields.io/badge/Telegram-HiHysteria-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://hihysteria.t.me)

[Changelog](md/logs.md)

[Hysteria V1](https://github.com/emptysuns/Hi_Hysteria/tree/v1)

## 1. Introduction

> Hysteria2 is a feature-rich network tool optimized for harsh network environments (dual-side acceleration) — satellite links, crowded public Wi-Fi, **connecting to overseas servers from China**, etc. Built on a modified QUIC protocol.
> 
It solves the biggest pain point when setting up proxy servers — **poor quality network routes**.

1. China Telecom direct to Japan NTT + Cloudflare WARP, unoptimized 163 backbone, peak hours (20:00-23:00) speedtest:

~~Note: The test machine is an LXC container — CPU maxed out due to performance limits~~

![image](imgs/speed.png)

2. No China-optimized routing, Los Angeles ShockHosting, 1c128m OVZ NAT, 4K@60fps:

![image](imgs/yt.jpg)

```
139783 Kbps
```

**This repository is for educational purposes only — researching optimization methods for high-jitter, high-latency network environments. Prohibited for illegal use. Please comply with your local laws.**

The author assumes no risk or legal liability for any issues caused. Please comply with the GPL open-source license.

There may be bugs — please file an issue if you find any. Stars welcome! Your ⭐ keeps this project going.


## 2. Features

<details>
<summary><b>Click to expand full feature list</b></summary>

* Supports all three masquerade modes provided by Hysteria2 with highly customizable content
* Four certificate import methods:
  * ACME HTTP Challenge
  * ACME DNS
  * Self-signed certificate for any domain
  * Local certificate files
* View Hysteria2 server statistics in the SSH terminal:
  * User traffic statistics
  * Online device count
  * Active connections and more
* ACL-based domain routing rules with domain blocking support
* Supports all mainstream operating systems and architectures:
  * OS: Arch, Alpine, RHEL, CentOS, AlmaLinux, Debian, Ubuntu, Rocky Linux, etc.
  * Arch: x86_64, i386/i686, aarch64/arm64, armv7, s390x, ppc64le
* QR code generation for hy2 share links directly in the terminal — less copy-paste hassle
* Generate Hysteria2 original client config files with the full set of client parameters
* High-priority process launch for Hysteria2 — speed first
* Port hopping and Hysteria2 daemon managed via auto-start scripts for better extensibility and compatibility
* Hysteria v1 installation script preserved as an option
* BDP (Bandwidth-Delay Product) calculation to tune QUIC parameters for diverse scenarios
* SOCKS5 outbound support, including automatic WARP outbound setup
* Supports LXC, OpenVZ, KVM and all mainstream virtualization platforms
* Realm mode (P2P hole-punching) — establish connections without a public IP or port forwarding
* Realm through Cloudflare WARP — connect to Hysteria2 via WARP IP, hiding the real server IP (effectively behind CF CDN)
* Timely updates — adapted within 24 hours of Hysteria2 releases

</details>

## 3. Usage

### First Time?

#### 1. [Firewall Guide](md/firewall.md)

#### 2. [Self-Signed Certificates](md/certificate.md)

#### 3. [UDP-Throttling ISP Blacklist (Updated 2025/01/07)](md/blacklist.md)

#### 4. [How to Set Latency / Upload / Download Speed](md/speed.md)

#### 5. [Supported Clients](md/client.md)

#### 6. [FAQ / Troubleshooting](md/issues.md)

#### 7. [Enable a Masquerade Website](md/masquerade.md)

#### 8. [Realm Mode — P2P Hole-Punching](md/realm.md)

### Quick Install

```
su - root # switch to root user.
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### Configuration

After first install: run `hihy` to open the menu. If you've updated the hihy script, use option `9` to get the latest config.

You can directly invoke functions by number, e.g. `hihy 5` restarts hysteria2.

```
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns   **********|
|**********   Version: ver1.12     **********|
 -------------------------------------------
Tips: hihy  command to run this script again.
............................................. 
############################### 
..................... 
1)  Install hysteria2 
2)  Uninstall 
..................... 
3)  Start 
4)  Stop 
5)  Restart 
6)  Status 
..................... 
7)  Update Core 
8)  View Config 
9)  Reconfigure 
10) Switch IPv4/IPv6 Priority 
11) Update hihy 
12) ACL Domain Routing 
13) View Statistics 
14) View Logs 
15) Add SOCKS5 Outbound [WARP auto-config] 
############################### 
0)  Exit 
............................................. 
Please choose:
```

**The script may change with each update. Please expand and review the demo to avoid unnecessary errors!**


> **Note:** The following demo shows a recording of the Chinese interface. With i18n support (ver1.12+), the actual script now displays in your selected language (en/zh/fa/ru).
<details>
  <summary>Long demo — click to view (terminal recording, Chinese interface)</summary>
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

## 4. Todo

**If you have feature suggestions, please open an issue! PRs welcome to add todo items or fix my spaghetti code.**

**My hobby is writing bugs (￣▽￣)~**

![img](imgs/gugugu.gif)

* [ ] Multi-user management: kick users offline, add new users, etc.

## 5. Conclusion

Hysteria2 performs well in high-latency, high-packet-loss environments thanks to its custom Brutal congestion control algorithm.

This contributes to research on challenging network environments. This repository aims to help researchers configure Hysteria2 conveniently. In principle, we support custom configuration for all Hysteria2 features, providing highly customizable setups.

If this helped you learn shell scripting, please give this repo a little ⭐ to help more people discover it.

**No donations or advertising sponsorships accepted. Please don't waste issue exposure opportunities.**

![img](./imgs/stickerpack.png)

## 6. Acknowledgments

[@apernet/hysteria](https://github.com/HyNetwork/hysteria)

[@2dust/v2rayN](https://github.com/2dust/v2rayN)

[@MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)

[@fscarmen/warp](https://gitlab.com/fscarmen/warp)
