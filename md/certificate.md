#### hysteria自签证书

自签证书时的**允许不安全连接**时会有MIMT(Man-in-the-middle attack, 中间人攻击)风险。现在脚本默认情况下允许不安全连接(~~我反正觉得被攻击的概率极小，自己判断吧~~

对于cmd“客户端”来说，在使用自签证书时，而且希望和正常证书一样安全时，请参考:

1. 手动复制server 自签的CA`/etc/hysteria/wechat.com.ca.crt`到cmd客户端的`ca/`文件夹下

2. 修改config.json `"insecure": true`为`false`

3. 在config.json中增加`ca`选项`"ca": "ca/wechat.com.ca.crt",`
4. 重新运行