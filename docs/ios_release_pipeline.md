# Mindra iOS 发布链路（完整工作流）

> 2026-08 确定的现行方案。核心原则：**签名证书不进 GitHub Secrets、不进任何 CI**；
> 证书管理与 TestFlight 上传由 appuploader（GUI）完成，编译在离线 Mac VM 上做，
> 衔接全部通过 **mise 任务**入口。
>
> 本文档是**按操作顺序编排的完整工作流**：从零开始照着走一遍「阶段一」就能完成
> 首次发布；之后每次发版只走「阶段二」。
>
> 2026-08-27 全链路首次跑通（1.0.0 build 1 已产出 IPA），当天修复的脚本问题
> 已全部反映在本文档的「故障排查」一节。
> 2026-08-28 增加**真机调试**与**真机独立安装包**两条车道：签名按构建配置拆分
> （Debug=AdHoc 真机 / Release=App Store 正式），详见「阶段二」与「签名参数的流转」。

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
| `ios:vm:archive` | **先自动同步代码**，再远程在编译机上构建 **App Store 签名** IPA（上架/TestFlight 用）|
| `ios:vm:archive:adhoc` | 同上，但构建 **AdHoc 签名** IPA（`mindra-adhoc.ipa`，装真机独立运行；勿传 TestFlight）|
| `ios:ipa:install` | （编译机上）按名称装 IPA 到真机：默认 `mindra-adhoc.ipa`；加 `-- --appstore` 装 `mindra.ipa`；`IPA_PATH=` 精确指定 |
| `ios:sync:push` | 只同步代码到编译机 |
| `ios:sync:back` | 从编译机回收 IPA 到宿主 `build/ios/ipa/` |
| `ios:sync:status` | 查看编译机环境（Xcode、项目、磁盘） |
| `ios:build:bump` | iOS build number +1（TestFlight 要求递增） |

编译机上直接运行的（一般用不着，远程任务已覆盖）：
`ios:signing:status` / `ios:signing:import` / `ios:signing:reset` / `ios:archive`。
真机调试在编译机上跑：`ios:run:debug`（Debug+AdHoc，热重载调外观，见车道 A）。

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

# 用实际路径执行（p12 密码即步骤 4 创建证书时设的密码）
mise run ios:vm:signing:import -- -c ~/下载/dist.p12 -p ~/下载/mindra.mobileprovision
```

> ⚠️ **密码必须通过环境变量或参数传入，mise 环境下无法交互输入**：
>
> ```bash
> # 方式一：环境变量（推荐，不落 shell history 可配合 read -s）
> read -s MINDRA_P12_PASSWORD && export MINDRA_P12_PASSWORD
> mise run ios:vm:signing:import -- -c ~/下载/dist.p12 -p ~/下载/mindra.mobileprovision
>
> # 方式二：命令行参数（注意会进 history）
> mise run ios:vm:signing:import -- -c <p12> -p <profile> --password '密码'
>
> # 换证书/profile 重灌：加 --reset
> #   mise run ios:vm:signing:import -- --reset -c <p12> -p <profile>
> ```
>
> mise 任务里 stdin 不是终端，脚本检测到后会明确报错（而不是静默失败），
> 但只有把密码传进去才能走通。

脚本自动完成（**不需要手动填任何签名参数**）：

- scp 两个文件到 VM 中转目录 `~/mindra-transfer/`，再远程执行导入
- 证书装进**专用 keychain**（`mindra-signing.keychain-db`，非 login keychain，不需要登录密码）
- 把仓库内置的 **Apple WWDR 中间证书**（`scripts/apple-certs/`，G3-G6）一并装进 keychain——
  离线 VM 上没有它，证书链验证不过，表现为 `find-identity` 报 "0 valid identities"
- profile 按 UUID 命名装到 Xcode 的 profile 目录
- 解析 profile 得到 **Team ID** 和 **profile 名**，写入 `ios/Flutter/Signing.xcconfig`
  （签名身份里的空格会原样保留，如 `iPhone Distribution`，导出时按名字匹配证书）
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
> ⚠️ `ios:build:bump` **只修改 `ios/build_number.txt`，不会改动任何已产出的 IPA**；
> 上传 TestFlight 时 appuploader 读取的是 IPA 打包时固化在 Info.plist 里的版本号。
> 想让新包带新号必须：**bump → archive**（bump 前的旧包文件不变）。

### 步骤 10：appuploader 上传 TestFlight

appuploader → 提交上传 → 选择 `mindra/build/ios/ipa/` 下的 IPA 文件 → 上传。

上传后在 [App Store Connect](https://appstoreconnect.apple.com) → TestFlight 页面看处理状态
（几分钟到半小时），构建版本出现后即可添加内部测试者装机测试。

> **出口合规**：`ios/Runner/Info.plist` 已声明 `ITSAppUsesNonExemptEncryption = false`
>（App 只用 HTTPS 等系统标准加密，属豁免范围）。新上传的构建会自动显示「合规，无需证明」；
> 历史构建仍提示「缺少出口合规证明」的话，在 ASC 构建弹窗 → 出口合规 → 管理里
> 选一次「不属于上述的任意一种算法」即可（见故障排查）。

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

## 阶段二：日常迭代发布（三条车道）

首次发布完成后，日常有三条互不干扰的车道，按需选：

### 车道 A：真机调试（调外观/功能，可热重载）

```bash
# 编译机上（Mac VM 终端）：
cd ~/mindra && mise run ios:run:debug
```

- Debug 构建自动读 `Signing.xcconfig`（AdHoc），安装到 `$IOS_DEVICE_ID` 那台 iPhone 上
- LLDB 附加已在编译机用 `flutter config --no-enable-lldb-debugging` 关闭
  （否则 Debug 版会停在蓝屏等调试器，见故障排查）
- **保持 flutter run 进程在线**；退出后直接点手机图标会提示
  "iOS 14+ debug mode can only be launched from flutter tooling"（系统限制，不是 bug）

### 车道 B：真机独立安装（体验正式包，不连电脑）

```bash
# 宿主机：构建 AdHoc 签名包（自动同步代码 → 编译机构建 mindra-adhoc.ipa）
mise run ios:vm:archive:adhoc

# 编译机上：按名称装到 iPhone（默认就是 mindra-adhoc.ipa）
mise run ios:ipa:install
```

- AdHoc 包是 Release 版，无 debugger 依赖，装完点图标独立运行，无"iOS 14+ 提示"
- 设备 UDID 必须在 `MindraAdHoc` profile 白名单里（appuploader 建 AdHoc 描述文件时勾设备）
- **AdHoc 包不能上传 TestFlight**（会被拒收）；上架必须走车道 C 的 App Store 包
- 安装按名称区分，不会装错：`mise run ios:ipa:install`（默认 adhoc）/
  `mise run ios:ipa:install -- --appstore`（App Store 包）/ `IPA_PATH=` 精确指定

### 车道 C：发布上架（TestFlight / App Store）

```bash
mise run ios:build:bump      # 1. build number +1（必须，否则 TestFlight 拒收；只对下一步构建生效，不影响已产出的包）
mise run ios:vm:archive      # 2. 同步代码 + 编译签名（App Store 包，自动读 Signing.release.xcconfig）
mise run ios:sync:back       # 3. IPA 回宿主
# 4. appuploader 里选新 IPA 上传
# 5. ASC → TestFlight 页面看处理状态（几分钟），添加测试者
# 6. 测试通过后，在 ASC 版本页面填「本次更新内容」→ 提交审核
```

三条车道共用同一张分发证书，只是 profile 不同；切换 profile 不改 Xcode、不改 pbxproj。

## 版本号规则

| 项 | 取值 | 来源 |
|---|---|---|
| marketing version | `1.0.0` | `pubspec.yaml` 的 `version:`（`+` 前面的部分） |
| build number | `1, 2, 3...` | `ios/build_number.txt`，独立计数，从 1 起 |

注意 pubspec 里的 `+7` 与 iOS build number **无关**（那是本地构建计数的历史遗留）。
iOS 的 build number 只通过 `ios/build_number.txt` 管理，`ios:build:bump` 递增。
`ios:build:bump` **不触发构建**：已产出 IPA 内的 build number 在打包时固化，
上传 TestFlight 以 IPA 内读到的值为准；先 `build:bump` 再 `ios:vm:archive` 新包才带新号。

git tag 发布版本时照旧用 tag 递增（`v0.5.8` 起），与上述规则互不影响。

## 关键文件

| 文件 | 作用 | 进 git？ |
|---|---|---|
| `mindra/mise.toml` | 所有 iOS 任务入口 | ✅ |
| `mindra/scripts/ios_sync.sh` | 宿主↔VM 同步、资产递送 | ✅ |
| `mindra/scripts/ios_signing_import.sh` | VM 侧签名资产导入 | ✅ |
| `mindra/scripts/ios_archive.sh` | VM 侧编译签名出 IPA（构建前自动解锁专用 keychain） | ✅ |
| `mindra/scripts/apple-certs/` | Apple WWDR 中间证书 G3-G6（离线 VM 验证证书链用） | ✅ |
| `mindra/ios/Flutter/Signing.debug.xcconfig` | 签名参数：**Debug 真机调试**（Development，get-task-allow） | ❌ 已 ignore，rsync 排除（`Signing*.xcconfig`）|
| `mindra/ios/Flutter/Signing.xcconfig` | 签名参数：**AdHoc 独立安装**（车道 B） | ❌ 同上 |
| `mindra/ios/Flutter/Signing.release.xcconfig` | 签名参数：**Release 正式 IPA**（App Store，车道 C） | ❌ 同上 |
| `mindra/ios/Flutter/Signing.xcconfig.example` | 签名参数模板 | ✅ |
| `mindra/ios/Flutter/Debug.xcconfig` / `Release.xcconfig` | Debug 先兜底 Signing.xcconfig、再优先 Signing.debug.xcconfig；Release include Signing.release.xcconfig | ✅ |
| `mindra/ios/ExportOptions.plist.template` | IPA 导出选项模板（`method` 为占位符，按 distribution 自动填） | ✅ |
| `mindra/ios/build_number.txt` | iOS build number | ✅ |

签名参数的流转：`pbxproj` 的 Debug/Release/Profile 配置均引用 `$(MINDRA_*)` 变量
（基配置 xcconfig 各 include 自己的签名文件）：

- **Debug（真机调试）**：`Debug.xcconfig` → `Signing.debug.xcconfig`（Development profile，
  带 get-task-allow 调试权限；未导入开发签名前兜底 `Signing.xcconfig` AdHoc，只能跑不能调）
- **AdHoc（独立安装包）**：`ios:vm:archive:adhoc` 读 `Signing.xcconfig`（AdHoc）
- **Release（正式 IPA）**：`Release.xcconfig` → `Signing.release.xcconfig`（App Store profile）

全程无人工填值，Team ID 不进版本库。**导入脚本按 profile 类型自动分流写入三份文件**
（development/adhoc/appstore，判断依据：get-task-allow=true→development；带设备列表→adhoc；
其余→appstore），开发签名无需先建文件。证书名**兼容新旧叫法**：开发证书
「Apple Development」（新）或「iPhone Developer」（appuploader/API 创建的旧式名）都认。
**真机调试与 App Store 发布并行兼容**——三条车道互不干扰、无需切换。
换 profile 只需重新导入并保证新 `.mobileprovision` 已装在编译机信任库
（`~/Library/MobileDevice/Provisioning Profiles/`，文件名=UUID，装好才算真的可用）。

## 故障排查

**Xcode 报「The sandbox is not in sync with the Podfile.lock」（红字）/ 「No podspec found for <插件> in .symlinks/plugins/<插件>/darwin」**
→ 同一根源，**已根治（2026-08-28）**：`ios_sync.sh push` 曾把宿主的
`.flutter-plugins-dependencies` / `ios/Podfile.lock` / `ios/Flutter/flutter_export_environment.sh`
同步到编译机（宿主版写死 `/home/decker/.pub-cache` 路径），Flutter 按它生成的 `.symlinks`
全部悬空 → pod install 找不到 podspec → Manifest.lock 永不同步。这三个文件现已加入
rsync 排除（另有 `Signing*.xcconfig`），编译机以自身 `flutter pub get` 产物为准。
若从旧状态救火（VM 上）：
```bash
cd ~/mindra && rm -rf ios/.symlinks .flutter-plugins-dependencies ios/Podfile.lock
flutter pub get
flutter build ios --debug --no-codesign   # .symlinks 由 build/run 时生成，pub get 不建它
```

**Xcode 弹「codesign wants to use the mindra-signing keychain」密码框**
→ 专用 keychain（mindra-signing.keychain-db）不像 login keychain 那样登录自动解锁；VM 挂起
恢复、注销重登或 securityd 重启后就锁定。SSH 与 GUI 是独立 audit session，CLI 构建
（`ios_archive.sh` 构建前自动解锁）不受影响，只有 Xcode(GUI) 会弹。已给 `ios_signing_import.sh`
加 `install_unlock_agent()`，会装一个 `com.mindra.signing-unlock` LaunchAgent（RunAtLoad 登录即
解锁 GUI 会话），Xcode 不再弹；若个别时候又锁，重跑一次 `mise run ios:vm:signing:unlock`。

**真机点 Run 报「0xe800801f (Attempted to install a Beta profile without the proper entitlement)」**
→ 用错了 profile 类型：App Store 分发 profile（MindraAppStore）只用于上传 App Store/TestFlight，
不允许直接装到真机上运行。真机要装包，走**车道 B**（`mise run ios:vm:archive:adhoc` +
`ios:ipa:install` 装 `mindra-adhoc.ipa`）——已内置 AdHoc 分发 profile（设备 UDID 加进白名单），
**不需要手动换签名配置**。旧做法「再导入一次 adhoc.mobileprovision」会覆盖 `Signing.xcconfig`、
破坏车道 A 的真机调试，不要再用了。

**真机点 Run 报「The executable does not contain get-task-allow ... the debugger will fail to attach」**
→ Release/Ad Hoc 签名不带 `get-task-allow`（调试权限），而 Xcode 的 Run 默认要挂调试器，所以报这
个。这是 Release 正常属性，不是配置错误。改用 **Product → Run Without Debugging（⌃⌘R）**，或在
**Edit Scheme → Run → 去掉 "Debug executable" 勾选**（Build Configuration 保持 Release）。若要在
真机断点/热重载，需另配 Development 证书 + Development profile。

**Xcode Signing 界面 Team 显示「Unknown Name (97W62GB3JA)」**
→ 编译机离线拿不到团队的显示名，属正常现象；Team ID 本身正确，不影响签名与构建。

**ExportOptions.plist.template 的 method 是占位符 `__MINDRA_EXPORT_METHOD__`**
→ 由 `ios_archive.sh` 按 `--distribution` 自动填：`app-store-connect`（默认，上架用）/
`ad-hoc`（`mise run ios:vm:archive:adhoc`，装真机用）。无需手工改模板。

**`mise run ios:vm:archive` 报 "No signing certificate / No profile matching"**
→ Signing.xcconfig 变量为空或证书没装。`mise run ios:vm:signing:status` 看缺什么，
必要时重新导入：`mise run ios:vm:signing:import -- --reset -c <p12> -p <profile>`。

**archive 报 "缺少 ios/Flutter/Signing.xcconfig"，但明明导入过**
→ 曾经的 bug：push 的 rsync 排除规则路径写错（写成了 `ios/Signing.xcconfig`），
带 `--delete` 的同步会把 VM 上刚生成的签名配置删掉。已修复（2026-08-27）；
若再遇到，重新跑一次 `ios:vm:signing:import`（只需 `-p` 参数）即可再生成。

**签名导入报 "MAC verification failed (wrong password?)"**
→ .p12 密码不对。就是 appuploader 里创建证书时设的那个密码，忘了只能重新创建证书。
注意它与 keychain 密码（脚本自管）是两回事。

**签名导入静默退出 / 报 "stdin 不是终端"**
→ 旧版脚本在非终端环境下交互读密码会被 `set -e` 静默吞掉，已改为显式报错。
用 `MINDRA_P12_PASSWORD` 环境变量或 `--password` 参数传密码（见步骤 6）。

**`security` 报 "User interaction is not allowed"**
→ keychain 锁定状态下执行了需要解锁的操作（SSH 会话里无法弹窗）。已修复：
导入脚本先 `unlock-keychain` 再改设置。若手动操作 keychain 遇到，先解锁：
`security unlock-keychain -p "$(cat ~/.mindra-signing-keychain-password)" mindra-signing.keychain-db`

**`find-identity` 显示 "0 valid identities"（证书和私钥都在）**
→ 缺 Apple WWDR 中间证书，证书链验证不过。已修复：导入脚本自动装
`scripts/apple-certs/` 里的 WWDR G3-G6。另一个可能：keychain 搜索列表损坏
（手动 `security list-keychains -s` 时参数拼接出错），修复：
`security list-keychains -d user -s login.keychain-db mindra-signing.keychain-db`

**编译签名时报 `errSecInternalComponent`**
→ 构建 SSH 会话里 keychain 是锁的，codesign 拿私钥时无法弹密码框。已修复：
`ios_archive.sh` 构建前自动解锁专用 keychain；`ios:run:debug` / `ios:run:release`
也已内置解锁（2026-08-28，否则 flutter run 时报
"Failed to codesign ... App.framework with identity ... errSecInternalComponent"）。
手动解锁：`./scripts/ios_signing_import.sh --unlock`（SSH 与 GUI 会话是独立 audit session，
互不覆盖，要用哪条就得在哪条里解锁）。

**导出 IPA 报 "No certificate for team ... matching 'iPhoneDistribution'"**
→ Signing.xcconfig 里的签名身份被去掉了空格（应为 `iPhone Distribution`）。
已修复：读取身份名时只清行尾空白。手动编辑过 xcconfig 的话注意保留空格。

**编译卡死不动**
→ 编译机 keychain 锁了（SSH 里看不到弹窗）。导入脚本已关闭超时锁定，若手动动过
keychain 则重跑导入。另：VM 上跑 Xcode GUI 自动签名必然失败——离线加固阻断了
`developerservices2.apple.com`，**这是预期行为，不要去修**。

**TestFlight 拒收 "build number already exists"**
→ 忘了 bump（或用了重复的 build number）。`mise run ios:build:bump` 后**必须重新构建**
（`ios:vm:archive` + `sync:back`）再上传——bump 只影响下一次构建，旧包不会被"修正"。

**TestFlight 提示「缺少出口合规证明」**
→ 出口合规问题：需要确认 App 是否使用非豁免加密。本 App 只用 HTTPS 等系统标准加密，
`ios/Runner/Info.plist` 里已声明 `ITSAppUsesNonExemptEncryption = false`（豁免），
新构建会**自动**标记为「合规，无需证明」，不用再管。对**已上传的旧构建**，在
ASC → TestFlight → 该版本的构建弹窗 → 出口合规 → 管理，选「不属于上述的任意一种算法」
一次即可（或在 App 页面一次性设置，若默认选标准加密会应用到全部后续构建）。
若将来引入自定义加密算法（如用户数据本地加密），改成 `true` 并按 Apple 要求提供证明。

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

## 2026-08-28 增补的故障排查

**真机蓝屏 / 停在 LaunchScreen、`flutter run` 卡 "Installing and launching..."**
→ Debug 版启动后等 LLDB 附加，SSH 会话里附加慢/卡是典型场景，app 停在默认蓝底 LaunchScreen。
已在编译机执行 `flutter config --no-enable-lldb-debugging` 关闭 LLDB 附加，之后跑
`mise run ios:run:debug` 正常出界面。旧进程先 Ctrl+C 清掉再跑。

**手机点图标提示「iOS 14+ debug mode only be launched from flutter tooling」**
→ Debug 版不允许脱离调试器独立启动（iOS 14+ 限制），是正常现象不是 bug。
要么保持 `flutter run` 在线使用，要么装 AdHoc 的 Release 包（车道 B，独立点图标无此限制）。

**archive 显示"构建完成"但 IPA 是旧的（exportArchive 有红字仍显示成功）**
→ 已修复（2026-08-28）：`ios_archive.sh` 现在只认构建开始后新生成的 IPA（mtime 比较），
无新产物会明确报「未产出新的 IPA」并提示查看 exportArchive 报错
（常见原因：profile 与 ExportOptions method 不匹配，如 AdHoc profile 配 app-store-connect）。

**keychain 解锁报 "label�: unbound variable"（macOS 自带 bash 3.2）**
→ bash 3.2 对 `$var）`（变量后紧跟全角字符）解析错误，须写成 `${var}）`。已修复（2026-08-28）。

**Archive 报「不是 iOS App Store profile」或切了 profile 后另一条车道失效**
→ 检查是否把 AdHoc 与 App Store 的 xcconfig 串了：`Signing.xcconfig`（Debug 真机）与
`Signing.release.xcconfig`（Release 正式）是两套，`ios_archive.sh` 按 `--distribution`
自动选，**不要手工互换**。导入脚本只写 `Signing.xcconfig`，重新导入 App Store profile 后
需把 AdHoc 值恢复回去（或用已有的 Signing.release.xcconfig 覆盖参数）。
