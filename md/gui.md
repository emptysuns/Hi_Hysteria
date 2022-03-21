#### 借用其他支持Socks5的GUI，来获得一个图形界面

hysteria支持socks5 来入栈，而现在几乎所有主流的代理软件的UI都支持导入socks5链接来使用，例如v2rayN,clash,qv2ray,winxray等等。


其实这种方法很笨拙，之前本以为会很快诞生一款服务于hysteria的图形界面，所以当时写cmd客户端的时候都设计用来度过这个过渡时期，没怎么注意它的可用性。

导致它现在有很多问题待解决(不人性化，多个配置文件时不方便切换等等)，但是贯彻“**能用就行**”的基本精神，鸽到了现在，以后也要无限期鸽下去～～～

**没想到它能用这么久...UI带佬们努努力啊**。


所以我们这里可以"鸠占鹊巢"的抢占掉原来图形界面的他们的本来的“地盘”，使它们为hysteria服务。

这里用 **v2rayN + hihysteria_cmd**举例子，其他同理（hihysteria cmd使用介绍看[**这里**](https://github.com/emptysuns/Hi_Hysteria/blob/main/md/cmd.md)）:


1. 使用hihysteria cmd客户端，测试`run.bat`运行成功,能正常使用hysteria进行代理。
![image](https://cloud.imoeq.com/0:/normal/img/hihysteria/mark.png)

2. 回车关闭`前台运行模式`，双击`back_start.bat`启动后台运行模式。

3. 启动V2rayN。

    这里需要注意，**是先运行cmd的back_start.bat，再开启V2rayN**，因
    V2rayN会修改系统代理，`back_start.bat`也会，如果改在V2rayN之后启动，将会使V2rayN被cmd客户端修改的地址给顶替掉，无法接管系统的http代理,注意如下图的端口地址是被V2rayN所接管的,而不是hysteria的`8888`。

    ![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/proxy.png)

    如果是`8888`则再点一次`自动配置系统代理`就行了

    ![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/changeProxy.png)

    
    这终究之一种另类的玩法，就不单单为这个做优化了，如果希望长期使用"**鸠占鹊巢**"，可以自己修改`back_start.sh` and `back_stop.sh`，删掉如下所有发生修改的注册表项，让cmd客户端不再自动配置系统http代理。
    ```
        REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
        REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect /t REG_DWORD /f /D 0
        REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /d "127.0.0.1:8888" /f
        REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*" /f
    ```
4. 按如下图导入socks5链接:
   
   ![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/s5.png)
5. 完成，验证结果
   
   ![image](https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/main/imgs/v2rayN.png)


##### 结尾
clash等其他代理的UI都会支持S5链接的，这里就不做介绍了，玩的开心～
