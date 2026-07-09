# 一键安装(零交互)

`ver1.13` 新增。适合脚本化部署、批量开机、或者只想"能用就行"的场景：不问任何问题，直接装好一个安全可用的 Hysteria2 服务端。

## 用法

全新机器（连 hihy 都没装）：

```bash
bash <(curl -fsSL https://git.io/hysteria.sh) --auto
```

已安装 hihy：

```bash
hihy autoinstall   # 等价: hihy 16 / 菜单选项 16
```

## 默认配置

| 项目 | 默认值 |
|---|---|
| 端口 | 10001-65534 随机空闲 UDP 端口 |
| 认证密码 | 随机 UUID |
| 证书 | 自签(SNI: `www.bing.com`)，客户端通过 `pinSHA256` 指纹校验——**无需域名、无需放行 80 端口、不降低安全性** |
| 拥塞控制 | BBR (standard) |
| 伪装网站 | 不启用(Hysteria2 内置返回 404，与常见未配置站点表现一致) |
| 端口跳跃 | 不启用 |
| 混淆 | 不启用(兼容性最好) |

安装完成后自动打印/生成三种客户端配置(原生 Hysteria2、mihomo、sing-box)与分享链接二维码，与交互式安装一致。

## 环境变量定制

所有变量均可选；不设置即用上表默认值。

```bash
HIHY_AUTO_PORT=443 \
HIHY_AUTO_PASSWORD=my-secret \
HIHY_AUTO_DOMAIN=cdn.example.com \
hihy autoinstall
```

| 变量 | 说明 |
|---|---|
| `HIHY_AUTO_PORT` | 指定 UDP 端口(1-65535)。被占用时直接报错退出，不会静默换端口 |
| `HIHY_AUTO_PASSWORD` | 指定认证密码 |
| `HIHY_AUTO_DOMAIN` | 自签证书的 SNI 域名 |
| `HIHY_AUTO_IP` | 跳过公网 IP 自动探测，直接使用该地址(探测失败时也会提示设置它) |
| `HIHY_AUTO_MASQUERADE` | 设置为反代目标 URL(如 `https://news.ycombinator.com`)即启用 proxy 伪装 |
| `HIHY_AUTO_PORT_HOPPING` | `true` 启用端口跳跃(默认范围 47000-48000，固定 30s 间隔) |
| `HIHY_AUTO_HOP_START` / `HIHY_AUTO_HOP_END` | 自定义跳跃范围 |
| `HIHY_AUTO_REMARKS` | 客户端配置备注名(默认 `auto-<端口>`) |

bootstrap 阶段(`install.sh --auto`)还支持 `--lang=zh|en|fa|ru` 指定语言，缺省英文。

## 与交互式安装的关系

一键安装与向导安装共用同一套配置生成、校验(本机拉起内核实测)、防火墙与服务注册代码——只是把"问答"替换成"默认值 + 环境变量"。装完后仍可用 `hihy 9` 重新进入交互式配置调整任意选项。
