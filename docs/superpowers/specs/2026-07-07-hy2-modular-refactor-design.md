# Hi Hysteria 模块化重构 + i18n + 多内核客户端配置 设计文档

日期:2026-07-07
状态:已与维护者逐节评审通过
分支策略:基于 `main`,合并 `feature/i18n-support`,完成后推送 `main`

## 1. 背景与目标

`server/hy2.sh` 已增长到 3859 行、约 80 个函数,单文件维护成本高。本次重构目标:

1. **模块化**:按功能拆分源码,提高可维护性,同时**分发形态保持单文件**(硬性兼容约束)
2. **i18n**:并入 `feature/i18n-support` 分支成果(纯 bash JSON loader + en/zh/fa/ru 四语言目录)
3. **客户端配置**:修复 Clash.Meta 配置错误并改名 mihomo;新增 sing-box 客户端配置输出
4. **发布**:版本 ver1.11 → ver1.12,分阶段 commit,推送 main

## 2. 硬性兼容约束(全部必须满足)

| 约束 | 原因 |
|------|------|
| `server/install.sh` 文件名/路径不变 | `bash <(curl -fsSL https://git.io/hysteria.sh)` 短链指向它 |
| `server/hy2.sh` 必须始终是**完整可直接运行的单文件** | 存量用户(ver1.09~1.11)"更新hihy"从 `refs/heads/main/server/hy2.sh` 下载单文件覆盖 `/usr/bin/hihy`;jsdelivr 镜像同理 |
| `/etc/hihy/` 目录结构不变、`backup.yaml` 字段只增不改 | 存量安装升级后需继续可读 |
| `hihy <N>` 数字快捷命令与菜单序号不变 | 用户习惯 + README 文档 |
| 现有测试继续 `source server/hy2.sh` 可用 | 测试以最终产物为对象 |

## 3. 架构:仓库内模块化 + 构建期组装(方案 A)

### 3.1 目录布局

```
server/
├── src/                     # 开发时编辑这里
│   ├── 00-header.sh         # shebang、hihyV、全局 HIHY_* 环境变量、I18N schema 常量
│   ├── 10-i18n.sh           # i18n loader(来自分支):i18n/i18nLookup/loadPersistedLanguage/refreshI18nFile 等
│   ├── 15-ui.sh             # echoColor、countdown、generate_qr、show_menu、wait_for_continue
│   ├── 20-net-yaml.sh       # downloadToFile、fetchRemote*FromSources、addOrUpdateYaml、getYamlValue、getListen*、generate_uuid
│   ├── 25-system.sh         # getArchitecture、detectVirtualization、checkSystemForUpdate、getStartCommand、cronTask
│   ├── 30-version.sh        # 版本检查缓存全套(state/lock/TTL/通知)
│   ├── 35-state.sh          # classifyInstallState、recoverPartialInstallState、markInstallFailed、getBackupValueOrDefault
│   ├── 40-cert.sh           # 四种证书方式子流程(从 wizard 抽出)
│   ├── 45-wizard.sh         # setHysteriaConfig 拆为 wizardStep* 每步一函数 + 服务端 config.yaml 生成
│   ├── 50-core.sh           # downloadHysteriaCore、updateHysteriaCore、getLatest*Version、startInstallValidationProcess
│   ├── 55-service.sh        # OpenRC/rc.d 服务脚本生成、setup_rc_local_for_arch、start/stop/restart/status/checkLogs
│   ├── 60-firewall.sh       # allowPort、delHihyFirewallPort、cleanupHysteria2Iptables、checkUFW/firewalld
│   ├── 65-lifecycle.sh      # install()、uninstall()、checkRoot、killHysteriaProcess、installHihyLauncher
│   ├── 70-client-common.sh  # loadClientParams():一次性读取 backup/config 全部参数(见 5.4)
│   ├── 72-client-native.sh  # generate_client_config:原生 yaml + hy2:// 分享链接 + 输出编排
│   ├── 74-client-mihomo.sh  # generateMihomoYaml(修复后)
│   ├── 76-client-singbox.sh # generateSingboxJson(新增)
│   ├── 80-stats.sh          # getHysteriaTrafic、format_bytes、format_time_display
│   ├── 85-actions.sh        # changeServerConfig、changeIp64、aclControl、addSocks5Outbound、hihyUpdate、更新通知
│   └── 90-main.sh           # menu()、`if BASH_SOURCE == $0` CLI 分发(必须最后)
├── i18n/{en,zh,fa,ru}.json  # 四语言目录(分支成果,运行时下载,不嵌入产物)
├── hy2.sh                   # ⚙️ 构建产物,提交入库
└── install.sh               # 名字不变;并入分支的语言选择逻辑
scripts/
├── build.sh                 # 组装脚本
├── i18n-extract.sh          # 分支已有
└── i18n-validate.sh         # 分支已有,本次增强(见 4.4)
```

### 3.2 构建机制(scripts/build.sh)

- 按文件名数字前缀顺序拼接 `src/*.sh` → `server/hy2.sh`
- 剥离各模块首行 shebang,产物只保留 `00-header.sh` 的 shebang
- 产物头部插入固定注释:`# GENERATED FILE — DO NOT EDIT. Edit server/src/ and run scripts/build.sh`
- **产物必须可复现**:不嵌入时间戳/commit hash(否则产物新鲜度测试无法做字节比对)
- 组装后执行 `bash -n` 语法检查;若安装了 shellcheck 则运行并输出报告(不作为失败门槛,仅修复明确错误项)

### 3.3 防脱节机制

- `server/test_build.sh`:重新构建后 `git diff --exit-code server/hy2.sh`,不一致即失败
- 产物文件头 GENERATED 注释作为人工防线

### 3.4 语言包分发

语言包**不嵌入产物**(维护者决策):`server/i18n/*.json` 留在仓库,运行时下载到 `/etc/hihy/i18n/`,schema 不匹配时静默刷新、回退英文。改进一点:分支的 `refreshI18nFile` 目前仅从 GitHub raw 下载,本次改为复用既有的 `fetchRemoteBodyFromSources`(GitHub + jsdelivr 双源),与项目镜像策略一致。

## 4. i18n 并入

### 4.1 合并顺序(关键)

**先 `git merge feature/i18n-support` 进 main,再模块化拆分。** 分支仅落后 main 2 个提交(c224312 防火墙规则、710c256 卸载清理),冲突集中在 uninstall/防火墙函数区域;解决原则:**以 main 的逻辑为准,为这些区域的字符串补 i18n key**。若先拆分后合并,分支 1172 行字符串迁移将全部冲突作废。

### 4.2 模块归属

loader 函数组 → `src/10-i18n.sh`;`install.sh` 的语言选择/下载逻辑保留(分支已实现)。

### 4.3 默认语言策略

优先级:`HIHY_LANG` 环境变量 > `/etc/hihy/conf/i18n.conf` 持久化 > **系统 `$LANG` 自动检测**(`zh*`→zh、`fa*`→fa、`ru*`→ru、其余→en)> `en`。

> 分支现状是无配置直接默认 en,会让存量中文用户更新后界面突变英文;`$LANG` 检测层修复此问题。

### 4.4 校验增强(scripts/i18n-validate.sh)

1. 四语言目录 key 集合一致性(缺失/多余 key 报错)
2. **printf 占位符一致性**:同一 key 在各语言中 `%s`/`%d` 数量与顺序必须一致(模板直接喂 printf,错位即运行时故障)

### 4.5 新增字符串

本次新增的所有用户可见文案(mihomo/sing-box 输出、构建提示、realm 提示等)一律走 i18n key,四语言目录同步补齐。

## 5. 客户端配置生成

### 5.1 文件命名与函数改名

| 旧 | 新 |
|----|----|
| `Hy2-${remarks}-ClashMeta.yaml` / `generateMetaYaml` | `Hy2-${remarks}-mihomo.yaml` / `generateMihomoYaml` |
| (无) | `Hy2-${remarks}-singbox.json` / `generateSingboxJson` |

输出文案中 "ClashMeta" 统一改为 "mihomo",客户端举例更新(Clash Verge Rev、FlClash、ClashMeta for Android、openclash 等)。

### 5.2 mihomo 修复清单(对照 wiki.metacubex.one)

| # | 问题 | 修复 |
|---|------|------|
| 1 | 无论拥塞模式选择,始终输出 `up`/`down`,强制 Brutal | 仅 brutal 输出 `up`/`down`;BBR/Reno **省略两字段**(mihomo 语义:缺省即 BBR) |
| 2 | gecko 混淆时输出 `obfs: gecko`,mihomo 仅支持 salamander | gecko 时**跳过生成 mihomo 配置文件**并提示"mihomo 不支持 gecko 混淆,请使用原生配置或 sing-box"(只删 obfs 字段会产生无法连接的假配置,比不生成更糟) |
| 3 | BBR profile 丢失 | congestion==bbr 时输出 `bbr-profile: <standard|conservative|aggressive>` |
| 4 | 端口跳跃缺 `hop-interval` | fixed 模式输出秒数;random 模式输出 `min-max` 区间语法(文档支持) |
| 5 | Realm 模式直接跳过 mihomo 配置 | 生成 `realm-opts`(enable/server-url/token/realm-id/stun-servers,由 realm URI 解析,见 5.5);文档示例保留顶层 `server`/`port`,按文档示例生成,**实现时用真实 mihomo 内核验证行为后定稿** |
| 6 | 规则含 `GEOIP,LAN`(疑似非法) | 实现时核实;倾向删除(`RULE-SET,lancidr` 已覆盖)或改 `GEOIP,private` |

保留项(经文档核对正确):`fingerprint`(cert SHA256 指纹)、`skip-cert-verify`、`sni`、`ports`(跳跃区间)、`password`。
DNS 块本次不改 enhanced-mode(redir-host 仍是合法默认值,fake-ip 切换属行为变化,超出范围)。

### 5.3 sing-box 配置(对照 sing-box.sagernet.org,基线 1.11+)

**整体结构**(维护者选择"完整配置+分流"):
`log` + `dns` + `inbounds:[mixed 127.0.0.1:20808]`(与原生配置 socks5 端口一致,降低用户切换成本)+ `outbounds:[hysteria2, direct]` + `route`(rule-set:geosite-cn/geoip-cn → direct,私网 → direct,其余 → hy2 出站)+ `experimental.clash_api` + `cache_file`。
DNS 方向:CN 域名走国内 DoH(阿里 `dns.alidns.com`)直连解析,其余经代理解析(具体 servers/rules 写法实现时按 sing-box 1.11 DNS 语法定稿)。

**hysteria2 outbound 字段映射**:

| 来源 | sing-box 字段 | 规则 |
|------|--------------|------|
| serverAddress | `server` | 常规模式 |
| 端口 | `server_port` | 端口跳跃时省略,改用 `server_ports: ["start:end"]`(**冒号**分隔,1.11+) |
| 跳跃间隔 | `hop_interval` | 字符串带单位如 `"30s"`;random 模式加 `hop_interval_max`(1.14+,附版本提示) |
| auth | `password` | |
| 带宽 | `up_mbps`/`down_mbps` | **纯数字**(剥离单位);仅 brutal 输出;BBR/Reno 省略(sing-box 语义:缺省即 BBR) |
| BBR profile | `bbr_profile` | congestion==bbr 且非 standard 时输出(1.14+,附版本提示) |
| 混淆 | `obfs.type`/`obfs.password` | salamander 全版本;gecko 需 1.14+(附版本提示);无混淆省略整块 |
| SNI | `tls.server_name` | `tls.enabled: true` |
| 自签证书 | `tls.certificate` | **内嵌 CA PEM**(读 `/etc/hihy/result/<domain>.ca.crt`),`insecure: false`;CA 文件缺失时回退 `insecure: true` 并警告 |
| ACME/本地证书 | — | `insecure` 按 backup.yaml 值 |

> **关键差异**:sing-box 不支持 hysteria 的 pinSHA256(其 `certificate_public_key_sha256` 是公钥哈希,与证书指纹值不同,不可直接复用)。自签场景配置在服务器本地生成,CA 文件就地可读,内嵌 PEM 是最干净且安全的方案。

**生成方式**:heredoc 模板 + 条件拼接可选块(端口跳跃/混淆/brutal-vs-bbr/自签 CA/realm 五个变量块),生成后用 `yq`(已有依赖)做 JSON 解析校验 + 格式化,避免手拼 JSON 语法错误。PEM 多行内容通过 `yq env()` 注入以正确转义。

### 5.4 公共参数提取(70-client-common.sh)

现状:三个生成器各自重复读取 backup.yaml/config.yaml 20+ 个值(约 150 行重复)。
新增 `loadClientParams()`:一次性读取全部客户端参数(server/port/auth/tls/obfs/quic/bandwidth/portHopping/realm/congestion),导出为 `HIHY_CP_*` 前缀变量,三个生成器共用。
同时:客户端生成路径中的硬编码 `/etc/hihy` 一律改经 `$HIHY_ROOT_DIR`,使生成器可用 fixture 目录测试。

### 5.5 Realm URI 解析(双客户端共用)

存储格式:`realm://<token>@<host>[:port]/<realm-id>` 或 `realm+http://...`。
解析函数 `parseRealmURI()` 输出:scheme(`realm`→`https`、`realm+http`→`http`)、server-url(`<scheme>://<host>[:port]`)、token、realm-id。
STUN 列表复用原生客户端配置中的既有清单(bilibili/miwifi/nextcloud/twilio)。

| 客户端 | Realm 生成 |
|--------|-----------|
| mihomo | `realm-opts` 块;顶层 server/port 按官方示例保留(实现时实测定稿) |
| sing-box | `realm` 块(server_url/token/realm_id/stun_servers);**必须省略** `server`/`server_port`/`server_ports`(文档明确冲突);需 1.14+,附版本提示 |

### 5.6 规则镜像策略

- 新增 `HIHY_RULESET_MIRROR` 环境变量,mihomo rule-providers 与 sing-box rule-sets 统一经它构造 URL
- **默认 jsDelivr**(`cdn.jsdelivr.net/gh/...`):大陆可访问、长期稳定,且本项目自更新已在用 jsdelivr,策略一致;替换现有硬编码的 `ghgo.xyz`
- mihomo 规则源:`Loyalsoldier/clash-rules@release`;sing-box `.srs` 源:`MetaCubeX/meta-rules-dat@sing`(实现时做一次连通性核对再定稿具体路径)
- 用户可覆盖为 Gitee 等其它镜像

### 5.7 输出编排

`generate_client_config` 末尾依次:原生 yaml → 分享链接/二维码 → mihomo(gecko 时跳过并提示)→ sing-box,各附适用客户端说明与最低版本提示(sing-box realm/gecko/bbr_profile → 1.14+,server_ports → 1.11+)。

## 6. 测试策略

| 测试 | 内容 |
|------|------|
| `test_bootstrap_install.sh`(现有) | 不动,继续 source 产物 |
| `test_install_recovery.sh`(现有) | 不动,继续 source 产物 |
| `test_build.sh`(新增) | 构建后 `git diff --exit-code server/hy2.sh`,防产物脱节 |
| `test_client_config.sh`(新增) | fixture 方式(HIHY_ROOT_DIR 指向临时目录 + mock backup/config yaml),矩阵:{brutal,bbr,reno} × {跳跃开/关} × {无混淆,salamander,gecko} × {自签,ACME} × {realm 开/关}。断言:① mihomo 产物 yq 可解析、sing-box 产物 yq JSON 可解析;② BBR/Reno 时 mihomo 无 up/down、sing-box 无 up_mbps/down_mbps(回归 5.2#1);③ gecko 时不生成 mihomo 文件(回归 5.2#2);④ sing-box realm 模式无 server_port(5.5);⑤ 自签时 sing-box 含内嵌证书且 insecure=false |
| `scripts/i18n-validate.sh`(增强) | key 一致性 + printf 占位符一致性 |

**strict mode 说明**:CLAUDE.md 声称全脚本 `set -euo pipefail`,实际 hy2.sh 并没有。本次**不强上 `-e`**(3859 行遗留代码行为风险过大),仅修复 shellcheck 明确错误项;CLAUDE.md 同步纠正此描述。

## 7. 发布计划

分阶段 commit(每阶段测试通过),最后一次性 push:

1. `merge: feature/i18n-support`(解决 2 处冲突,i18n 在单文件形态下先跑通)
2. `refactor: split hy2.sh into src/ modules + build system`(纯搬运,产物与合并后单文件**功能等价**,行为零变化)
3. `fix(mihomo): congestion/gecko/bbr-profile/hop-interval fixes + rename ClashMeta to mihomo`
4. `feat(singbox): add sing-box client config generation`
5. `feat(client): unified ruleset mirror + realm support for mihomo/sing-box`
6. `chore: bump to ver1.12, update README/CLAUDE.md/md docs`

版本号:`hihyV="ver1.12"`;README 头部按既有格式添加变更日志,历史记录追加到 `md/logs.md`;`md/client.md` 增补 mihomo/sing-box 使用说明。

## 8. 明确不在本次范围

- systemd unit 迁移(维持 rc.d/OpenRC 方案)
- 多用户管理(README Todo 项)
- mihomo DNS fake-ip 切换
- 全量 `set -euo pipefail` 改造
- Hysteria1(v1 分支)任何改动
- install.sh 改名或分发链变更

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 模块拆分搬运手误 | 拆分阶段零行为变化 + `bash -n` + 现有测试 source 产物 + test_build.sh |
| i18n 合并冲突处理出错 | 冲突范围已定位(2 个提交的函数区域);以 main 逻辑为准 |
| mihomo realm-opts 文档与实际行为不符 | 标注 best-effort,实现时以真实内核验证;不影响原生/sing-box 路径 |
| jsdelivr 规则路径失效 | 实现时连通性核对;HIHY_RULESET_MIRROR 可覆盖 |
| 翻译占位符错位导致 printf 故障 | i18n-validate 占位符一致性检查 |
