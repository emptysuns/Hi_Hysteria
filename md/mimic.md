# Mimic（伪装 TCP）

`ver1.17` 新增，需要 Hysteria2 内核 **v2.12.0 及以上**。

## 这是什么

Mimic 是 [hack3ric/mimic](https://github.com/hack3ric/mimic) 项目，用 eBPF 在数据链路层把 UDP 包改写成 TCP 外观，适合限制/封锁 UDP 的网络。Hysteria2 配置里的 `mimic.enabled: true` 只是告诉内核启用伪装，实际伪装工作全部由 mimic 程序完成。

## 安装：服务端自动，客户端手动

**服务端：脚本自动下载安装。** 启用 Mimic 时，脚本会从 [hack3ric/mimic](https://github.com/hack3ric/mimic) 官方 release 自动下载并安装（程序 + 内核模块），无需手动操作。

**客户端：需手动安装。** mimic 与 hysteria 是两个独立项目，客户端机器（如软路由）上的 mimic 需自行安装：

- **安装方法**请参阅 mimic 自己的 Getting Started 文档：https://github.com/hack3ric/mimic/blob/master/docs/getting-started.md
- **完整的命令行说明**请参阅 mimic(1)：https://github.com/hack3ric/mimic/blob/master/docs/mimic.1.md
- Hysteria 官方文档：https://hysteria.network/zh/docs/advanced/Mimic/

要点（详见 Getting Started）：

- 内核 **Linux ≥ 6.1**（需要 BPF dynptrs），多数发行版默认开启相关选项，一般开箱即用
- 发行版包自带 systemd 服务与 DKMS 内核模块：装好后 `modprobe mimic` 即可用
- **用 Hysteria 时不需要手动配置 mimic**（不需要 systemd 服务、不需要 `/etc/mimic/*.conf`、不需要手动 `mimic run`）——hysteria 检测到 `mimic.enabled: true` 后会**自动启动并管理 mimic**，你只需保证程序在 PATH、模块已加载、hysteria 以 root 运行
- Getting Started 里那套 `systemctl start mimic@eth0` / `mimic run -f ...` 是给独立使用 mimic 的场景（如 WireGuard），与 Hysteria 无关

## 脚本会帮你做什么

服务端启用 Mimic 时，脚本会自动完成整个安装流程：

1. **自动下载**：从官方 release 下载 mimic 安装包（amd64/arm64），带 sha256 校验
2. **自动安装**：Debian/Ubuntu 用 apt 整装（自动拉取 dkms/内核头文件依赖并编译）；其他发行版解包静态二进制到 `/usr/sbin/mimic`，有 dkms 则自动编译内核模块
3. 执行 `modprobe mimic` 加载内核模块，并写入 `/etc/modules-load.d/mimic.conf` 配置**开机自启**
4. **失败自动回退**：下载/编译任一步失败（如内核 < 6.1、架构不支持、缺编译环境）→ 不写入 mimic 配置、服务照常启动，并提示原因；修复后 `hihy 9` 重新配置即可

如果之前已手动装好 mimic 且模块可用，脚本会直接复用，不重复下载。
## 怎么开

**交互安装**：向导在混淆之后询问「是否启用 Mimic」，选 `2` 启用（会自动跳过端口跳跃）。

**一键安装**：

```bash
HIHY_AUTO_MIMIC=true hihy autoinstall
```

**已装机器**：`hihy 9` 重新配置即可。

启用时脚本会：自动下载安装 mimic 并加载内核模块（见上节）、服务端/原生客户端配置写入 `mimic.enabled: true`、跳过端口跳跃（二者互斥）、跳过 mihomo/sing-box 配置生成（它们不支持 mimic）。

## 注意事项

- **两端都必须启用 mimic**，且都装好 mimic 程序 + 内核模块；未启用的一侧收不到任何响应（看起来像网络故障）
- 客户端必须是 **Linux + root**（如软路由）；Windows/macOS/手机无法使用
- **架构限制**：官方 release 仅提供 amd64/arm64 包，其他架构无法自动安装，需按 Getting Started 从源码自行编译
- 防火墙需同时放行 TCP 和 UDP（TC eBPF 在 netfilter 之后仍显示为 UDP，XDP 控制包是真实 TCP）
- 部分网卡驱动（如 Intel i225/igc）XDP native 模式可能丢包，可在配置中指定 `xdp_mode = skb`
- 内核低于 v2.12.0 时脚本自动跳过 mimic 并提示：先 `hihy 7` 更新内核，再 `hihy 9` 重新配置

## 参考

- [mimic Getting Started（安装方法）](https://github.com/hack3ric/mimic/blob/master/docs/getting-started.md)
- [mimic(1)（命令行说明）](https://github.com/hack3ric/mimic/blob/master/docs/mimic.1.md)
- [Hysteria 官方 Mimic 文档](https://hysteria.network/zh/docs/advanced/Mimic/)
