# Hi Hysteria 模块化重构 + i18n + 多内核客户端配置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 3859 行的 `server/hy2.sh` 拆成 `server/src/` 模块化源码 + 构建期组装的单文件产物,并入 i18n 分支,修复 mihomo 客户端配置、新增 sing-box 客户端配置,发布 ver1.12。

**Architecture:** 源码模块化(`server/src/*.sh` 按数字前缀排序)、`scripts/build.sh` 拼接成单文件 `server/hy2.sh`(提交入库,保持分发/自更新单文件形态不变)。i18n 复用 `feature/i18n-support` 分支的纯 bash JSON loader。三个客户端生成器共用 `loadClientParams()` 一次性读参。

**Tech Stack:** bash 4+、mikefarah `yq`(YAML+JSON)、openssl、curl/wget、GitHub Actions 无关(本地测试)。

## Global Constraints

- `server/install.sh` 文件名与路径**不可变**(`https://git.io/hysteria.sh` 短链指向它)。
- `server/hy2.sh` 必须始终是**完整可直接 `bash` 运行的单文件**(存量用户从 `refs/heads/main/server/hy2.sh` 下载单文件自更新;jsdelivr 镜像同理)。
- `/etc/hihy/` 目录结构不变;`backup.yaml` 字段**只增不改**。
- `hihy <N>` 数字快捷命令与菜单序号不变。
- 版本号最终为 `hihyV="ver1.12"`。
- 所有 `/etc/hihy` 路径在客户端生成器中改经 `$HIHY_ROOT_DIR`(默认 `/etc/hihy`),以便 fixture 测试。
- 规则镜像默认 jsDelivr,经 `HIHY_RULESET_MIRROR` 可覆盖。
- 新增用户可见文案一律走 i18n key,四语言(en/zh/fa/ru)同步补齐。
- **不**全量上 `set -euo pipefail`;仅修 shellcheck 明确错误。
- 语言包不嵌入产物,运行时下载。

---

## Phase 0:分支合并(前置,必须最先做)

### Task 0: 合并 feature/i18n-support 进 main

**Files:**
- Modify: `server/hy2.sh`(合并冲突解决)
- Modify: `server/install.sh`(合并冲突解决)
- 新增(来自分支):`server/i18n/{en,zh,fa,ru}.json`、`scripts/i18n-extract.sh`、`scripts/i18n-validate.sh`、`docs/superpowers/plans/2026-07-02-i18n-support.md`

**Interfaces:**
- Produces: 合并后的单文件 `server/hy2.sh` 顶部含 i18n loader 函数组:`loadPersistedLanguage`、`savePersistedLanguage`、`i18nLookup key`、`i18n key [args...]`、`refreshI18nFile lang`、`i18nValueFromFile file key`、`getI18nSchemaVersion file`、`detectRtlFromMeta file`。全局变量 `HIHY_I18N_SCHEMA=1`、`HIHY_I18N_DIR`、`HIHY_I18N_CONF`、`HIHY_LANG`。

- [ ] **Step 1: 确认干净工作区并创建合并前快照 tag**

Run:
```bash
cd /home/sakurairo/Desktop/workspace/Github/Hi_Hysteria
git status --porcelain
git tag pre-i18n-merge-backup
```
Expected: `git status` 仅显示未跟踪的 `CLAUDE.md`(若有);tag 创建成功。

- [ ] **Step 2: 执行合并(预期在 uninstall/防火墙区域冲突)**

Run:
```bash
git merge --no-ff feature/i18n-support -m "merge: adopt feature/i18n-support (bash i18n loader + en/zh/fa/ru catalogs)"
```
Expected: 报告 `CONFLICT (content): Merge conflict in server/hy2.sh`(可能还有 install.sh)。若无冲突直接成功则跳到 Step 5。

- [ ] **Step 3: 解决冲突**

原则:**main 侧的逻辑为准**(main 领先分支 2 个提交:c224312 移除脚本管理的端口跳跃防火墙规则、710c256 卸载时 kill 进程+清理 iptables 链)。对每个冲突块:
- 保留 main 的 `uninstall()` / `cleanupHysteria2Iptables()` / `delHihyFirewallPort()` 逻辑主体
- 把分支侧在这些区域引入的 `i18n "..."` 字符串调用**移植到 main 逻辑上**(即:用 main 的控制流,把其中的硬编码中文替换为分支对应的 i18n key 调用)

逐个打开冲突文件解决:
```bash
git diff --name-only --diff-filter=U
```
对每个文件编辑消除 `<<<<<<<`/`=======`/`>>>>>>>` 标记。

- [ ] **Step 4: 校验语法与冲突标记清除**

Run:
```bash
grep -rn '^<<<<<<<\|^=======\|^>>>>>>>' server/ || echo "NO_MARKERS"
bash -n server/hy2.sh && echo "hy2.sh SYNTAX_OK"
bash -n server/install.sh && echo "install.sh SYNTAX_OK"
```
Expected: `NO_MARKERS`、两个 `SYNTAX_OK`。

- [ ] **Step 5: 运行既有测试 + i18n 校验**

Run:
```bash
bash server/test_bootstrap_install.sh
bash server/test_install_recovery.sh
bash scripts/i18n-validate.sh
```
Expected: 全部通过("All ... tests passed" / validate 无报错)。

- [ ] **Step 6: 冒烟测试 i18n loader**

Run:
```bash
HIHY_LANG=zh bash -c 'source <(sed -n "1,120p" server/hy2.sh); i18nValueFromFile server/i18n/zh.json menu_option_install 2>/dev/null || echo LOADER_PRESENT'
```
Expected: 输出中文安装菜单文案或 `LOADER_PRESENT`(证明 loader 函数存在且可 source)。

- [ ] **Step 7: 完成合并提交**

Run:
```bash
git commit --no-edit 2>/dev/null || git commit -m "merge: adopt feature/i18n-support (bash i18n loader + en/zh/fa/ru catalogs)"
git log --oneline -1
```
Expected: 合并提交已创建。

---

## Phase 1:构建系统(先建脚手架,后填模块)

### Task 1: 创建 build.sh 与模块目录约定

**Files:**
- Create: `scripts/build.sh`
- Create: `server/src/.gitkeep`(占位,后续任务填模块)

**Interfaces:**
- Produces: `scripts/build.sh` — 读 `server/src/*.sh`(按文件名排序)拼接为 `server/hy2.sh`;剥离除首模块外的 shebang;插入 GENERATED 头注释;`bash -n` 校验。

- [ ] **Step 1: 写 build.sh**

Create `scripts/build.sh`:
```bash
#!/bin/bash
# 组装 server/src/*.sh -> server/hy2.sh (单文件分发产物)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/server/src"
OUT="$REPO_ROOT/server/hy2.sh"
TMP="$(mktemp)"

shopt -s nullglob
modules=("$SRC_DIR"/*.sh)
shopt -u nullglob

if [ "${#modules[@]}" -eq 0 ]; then
    echo "ERROR: no modules found in $SRC_DIR" >&2
    exit 1
fi

# 首模块(00-header.sh)保留 shebang + GENERATED 注释
first=1
for m in "${modules[@]}"; do
    if [ "$first" -eq 1 ]; then
        # 取 shebang 行
        head -n 1 "$m" >>"$TMP"
        cat >>"$TMP" <<'GEN'
# =============================================================================
# GENERATED FILE — DO NOT EDIT.
# Source lives in server/src/*.sh. Edit there and run: bash scripts/build.sh
# =============================================================================
GEN
        # 首模块去掉 shebang 后的余下内容
        tail -n +2 "$m" >>"$TMP"
        first=0
    else
        # 其余模块:去掉 shebang(若有),前置一个分隔注释
        printf '\n# ----- %s -----\n' "$(basename "$m")" >>"$TMP"
        if head -n 1 "$m" | grep -q '^#!'; then
            tail -n +2 "$m" >>"$TMP"
        else
            cat "$m" >>"$TMP"
        fi
    fi
done

bash -n "$TMP" || { echo "ERROR: assembled script failed syntax check" >&2; rm -f "$TMP"; exit 1; }
mv "$TMP" "$OUT"
chmod +x "$OUT"
echo "Built $OUT from ${#modules[@]} modules."

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S error "$OUT" && echo "shellcheck: no errors" || echo "shellcheck: errors above (review)"
fi
```

- [ ] **Step 2: 创建目录占位**

Run:
```bash
mkdir -p server/src && touch server/src/.gitkeep
chmod +x scripts/build.sh
```
Expected: 目录创建成功。

- [ ] **Step 3: 提交脚手架**

Run:
```bash
git add scripts/build.sh server/src/.gitkeep
git commit -m "build: add module assembly script (scripts/build.sh)"
```

---

### Task 2: 模块拆分 —— 把合并后的 hy2.sh 切成 server/src/*.sh

> 这是**机械搬运**任务:把当前 `server/hy2.sh` 的内容按下表**逐段原样**移入对应模块文件,再用 build.sh 组装回 `server/hy2.sh`,产物必须与拆分前**功能等价**(现有测试全过)。不要改任何逻辑。

**Files:**
- Create: `server/src/00-header.sh` … `server/src/90-main.sh`(见分配表)
- Modify: `server/hy2.sh`(改由 build.sh 生成)
- Delete: `server/src/.gitkeep`

**模块分配表**(按合并后 hy2.sh 的内容归类;行号会因 i18n 合并偏移,按**函数名**定位):

| 模块 | 内容 |
|------|------|
| `00-header.sh` | shebang、`hihyV` 变量、i18n 全局变量(`HIHY_I18N_*`/`HIHY_LANG`)、其余 `HIHY_*` 环境变量声明 |
| `10-i18n.sh` | `loadPersistedLanguage`、`savePersistedLanguage`、`detectRtlFromMeta`、`getI18nSchemaVersion`、`refreshI18nFile`、`i18nValueFromFile`、`i18nLookup`、`i18n` |
| `15-ui.sh` | `echoColor`、`countdown`、`generate_qr`、`getPortBindMsg`、`show_menu`、`wait_for_continue` |
| `20-net-yaml.sh` | `installHihyLauncher`、`downloadToFile`、`fetchRemoteBodyFromSources`、`fetchRemoteHeadersFromSources`、`addOrUpdateYaml`、`getYamlValue`、`generate_uuid`、`getListenPrimaryPort`、`getListenRangePart` |
| `25-system.sh` | `detectVirtualization`、`getStartCommand`、`cronTask`、`getArchitecture`、`checkSystemForUpdate` |
| `30-version.sh` | `getLatestHihyVersion`、`getLatestHysteriaVersion`、`getLocalHysteriaVersion`、`ensureVersionCheckStateDir`、`readVersionCheckValue`、`writeVersionCheckState`、`acquireVersionCheckLock`、`releaseVersionCheckLock`、`shouldStartVersionCheck`、`refreshVersionCheckState`、`startBackgroundVersionCheck`、`displayCachedVersionNotifications`、`hihy_update_notifycation`、`hyCore_update_notifycation` |
| `35-state.sh` | `getBackupValueOrDefault`、`getInstallFailureMarker`、`getHihyServiceScriptPrimary`、`getHihyServiceScriptFallback`、`classifyInstallState`、`markInstallFailed`、`clearInstallFailureMarker`、`recoverPartialInstallState` |
| `45-wizard.sh` | `startInstallValidationProcess`、`setHysteriaConfig`(含其内部证书逻辑) |
| `50-core.sh` | `downloadHysteriaCore`、`updateHysteriaCore` |
| `55-service.sh` | `setup_rc_local_for_arch`、`uninstall_rc_local_for_arch`、`install`、服务脚本内 `depend/start_pre/start/stop/restart/status/log`(**注意**:这些是 heredoc 内文本,随 `install()` 一起搬)、顶层 `start`/`stop`/`restart`/`checkStatus`/`checkLogs`(2214-2258、3107-3186 区块) |
| `60-firewall.sh` | `formatFirewallPortSpec`、`hasFirewallToken`、`checkUFWAllowPort`、`checkFirewalldAllowPort`、`allowPort`、`delHihyFirewallPort` |
| `65-lifecycle.sh` | `killHysteriaProcess`、`cleanupHysteria2Iptables`、`checkRoot`、`uninstall` |
| `70-client-common.sh` | (本 Phase 先留空占位,Task 6 填 `loadClientParams`/`parseRealmURI`) |
| `72-client-native.sh` | `generate_client_config` |
| `74-client-mihomo.sh` | `generateMetaYaml`(Task 4 改名/修复) |
| `80-stats.sh` | `format_bytes`、`getHysteriaTrafic`、`format_time_display` |
| `85-actions.sh` | `hihyUpdate`、`changeIp64`、`changeServerConfig`、`aclControl`、`addSocks5Outbound` |
| `90-main.sh` | `menu`、末尾 `if [ "${BASH_SOURCE[0]}" = "$0" ]; then … dispatch … fi` |

> **搬运顺序警告**:`90-main.sh` 末尾的 `if BASH_SOURCE == $0` dispatch 块必须是整个产物的最后内容。函数定义顺序在 bash 中不影响调用(全部先定义后在 dispatch 执行),但**顶层非函数语句**(如 `HIHY_*` 变量赋值)必须在使用前,故都归入 `00-header.sh`。

- [ ] **Step 1: 备份当前产物为参考基线**

Run:
```bash
cp server/hy2.sh /tmp/hy2-baseline.sh
grep -c '^[a-zA-Z_][a-zA-Z0-9_]*()' /tmp/hy2-baseline.sh
```
Expected: 打印函数总数(记下,拆分后须一致)。

- [ ] **Step 2: 按分配表创建各模块文件**

对每个模块:新建 `server/src/NN-name.sh`,首行写 `#!/bin/bash`,把分配表对应函数**从 baseline 原样复制**进去(用 Read 定位函数区间,Write 到模块文件)。`00-header.sh` 放 shebang + 全部顶层变量声明。`90-main.sh` 放 `menu` + dispatch 尾块。

逐模块完成后删除占位:
```bash
rm -f server/src/.gitkeep
```

- [ ] **Step 3: 组装并语法校验**

Run:
```bash
bash scripts/build.sh
grep -c '^[a-zA-Z_][a-zA-Z0-9_]*()' server/hy2.sh
```
Expected: `Built server/hy2.sh from N modules.`;函数数与 Step 1 一致。

- [ ] **Step 4: 功能等价校验(diff 忽略 GENERATED 头与分隔注释)**

Run:
```bash
# 去掉 GENERATED 头/模块分隔注释后与 baseline 比对函数体
diff <(grep -v '^# ----- \|^# ===\|^# GENERATED\|^# Source lives\|^# ===' /tmp/hy2-baseline.sh) \
     <(grep -v '^# ----- \|^# ===\|^# GENERATED\|^# Source lives\|^# ===' server/hy2.sh) \
     && echo "FUNCTIONALLY_EQUIVALENT" || echo "REVIEW_DIFF_ABOVE"
```
Expected: `FUNCTIONALLY_EQUIVALENT`。若有 diff,检查是否只是空白/注释顺序;逻辑行不得有差异。

- [ ] **Step 5: 跑全部现有测试**

Run:
```bash
bash server/test_bootstrap_install.sh
bash server/test_install_recovery.sh
bash scripts/i18n-validate.sh
bash -n server/hy2.sh && echo SYNTAX_OK
```
Expected: 全绿。

- [ ] **Step 6: 提交模块化重构**

Run:
```bash
git add server/src/ server/hy2.sh
git commit -m "refactor: split hy2.sh into server/src/ modules assembled by build.sh"
```

---

### Task 3: 新增 test_build.sh 防产物脱节

**Files:**
- Create: `server/test_build.sh`

**Interfaces:**
- Consumes: `scripts/build.sh`
- Produces: 可执行测试:重建后 `git diff --exit-code server/hy2.sh` 非空即失败。

- [ ] **Step 1: 写测试**

Create `server/test_build.sh`:
```bash
#!/bin/bash
# 校验 server/hy2.sh 与 server/src/ 同步(产物未被手改)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$REPO_ROOT/scripts/build.sh" >/dev/null

if git -C "$REPO_ROOT" diff --quiet -- server/hy2.sh; then
    echo "test_build: server/hy2.sh is in sync with server/src/. PASS"
else
    echo "test_build: server/hy2.sh is STALE — rebuild with 'bash scripts/build.sh' and commit." >&2
    git -C "$REPO_ROOT" --no-pager diff --stat -- server/hy2.sh >&2
    exit 1
fi
```

- [ ] **Step 2: 验证测试通过(产物已同步)**

Run:
```bash
chmod +x server/test_build.sh
bash server/test_build.sh
```
Expected: `... PASS`。

- [ ] **Step 3: 验证测试能抓到脱节(负向验证)**

Run:
```bash
printf '\n# tampered\n' >> server/hy2.sh
bash server/test_build.sh; echo "exit=$?"
git checkout -- server/hy2.sh
```
Expected: 打印 `STALE` 且 `exit=1`;随后 checkout 还原。

- [ ] **Step 4: 提交**

Run:
```bash
git add server/test_build.sh
git commit -m "test: add test_build.sh to keep hy2.sh in sync with server/src/"
```

---

## Phase 2:客户端配置公共层

### Task 6: 抽取 loadClientParams 与 parseRealmURI

> 编号接续(Task 4/5 为 mihomo/sing-box,排在本任务后,因它们依赖公共层)。

**Files:**
- Modify: `server/src/70-client-common.sh`
- Modify: `server/src/72-client-native.sh`(改用公共层变量)
- Test: `server/test_client_config.sh`(本任务新建,后续任务追加用例)

**Interfaces:**
- Produces:
  - `loadClientParams()` — 读取 `$HIHY_ROOT_DIR/conf/{backup,config}.yaml`,导出变量:`HIHY_CP_remarks`、`HIHY_CP_serverAddress`、`HIHY_CP_realmMode`(true/false)、`HIHY_CP_realmURI`、`HIHY_CP_port`、`HIHY_CP_auth`、`HIHY_CP_sni`、`HIHY_CP_insecure`、`HIHY_CP_pinSHA256`、`HIHY_CP_obfsStatus`(true/false)、`HIHY_CP_obfsType`、`HIHY_CP_obfsPass`、`HIHY_CP_congestionMode`(brutal/bbr/reno)、`HIHY_CP_congestionType`、`HIHY_CP_bbrProfile`、`HIHY_CP_down`、`HIHY_CP_up`、`HIHY_CP_srw`/`HIHY_CP_crw`/`HIHY_CP_maxCrw`/`HIHY_CP_maxSrw`、`HIHY_CP_phStatus`(true/false)、`HIHY_CP_phStart`、`HIHY_CP_phEnd`、`HIHY_CP_phIntervalMode`(fixed/random)、`HIHY_CP_phHopInterval`、`HIHY_CP_phMinHopInterval`、`HIHY_CP_phMaxHopInterval`。
  - `parseRealmURI uri` — 解析 `realm://token@host[:port]/realm-id` 或 `realm+http://…`,导出:`HIHY_REALM_SCHEME`(http/https)、`HIHY_REALM_SERVER_URL`、`HIHY_REALM_TOKEN`、`HIHY_REALM_ID`。

- [ ] **Step 1: 写 loadClientParams 与 parseRealmURI 的失败测试**

Create `server/test_client_config.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAIL=1; }

# 用临时 HIHY_ROOT_DIR + mock yaml 驱动
setup_fixture() {
    HIHY_ROOT_DIR="$(mktemp -d)"
    export HIHY_ROOT_DIR
    mkdir -p "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/result"
    cat > "$HIHY_ROOT_DIR/conf/config.yaml" <<'YML'
listen: :34567
auth:
  password: testpass-uuid
obfs:
  type: none
quic:
  initStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 134217728
  maxStreamReceiveWindow: 67108864
bandwidth:
  up: 50 mbps
  down: 200 mbps
YML
    cat > "$HIHY_ROOT_DIR/conf/backup.yaml" <<'YML'
remarks: testnode
serverAddress: 1.2.3.4
realmMode: false
domain: helloworld.com
insecure: true
pinSHA256: "AA:BB:CC"
congestionMode: brutal
portHoppingStatus: false
YML
}
teardown_fixture() { rm -rf "$HIHY_ROOT_DIR"; }

# 加载产物中的函数(source 整个脚本但不触发 dispatch:BASH_SOURCE != $0)
load_funcs() { source "$REPO_ROOT/server/hy2.sh"; }

# --- loadClientParams ---
setup_fixture
load_funcs
loadClientParams
[ "$HIHY_CP_remarks" = "testnode" ] && pass "loadClientParams remarks" || fail "loadClientParams remarks got '$HIHY_CP_remarks'"
[ "$HIHY_CP_auth" = "testpass-uuid" ] && pass "loadClientParams auth" || fail "loadClientParams auth got '$HIHY_CP_auth'"
[ "$HIHY_CP_congestionMode" = "brutal" ] && pass "loadClientParams congestion" || fail "loadClientParams congestion"
teardown_fixture

# --- parseRealmURI ---
parseRealmURI "realm://public@realm.hy2.io/abc-123"
[ "$HIHY_REALM_SERVER_URL" = "https://realm.hy2.io" ] && pass "parseRealmURI server_url" || fail "parseRealmURI server_url got '$HIHY_REALM_SERVER_URL'"
[ "$HIHY_REALM_TOKEN" = "public" ] && pass "parseRealmURI token" || fail "parseRealmURI token got '$HIHY_REALM_TOKEN'"
[ "$HIHY_REALM_ID" = "abc-123" ] && pass "parseRealmURI realm_id" || fail "parseRealmURI realm_id got '$HIHY_REALM_ID'"
parseRealmURI "realm+http://tok@host.example:8443/id9"
[ "$HIHY_REALM_SERVER_URL" = "http://host.example:8443" ] && pass "parseRealmURI http scheme" || fail "parseRealmURI http got '$HIHY_REALM_SERVER_URL'"

[ "$FAIL" -eq 0 ] && echo "ALL client_config TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
```

- [ ] **Step 2: 运行,确认失败(函数未定义)**

Run:
```bash
chmod +x server/test_client_config.sh
bash server/test_client_config.sh; echo "exit=$?"
```
Expected: FAIL(`loadClientParams: command not found` 类),`exit=1`。

- [ ] **Step 3: 实现 parseRealmURI**

写入 `server/src/70-client-common.sh`(替换占位内容,保留 shebang):
```bash
#!/bin/bash

# 解析 realm URI: realm://<token>@<host>[:port]/<realm-id> 或 realm+http://...
# 导出 HIHY_REALM_SCHEME / HIHY_REALM_SERVER_URL / HIHY_REALM_TOKEN / HIHY_REALM_ID
parseRealmURI() {
    local uri="$1"
    local scheme rest hostport
    if [[ "$uri" == realm+http://* ]]; then
        HIHY_REALM_SCHEME="http"
        rest="${uri#realm+http://}"
    else
        HIHY_REALM_SCHEME="https"
        rest="${uri#realm://}"
    fi
    # token@hostport/realm-id
    HIHY_REALM_TOKEN="${rest%%@*}"
    rest="${rest#*@}"
    hostport="${rest%%/*}"
    HIHY_REALM_ID="${rest#*/}"
    HIHY_REALM_SERVER_URL="${HIHY_REALM_SCHEME}://${hostport}"
    export HIHY_REALM_SCHEME HIHY_REALM_SERVER_URL HIHY_REALM_TOKEN HIHY_REALM_ID
}
```

- [ ] **Step 4: 实现 loadClientParams**

追加到 `server/src/70-client-common.sh`(把 `72-client-native.sh` 中 `generate_client_config` 顶部的读取逻辑抽取为此函数;所有硬编码 `/etc/hihy` 改 `$HIHY_ROOT_DIR`):
```bash
# 一次性读取 backup/config.yaml 全部客户端参数,导出 HIHY_CP_* 供各生成器共用
loadClientParams() {
    local root="${HIHY_ROOT_DIR:-/etc/hihy}"
    local backup="$root/conf/backup.yaml"
    local config="$root/conf/config.yaml"

    HIHY_CP_remarks=$(getYamlValue "$backup" "remarks")
    HIHY_CP_serverAddress=$(getYamlValue "$backup" "serverAddress")
    HIHY_CP_realmMode=$(getBackupValueOrDefault "$backup" "realmMode" "false")
    HIHY_CP_realmURI=""
    if [ "$HIHY_CP_realmMode" = "true" ]; then
        HIHY_CP_realmURI=$(getYamlValue "$backup" "realmURI")
    fi
    local listen_value
    listen_value=$(getYamlValue "$config" "listen")
    HIHY_CP_port=$(getListenPrimaryPort "$listen_value")
    HIHY_CP_auth=$(getYamlValue "$config" "auth.password")
    HIHY_CP_sni=$(getYamlValue "$backup" "domain")
    HIHY_CP_insecure=$(getYamlValue "$backup" "insecure")
    HIHY_CP_pinSHA256=$(getBackupValueOrDefault "$backup" "pinSHA256" "")
    if [ -z "$HIHY_CP_pinSHA256" ] || [ "$HIHY_CP_pinSHA256" = "null" ]; then
        HIHY_CP_pinSHA256=""
        local cert_path
        cert_path=$(getYamlValue "$config" "tls.cert")
        if [ "$HIHY_CP_insecure" = "true" ] && [ -n "$cert_path" ] && [ "$cert_path" != "null" ] && [ -f "$cert_path" ]; then
            HIHY_CP_pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in "$cert_path" 2>/dev/null | sed 's/^.*=//')
        fi
    fi

    HIHY_CP_obfsType=$(getYamlValue "$config" "obfs.type")
    if [ "$HIHY_CP_obfsType" = "salamander" ] || [ "$HIHY_CP_obfsType" = "gecko" ]; then
        HIHY_CP_obfsStatus="true"
        HIHY_CP_obfsPass=$(getYamlValue "$config" "obfs.${HIHY_CP_obfsType}.password")
    else
        HIHY_CP_obfsStatus="false"
        HIHY_CP_obfsType=""
        HIHY_CP_obfsPass=""
    fi

    HIHY_CP_srw=$(getYamlValue "$config" "quic.initStreamReceiveWindow"); [ "$HIHY_CP_srw" = "null" ] && HIHY_CP_srw=""
    HIHY_CP_crw=$(getYamlValue "$config" "quic.initConnReceiveWindow"); [ "$HIHY_CP_crw" = "null" ] && HIHY_CP_crw=""
    HIHY_CP_maxCrw=$(getYamlValue "$config" "quic.maxConnReceiveWindow"); [ "$HIHY_CP_maxCrw" = "null" ] && HIHY_CP_maxCrw=""
    HIHY_CP_maxSrw=$(getYamlValue "$config" "quic.maxStreamReceiveWindow"); [ "$HIHY_CP_maxSrw" = "null" ] && HIHY_CP_maxSrw=""

    HIHY_CP_congestionMode=$(getBackupValueOrDefault "$backup" "congestionMode" "brutal")
    HIHY_CP_congestionType=$(getBackupValueOrDefault "$backup" "congestionType" "")
    HIHY_CP_bbrProfile=$(getBackupValueOrDefault "$backup" "congestionBbrProfile" "standard")

    # 注意:原生配置里 down 取 bandwidth.up、up 取 bandwidth.down(既有约定,保持不变)
    HIHY_CP_down=$(getYamlValue "$config" "bandwidth.up"); [ "$HIHY_CP_down" = "null" ] && HIHY_CP_down=""
    HIHY_CP_up=$(getYamlValue "$config" "bandwidth.down"); [ "$HIHY_CP_up" = "null" ] && HIHY_CP_up=""

    HIHY_CP_phStatus=$(getYamlValue "$backup" "portHoppingStatus")
    HIHY_CP_phStart=""; HIHY_CP_phEnd=""; HIHY_CP_phIntervalMode="fixed"
    HIHY_CP_phHopInterval="30s"; HIHY_CP_phMinHopInterval="10s"; HIHY_CP_phMaxHopInterval="30s"
    if [ "$HIHY_CP_phStatus" = "true" ]; then
        HIHY_CP_phStart=$(getBackupValueOrDefault "$backup" "portHoppingStart" "$HIHY_CP_port")
        HIHY_CP_phEnd=$(getBackupValueOrDefault "$backup" "portHoppingEnd" "$HIHY_CP_port")
        HIHY_CP_phIntervalMode=$(getBackupValueOrDefault "$backup" "portHoppingIntervalMode" "fixed")
        HIHY_CP_phHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingHopInterval" "30s")
        HIHY_CP_phMinHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingMinHopInterval" "10s")
        HIHY_CP_phMaxHopInterval=$(getBackupValueOrDefault "$backup" "portHoppingMaxHopInterval" "30s")
    fi
}
```

- [ ] **Step 5: 组装并运行测试**

Run:
```bash
bash scripts/build.sh
bash server/test_client_config.sh
```
Expected: `ALL client_config TESTS PASSED`。

- [ ] **Step 6: 让 generate_client_config 复用公共层**

在 `server/src/72-client-native.sh` 中,把 `generate_client_config` 顶部原有的逐值读取替换为 `loadClientParams` 调用,并把函数体内后续引用改用 `HIHY_CP_*` 变量(逐个替换:`remarks`→`$HIHY_CP_remarks`、`auth_secret`→`$HIHY_CP_auth`、`port`→`$HIHY_CP_port` 等)。保持输出逻辑与分享链接生成**完全不变**。

- [ ] **Step 7: 回归 —— 原生配置行为不变**

Run:
```bash
bash scripts/build.sh
bash server/test_install_recovery.sh
bash server/test_bootstrap_install.sh
bash -n server/hy2.sh && echo SYNTAX_OK
```
Expected: 全绿。

- [ ] **Step 8: 提交**

Run:
```bash
git add server/src/70-client-common.sh server/src/72-client-native.sh server/hy2.sh server/test_client_config.sh
git commit -m "refactor(client): extract loadClientParams + parseRealmURI shared layer"
```

---

## Phase 3:mihomo 修复与改名

### Task 4: 修复 mihomo 配置并改名 generateMihomoYaml

**Files:**
- Modify: `server/src/74-client-mihomo.sh`(`generateMetaYaml` → `generateMihomoYaml`)
- Modify: `server/src/72-client-native.sh`(调用点改名 + gecko 跳过逻辑)
- Modify: `server/test_client_config.sh`(追加 mihomo 断言)
- Modify: `server/i18n/*.json`(新增文案 key)

**Interfaces:**
- Consumes: `loadClientParams`、`parseRealmURI`、`HIHY_RULESET_MIRROR`
- Produces: `generateMihomoYaml()` — 输出 `./Hy2-${HIHY_CP_remarks}-mihomo.yaml`;BBR/Reno 不含 `up`/`down`;含 `bbr-profile`(bbr 时);端口跳跃含 `hop-interval`;realm 时输出 `realm-opts`。

- [ ] **Step 1: 追加 mihomo 回归断言到 test_client_config.sh**

在 `server/test_client_config.sh` 的最终汇总行**之前**插入:
```bash
# --- mihomo: BBR 模式不得输出 up/down(回归 5.2#1)---
setup_fixture
sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
echo 'congestionType: bbr' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateMihomoYaml >/dev/null 2>&1
  mf="$HIHY_ROOT_DIR/Hy2-testnode-mihomo.yaml"
  if [ -f "$mf" ] && ! grep -qE '^\s+up:|^\s+down:' "$mf"; then echo "PASS: mihomo bbr omits up/down"; else echo "FAIL: mihomo bbr up/down" >&2; fi )
teardown_fixture

# --- mihomo: brutal 模式必须输出 up/down ---
setup_fixture
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateMihomoYaml >/dev/null 2>&1
  mf="$HIHY_ROOT_DIR/Hy2-testnode-mihomo.yaml"
  if grep -qE '^\s+up:' "$mf" && grep -qE '^\s+down:' "$mf"; then echo "PASS: mihomo brutal has up/down"; else echo "FAIL: mihomo brutal up/down" >&2; fi )
teardown_fixture

# --- mihomo: 产物可被 yq 解析 ---
setup_fixture
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateMihomoYaml >/dev/null 2>&1
  mf="$HIHY_ROOT_DIR/Hy2-testnode-mihomo.yaml"
  if yq eval '.' "$mf" >/dev/null 2>&1; then echo "PASS: mihomo yq-parseable"; else echo "FAIL: mihomo yq parse" >&2; fi )
teardown_fixture
```
> 注:`generateMihomoYaml` 内的产物路径需为 `./Hy2-...`(相对当前目录),测试用 `cd "$HIHY_ROOT_DIR"` 隔离产物。若 fixture 缺 `FAIL` 计数联动,统一在文件末尾 `grep -q '^FAIL' ` 由 CI 视 stderr;保持既有 `FAIL` 变量模式即可(把新块的 `echo FAIL` 改为调用 `fail "..."`)。

- [ ] **Step 2: 运行确认失败(函数名仍是旧的)**

Run:
```bash
bash server/test_client_config.sh; echo "exit=$?"
```
Expected: mihomo 相关断言 FAIL(`generateMihomoYaml: command not found`)。

- [ ] **Step 3: 重写 generateMihomoYaml**

把 `server/src/74-client-mihomo.sh` 的 `generateMetaYaml` 改为 `generateMihomoYaml`,并按下述规则重写动态字段部分(静态 heredoc 头——`mixed-port`/`dns`/`rule-providers`/`rules`——保留,但:① rule-provider 的 URL 前缀由 `HIHY_RULESET_MIRROR` 构造;② 删除 `rules` 中的 `GEOIP,LAN` 行,保留 `RULE-SET,lancidr,DIRECT`)。动态字段块替换为:
```bash
generateMihomoYaml() {
    loadClientParams
    local remarks="$HIHY_CP_remarks"
    local metaFile="./Hy2-${remarks}-mihomo.yaml"
    local mirror="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
    [ -f "$metaFile" ] && rm -f "$metaFile"
    touch "$metaFile"

    # ---- 静态头:此处 cat heredoc 写入 general/dns/rule-providers/rules ----
    # (保留原有内容,但 rule-provider url 改为 "${mirror}/Loyalsoldier/clash-rules@release/<name>.txt")
    # (删除 rules 中的 "  - GEOIP,LAN,DIRECT" 行)
    _mihomo_write_static_head "$metaFile" "$mirror"

    # ---- 动态 proxies[0] ----
    addOrUpdateYaml "$metaFile" "proxies[0].name" "${remarks}"
    addOrUpdateYaml "$metaFile" "proxies[0].type" "hysteria2"

    if [ "$HIHY_CP_realmMode" = "true" ]; then
        # Realm: 官方示例保留顶层 server(用 realm host),端口省略;realm-opts 承载细节
        parseRealmURI "$HIHY_CP_realmURI"
        addOrUpdateYaml "$metaFile" "proxies[0].server" "${HIHY_CP_serverAddress}"
        yq eval 'del(.proxies[0].port)' -i "$metaFile"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.enable" "true"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.server-url" "${HIHY_REALM_SERVER_URL}"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.token" "${HIHY_REALM_TOKEN}"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.realm-id" "${HIHY_REALM_ID}" "string"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.stun-servers[0]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$metaFile" "proxies[0].realm-opts.stun-servers[1]" "global.stun.twilio.com:3478"
    else
        addOrUpdateYaml "$metaFile" "proxies[0].server" "${HIHY_CP_serverAddress}"
        addOrUpdateYaml "$metaFile" "proxies[0].port" "${HIHY_CP_port}"
        if [ "$HIHY_CP_phStatus" = "true" ]; then
            addOrUpdateYaml "$metaFile" "proxies[0].ports" "${HIHY_CP_phStart}-${HIHY_CP_phEnd}"
            if [ "$HIHY_CP_phIntervalMode" = "random" ]; then
                addOrUpdateYaml "$metaFile" "proxies[0].hop-interval" "$(echo "$HIHY_CP_phMinHopInterval" | tr -dc 0-9)-$(echo "$HIHY_CP_phMaxHopInterval" | tr -dc 0-9)" "string"
            else
                addOrUpdateYaml "$metaFile" "proxies[0].hop-interval" "$(echo "$HIHY_CP_phHopInterval" | tr -dc 0-9)"
            fi
        fi
    fi

    addOrUpdateYaml "$metaFile" "proxies[0].password" "${HIHY_CP_auth}"

    # 拥塞:仅 brutal 输出 up/down;bbr 输出 bbr-profile;reno 两者皆省
    if [ "$HIHY_CP_congestionMode" = "brutal" ]; then
        local up_num down_num
        up_num=$(echo "$HIHY_CP_up" | tr -dc 0-9)
        down_num=$(echo "$HIHY_CP_down" | tr -dc 0-9)
        addOrUpdateYaml "$metaFile" "proxies[0].up" "${up_num} Mbps"
        addOrUpdateYaml "$metaFile" "proxies[0].down" "${down_num} Mbps"
    else
        yq eval 'del(.proxies[0].up, .proxies[0].down)' -i "$metaFile"
        if [ "$HIHY_CP_congestionMode" = "bbr" ] && [ "$HIHY_CP_bbrProfile" != "standard" ]; then
            addOrUpdateYaml "$metaFile" "proxies[0].bbr-profile" "${HIHY_CP_bbrProfile}"
        fi
    fi

    # 证书
    if [ -n "$HIHY_CP_pinSHA256" ]; then
        addOrUpdateYaml "$metaFile" "proxies[0].skip-cert-verify" "false"
        addOrUpdateYaml "$metaFile" "proxies[0].fingerprint" "${HIHY_CP_pinSHA256}" "string"
    else
        addOrUpdateYaml "$metaFile" "proxies[0].skip-cert-verify" "${HIHY_CP_insecure}"
        yq eval 'del(.proxies[0].fingerprint)' -i "$metaFile"
    fi

    # 混淆:gecko 不应走到这里(调用方已拦截),仅处理 salamander
    if [ "$HIHY_CP_obfsStatus" = "true" ] && [ "$HIHY_CP_obfsType" = "salamander" ]; then
        addOrUpdateYaml "$metaFile" "proxies[0].obfs" "salamander"
        addOrUpdateYaml "$metaFile" "proxies[0].obfs-password" "${HIHY_CP_obfsPass}"
    else
        yq eval 'del(.proxies[0].obfs, .proxies[0].obfs-password)' -i "$metaFile"
    fi

    addOrUpdateYaml "$metaFile" "proxies[0].sni" "${HIHY_CP_sni}"
    addOrUpdateYaml "$metaFile" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "$metaFile" "proxy-groups[0].type" "select"
    addOrUpdateYaml "$metaFile" "proxy-groups[0].proxies" "[${remarks}]"

    echoColor purple "\n$(i18n client_mihomo_file_hint "$(echoColor green "${metaFile}")")"
}
```
并新增 `_mihomo_write_static_head()`:把原 `generateMetaYaml` 里那段 `cat <<EOF >${metaFile} … EOF` 静态内容搬进去,形参 `$1`=文件、`$2`=mirror;把每个 rule-provider 的 `url:` 改为 `"${2}/Loyalsoldier/clash-rules@release/<name>.txt"`;删除 `- GEOIP,LAN,DIRECT` 行。

> **实现时务必**联网核对 mihomo `realm-opts` 字段名与顶层 server/port 语义(spec 5.5 标注),以真实 mihomo 内核 `-t` 校验配置合法性后定稿;STUN 列表可复用原生配置清单。

- [ ] **Step 4: 调用方改名 + gecko 拦截**

在 `server/src/72-client-native.sh` 末尾,把 `generateMetaYaml` 调用改为:
```bash
    if [ "${HIHY_CP_realmMode}" != "true" ] && [ "${HIHY_CP_obfsType}" = "gecko" ]; then
        echoColor yellow "$(i18n client_mihomo_gecko_skip)"
    else
        generateMihomoYaml
    fi
```
> 注意:此处 `HIHY_CP_*` 需已由本函数内 `loadClientParams` 赋值;确保调用在其后。

- [ ] **Step 5: 补 i18n 文案 key**

对 `server/i18n/{en,zh,fa,ru}.json` 各加两个 key(值按语言翻译):
- `client_mihomo_file_hint`:en=`"📱 [Clash Verge Rev/FlClash/ClashMeta for Android/OpenClash] mihomo config file: %s"`,zh=`"📱 [Clash Verge Rev/FlClash/ClashMeta安卓版/OpenClash] mihomo 配置文件: %s"`
- `client_mihomo_gecko_skip`:en=`"Note: mihomo does not support gecko obfuscation; use the native config or sing-box instead. Skipping mihomo config."`,zh=`"提示: mihomo 不支持 gecko 混淆,请使用原生配置或 sing-box,已跳过 mihomo 配置。"`
- fa/ru 同 key 翻译(短句)。

- [ ] **Step 6: 组装 + 测试 + i18n 校验**

Run:
```bash
bash scripts/build.sh
bash server/test_client_config.sh
bash scripts/i18n-validate.sh
```
Expected: mihomo 断言全 PASS;i18n 校验通过。

- [ ] **Step 7: 提交**

Run:
```bash
git add server/src/74-client-mihomo.sh server/src/72-client-native.sh server/i18n/ server/hy2.sh server/test_client_config.sh
git commit -m "fix(mihomo): congestion/gecko/bbr-profile/hop-interval fixes + rename to mihomo"
```

---

## Phase 4:sing-box 客户端配置(新增)

### Task 5: 新增 generateSingboxJson

**Files:**
- Create: `server/src/76-client-singbox.sh`
- Modify: `server/src/72-client-native.sh`(输出编排追加调用)
- Modify: `server/test_client_config.sh`(追加 sing-box 断言)
- Modify: `server/i18n/*.json`(新增文案)

**Interfaces:**
- Consumes: `loadClientParams`、`parseRealmURI`、`HIHY_RULESET_MIRROR`、`HIHY_ROOT_DIR`
- Produces: `generateSingboxJson()` — 输出 `./Hy2-${HIHY_CP_remarks}-singbox.json`;端口跳跃用 `server_ports:["a:b"]`;BBR/Reno 省 `up_mbps`/`down_mbps`;自签内嵌 CA PEM;realm 省 `server_port`。

- [ ] **Step 1: 追加 sing-box 断言到 test_client_config.sh**

在汇总行前插入:
```bash
# --- sing-box: 产物是合法 JSON ---
setup_fixture
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateSingboxJson >/dev/null 2>&1
  sf="$HIHY_ROOT_DIR/Hy2-testnode-singbox.json"
  if yq -p json eval '.' "$sf" >/dev/null 2>&1; then echo "PASS: singbox valid json"; else fail "singbox json invalid"; fi )
teardown_fixture

# --- sing-box: BBR 省 up_mbps/down_mbps ---
setup_fixture
sed -i 's/congestionMode: brutal/congestionMode: bbr/' "$HIHY_ROOT_DIR/conf/backup.yaml"
echo 'congestionType: bbr' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateSingboxJson >/dev/null 2>&1
  sf="$HIHY_ROOT_DIR/Hy2-testnode-singbox.json"
  if ! grep -q 'up_mbps' "$sf" && ! grep -q 'down_mbps' "$sf"; then echo "PASS: singbox bbr omits mbps"; else fail "singbox bbr mbps present"; fi )
teardown_fixture

# --- sing-box: realm 模式省 server_port ---
setup_fixture
cat >> "$HIHY_ROOT_DIR/conf/backup.yaml" <<'YML'
YML
sed -i 's/realmMode: false/realmMode: true/' "$HIHY_ROOT_DIR/conf/backup.yaml"
echo 'realmURI: realm://public@realm.hy2.io/abc-123' >> "$HIHY_ROOT_DIR/conf/backup.yaml"
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateSingboxJson >/dev/null 2>&1
  sf="$HIHY_ROOT_DIR/Hy2-testnode-singbox.json"
  if ! grep -q 'server_port' "$sf" && grep -q 'realm' "$sf"; then echo "PASS: singbox realm omits server_port"; else fail "singbox realm server_port"; fi )
teardown_fixture

# --- sing-box: 自签内嵌证书且 insecure=false ---
setup_fixture
mkdir -p "$HIHY_ROOT_DIR/result"
printf -- '-----BEGIN CERTIFICATE-----\nMIICtestCAdata\n-----END CERTIFICATE-----\n' > "$HIHY_ROOT_DIR/result/helloworld.com.ca.crt"
( cd "$HIHY_ROOT_DIR" && load_funcs && loadClientParams && generateSingboxJson >/dev/null 2>&1
  sf="$HIHY_ROOT_DIR/Hy2-testnode-singbox.json"
  if grep -q 'BEGIN CERTIFICATE' "$sf" && yq -p json eval '.outbounds[0].tls.insecure' "$sf" | grep -q false; then echo "PASS: singbox embeds CA, insecure=false"; else fail "singbox CA embed"; fi )
teardown_fixture
```

- [ ] **Step 2: 运行确认失败**

Run:
```bash
bash server/test_client_config.sh; echo "exit=$?"
```
Expected: sing-box 断言 FAIL(`generateSingboxJson: command not found`)。

- [ ] **Step 3: 实现 generateSingboxJson**

Create `server/src/76-client-singbox.sh`:
```bash
#!/bin/bash

# 生成 sing-box 客户端配置(基线 1.11+;realm/gecko/bbr_profile 需 1.14+)
generateSingboxJson() {
    loadClientParams
    local remarks="$HIHY_CP_remarks"
    local root="${HIHY_ROOT_DIR:-/etc/hihy}"
    local mirror="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
    local outFile="./Hy2-${remarks}-singbox.json"
    [ -f "$outFile" ] && rm -f "$outFile"

    # ---- 组装 hysteria2 outbound 的可选字段片段 ----
    local server_block obfs_block cc_block tls_block

    if [ "$HIHY_CP_realmMode" = "true" ]; then
        parseRealmURI "$HIHY_CP_realmURI"
        # realm 模式:省略 server/server_port,使用 realm 块
        server_block=$(cat <<JSON
      "realm": {
        "server_url": "${HIHY_REALM_SERVER_URL}",
        "token": "${HIHY_REALM_TOKEN}",
        "realm_id": "${HIHY_REALM_ID}",
        "stun_servers": ["stun.nextcloud.com:3478", "global.stun.twilio.com:3478"]
      },
JSON
)
    elif [ "$HIHY_CP_phStatus" = "true" ]; then
        server_block=$(cat <<JSON
      "server": "${HIHY_CP_serverAddress}",
      "server_ports": ["${HIHY_CP_phStart}:${HIHY_CP_phEnd}"],
      "hop_interval": "${HIHY_CP_phHopInterval}",
JSON
)
    else
        server_block=$(cat <<JSON
      "server": "${HIHY_CP_serverAddress}",
      "server_port": ${HIHY_CP_port},
JSON
)
    fi

    if [ "$HIHY_CP_obfsStatus" = "true" ]; then
        obfs_block=$(cat <<JSON
      "obfs": { "type": "${HIHY_CP_obfsType}", "password": "${HIHY_CP_obfsPass}" },
JSON
)
    else
        obfs_block=""
    fi

    if [ "$HIHY_CP_congestionMode" = "brutal" ]; then
        local up_num down_num
        up_num=$(echo "$HIHY_CP_up" | tr -dc 0-9)
        down_num=$(echo "$HIHY_CP_down" | tr -dc 0-9)
        cc_block="      \"up_mbps\": ${up_num},
      \"down_mbps\": ${down_num},"
    elif [ "$HIHY_CP_congestionMode" = "bbr" ] && [ "$HIHY_CP_bbrProfile" != "standard" ]; then
        cc_block="      \"bbr_profile\": \"${HIHY_CP_bbrProfile}\","
    else
        cc_block=""
    fi

    # TLS:自签内嵌 CA PEM;否则按 insecure
    local ca_file="$root/result/${HIHY_CP_sni}.ca.crt"
    if [ -n "$HIHY_CP_pinSHA256" ] && [ -f "$ca_file" ]; then
        # 把 PEM 转成 JSON 字符串数组(每行一个元素)
        local pem_json
        pem_json=$(awk 'BEGIN{ORS=""} {gsub(/\r/,""); printf "%s\"%s\"", (NR>1?", ":""), $0}' "$ca_file")
        tls_block=$(cat <<JSON
      "tls": {
        "enabled": true,
        "server_name": "${HIHY_CP_sni}",
        "insecure": false,
        "certificate": [${pem_json}]
      },
JSON
)
    else
        local insec="false"; [ "$HIHY_CP_insecure" = "true" ] && insec="true"
        tls_block=$(cat <<JSON
      "tls": {
        "enabled": true,
        "server_name": "${HIHY_CP_sni}",
        "insecure": ${insec}
      },
JSON
)
    fi

    # ---- 写完整配置 ----
    cat > "$outFile" <<JSON
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "google", "address": "tls://8.8.8.8", "detour": "PROXY" },
      { "tag": "local", "address": "https://dns.alidns.com/dns-query", "detour": "direct" }
    ],
    "rules": [ { "rule_set": "geosite-cn", "server": "local" } ],
    "final": "google"
  },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 20808 }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "PROXY",
${server_block}
${cc_block}
${obfs_block}
      "password": "${HIHY_CP_auth}",
${tls_block}
      "network": "udp"
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "rule_set": [
      { "type": "remote", "tag": "geosite-cn", "format": "binary", "url": "${mirror}/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs", "download_detour": "PROXY" },
      { "type": "remote", "tag": "geoip-cn", "format": "binary", "url": "${mirror}/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs", "download_detour": "PROXY" }
    ],
    "rules": [
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": ["geosite-cn", "geoip-cn"], "outbound": "direct" }
    ],
    "final": "PROXY"
  },
  "experimental": {
    "clash_api": { "external_controller": "127.0.0.1:9090" },
    "cache_file": { "enabled": true }
  }
}
JSON

    # 清理可能的空行(cc_block/obfs_block 为空时)并校验/格式化
    if command -v yq >/dev/null 2>&1; then
        yq -p json -o json eval '.' "$outFile" > "${outFile}.tmp" 2>/dev/null && mv "${outFile}.tmp" "$outFile" || rm -f "${outFile}.tmp"
    fi

    echoColor purple "\n$(i18n client_singbox_file_hint "$(echoColor green "${outFile}")")"
    echoColor yellow "$(i18n client_singbox_version_hint)"
}
```

> **实现时务必**:① 用真实 sing-box `check -c` 校验产物合法(尤其 realm/server_ports/certificate 字段);② 核对 `meta-rules-dat@sing` 的 `.srs` 路径在 jsdelivr 上真实存在,不存在则换 MetaCubeX 实际发布路径;③ 空 `cc_block`/`obfs_block` 行由 `yq` 重新序列化时会消失,若未安装 yq 则需删除空行——保证 JSON 合法。

- [ ] **Step 4: 输出编排追加 sing-box**

在 `server/src/72-client-native.sh` 的 mihomo 调用块之后追加:
```bash
    generateSingboxJson
```

- [ ] **Step 5: 补 i18n 文案**

各语言加:
- `client_singbox_file_hint`:en=`"📦 [sing-box/SFA/SFI/SFM/SFT] sing-box config file: %s"`,zh=`"📦 [sing-box/SFA/SFI/SFM/SFT] sing-box 配置文件: %s"`
- `client_singbox_version_hint`:en=`"Note: requires sing-box 1.11+ (realm / gecko obfs / bbr_profile need 1.14+)."`,zh=`"提示: 需 sing-box 1.11+(realm / gecko 混淆 / bbr_profile 需 1.14+)。"`
- fa/ru 翻译。

- [ ] **Step 6: 组装 + 测试**

Run:
```bash
bash scripts/build.sh
bash server/test_client_config.sh
bash scripts/i18n-validate.sh
```
Expected: sing-box 断言全 PASS。

- [ ] **Step 7: 提交**

Run:
```bash
git add server/src/76-client-singbox.sh server/src/72-client-native.sh server/i18n/ server/hy2.sh server/test_client_config.sh
git commit -m "feat(singbox): add sing-box client config generation"
```

---

## Phase 5:镜像统一 + 收尾发布

### Task 7: 统一 rule-set 镜像变量声明

**Files:**
- Modify: `server/src/00-header.sh`(声明 `HIHY_RULESET_MIRROR`)

- [ ] **Step 1: 在 00-header.sh 加变量**

在 `00-header.sh` 的 `HIHY_*` 变量区加:
```bash
HIHY_RULESET_MIRROR="${HIHY_RULESET_MIRROR:-https://cdn.jsdelivr.net/gh}"
```

- [ ] **Step 2: 组装 + 确认两个生成器都读到默认值**

Run:
```bash
bash scripts/build.sh
bash server/test_client_config.sh
grep -c 'cdn.jsdelivr.net' <(cd /tmp && HIHY_ROOT_DIR=$(mktemp -d) bash -c 'true') || true
bash -n server/hy2.sh && echo SYNTAX_OK
```
Expected: 测试通过;语法 OK。

- [ ] **Step 3: 提交**

Run:
```bash
git add server/src/00-header.sh server/hy2.sh
git commit -m "feat(client): unified ruleset mirror via HIHY_RULESET_MIRROR (default jsdelivr)"
```

---

### Task 8: i18n-validate 增强(占位符一致性)

**Files:**
- Modify: `scripts/i18n-validate.sh`

- [ ] **Step 1: 读现有 validate 脚本**

Run:
```bash
cat scripts/i18n-validate.sh
```
Expected: 了解现有 key 一致性校验实现。

- [ ] **Step 2: 追加 printf 占位符一致性检查**

在 `scripts/i18n-validate.sh` 末尾(汇总前)加入:对每个 key,以 `en.json` 为基准统计 `%s`/`%d` 出现次数,遍历 zh/fa/ru 同 key,数量不等则报错累加。用 `grep -o '%[sd]' | wc -l` 计数(纯 bash + grep,不依赖 jq)。示例:
```bash
check_placeholders() {
    local base="server/i18n/en.json"
    local langs="zh fa ru"
    local err=0
    # 逐 key 提取(沿用脚本已有的 key 提取方式);对每个 key:
    #   base_count=$(printf '%s' "$en_value" | grep -o '%[sd]' | wc -l)
    #   lang_count=$(printf '%s' "$lang_value" | grep -o '%[sd]' | wc -l)
    #   [ "$base_count" != "$lang_count" ] && { echo "placeholder mismatch: $key ($lang)"; err=1; }
    return $err
}
```
> 按现有脚本的 key/value 提取风格实现;保持无 jq 依赖。

- [ ] **Step 3: 运行校验**

Run:
```bash
bash scripts/i18n-validate.sh; echo "exit=$?"
```
Expected: 通过(`exit=0`);若新增文案占位符不一致会被抓出并修正。

- [ ] **Step 4: 提交**

Run:
```bash
git add scripts/i18n-validate.sh
git commit -m "test(i18n): validate printf placeholder consistency across catalogs"
```

---

### Task 9: 版本号 + 文档同步 → ver1.12

**Files:**
- Modify: `server/src/00-header.sh`(`hihyV="ver1.12"`)
- Modify: `README.md`(头部版本 + 变更日志)
- Modify: `md/logs.md`(历史追加)
- Modify: `md/client.md`(mihomo/sing-box 说明)
- Modify: `CLAUDE.md`(版本、strict mode 纠正、构建说明、模块结构)

- [ ] **Step 1: 改版本号**

在 `server/src/00-header.sh` 把 `hihyV="ver1.11"` 改为 `hihyV="ver1.12"`。

- [ ] **Step 2: README 头部变更日志**

在 `README.md` 第 2 行版本与代码块按既有格式追加 ver1.12 条目,概述:mihomo 配置修复并改名、新增 sing-box 客户端配置、脚本模块化重构、i18n 多语言支持。

- [ ] **Step 3: md/logs.md 追加历史条目**;**md/client.md 增补** mihomo(改名说明)与 sing-box 客户端下载/导入指引及最低版本要求。

- [ ] **Step 4: 更新 CLAUDE.md**

- 版本 ver1.11 → ver1.12;
- 纠正"All scripts use `set -euo pipefail`":实为 install.sh/测试用严格模式,主脚本 hy2.sh 未启用;
- 新增"构建"说明:改 `server/src/*.sh` 后跑 `bash scripts/build.sh` 重新生成 `server/hy2.sh`;`server/hy2.sh` 是产物勿手改;
- 更新架构段:hy2.sh 现为 `server/src/` 模块组装产物;新增客户端生成器 mihomo/sing-box;i18n 目录;
- 测试段补 `test_build.sh`、`test_client_config.sh`、`scripts/i18n-validate.sh`。

- [ ] **Step 5: 组装 + 全量测试**

Run:
```bash
bash scripts/build.sh
grep -n 'ver1.12' server/hy2.sh | head -1
bash server/test_build.sh
bash server/test_bootstrap_install.sh
bash server/test_install_recovery.sh
bash server/test_client_config.sh
bash scripts/i18n-validate.sh
bash -n server/hy2.sh && echo SYNTAX_OK
```
Expected: 全绿;`ver1.12` 出现在产物。

- [ ] **Step 6: 提交**

Run:
```bash
git add server/src/00-header.sh server/hy2.sh README.md md/logs.md md/client.md CLAUDE.md
git commit -m "chore: bump to ver1.12, update README/CLAUDE.md/client docs"
```

---

### Task 10: 最终验证 + 推送

- [ ] **Step 1: 全量回归 + 产物新鲜度**

Run:
```bash
bash scripts/build.sh
git diff --exit-code server/hy2.sh && echo "PRODUCT_IN_SYNC"
for t in test_build test_bootstrap_install test_install_recovery test_client_config; do
  echo "== $t =="; bash server/$t.sh || exit 1
done
bash scripts/i18n-validate.sh
```
Expected: `PRODUCT_IN_SYNC` + 每个测试通过。

- [ ] **Step 2: 核对提交历史**

Run:
```bash
git log --oneline pre-i18n-merge-backup..HEAD
```
Expected: 依次可见 merge、refactor、test_build、client-common、mihomo、singbox、mirror、i18n-validate、chore 各提交。

- [ ] **Step 3: 推送**

Run:
```bash
git push origin main
```
Expected: 推送成功。

- [ ] **Step 4: 清理备份 tag**

Run:
```bash
git tag -d pre-i18n-merge-backup
```

---

## Self-Review 结论

- **Spec 覆盖**:模块化(Task 1-3)、i18n 并入(Task 0)、公共层(Task 6)、mihomo 修复+改名(Task 4)、sing-box 新增(Task 5)、镜像统一(Task 7)、i18n 校验增强(Task 8)、版本+文档(Task 9)、发布(Task 10)——spec 各节均有对应任务。
- **已知实现期需联网二次核对项**(spec 已标注,任务内以 `实现时务必` 提示):mihomo realm-opts 字段与 server/port 语义、sing-box realm/server_ports/certificate 合法性、`meta-rules-dat@sing` 的 `.srs` jsdelivr 路径、mihomo `GEOIP,LAN` 处置。
- **类型一致性**:`HIHY_CP_*` / `HIHY_REALM_*` 变量名在 Task 6 定义,Task 4/5 复用一致;`generateMihomoYaml`/`generateSingboxJson`/`loadClientParams`/`parseRealmURI` 命名全程统一。
- **占位符**:无 TBD;机械搬运(Task 2)以"功能等价 + 现有测试"为验收,非代码空位。
