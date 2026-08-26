# Mindra iOS 发布链路

> 2026-08 确定的现行方案。核心原则：**签名证书不进 GitHub Secrets、不进任何 CI**；
> 证书管理与 TestFlight 上传由 appuploader（GUI）完成，本项目只做衔接，
> 衔接全部通过 **mise 任务**入口。

## 架构总览

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
| 申请 Distribution 证书 | 宿主 Linux | appuploader 手动操作 |
| 创建 App ID / profile | 宿主 Linux | appuploader 手动操作 |
| 签名资产装进编译机 | VM（远程触发） | `mise run ios:vm:signing:import` |
| 编译签名出 IPA | VM（远程触发） | `mise run ios:vm:archive` |
| IPA 回宿主 | 宿主 Linux | `mise run ios:sync:back` |
| 上传 TestFlight | 宿主 Linux | appuploader 手动选文件 |

### 为什么这样设计

- **证书不出本机**：签名的 p12 只在宿主和编译机之间传递，不经过任何第三方（含 GitHub）。
- **VM 纯离线**：封号风险不在"用 VM 编译"（纯本地不联网），而在"用 VM 联系 Apple"（Xcode 登录/自动签名/Organizer 上传会上报硬件指纹）。所以编译机彻底离线，联系 Apple 的动作全部在宿主走 ASC API（请求里只有 JWT，无硬件信息）。
- **上传不走 altool/iTMSTransporter**：它们要在 Mac 上联系 Apple。appuploader 的 `/v1/buildUploads` 纯 HTTP 上传在 Linux 上完成。

## mise 任务一览

宿主 Linux 上运行的：

| 任务 | 作用 |
|---|---|
| `ios:vm:signing:import` | 递送 .p12/.mobileprovision 到编译机并导入（参数透传：`-- -c <p12> -p <profile>`） |
| `ios:vm:signing:status` | 远程查看编译机签名资产状态 |
| `ios:vm:archive` | **先自动同步代码**，再远程在编译机上构建 IPA |
| `ios:sync:push` | 只同步代码到编译机 |
| `ios:sync:back` | 从编译机回收 IPA 到宿主 `build/ios/ipa/` |
| `ios:sync:status` | 查看编译机环境（Xcode、项目、磁盘） |
| `ios:build:bump` | iOS build number +1（TestFlight 要求递增） |

编译机上直接运行的（一般用不着，远程任务已覆盖）：
`ios:signing:status` / `ios:signing:import` / `ios:signing:reset` / `ios:archive`。

## 首次配置（账号下来后做一次）

### 前置条件

- 付费 Apple Developer Program 账号已生效（Individual Key 无 Provisioning 权限，**必须建 Team Key**）
- App Store Connect 网页 → 用户和访问 → 集成 → 创建 **App Store Connect API Key（Team Key）**，下载 .p8（只能下载一次，妥善保存）
- appuploader 已导入该 API Key

### 步骤

```bash
cd mindra/

# 1. appuploader 里操作：
#    - 创建证书（Apple Distribution），导出 .p12（设个密码）
#    - 创建 App ID（com.gonewx.mindra.app，如尚未注册）
#    - 创建 profile（类型选 App Store Connect），下载 .mobileprovision

# 2. 装进编译机（密码会提示输入，或用 MINDRA_P12_PASSWORD 环境变量）
mise run ios:vm:signing:import -- -c ~/下载/dist.p12 -p ~/下载/mindra.mobileprovision

# 3. 确认状态（应看到证书、profile、Signing.xcconfig 三项全绿）
mise run ios:vm:signing:status

# 4. 编译（自动先同步代码，VM 上约 1-3 分钟）
mise run ios:vm:archive

# 5. IPA 回宿主
mise run ios:sync:back

# 6. appuploader 里选 build/ios/ipa/ 下的 IPA 上传 TestFlight
```

签名导入脚本会自动做这些事，不需要手动填任何签名参数：

- 证书装进**专用 keychain**（`mindra-signing.keychain-db`，非 login keychain，不需要登录密码）
- profile 按 UUID 命名装到 Xcode 的 profile 目录
- 解析 profile 得到 **Team ID** 和 **profile 名**，写入 `ios/Flutter/Signing.xcconfig`
- 校验 profile 的 App ID 与项目 Bundle ID 匹配、没过期、不是 7 天期的免费账号 profile

## 日常迭代发布

```bash
mise run ios:build:bump      # 1. build number +1（必须，否则 TestFlight 拒收）
mise run ios:vm:archive      # 2. 同步代码 + 编译签名
mise run ios:sync:back       # 3. IPA 回宿主
# 4. appuploader 里选新 IPA 上传
# 5. App Store Connect → TestFlight 页面看处理状态（几分钟），添加测试者
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

- `docs/app_store_release_guide_ZH.md` —— App Store 元数据、截图、提审流程
- `scripts/ios_build_guide.md` —— 构建脚本细节（本文档的链路就是它的自动化版）
- 记忆：`ios-release-strategy`、`macos-vm-access`、`apple-dev-account-pending`
