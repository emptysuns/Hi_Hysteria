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

这是一款我在闲暇时为了方便自己而写的快速使用脚本，该项目仅作学习用途，请查看的访客在5s之内立即删除并停止使用。

由它所引起的任何问题，作者并不不承担风险和任何法律责任。

因为脚本现处于0.x的测试版本，可能会有一些bug，如果遇到请发issue，欢迎star.


```
(2021/10/04 16:19)v0.1:修复因dns污染无法代理的bug并增加去广告规则、增加arm和mipsle架构适配、增加客户端防呆
```


## 二·使用
- 安装依赖

```
# centos
yum install -y wget curl
```

```
# debian/ubuntu
apt-get install -y wget curl
```

- 拉取安装

```
sudo su root  #Change to the user root!
sh <(curl -fsSL https://git.io/hysteria.sh)
```
- 配置过程

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
- 客户端使用

本项目只介绍如何在windows环境下使用，其他环境请参考[官方原文](https://github.com/HyNetwork/hysteria)。

因为暂时没有hysteria的图形界面，所以我用批处理写了一个简单的“客户端”，支持自动改代理和清除代理，实际使用没问题，**注意在运行时不要关闭cmd端口**。欢迎其他开发者贡献新的UI或者插件。


当出现**安装完毕**字样后，当前目录下会生成一个config.json文件，
将这个文件下载下来并加入[**release**](https://github.com/emptysuns/Hi_Hysteria/releases/download/0.1/hihysteria_windows0.1.rar)中提供的简单的windows cmd客户端.

保证这个config.json文件和如下几个文件是同目录的，如下图（**请保证这五个文件同目录**）：

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/dir.png)



如果无法直接下载用cat打印文本后复制，在如上文件夹新建一个config.json（**一定要是这个名称！**）:

```
cat /root/config.json

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


ctrl+c and +v. 保证目录结构如上图！
```

运行run.bat启动

![image](https://cloud.iacg.cf/0:/normal/img/hihysteria/mark.png)

- 客户端配置未生效？

如上图启动成功，但代理并未启用，请手动打开设置->网络->代理,查看配置是否生效

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/proxy.png)

- 客户端停止代理

有防呆功能，关闭请在运行的该cmd窗口下：

**直接键入Enter关闭客户端！**

**直接键入Enter关闭客户端！**

**直接键入Enter关闭客户端！**

**切记不要直接关闭cmd窗口！**

**切记不要直接关闭cmd窗口！**

**切记不要直接关闭cmd窗口！**


直接关闭后会导致hysteria的程序无法停止并且代理功能并不能关闭！

批处理脚本能处理的功能有限请谅解...欢迎提供更好的解决方案

![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/stop.png)

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

走udp的quic协议，加了tls和混淆，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。
