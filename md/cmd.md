# `0.3.7`之后停止更新 !!!
### cmd客户端介绍

本项目只介绍如何在windows环境下使用，其他环境请参考[这里](https://github.com/HyNetwork/hysteria)。

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
# cat config.json 
{
"server": "1.2.3.4:57582",
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
"mmdb": "acl/Country.mmdb",
"ca": "ca/wechat.com.ca.crt",
"auth_str": "pekora",
"server_name": "wechat.com",
"insecure": false,
"recv_window_conn": 10485760,
"recv_window": 41943040,
"resolver": "119.29.29.29:53",
"retry": 5,
"retry_interval": 3
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