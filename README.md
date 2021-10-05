# Hi Hysteria

## 一·简介
> Hysteria 是一个功能丰富的，专为恶劣网络环境进行优化的网络工具（双边加速），比如卫星网络、拥挤的公共 Wi-Fi、在**中国连接国外服务器**等。 基于修改版的 QUIC 协议。
by:[Hynetwork](https://github.com/HyNetwork)（Thank you!）

Hysteria这是一款由go编写的非常优秀的“轻量”代理程序并且支持acme验证，它很好的解决了，在搭建代理服务器时最大的痛点--**线路垃圾**。在魔法咏唱时最难的不是搭建维护，而是在晚高峰时期的交付质量。~~当三大运营商晚高变成了：奠信、连不通、移不动时，你我都有感触。~~ 虽然是走的udp但是因为加了混淆使暂时不会被运营商qos。

项目作者提供的速度测试:

![image](https://raw.githubusercontent.com/HyNetwork/hysteria/master/docs/bench/bench.png)

50mbps北方电信,北京出口 直连落地vir San Jose机房163线路，22-23点测试YT 1080p60直播流:

![image](https://cloud.iacg.cf/0:/normal/img/hihysteria/speed.png)

```
190 dropped of 131329
```

该项目仅作学习用途，请查看的访客在5s之内立即删除并停止使用。

由它所引起的任何问题，作者并不不承担风险和任何法律责任。

因为脚本现处于0.x的测试版本，可能会有一些bug，如果遇到请发issue，欢迎star.


```
(2021/10/05 18:36)v0.2:优化客户端(！？)结构，增加后台运行功能

(2021/10/04 16:19)v0.1:修复因dns污染无法代理的bug并增加去广告规则、增加arm和mipsle架构适配、增加客户端防呆
```


## 二·使用
### 安装依赖

```
# centos
yum install -y wget curl
```

```
# debian/ubuntu
apt-get install -y wget curl
```

### 拉取安装

```
sudo su root  #Change to the user root!
sh <(curl -fsSL https://git.io/hysteria.sh)
```
### 配置过程

```
开始配置: 
请输入您的域名(必须是存在的域名，并且解析到此ip):
a.com
请输入你想要开启的端口（此端口是server的开启端口10000-65535）：
12345
期望速度，请如实填写，这是客户端的峰值速度，服务端默认不受限。期望过低或者过高会影响转发速度！
请输入客户端期望的下行速度:
50
请输入客户端期望的上行速度:
10
请输入混淆口令（相当于连接密钥）:
pekora
```
### cmd客户端介绍

本项目只介绍如何在windows环境下使用，其他环境请参考[官方原文](https://github.com/HyNetwork/hysteria)。

因为暂时没有hysteria的图形界面，所以我用批处理写了一个简单的“[客户端](https://github.com/emptysuns/Hi_Hysteria/releases/download/0.2/hihysteria_windows0.2.rar)”，支持自动改代理和清除代理，实际使用没问题，**注意在运行时不要关闭cmd端口**。
可自行到[release](https://github.com/emptysuns/Hi_Hysteria/releases)中下载最新版本。

欢迎其他开发者贡献新的UI或者插件。


当出现**安装完毕**字样后，**会自动打印生成的配置信息**，同时**当前目录**下会生成一个config.json文件。

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/result.png)

可以本地新建一个config.json（**一定要是这个名称！**）文件，复制粘贴到本地**conf**文件夹下，也可以直接下载生成的文件到本地**conf**文件夹下。


将config.json加入[**release**](https://github.com/emptysuns/Hi_Hysteria/releases/download/0.2/hihysteria_windows0.2.rar)中提供的简单的windows cmd客户端的解压目录中.



![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/s1.png)

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/s2.png)


如果本地配置丢失?使用cat打印config.json后复制:

```
cat config.json

# cat config.json 
{
"server": "a.com:12345",
"up_mbps": 10,
"down_mbps": 50,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"acl": "chnroutes.acl",
"obfs": "pekora",
"auth_str": "pekopeko",
"server_name": "a.com",
"insecure": false,
"recv_window_conn": 15728640,
"recv_window": 67108864,
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
sh <(curl -fsSL https://git.io/rmhysteria.sh)
```
- 重新安装/升级
```
sh <(curl -fsSL https://git.io/rehysteria.sh)
```
## 四·结语

走UDP的QUIC协议，加了tls和混淆，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。
