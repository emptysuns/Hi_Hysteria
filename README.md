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

**如果您有好的功能建议，请不要忘记开个issue提出来欧～～～**

```
(2022/02/20 17:26) v0.2.9:（旧客户端不兼容新服务端，建议一起更新）
1、hysteria->1.0.1 hi_hysteria_cmd 0.2h，跳过1.0.0版本，s5出栈有bug
1.0.1版本新增udp大包的分片和重组，效率进一步增强
新的s5 outbound可配合warp或者xray进行分流，但目前没好的想法，先鸽了。
2、新增自动放行防火墙
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

### 安装依赖

```
# centos
sudo su root  #Change to the user root!
yum install -y wget curl netfilter-persistent
```

```
# debian/ubuntu
sudo su root  #Change to the user root!
apt-get install -y wget curl netfilter-persistent
```

### 拉取安装

```
bash <(curl -fsSL https://git.io/hysteria.sh)
```

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
Version: 0.2.9
Github: https://github.com/emptysuns/Hi_Hysteria
******************************************************************
Ready to install.

The Latest hysteria version: v1.0.1. Download...

Download completed.

开始配置:
请输入您的域名(不输入回车，则默认自签wechat.com证书，不推荐):

您的公网ip为:1.2.3.4

请输入你想要开启的端口（此端口是server端口，请提前放行防火墙，建议10000-65535，回车随机）：

随机端口：50294

选择协议类型:

1、udp(QUIC)
2、faketcp
3、wechat-video(回车默认)

输入序号:
3
传输协议:wechat-video

请输入您到此服务器的平均延迟,关系到转发速度（回车默认200ms）:
180

期望速度，请如实填写，这是客户端的峰值速度，服务端默认不受限。期望过低或者过高会影响转发速度！
请输入客户端期望的下行速度:(默认50mbps):
200
请输入客户端期望的上行速度(默认10mbps):
40
请输入认证口令:
pekomiko

配置录入完成！

执行配置...
SIGN...
OK.

net.core.rmem_max = 4000000
Created symlink /etc/systemd/system/multi-user.target.wants/hysteria.service → /etc/systemd/system/hysteria.service.

wait...

所有安装已经完成，配置文件输出如下且已经在本目录生成（可自行复制粘贴到本地）！

Tips:客户端默认只开启http(8888)、socks5(8889, user:pekora;password:pekopeko)代理!其他方式请参照文档自行修改客户端config.json
↓***********************************↓↓↓copy↓↓↓*******************************↓
{
"server": "1.2.3.4:50294",
"protocol": "wechat-video",
"up_mbps": 50,
"down_mbps": 250,
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
"mmdb": "acl/Country.mmdb",
"auth_str": "pekomiko",
"server_name": "wechat.com",
"insecure": true,
"recv_window_conn": 23592960,
"recv_window": 94371840,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 5,
"retry_interval": 3
}
↑***********************************↑↑↑copy↑↑↑*******************************↑
安装完毕


root@dedicated:~# systemctl status hysteria
* hysteria.service - hysteria:Hello World!
   Loaded: loaded (/etc/systemd/system/hysteria.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2022-01-10 04:17:23 EST; 15s ago
 Main PID: 29691 (hysteria)
    Tasks: 6 (limit: 1120)
   CGroup: /system.slice/hysteria.service
           `-29691 /etc/hysteria/hysteria --log-level warn -c /etc/hysteria/config.json server

Jan 10 04:17:23 dedicated systemd[1]: Started hysteria:Hello World!.

  </blockcode></pre>
</details>


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

魔改UDP的QUIC协议，加了tls和混淆的话，个人跑了一段时间大流量，未被运营商QoS，落地ip并没有被墙，也不知道什么时候被针对，大家且用且珍惜吧。

## 五·鸣谢


[@HyNetwork/hysteria](https://github.com/HyNetwork/hysteria)


[@Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)
