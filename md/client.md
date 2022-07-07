# 支持的客户端

## 1. Clash.Meta[推荐]

### 介绍
[clash.meta](https://github.com/MetaCubeX/Clash.Meta/releases/tag/Prerelease-Alpha) 继承了clash的所有特点，所以clash能用的GUI，它全部可以使用，包括openclash、clash verge等等。

推荐使用[Alpha](https://github.com/MetaCubeX/Clash.Meta/releases/tag/Prerelease-Alpha)分支，同步最新代码。

更多支持clash.meta的客户端参考[这里](https://docs.metacubex.one/used)，hihy提供打包好的clash.verge 请在release查看, android端[查看](https://github.com/MetaCubeX/ClashMetaForAndroid/releases/tag/Prerelease-alpha)。

### 优点
它有许多hysteria core无法完成但是必要的功能。比如:
1. `type: url-test`可以自动根据httping选择节点
2. 而且得益于`rule-providers`这个clash配置项，用户不需要手动更新分流规则，每次连接都会自动更新，能做到完全无感。
3. 使用doh dot增加安全性，也能单独为dns配置节点
4. fallback 测试节点可用性并自动切换、负载均衡
5. GUI全平台都有很好的支持
6. 流媒体分流
7. .....

### 使用
hihy不支持生成clash.meta url导入远程配置文件，主要是考虑到安全问题，防止节点信息泄露，**需要用户复制粘贴到客户端自己本地文件，导入配置**

这里用clash_verge 为例,随意创建一个文件夹用来保存metaHys.yaml:
![image](../imgs/verge1.png)
![image](../imgs/verge2.png)

**测试**
![image](../imgs/verge3.png)
![image](../imgs/verge4.png)

clash.meta可以同时配置支持vless、ss2022、trojan等等多配置，不过hihy目前不支持，没好的想法，更多配置请参考[DOC](https://docs.metacubex.one/example/ex1)。

目前许多优秀的特点hihy输出的配置文件没有支持，尽情期待 ～d=v=b～

## 2. v2rayN

v2rayN已经在添加自定义配置时支持hysteria并能自动识别config的类型，hihy在`0.3.7`版本之后兼容v2rayN，hihy_cmd已经需要退出舞台了，**不会再对它进行维护**。

我将如何使用呢?你可以直接下载我打包好的[v2rayN-hysteriaCore](../client/windows/v2rayN/v2rayN-hysteriaCore.rar)，可忽略下方的配置v2n过程。

1. [点我下载](https://github.com/2dust/v2rayN/releases/latest/download/v2rayN.zip)最新的v2rayN，并解压。

2. [点我下载](https://github.com/HyNetwork/hysteria/releases/latest/download/hysteria-tun-windows-6.0-amd64.exe)hysteria最新版本的Core，修改名称为`hysteria.exe`,将它放到v2rayN的根目录里。
3. 使用提供的[脚本](https://github.com/emptysuns/Hi_Hysteria/tree/main/acl)生成acl文件和Country.mmdb文件,在v2rayN根目录创建一个新的文件夹名称为`acl`并将这两个文件放到这个目录里。
4. 开始使用时需要得到hihy生成的config.json配置文件，v2rayN选择这个文件，双击选择此节点。如下图:

* **保证有core和acl文件**
![image](../imgs/v2ndir.png)
![image](../imgs/v2nacldir.png)
* **配置v2rayN hysteria**
![image](../imgs/v2n1.png)
![image](../imgs/v2n2.png)
![image](../imgs/v2n3.png)
![image](../imgs/v2n4.png)
![image](../imgs/v2n5.png)
![image](../imgs/v2n6.png)
* **看到下图则说明代理正常运行v2rayN hysteria**
![image](../imgs/v2n7.png)
* **从服务器下载的config.json可以删掉，v2rayN会自动在目录创建文件夹用来保存这些自定义配置文件**
![image](../imgs/v2n8.png)

5. **Hello World！**



## 3. sagernet [android]
  可通过一键链接导入。

  安装hysteria-plugin并**允许该插件被其他应用启动**，否则提示启动失败（tips: sagernet支持直接剪切板导入hysteria的json文本）

## 4. openwrt passwall
只能在编译固件时加进去，请op刷到最新版本,才会支持hysteria，对应config.json看下面
![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/passwall.png)

## 5. openclash
待补充或者请您提交pr

## 6. nekoray
待补充或者请您提交pr

## 7. shadowrocket
没有IOS，请提交pr此项

## 8. [~~hihy_cmd~~](cmd.md)
**停止更新**
