# Hi Hysteria

## 一·简介
> Hysteria 是一个功能丰富的，专为恶劣网络环境进行优化的网络工具（双边加速），比如卫星网络、拥挤的公共 Wi-Fi、在**中国连接国外服务器**等。 基于修改版的 QUIC 协议。

Hysteria这是一款由go编写的非常优秀的“轻量”代理程序，它很好的解决了在搭建富强魔法服务器时最大的痛点——**线路拉跨**。

在魔法咏唱时最难的不是搭建维护，而是在晚高峰时期的交付质量。~~当三大运营商晚高变成了：奠信、连不通、移不动时，你我都有感触。~~ 虽然是走的udp但是提供obfs，暂时不会被运营商针对性的QoS(不开obfs也不会被QoS)。

1、原项目提供的bench:

![image](https://raw.githubusercontent.com/HyNetwork/hysteria/master/docs/bench/bench.png)

2、50mbps北方电信,北京出口 直连落地vir San Jose机房163线路，22-23点测试YT 1080p60直播流:

![image](https://cloud.imoeq.com/0:/normal/img/hihysteria/speed.png)

```
190 dropped of 131329
```

3、无对钟国大陆线路优化，洛杉矶shockhosting机房，1c128m ovznat 4k@p60：
![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/yt.jpg)
```
139783 Kbps
```
该项目仅作学习用途，请查看的访客在5s之内立即删除并停止使用。

由它所引起的任何问题，作者并不承担风险和任何法律责任。

因为脚本现处于0.x的测试版本，可能会有一些bug，如果遇到请发issue，欢迎star，您的⭐是我维护的动力。

适配ubuntu/debian, centos操作系统,misple/arm/x86架构。

windows使用请仔细阅读[cmd客户端(伪)介绍](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/cmd.md)其他平台看[这里](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/others.md)。


```
(2022/03/21) 0.3.0(此次改进较多):
1· 新增"菜单"功能，更新到0.3.0版本，后使用hihys命令即可调出菜单
2. 将依赖的安装集中到的脚本内，无需手动安装了，并且完善系统检测流程
3. 新增生成小火箭一键链接
4. 优化脚本提示，重写了部分代码，更加方便增加新的功能
5. 完善readme介绍部分，使之更加易懂，加入passwall的example图片
6. 加入"高级玩法(伪"，介绍一些别的玩法
7. 守护进程名称用hihys替代掉了hysteria
8. 取消了S5默认带密码的配置
```
[历史改进](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/log.md)

## 二·使用
### 第一次使用?

#### 1. [防火墙问题](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/firewall.md)

#### 2. [自签证书](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/certificate.md)


#### 3. [限制UDP的服务商排雷列表【2022/02/20更新】](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/blacklist.md)

#### 4. [hysteria各个协议介绍](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/protocol.md)

#### 5. [cmd客户端(伪)介绍](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/cmd.md)

#### 6. [部分其他平台？](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/others.md)

#### 7. [如何设置我的延迟、上行/下行速度？](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/speed.md)


### 拉取安装

```
su - root #Change to root
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### 配置过程
首次安装后: `hihys`命令调出菜单
```
-------------------------------------------
|**********      Hi Hysteria       **********|
|**********   Author: emptysuns  ************|
|**********     Version: 0.3.0     **********|
 -------------------------------------------

Tips:hihys 命令再次运行本脚本.
.............................................

####################
1)安装 hysteria

2)卸载 hysteria
####################
3)启动 hysteria

4)暂停 hysteria

5)重新启动 hysteria
####################
6)检测 hysteria运行状态

7)查看当前配置

8)重新安装/升级



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

The Latest hysteria version:v1.0.1
Download...

Download completed.

Update.wait...
Hit:1 <http://archive.ubuntu.com/ubuntu> bionic InRelease
Hit:2 <http://security.ubuntu.com/ubuntu> bionic-security InRelease
Hit:4 <http://archive.ubuntu.com/ubuntu> bionic-updates InRelease
Hit:5 <http://archive.ubuntu.com/ubuntu> bionic-backports InRelease
Hit:3 <https://packagecloud.io/ookla/speedtest-cli/ubuntu> bionic InRelease
Reading package lists... Done
Building dependency tree
Reading state information... Done
57 packages can be upgraded. Run 'apt list --upgradable' to see them.

Done.
Install wget curl netfilter-persistent
*wget
Reading package lists...
Building dependency tree...
Reading state information...
wget is already the newest version (1.19.4-1ubuntu2.2).
0 upgraded, 0 newly installed, 0 to remove and 57 not upgraded.
*curl
Reading package lists...
Building dependency tree...
Reading state information...
curl is already the newest version (7.58.0-2ubuntu3.16).
0 upgraded, 0 newly installed, 0 to remove and 57 not upgraded.
*netfilter-persistent
Reading package lists...
Building dependency tree...
Reading state information...
netfilter-persistent is already the newest version (1.0.4+nmu2ubuntu1.1).
0 upgraded, 0 newly installed, 0 to remove and 57 not upgraded.

Done.
开始配置:
请输入您的域名(不输入回车,则默认自签wechat.com证书,不推荐):

您选择自签wechat证书.公网ip:1.2.3.4

请输入你想要开启的端口,此端口是server端口,建议10000-65535.(默认随机)

随机端口:20882

选择协议类型:

1、udp(QUIC)
2、faketcp
3、wechat-video(回车默认)

输入序号:

传输协议:wechat-video

请输入您到此服务器的平均延迟,关系到转发速度(默认200,单位:ms):

delay:200 ms

期望速度,这是客户端的峰值速度,服务端默认不受限。Tips:脚本会自动*1.25做冗余，您期望过低或者过高会影响转发效率,请如实填写!
请输入客户端期望的下行速度:(默认50,单位:mbps):

客户端下行速度：50 mbps

请输入客户端期望的上行速度(默认10,单位:mbps):

客户端上行速度：50 mbps

请输入认证口令:

此选项不能省略,请重新输入!
请输入认证口令:

此选项不能省略,请重新输入!
请输入认证口令:
pekopeko

配置录入完成!

执行配置...
SIGN...

Signature ok
subject=C = CN, ST = GuangDong, L = ShenZhen, O = PonyMa, OU = Tecent, emailAddress = admin@qq.com, CN = Tencent Root CA
Getting CA Private Key
OK.

net.core.rmem_max = 8000000
Created symlink /etc/systemd/system/multi-user.target.wants/hihys.service -> /etc/systemd/system/hihys.service.

wait...

配置文件输出如下且已经在本目录生成(可自行复制粘贴到本地)

Tips:客户端默认只开启http(8888)、socks5(8889)代理!其他方式请参照文档自行修改客户端config.json
***********************************↓↓↓copy↓↓↓*******************************↓
{
"server": "1.2.3.4:20882",
"protocol": "wechat-video",
"up_mbps": 12,
"down_mbps": 62,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "pekopeko",
"server_name": "wechat.com",
"insecure": true,
"recv_window_conn": 6291456,
"recv_window": 25165824,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 3,
"retry_interval": 3
}
↑***********************************↑↑↑copy↑↑↑*******************************↑

Shadowrocket一键链接:
hysteria://1.2.3.4:20882?protocol=wechat-video&auth=pekopeko&peer=wechat.com&insecure=1&upmbps=12&downmbps=62&alpn=h3#Hys-1.2.3.4

安装完毕


root@dedicated:~# systemctl status hihys
* hysteria.service - hysteria:Hello World!
   Loaded: loaded (/etc/systemd/system/hysteria.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2022-01-10 04:17:23 EST; 15s ago
 Main PID: 29691 (hysteria)
    Tasks: 6 (limit: 1120)
   CGroup: /system.slice/hysteria.service
           `-29691 /etc/hihys/hysteria --log-level warn -c /etc/hihys/config.json server

Jan 10 04:17:23 dedicated systemd[1]: Started hysteria:Hello World!.

  </blockcode></pre>
</details>


## 三·高级玩法(伪

#### 1. [借用其他支持Socks5的GUI，来获得一个图形界面](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/gui.md)


## 四·结语

魔改UDP的QUIC协议，加了tls和混淆的话，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。

## 五·Todo
**如果您有好的功能建议，请不要忘记开个issue提出来欧～～～欢迎PR来完成Todo或者给我纠正我的渣代码。**
* [x] 检测端口是否被占用
* [ ] 利用xray s5 inbound来支持按域名分流(warp)
* [x] 生成分享链接
* [ ] 客户端自动更新
* [x] hihys替换掉hysteria
* [ ] 规范化脚本代码
* [ ] 利用docker安装?(不知道是否有必要)
* [ ] cmd客户端的“便捷性”优化...

## 六·鸣谢


[@HyNetwork/hysteria](https://github.com/HyNetwork/hysteria)


[@Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)


[@mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent)
