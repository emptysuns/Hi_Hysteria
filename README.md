# Hi Hysteria

##### (2022/11/26) 0.4.4.k:

```
hysteria 1.3.1发布,支持了fast_open加快响应速度和提升了些许性能(目前fast_open仅适用hysteria内核直接运行方式(V2rayN),其他客户端未直接支持)
1. 支持对配置进行备注
2. 增加对自签证书的提示，最近GFW对自签证书阻断情况严重，不再推荐使用
3. 增加了一些提示信息方便配置过程
4. 增加随机密码功能
5. 完善对PortHopping的支持，修复重启系统后iptables规则消失的bug
6. 修复ip被github拉黑无法获得hysteria core时下载为空的bug
7. 增加重启hysteria后的检测，修复重启失败时提示成功的bug
8. 修复netfilter-persistent规则无法删除的bug
9. 一些其它bug修复
10.支持fast_open
11.在release上增加其他客户端下载方便直接取得
12.修复lsof不区分端口类型和监听状态的bug
13.完善对端口合法性的判断，引导用户尽可能输入正确的端口
14.修改测试配置的方式，加快配置打印时间
15.修复实时日志打印的方式，使用重定向到cat防止更新不及时

Q: 为什么0.4.4更新这么频繁，内容这么多?
A: 上个版本为了兼容portHopping动了很多祖传代码，导致一堆bug，所以修复的比较多
```

[历史改进](md/log.md)

## 一·简介

> Hysteria 是一个功能丰富的，专为恶劣网络环境进行优化的网络工具（双边加速），比如卫星网络、拥挤的公共 Wi-Fi、在**中国连接国外服务器**等。 基于修改版的 QUIC 协议。

Hysteria这是一款由go编写的非常优秀的“轻量”代理程序，它很好的解决了在搭建富强魔法服务器时最大的痛点——**线路拉跨**。

在魔法咏唱时最难的不是搭建维护，而是在晚高峰时期的交付质量。~~当三大运营商晚高变成了：奠信、连不通、移不动时，你我都有感触。~~ 虽然是走的udp但是提供obfs，暂时不会被运营商针对性的QoS(不开obfs也不会被QoS)。

1、原项目提供的bench:

![image](https://raw.githubusercontent.com/HyNetwork/hysteria/master/docs/bench/bench.png)

2、50mbps北方电信,北京出口 直连落地vir San Jose机房163线路，22-23点测试YT 1080p60直播流:

![image](imgs/speed.png)

```
190 dropped of 131329
```

3、无对钟国大陆线路优化，洛杉矶shockhosting机房，1c128m ovznat 4k@p60：
![image](imgs/yt.jpg)

```
139783 Kbps
```

该项目仅作学习用途，请查看的访客在5s之内立即删除并停止使用。

由它所引起的任何问题，作者并不承担风险和任何法律责任。

因为脚本现处于0.x的测试版本，可能会有一些bug，如果遇到请发issue，欢迎star，您的⭐是我维护的动力。

适配ubuntu/debian, centos/rhel操作系统,misple/arm/x86/s390x架构。

## 二·使用

### 第一次使用?

#### 1. [防火墙问题](md/firewall.md)

#### 2. [自签证书](md/certificate.md)

#### 3. [限制UDP的服务商排雷列表【2022/03/21更新】](md/blacklist.md)

#### 4. [hysteria各个协议介绍](md/protocol.md)

#### 5. [如何设置我的延迟、上行/下行速度？](md/speed.md)

#### 6. [支持的客户端](md/client.md)

#### 7. [常见问题/通知](md/issues.md)

#### 8. [[端口跳跃/多端口](Port Hopping)介绍](md/portHopping.md)

### 拉取安装

```
su - root #switch to root user.
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### 配置过程

首次安装后: `hihy`命令调出菜单,如更新了hihy脚本，请执行选项 `9`或者 `12`,获得最新的配置

```
3 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns   **********|
|**********     Version: 0.4.4     **********|
 -------------------------------------------
Tips:hihy 命令再次运行本脚本.
............................................. 
############################### 

..................... 
1)  安装 hysteria 
2)  卸载 
..................... 
3)  启动 
4)  暂停 
5)  重新启动 
6)  运行状态 
..................... 
7)  更新Core 
8)  查看当前配置 
9)  重新配置 
10) 切换ipv4/ipv6优先级 
11) 更新hihy 
12) 完全重置所有配置 
13) 修改当前协议类型
14) 查看实时日志

############################### 


0)退出 
............................................. 
请选择:
```

**脚本每次更新都可能会发生改变，请一定要展开并仔细参考演示过程，避免发生不必要的错误！**

<details>
  <summary>演示较长，点我查看</summary>
  <pre><blockcode> 
  请选择:1
Ready to install.

Update.wait...
Hit:1 [http://security.debian.org](http://security.debian.org) buster/updates InRelease
Hit:2 [http://ftp.debian.org/debian](http://ftp.debian.org/debian) buster InRelease
Hit:3 [http://ftp.debian.org/debian](http://ftp.debian.org/debian) buster-updates InRelease
Reading package lists... Done
Building dependency tree
Reading state information... Done
4 packages can be upgraded. Run 'apt list --upgradable' to see them.

Done.
Install wget curl lsof
*wget
Installed.Ignore.
*curl
Installed.Ignore.
*lsof
Installed.Ignore.

Done.
The Latest hysteria version:v1.3.1
Download...

Download completed.
开始配置:
请选择证书申请方式:

1、使用ACME申请(推荐,需打开tcp 80/443)
2、使用本地证书文件
3、自签证书

输入序号:
1
请输入域名(需正确解析到本机,关闭CDN):
test.example.com

您已选择使用ACME自动签发可信的test.example.com证书加密.

请输入你想要开启的端口,此端口是server端口,建议10000-65535.(默认随机)

随机端口:60853

选择协议类型:

1、udp(QUIC,可启动端口跳跃)
2、faketcp
3、wechat-video(默认)

输入序号:
1
传输协议:udp

您选择udp协议,可使用[端口跳跃/多端口](Port Hopping)功能
强烈推荐,但是处于beta测试中,目前hihy对此功能支持尚不完善,后续会慢慢修改更新,如有问题请反馈给作者,谢谢!

Tip: 长时间单端口 UDP 连接容易被运营商封锁/QoS/断流,启动此功能可以有效避免此问题.
更加详细介绍请参考: [https://github.com/emptysuns/Hi_Hysteria/blob/main/md/portHopping.md](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/portHopping.md)

选择是否启用:

1、启用(默认)
2、跳过

输入序号:

您选择启用端口跳跃/多端口(Port Hopping)功能
端口跳跃/多端口(Port Hopping)功能需要占用多个端口,请保证这些端口没有监听其他服务
Tip: 端口选择数量不宜过多,推荐1000个左右,建议选择连续的端口范围.
更多介绍参考: [https://hysteria.network/docs/port-hopping/](https://hysteria.network/docs/port-hopping/)
请输入起始端口(默认47000):

起始端口:47000

请输入结束端口(默认48000):

结束端口:48000

您选择的端口跳跃/多端口(Port Hopping)参数为: 47000:48000

请输入您到此服务器的平均延迟,关系到转发速度(默认200,单位:ms):

延迟:200 ms

期望速度,这是客户端的峰值速度,服务端默认不受限。Tips:脚本会自动*1.10做冗余，您期望过低或者过高会影响转发效率,请如实填写!
请输入客户端期望的下行速度:(默认50,单位:mbps):
100
客户端下行速度：100 mbps

请输入客户端期望的上行速度(默认10,单位:mbps):
10
客户端上行速度：10 mbps

请输入认证口令(默认随机生成,建议20位以上强密码):

认证口令:f45fd50b526907b2ba8f03df0

请输入客户端名称备注(默认使用域名/IP区分,例如输入test,则名称为Hys-test):
ppeko

配置录入完成!

执行配置...
IPTABLES OPEN: udp/60853
Reading package lists...
Building dependency tree...
Reading state information...
wget is already the newest version (1.20.1-1.1).
0 upgraded, 0 newly installed, 0 to remove and 4 not upgraded.
Port: TCP/80 已经被 apache2(*:http) 占用,进程pid为: 6371.
是否自动关闭端口占用?(y/N)
y
端口解绑成功...
IPTABLES OPEN: tcp/80
IPTABLES OPEN: tcp/443

Test config...

Test success!Generating config...
in.sh: line 211:  5296 Killed                  /etc/hihy/bin/appS -c /etc/hihy/conf/hihyServer.json server > /tmp/hihy_debug.info 2>&1
安装成功,请查看下方配置详细信息
sysctl: cannot stat /proc/sys/net/core/rmem_max: No such file or directory
Created symlink /etc/systemd/system/multi-user.target.wants/hihy.service → /etc/systemd/system/hihy.service.

1* [v2rayN/nekoray] 使用hysteria core直接运行:
客户端配置文件输出至: /root/Hys-ppeko(v2rayN).json ( 直接下载生成的配置文件[推荐] / 自行复制粘贴下方配置到本地 )
Tips:客户端默认只开启http(8888)、socks5(8889)代理!其他方式请参照hysteria文档自行修改客户端config.json
↓***********************************↓↓↓copy↓↓↓*******************************↓
{
"server": "test.example.com:60853,47000-48000",
"protocol": "udp",
"up_mbps": 11,
"down_mbps": 110,
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "f45fd50b526907b2ba8f03df0",
"server_name": "test.example.com",
"insecure": false,
"recv_window_conn": 11534336,
"recv_window": 46137344,
"disable_mtu_discovery": true,
"resolver": "https://223.5.5.5/dns-query",
"retry": 3,
"retry_interval": 3,
"quit_on_disconnect": false,
"handshake_timeout": 15,
"idle_timeout": 30,
"fast_open": true,
"hop_interval": 180
}
↑***********************************↑↑↑copy↑↑↑*******************************↑

2* [Shadowrocket/Sagernet/Passwall] 一键链接:
hysteria://test.example.com:60853?protocol=udp&auth=f45fd50b526907b2ba8f03df0&peer=test.example.com&insecure=0&upmbps=11&downmbps=110&alpn=h3#Hys-ppeko

3* [Clash.Meta] 配置文件已在/root/Hys-ppeko(clashMeta).yaml输出,请下载至客户端使用(beta)
安装完毕

  `</blockcode></pre>`

</details>

## 三·选读

#### 1. [借用其他支持Socks5的GUI，来获得一个图形界面](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/gui.md)

## 四·Todo

**如果您有好的功能建议，请不要忘记开个issue提出来欧～～～欢迎PR来完成Todo或者给我纠正我的渣代码**

**我的爱好是写bug （￣▽￣）~**

* [X] 检测端口是否被占用
* [ ] 利用xray s5 inbound来支持按域名分流(warp)
* [X] 生成分享链接
* [X] hihy替换掉hysteria
* [ ] 规范化脚本代码
* [ ] 提供docker和systemd(已完成)两种运行方式
* [ ] 利用base64加密替换原来的auth_str
* [X] 兼容v2rayN,放弃cmd的更新
* [X] 支持clash.meta核心
* [X] 优化clash配置选项
* [ ] 支持sing-box作为core运行方式
* [X] 提供查看实时log选项
* [ ] 生成clash配置时，提供一个远程链接来代替本地导入（咕～）
* [X] 完善对portHopping功能的支持

## 五·结语

魔改UDP的QUIC协议，加了tls和混淆的话，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。

## 六·鸣谢

[@apernet/hysteria](https://github.com/HyNetwork/hysteria)

[@Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)

[@mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent)

[@2dust/v2rayN](https://github.com/2dust/v2rayN)

[@Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)

[@zzzgydi/clash-verge](https://github.com/zzzgydi/clash-verge)

[@MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)

## 七·捐赠

如果您有能力，请捐赠**hysteria开发项目组**去支持它们无私的工作，谢谢:

此捐助对象不是hihy,只是单纯帮它们宣传...

[https://hysteria.network/docs/donations/](https://hysteria.network/docs/donations/)

[![Crypto donation button by NOWPayments](https://camo.githubusercontent.com/70a3b7fb344c4dc9151639ec5db5e713b2bb177aa6cac6e63538f33a74585e48/68747470733a2f2f6e6f777061796d656e74732e696f2f696d616765732f656d626564732f646f6e6174696f6e2d627574746f6e2d626c61636b2e737667)](https://nowpayments.io/donation?api_key=EJH83FM-FDC40ZW-QGDZRR4-A7SC67S)
