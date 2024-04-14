## 生成hysteria的代理直连规则+反广告

由于直接用网段判断代理时，dns污染后返回的ip也属于大陆ip，会导致无法代理，所以加入域名列表，顺手加上antiAD

规则转化至长期维护的clash规则: [@Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)

```
#生成routes.acl + 获得geoip Country.mmdb
>python3 GetRoutes.py

July 07, 2022,Loading...

Block rules: 53337 done.
Direct rules: 66789 done.
Proxy rules: 31924 done.

All rules: 152050

Hi
Generate completed!
```
