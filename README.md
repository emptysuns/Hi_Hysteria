# Hi Hysteria

## 一·简介
> Hysteria 是一个功能丰富的，专为恶劣网络环境进行优化的网络工具（双边加速），比如卫星网络、拥挤的公共 Wi-Fi、在**中国连接国外服务器**等。 基于修改版的 QUIC 协议。
by:[Hynetwork](https://github.com/HyNetwork)（Thank you!）

Hysteria这是一款由go编写的非常优秀的“轻量”代理程序，它很好的解决了在搭建富强魔法服务器时最大的痛点——**线路拉跨**。

在魔法咏唱时最难的不是搭建维护，而是在晚高峰时期的交付质量。~~当三大运营商晚高变成了：奠信、连不通、移不动时，你我都有感触。~~ 虽然是走的udp但是因为加了混淆使暂时不会被运营商针对性的QoS。

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



```
(2022/01/04 21:59) v0.2.5:
1、hysteria版本升级成了0.9.3，请重新下载"cmd客户端",version:0.2d
！
由于原项目使用github action编译带tun版本时，使用的最新的GLIBC_2.32
很多系统目前没有很好的支持，有依赖问题
所以我自己编译了一个，作为暂时的解决办法。
！
2、新增wechat视频通话流量伪装
3、readme中加入各个协议类型介绍
4、取消obfs选项支持（没必要开启它，当你的网络环境限制QUIC传输，可自行添加），大幅减小cpu的开销，提升速度
```

<details>
  <summary>历史改进</summary>
    <pre><blockcode> 
(2021/12/19 21:16) v0.2.4: 
1、hysteria版本升级成了0.9.1，请重新下载"cmd客户端",version:0.2c
2、增加faketcp模式配置，详情请查看：“使用前注意”条目
3、outbound被鸽了
4、客户端增加socks5（端口:8889）代理方式,user：pekora;password:pekopeko。可自行修改用户密码
5、增加自定义dns如8.8.8.8等，防止运营商dns劫持攻击

(2021/12/10 18:59) v0.2.3a: 
1、hysteria版本升级成了0.9.0,请重新下载"cmd客户端"，version:0.2b（注: 因为0.9.0新的特征ipv6_only开启后无法解析ipv4，可以等下个版本所支持的outbound特征，这里就不特意添加了
2、刷新了acl。

(2021/11/26 10:30) v0.2.3: 
1、alpn改成了h3(虽然没什么必要)
2、hysteria版本升级成了0.8.6请重新下载"cmd客户端?!"，version:0.2a

(2021/11/08 19:50) v0.2.2: 
1、整合自签/ACME
2、更改buffer计算方式提升速度
3、修复自签ipv6时多符号bug
4、增加随机端口功能
5、增加每一天自动重启服务端功能防止内存占用过大

(2021/11/06 21:16) v0.2.1: 
1、提供自签证书安装，为了有些ACME死活无法验证用户

(2021/10/05 18:36) v0.2: 
1、优化客户端(！？)结构
2、增加后台运行功能

(2021/10/04 16:19) v0.1: 
1、修复因dns污染无法代理的bug并增加去广告规则
2、增加arm和mipsle架构适配
3、增加客户端防呆
  </blockcode></pre>
</details>


## 二·使用
### 使用前须知
#### 防火墙问题：

请提前放行防火墙，保证该udp端口可达！

仅对于faketcp模式，则为放行server的tcp端口。

如果不使用自签方式，则应该放行TCP 80/443供hysteria内置的ACME验证。


### 安装依赖

```
# centos
sudo su root  #Change to the user root!
yum install -y wget curl
```

```
# debian/ubuntu
sudo su root  #Change to the user root!
apt-get install -y wget curl
```

### 拉取安装

```
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### 各协议介绍
#### 1、udp
可被识别为QUIC流量，直接使用最佳。

脚本0.2.5版本后不再默认加入`obfs`选项了，由于混淆的开销太大，会让cpu性能成为速度的瓶颈。

而且运营商不会单单限速QUIC的传输，长时间测试过程中未被限速过，所以取消掉`obfs`支持。

#### 2、faketcp:
hysteria v0.9.1 开始支持faketcp，将hysteria的UDP传输过程伪装成TCP，可以躲过运营商和“比较专业”的IDC服务商的QoS设备的对UDP的限速、阻断。

目前faketcp模式客户端只支持在linux类系统root用户内使用包括安卓，**windows无法使用**（但是可配合udp2raw伪装tcp代替）。

所以我的建议是：

**追求代理性能时不要开启它**。当下行速度一直被限制在例如128kB/s这种非常非常低的速率情况时，你确认被限制UDP后再重新安装后开启，它并不能"增速"，反而会增加cpu的开销，给hysteria“减速”。

**追求稳定性且能准备root权限使用环境时**。能开faketcp就开它。

#### 3、wechat-video

伪装成wechat的语音视频通话，可能会绕过少部分国内运营商对udp针对性限速？有待证实。

### 配置过程

<details>
  <summary>演示较长，点我查看</summary>
    <pre><blockcode> 
******************************************************************
 ██      ██                    ██                  ██          
░██     ░██  ██   ██          ░██                 ░░           
░██     ░██ ░░██ ██   ██████ ██████  █████  ██████ ██  ██████  
░██████████  ░░███   ██░░░░ ░░░██░  ██░░░██░░██░░█░██ ░░░░░░██ 
░██░░░░░░██   ░██   ░░█████   ░██  ░███████ ░██ ░ ░██  ███████ 
░██     ░██   ██     ░░░░░██  ░██  ░██░░░░  ░██   ░██ ██░░░░██ 
░██     ░██  ██      ██████   ░░██ ░░██████░███   ░██░░████████
░░      ░░  ░░      ░░░░░░     ░░   ░░░░░░ ░░░    ░░  ░░░░░░░░ 
Version: 0.2.4
Github: https://github.com/emptysuns/Hi_Hysteria
******************************************************************
Ready to install.
 
The hysteria latest version: v0.9.1. Download...

Download completed.

开始配置: 
请输入您的域名(不输入回车，则默认自签pan.baidu.com证书，不推荐):
a.com
是否启用faketcp,输入1启用,默认不启用(回车)：

传输协议:udp

请输入你想要开启的端口（此端口是server端口，请提前放行防火墙，建议10000-65535，回车随机）：

随机端口：29714

请输入您到此服务器的平均延迟,关系到转发速度（回车默认200ms）:
100

期望速度，请如实填写，这是客户端的峰值速度，服务端默认不受限。期望过低或者过高会影响转发速度！
请输入客户端期望的下行速度:(默认50mbps):
200
请输入客户端期望的上行速度(默认10mbps):
40
请输入混淆口令（相当于连接密钥）:
mikomiko

配置录入完成！

执行配置...
net.core.rmem_max=4000000
Created symlink /etc/systemd/system/multi-user.target.wants/hysteria.service → /etc/systemd/system/hysteria.service.
所有安装已经完成，配置文件输出如下且已经在本目录生成（可自行复制粘贴到本地）！


Tips:客户端默认只开启http(8888)、socks5代理(8889, user:pekora;password:pekopeko)!其他方式请参照文档自行修改客户端config.json
↓***********************************↓↓↓copy↓↓↓*******************************↓
{
"server": "a.com:29714",
"protocol": "udp",
"up_mbps": 40,
"down_mbps": 200,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false,
"user": "pekora",
"password": "pekopeko"
},
"alpn": "h3",
"acl": "acl/routes.acl",
"obfs": "mikomiko",
"auth_str": "pekopeko",
"server_name": "a.com",
"insecure": false,
"recv_window_conn": 10485760,
"recv_window": 41943040,
"resolver": "119.29.29.29:53",
"disable_mtu_discovery": false
}
↑***********************************↑↑↑copy↑↑↑*******************************↑
安装完毕

root@1:~# systemctl status hysteria
● hysteria.service - hysteria:Hello World!
   Loaded: loaded (/etc/systemd/system/hysteria.service; enabled; vendor preset: enabled)
   Active: active (running) since Sun 2021-12-19 15:01:35 CET; 13s ago
 Main PID: 31301 (hysteria)
    Tasks: 5 (limit: 4915)
   CGroup: /system.slice/hysteria.service
           └─31301 /etc/hysteria/hysteria --log-level warn -c /etc/hysteria/config.json server >> /etc/hysteria/warn.log

  </blockcode></pre>
</details>

### cmd客户端介绍

本项目只介绍如何在windows环境下使用，其他环境请参考[官方原文](https://github.com/HyNetwork/hysteria)。

因为暂时没有hysteria的图形界面，所以我用批处理写了一个简单的“客户端?!"，支持自动改代理和清除代理，实际使用没问题。
可自行到[release](https://github.com/emptysuns/Hi_Hysteria/releases)中下载最新版本。

欢迎其他开发者贡献新的UI或者插件。


当出现**安装完毕**字样后，**会自动打印生成的配置信息**，同时**当前目录**下会生成一个config.json文件。

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/result.png)

可以本地新建一个config.json（**一定要是这个名称！**）文件，复制粘贴到本地**conf**文件夹下，也可以直接下载生成的文件到本地**conf**文件夹下。


将config.json加入[**release**](https://github.com/emptysuns/Hi_Hysteria/releases)中提供的简单的windows cmd客户端的解压目录中.



![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/s1.png)

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/s2.png)


如果本地配置丢失?使用cat打印config.json后复制:

```
cat config.json

# cat config.json 
{
"server": "a.com:29714",
"protocol": "udp",
"up_mbps": 40,
"down_mbps": 200,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false,
"user": "pekora",
"password": "pekopeko"
},
"alpn": "h3",
"acl": "acl/routes.acl",
"obfs": "mikomiko",
"auth_str": "pekopeko",
"server_name": "a.com",
"insecure": false,
"recv_window_conn": 10485760,
"recv_window": 41943040,
"resolver": "119.29.29.29:53",
"disable_mtu_discovery": false
}


ctrl+c and +v.
```

### 客户端使用

提供两种运行方法：后台运行（无cmd窗口无感） 和 前台运行（必须得有cmd窗口，但是可查看当前日志）

**启动之前**请把config.json放到conf文件夹！



******************************************************************************
- 方法一：后台运行（推荐）

运行:双击back_start.bat

停止:双击back_stop.bat

运行back_start.bat后，可以回车关闭此窗口，不需保留。

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/tips.png)

停止后台运行：

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/back_stop.png)

批处理能力有限，请谅解.
******************************************************************************

- 方法二：前台运行

运行:双击run.bat

停止:回车，或者键入其他非'n'的字符


打开run.bat运行，运行时按回车键停止，防呆键入n继续运行

**直接键入Enter关闭客户端！**

**直接键入Enter关闭客户端！**

**直接键入Enter关闭客户端！**

**切记不要直接关闭cmd窗口！**

**切记不要直接关闭cmd窗口！**

**切记不要直接关闭cmd窗口！**

批处理能力有限，请谅解.

<center><font size=2>启动</font></center>

![image](https://cloud.iacg.cf/0:/normal/img/hihysteria/mark.png)

<center><font size=2>防呆/关闭</font></center>

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/stop.png)


**Tips:前台运行模式下，不小心关掉窗口导致无法上网时，运行back_stop.bat可以清除代理和关闭hysteria。**


******************************************************************************


### 客户端配置未生效？

如上图启动成功，但代理并未启用，请手动打开设置->网络->代理,查看配置是否生效

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/proxy.png)

### 配置开机自启

~~不会有人不知道吧:)~~

对back_start.bat(**后台模式**) 或者 run.bat(**前台模式**)文件创建一个**快捷方式**

win+r 键入
```
shell:startup
```
打开自启目录将快捷方式**复制**进去，下次开机就会自启动。

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/startup.png)
<center><font size=2>这里用后台做演示，前台同理</font></center>

## 三·服务端管理
- 重启

```
systemctl restart hysteria
```
- 停止

```
systemctl stop hysteria
```
- 状态

```
systemctl status hysteria -l
```

- 卸载

```
bash <(curl -fsSL https://git.io/rmhysteria.sh)
```
- 重新安装/升级
```
bash <(curl -fsSL https://git.io/rehysteria.sh)
```
## 四·结语

魔改UDP的QUIC协议，加了tls和混淆，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。
