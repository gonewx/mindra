# Mindra iOS 发布链路（完整工作流）

> 2026-08 确定的现行方案。核心原则：**签名证书不进 GitHub Secrets、不进任何 CI**；
> 证书管理与 TestFlight 上传由 appuploader（GUI）完成，编译在离线 Mac VM 上做，
> 衔接全部通过 **mise 任务**入口。
>
> 本文档是**按操作顺序编排的完整工作流**：从零开始照着走一遍「阶段一」就能完成
> 首次发布；之后每次发版只走「阶段二」。

## 目录

- [总览](#总览)
- [固定参数速查](#固定参数速查)
- [阶段一：首次配置与首次发布（只做一次）](#阶段一首次配置与首次发布只做一次)
  - [步骤 1：App Store Connect 创建 Team API Key](#步骤-1app-store-connect-创建-team-api-key)
  - [步骤 2：appuploader 导入 API Key 并登录](#步骤-2appuploader-导入-api-key-并登录)
  - [步骤 3：appuploader 注册 App ID](#步骤-3appuploader-注册-app-id)
  - [步骤 4：appuploader 创建发布证书（.p12）](#步骤-4appuploader-创建发布证书p12)
  - [步骤 5：appuploader 创建描述文件（.mobileprovision）](#步骤-5appuploader-创建描述文件mobileprovision)
  - [步骤 6：签名资产装进编译机](#步骤-6签名资产装进编译机)
  - [步骤 7：验证签名状态](#步骤-7验证签名状态)
  - [步骤 8：App Store Connect 创建应用记录](#步骤-8app-store-connect-创建应用记录)
  - [步骤 9：编译并回收 IPA](#步骤-9编译并回收-ipa)
  - [步骤 10：appuploader 上传 TestFlight](#步骤-10appuploader-上传-testflight)
  - [步骤 11：填写商店元数据并提交审核](#步骤-11填写商店元数据并提交审核)
- [阶段二：日常迭代发布](#阶段二日常迭代发布)
- [版本号规则](#版本号规则)
- [关键文件](#关键文件)
- [故障排查](#故障排查)

## 总览

```
┌─────────────────────── 宿主 Linux ───────────────────────┐
│                                                          │
│  appuploader (GUI)              mise 任务入口            │
│  ├─ 申请 Distribution 证书      ├─ ios:vm:signing:import │
│  ├─ 创建 profile               ├─ ios:vm:archive        │
│  ├─ 导出 .p12 / .mobileprovision├─ ios:sync:back        │
│  └─ 上传 IPA 到 TestFlight      └─ ios:build:bump       │
│         ↑ 手动操作                     │ 自动            │
└─────────┼──────────────────────────────┼─────────────────┘
          │ .p12/.mobileprovision        │ rsync
          ↓                              ↓
┌─────────────────── Mac 编译机（离线 VM）──────────────────┐
│  imacvm-tahoe（SSH 别名），~/mindra 项目副本              │
│  ├─ ios_signing_import.sh   装证书+profile，写签名配置   │
│  └─ ios_archive.sh          编译签名出 IPA               │
│         │                                                │
│         └─ 已加固：/etc/hosts 阻断 Apple 端点，           │
│            任何联系 Apple 的操作在这里都会失败（预期行为）  │
└──────────────────────────────────────────────────────────┘
```

### 职责分工

| 环节 | 在哪做 | 谁做 |
|---|---|---|
| 创建 API Key / 应用记录 / 填商店元数据 | App Store Connect 网页 | 手动 |
| 申请 Distribution 证书、注册 App ID、创建 profile | 宿主 Linux | appuploader 手动操作 |
| 签名资产装进编译机 | VM（远程触发） | `mise run ios:vm:signing:import` |
| 编译签名出 IPA | VM（远程触发） | `mise run ios:vm:archive` |
| IPA 回宿主 | 宿主 Linux | `mise run ios:sync:back` |
| 上传 TestFlight | 宿主 Linux | appuploader 手动选文件 |

### 为什么这样设计

- **证书不出本机**：签名的 p12 只在宿主和编译机之间传递，不经过任何第三方（含 GitHub）。
- **VM 纯离线**：封号风险不在"用 VM 编译"（纯本地不联网），而在"用 VM 联系 Apple"（Xcode 登录/自动签名/Organizer 上传会上报硬件指纹）。所以编译机彻底离线，联系 Apple 的动作全部在宿主侧完成——appuploader 走 ASC API（请求里只有 JWT，无硬件信息）。
- **上传不走 altool/iTMSTransporter**：它们要在 Mac 上联系 Apple。appuploader 的纯 HTTP 上传在 Linux 上完成。

### mise 任务一览（宿主 Linux 上运行）

| 任务 | 作用 |
|---|---|
| `ios:vm:signing:import` | 递送 .p12/.mobileprovision 到编译机并导入（参数透传：`-- -c <p12路径> -p <profile路径>`） |
| `ios:vm:signing:status` | 远程查看编译机签名资产状态 |
| `ios:vm:archive` | **先自动同步代码**，再远程在编译机上构建 IPA |
| `ios:sync:push` | 只同步代码到编译机 |
| `ios:sync:back` | 从编译机回收 IPA 到宿主 `build/ios/ipa/` |
| `ios:sync:status` | 查看编译机环境（Xcode、项目、磁盘） |
| `ios:build:bump` | iOS build number +1（TestFlight 要求递增） |

编译机上直接运行的（一般用不着，远程任务已覆盖）：
`ios:signing:status` / `ios:signing:import` / `ios:signing:reset` / `ios:archive`。

## 固定参数速查

| 参数 | 值 | 说明 |
|---|---|---|
| Bundle ID | `com.gonewx.mindra.app` | 全平台统一 |
| Team ID | `97W62GB3JA` | App ID Prefix 会自动带出 |
| SSH 别名（编译机） | `imacvm-tahoe` | 可用 `MINDRA_VM_HOST` 覆盖 |
| VM 项目目录 | `~/mindra` | — |
| VM 签名资产中转目录 | `~/mindra-transfer` | 可用 `MINDRA_TRANSFER_DIR` 覆盖 |
| marketing version | `1.0.0` | 取自 `pubspec.yaml` |
| iOS build number | 见 `ios/build_number.txt`（当前 1，独立计数） | `ios:build:bump` 递增 |

---

## 阶段一：首次配置与首次发布（只做一次）

> 前提：付费 Apple Developer Program 账号已生效。
> 没生效时 Individual/免费账号签的证书和 profile 只有 7 天有效期，且无法上传 App Store。

### 步骤 1：App Store Connect 创建 Team API Key

在 [App Store Connect](https://appstoreconnect.apple.com) 网页：**用户和访问 → 集成 → 生成 API 密钥**。

| 字段 | 填法 | 说明 |
|---|---|---|
| 名称 | `appuploader` | API Key 绑定的是**开发者账号**而非某个 App，按用途/工具命名（不要用 `Mindra` 这类产品名，以后第二个 App 上架时会误导） |
| 访问 | **Team Keys（团队密钥）** | ⚠️ Individual Key 没有 Provisioning 权限，appuploader 建 profile 会失败，**这是唯一硬性要求** |
| 角色（Role） | **Admin** | appuploader 要建证书/注册 App ID/建 profile/上传构建版本；App Manager 也够用，Admin 最省事 |

生成后**三件套都要记录**（下一步导入时全部要用）：

1. **Key ID**：密钥列表里的 10 位 ID
2. **Issuer ID**：页面顶部的 UUID
3. **.p8 文件**：点 Download 下载，**只能下载一次**，关掉页面就再也无法下载

> ⚠️ .p8 是账号最高权限凭据，只粘贴到本机 appuploader，不要贴到任何网页或聊天工具。

### 步骤 2：appuploader 导入 API Key 并登录

打开 appuploader → 添加账号 → 录入方式选 **API 密钥**，「添加 API 密钥」对话框：

| 字段 | 填法 | 说明 |
|---|---|---|
| 名称 | `Mindra`（或 `appuploader`） | 本机账号列表里的备注名，随便起 |
| Issuer ID | ASC 页面顶部的 UUID | 三件套之一 |
| Key ID | 密钥列表里的 10 位 ID | 三件套之一 |
| Private Key | **粘贴 .p8 文件全文** | 是**文本框**不是选文件按钮；从 `-----BEGIN PRIVATE KEY-----` 到 `-----END PRIVATE KEY-----` 整段复制（含首尾行），用纯文本编辑器打开（如 `cat`/VS Code），别用 Word 类富文本软件 |

登录后注意：

- API 密钥登录是**无状态 JWT 认证**：免密码、免双重验证、长期有效；.p8 私钥只保存在本地
- 一个 Apple ID 可属于多个团队，登录后在**账号概览**确认当前激活团队是自己的
  Team（`97W62GB3JA`）——证书、Bundle ID、描述文件都基于当前激活团队
- 若提示「待同意 Apple 协议」，点「查看并同意」逐份处理；涉及税务/银行的协议要去
  developer.apple.com 网页处理

### 步骤 3：appuploader 注册 App ID

appuploader 主界面 → Bundle ID / App ID 管理 → **Register an App ID**：

| 字段 | 填法 | 说明 |
|---|---|---|
| Platform | iOS | — |
| App ID Prefix | 自动带出 Team ID（`97W62GB3JA`），不用动 | — |
| Description | `Mindra` | **内部备注名**，只在 Identifiers 列表里显示，不上商店页面 |
| Bundle ID | 选 **Explicit**，填 `com.gonewx.mindra.app` | 与项目 Bundle ID 一致，不能含 `*` |
| Capabilities / App Services / Capability Requests | **全部不勾，保持默认** | 见下方说明 |

> 坑：App ID 的 Description 字段禁用特殊字符（`@` `&` `*` `"`），填 `Meditation & Mindfulness` 这类带 `&` 的文本会报错。
> 它和 App Store Connect 商店页面的**副标题是两回事**——ASC 网页的副标题允许 `&`，不需要因此改文案。

> Capabilities 为什么全不勾（对应项目实际情况）：
> - 本地通知提醒（flutter_local_notifications）不走 APNs，**不需要** Push Notifications
> - 后台播放音频是 Info.plist 的 `UIBackgroundModes: audio`，不是 App ID capability
> - 勾了用不到的 capability（如 Push）会让 profile 带 `aps-environment` 而 App 二进制没有对应
>   entitlements，签名配置不一致；部分 Capability Requests 还要等 Apple 确认生效，拖慢流程
> - 以后需要（如远程推送）随时回来编辑 App ID 勾上并重新生成 profile 即可

### 步骤 4：appuploader 创建发布证书（.p12）

appuploader 主界面 → **证书管理 → 添加**：

| 字段 | 填法 | 说明 |
|---|---|---|
| 类型 | **distribution**（Apple Distribution / iOS Distribution） | 发布上架用；development 是真机调试用的，本项目用不上 |
| 名称 | `MindraDistribution`（字母数字组合） | 证书备注名 |
| 密码 | 自定义（字母数字组合） | **这是 p12 文件密码**，不是 Apple 账号密码；步骤 6 要输的就是它，**忘了无法找回只能重建** |

appuploader 会自动生成 CSR、向 Apple 请求签发并合成 `.p12`，**全程不需要 Mac**。
生成后**导出/下载 .p12 文件**保存。

> 坑：不要走「Create a New Certificate → Upload a Certificate Signing Request」入口——那是 Apple
> 开发者网站的手动 CSR 流程（给有 Mac 钥匙串的人用的），在 appuploader 里完全不需要。
>
> 发布证书与 App 不是一一对应，一个证书可签多个 App，以后新 App 无需再建。
> 若发现证书有效期只剩几天，说明签发用的是免费账号（7 天期），检查 appuploader 登录的账号。

### 步骤 5：appuploader 创建描述文件（.mobileprovision）

appuploader 主界面 → **描述文件管理 → 新建描述文件**：

| 字段 | 填法 | 说明 |
|---|---|---|
| 描述文件名称 | `MindraAppStore`（字母数字组合） | 备注名 |
| 描述文件类型 | **App Store** | 发布上架用；Development 是真机调试用（还要勾选测试设备 UDID），本项目用不上 |
| Bundle ID | `com.gonewx.mindra.app` | 下拉选择；没有就点「添加 Bundle」回到步骤 3 |

制作完成后**下载 `.mobileprovision` 文件**保存。注意：profile 与 Bundle ID 绑定（每个 App 一份），
但多个 App 可共用同一张证书。

**步骤 4/5 产出的两个文件的存放与命名**

| 项 | 要求 |
|---|---|
| 存放位置 | 统一放宿主机 `~/下载/`（或任意**项目目录外**的位置）；`.gitignore` 已忽略 `*.p12` / `*.mobileprovision` / `*.p8`，即使误放进项目目录也不会进 git，但仍建议放项目外，避免误同步到编译机 |
| 命名 | 文件名**无任何要求**——导入脚本只认内容（按 profile 内的 UUID 归档、解析出 Team ID），不解析文件名。建议命名 `dist.p12` + `mindra.mobileprovision`，与下文命令一致 |
| 备份 | `.p12` **丢了无法补发**（Apple 侧只能重新签发新证书），和 .p8 一起离线备份一份（加密 U 盘/密码管理器附件） |
| 密码 | `.p12` 的密码与文件**分开存放**，别写在同一目录的笔记里 |

### 步骤 6：签名资产装进编译机

在宿主机 `mindra/` 目录执行。**文件路径由 `-c` / `-p` 参数现填**——脚本不依赖固定位置，
你的文件在哪就叫什么名字，就把实际路径写上去：

```bash
cd /mnt/disk0/project/mindra/mindra_cc/mindra/

# 不确定文件实际叫什么就先看一眼
ls -l ~/下载/*.p12 ~/下载/*.mobileprovision

# 用实际路径执行（会提示输 p12 密码，即步骤 4 创建证书时设的密码）
mise run ios:vm:signing:import -- -c ~/下载/dist.p12 -p ~/下载/mindra.mobileprovision

# 免交互方式：提前 export MINDRA_P12_PASSWORD='密码'
# 换证书/profile 重灌：加 --reset
#   mise run ios:vm:signing:import -- --reset -c <p12> -p <profile>
```

脚本自动完成（**不需要手动填任何签名参数**）：

- scp 两个文件到 VM 中转目录 `~/mindra-transfer/`，再远程执行导入
- 证书装进**专用 keychain**（`mindra-signing.keychain-db`，非 login keychain，不需要登录密码）
- profile 按 UUID 命名装到 Xcode 的 profile 目录
- 解析 profile 得到 **Team ID** 和 **profile 名**，写入 `ios/Flutter/Signing.xcconfig`
- 校验 profile 的 App ID 与项目 Bundle ID 匹配、没过期、不是 7 天期的免费账号 profile
- 密码通过 stdin 传给远端脚本，不进进程列表与 history

### 步骤 7：验证签名状态

```bash
mise run ios:vm:signing:status
```

应看到**证书、profile、Signing.xcconfig 三项全绿**。有红的按提示补（通常是文件没送对
或密码错了，回步骤 6 重跑）。

### 步骤 8：App Store Connect 创建应用记录

**上传 IPA 之前必须先有应用记录**（appuploader 上传时按 Bundle ID 匹配应用）。
在 [App Store Connect](https://appstoreconnect.apple.com) 网页 → 我的 App → 「+」→ 新建 App：

| 字段 | 填法 |
|---|---|
| 平台 | iOS |
| 名称 | `Mindra`（App 名称全 App Store 唯一，被占用就换 `Mindra - 冥想与正念` 之类） |
| 主要语言 | 简体中文 |
| Bundle ID | `com.gonewx.mindra.app`（下拉选步骤 3 注册的） |
| SKU | `mindra-app`（内部标识，不对外展示，随意但唯一） |
| 用户访问权限 | 完全访问权限 |

### 步骤 9：编译并回收 IPA

```bash
cd mindra/

# 自动先同步代码到编译机，再远程编译签名（VM 上约 1-3 分钟）
mise run ios:vm:archive

# IPA 回宿主 build/ios/ipa/（脚本会打印出文件名和大小）
mise run ios:sync:back
```

> 如果这一步之前已经在别处构建过同版本 build number，先 `mise run ios:build:bump`
> 再 archive——TestFlight 要求 build number 严格递增，重复上传同一 build number 会被拒收。

### 步骤 10：appuploader 上传 TestFlight

appuploader → 提交上传 → 选择 `mindra/build/ios/ipa/` 下的 IPA 文件 → 上传。

上传后在 [App Store Connect](https://appstoreconnect.apple.com) → TestFlight 页面看处理状态
（几分钟到半小时），构建版本出现后即可添加内部测试者装机测试。

### 步骤 11：填写商店元数据并提交审核

在 ASC 网页的 App 页面完善各标签页。**完整字段值和截图规格见
[app_store_release_guide_ZH.md](app_store_release_guide_ZH.md)「Apple App Store 发布」一节**，
关键项速记：

| 项 | 值 |
|---|---|
| 副标题 | 冥想与正念（允许 `&` 等特殊字符，和 App ID 的 Description 是两回事） |
| 类别 | 主要：健康健美；次要：生活 |
| 内容分级 | 4+（填问卷） |
| 关键词 | 冥想,正念,放松,专注,健康,心理健康,减压,睡眠,瑜伽,呼吸 |
| 营销/支持/隐私政策 URL | https://mindra.gonewx.com 等（见发布指南） |
| 价格 | 免费 |
| 截图 | iPhone 至少 1 张，6.7" 用 1290x2796 px，PNG/JPG |
| App Review 联系信息 | 姓名/电话/邮箱（应用无需登录，不用给演示账户） |
| 版本说明 | 见发布指南「版本信息」 |

全部填好后点「提交以供审核」，等待审核结果（通常 1-7 天）。被拒时按拒绝原因修改后重新提交。

---

## 阶段二：日常迭代发布

首次发布完成后，每次更新版本只需：

```bash
cd mindra/

mise run ios:build:bump      # 1. build number +1（必须，否则 TestFlight 拒收）
mise run ios:vm:archive      # 2. 同步代码 + 编译签名
mise run ios:sync:back       # 3. IPA 回宿主
# 4. appuploader 里选新 IPA 上传
# 5. ASC → TestFlight 页面看处理状态（几分钟），添加测试者
# 6. 测试通过后，在 ASC 版本页面填「本次更新内容」→ 提交审核
```

## 版本号规则

| 项 | 取值 | 来源 |
|---|---|---|
| marketing version | `1.0.0` | `pubspec.yaml` 的 `version:`（`+` 前面的部分） |
| build number | `1, 2, 3...` | `ios/build_number.txt`，独立计数，从 1 起 |

注意 pubspec 里的 `+7` 与 iOS build number **无关**（那是本地构建计数的历史遗留）。
iOS 的 build number 只通过 `ios/build_number.txt` 管理，`ios:build:bump` 递增。

git tag 发布版本时照旧用 tag 递增（`v0.5.8` 起），与上述规则互不影响。

## 关键文件

| 文件 | 作用 | 进 git？ |
|---|---|---|
| `mindra/mise.toml` | 所有 iOS 任务入口 | ✅ |
| `mindra/scripts/ios_sync.sh` | 宿主↔VM 同步、资产递送 | ✅ |
| `mindra/scripts/ios_signing_import.sh` | VM 侧签名资产导入 | ✅ |
| `mindra/scripts/ios_archive.sh` | VM 侧编译签名出 IPA | ✅ |
| `mindra/ios/Flutter/Signing.xcconfig` | 签名参数（Team ID 等） | ❌ 已 ignore |
| `mindra/ios/Flutter/Signing.xcconfig.example` | 上面的模板 | ✅ |
| `mindra/ios/ExportOptions.plist.template` | IPA 导出选项模板 | ✅ |
| `mindra/ios/build_number.txt` | iOS build number | ✅ |

签名参数的流转：`pbxproj` 引用 `$(MINDRA_*)` 变量 → 变量定义在 `Signing.xcconfig` →
由导入脚本从 profile 自动解析写入。全程无人工填值，Team ID 不进版本库。

## 故障排查

**`mise run ios:vm:archive` 报 "No signing certificate / No profile matching"**
→ Signing.xcconfig 变量为空或证书没装。`mise run ios:vm:signing:status` 看缺什么，
必要时重新导入：`mise run ios:vm:signing:import -- --reset -c <p12> -p <profile>`。

**编译卡死不动**
→ 编译机 keychain 锁了（SSH 里看不到弹窗）。导入脚本已关闭超时锁定，若手动动过
keychain 则重跑导入。另：VM 上跑 Xcode GUI 自动签名必然失败——离线加固阻断了
`developerservices2.apple.com`，**这是预期行为，不要去修**。

**TestFlight 拒收 "build number already exists"**
→ 忘了 bump。`mise run ios:build:bump` 后重新构建。

**profile 只剩几天有效期**
→ 免费账号签的（7 天期），无法做 App Store 分发。确认 appuploader 里登录的是
付费账号的 Team Key，重新创建 profile。

**`ios:sync:back` 说没有新 IPA**
→ VM 上还没编译过，或产物名没变被 `--ignore-existing` 跳过。先 `ios:vm:archive`。

**SSH 连不上编译机**
→ VM 没开。启动脚本：`/mnt/disk0/project/mindra/mindra_cc/.build_usbmuxd/start-macos-tahoe.sh`，
等两分钟再试 `mise run ios:sync:status`。

## 相关文档

- `docs/app_store_release_guide_ZH.md` —— App Store 元数据、截图规格、提审流程（步骤 11 的详细版）
- `scripts/ios_build_guide.md` —— 构建脚本细节（本文档的链路就是它的自动化版）
