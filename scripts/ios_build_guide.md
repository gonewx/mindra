# iOS 构建指南（脚本细节）

> 本文档讲构建脚本的参数与细节。**日常发布请直接看 [docs/ios_release_pipeline.md](../docs/ios_release_pipeline.md)**，
> 那里有完整的链路说明与 mise 任务入口。

## 方案速览

证书管理与 TestFlight 上传由 **appuploader**（GUI）完成，本项目不管理证书。
编译签名在一台**离线的 macOS 编译机**（SSH 别名 `imacvm-tahoe`）上完成，
宿主 Linux 通过 mise 任务远程驱动，全程 rsync 传递文件。

签名方式是**手动签名**（Manual signing）：

- `pbxproj` 的 Release/Profile 配置引用 `$(MINDRA_*)` 变量
- 变量定义在 `ios/Flutter/Signing.xcconfig`（不进 git）
- 导入脚本从 .mobileprovision 自动解析 Team ID 与 profile 名写入该文件
- Debug 配置保持 Automatic（本地真机调试不受影响）

## 前提条件

1. **macOS 编译机**：SSH 别名 `imacvm-tahoe`，已装 Xcode + Flutter（mise 管理）
2. **appuploader**（宿主 Linux）：已导入 App Store Connect API **Team Key**
3. **签名资产**：.p12（Apple Distribution）+ .mobileprovision（App Store 类型），
   均由 appuploader 产出
4. Bundle ID：`com.gonewx.mindra.app`

## 构建脚本

### scripts/ios_archive.sh（编译机上运行）

```bash
./scripts/ios_archive.sh              # 构建 IPA 到 build/ios/ipa/
./scripts/ios_archive.sh -c           # 构建前 flutter clean
./scripts/ios_archive.sh --build 5    # 覆盖 build number（不写回文件）
./scripts/ios_archive.sh --skip-verify # 跳过产物校验
```

它会：

1. 读 `ios/Flutter/Signing.xcconfig`（缺失或变量为空直接报错退出）
2. 从 `pubspec.yaml` 取 marketing version，从 `ios/build_number.txt` 取 build number
3. 用模板 `ios/ExportOptions.plist.template` 生成 `build/ios/ExportOptions.plist`
   （`signingStyle=manual`，Team ID / profile 名从 xcconfig 注入）
4. `flutter build ipa --release`
5. 校验产物：Bundle ID、version/build、embedded profile 的 Team 一致性，
   不匹配立即失败（TestFlight 的拒收远比本地校验慢，早失败省时间）

### scripts/ios_signing_import.sh（编译机上运行）

```bash
./scripts/ios_signing_import.sh --status                    # 查看资产状态
./scripts/ios_signing_import.sh -c dist.p12 -p app.mobileprovision   # 导入
./scripts/ios_signing_import.sh --reset -c ... -p ...       # 清空后重新导入
```

细节：

- 证书装进**专用 keychain**（`mindra-signing.keychain-db`），不用 login keychain
  ——不需要登录密码、与日常钥匙串隔离、`--reset` 可整体删除重来
- keychain 密码自动生成存在 `~/.mindra-signing-keychain-password`（600 权限）
- profile 按 UUID 命名，装到新旧两个目录（Xcode 26 读 `~/Library/Developer/Xcode/UserData/Provisioning Profiles`，老位置也放一份兼容其他工具）
- 自动校验：App ID 与 Bundle ID 匹配、未过期、剩余有效期 ≤14 天警告
  （7 天期 = 免费账号 profile，不能做 App Store 分发）
- 成功后把 Team ID / profile 名写进 `ios/Flutter/Signing.xcconfig`

### scripts/ios_sync.sh（宿主 Linux 上运行）

```bash
./scripts/ios_sync.sh push                 # 代码 → 编译机（排除 build/Pods 等）
./scripts/ios_sync.sh pull                 # IPA ← 编译机（到 build/ios/ipa/）
./scripts/ios_sync.sh cert -c p12 -p profile  # 递送签名资产并在 VM 上导入
./scripts/ios_sync.sh status               # 查看 VM 环境
```

### scripts/build_ios.sh 与 release_ios.sh（旧脚本，已降级）

- `build_ios.sh`：仍然可用的通用构建脚本（archive / 模拟器构建等）。证书检查
  已改为兼容手动签名链路。**发布构建建议用 `ios_archive.sh`**
- `release_ios.sh`：导出 IPA + 打印 appuploader 上传指引。上传动作本身不归它
  （历史上走 `xcrun altool`，现已在编译机离线加固前提下废弃）
- ~~fastlane~~：已删除（`ios/fastlane/`）。证书不交给 CI 的方案下 match 不可用

## 重要配置文件

### ios/Runner/Info.plist

确保以下配置正确：

```xml
<key>CFBundleDisplayName</key>
<string>Mindra</string>
<key>CFBundleIdentifier</key>
<string>com.gonewx.mindra.app</string>
```

### 权限配置

如果应用使用了特殊权限，需要在 Info.plist 中添加相应的使用说明：

```xml
<!-- 如果使用麦克风 -->
<key>NSMicrophoneUsageDescription</key>
<string>Mindra 需要访问麦克风来录制您的冥想笔记</string>

<!-- 如果使用通知 -->
<key>NSUserNotificationUsageDescription</key>
<string>Mindra 需要发送通知来提醒您的冥想时间</string>
```

### 版本号

| 项 | 来源 | 说明 |
|---|---|---|
| marketing version | `pubspec.yaml` 的 `version:` | 当前 1.0.0 |
| build number | `ios/build_number.txt` | 独立计数从 1 起，`mise run ios:build:bump` 递增 |

pubspec 里的 `+7` 与 iOS 无关。TestFlight 要求同一 version 下 build number
严格递增，重复直接拒收。

## 常见问题

### 1. 签名问题

- `mise run ios:vm:signing:status` 看缺什么（keychain / 证书 / profile / xcconfig）
- 证书过期：appuploader 里重签，重新导入（加 `--reset` 清旧的）
- `Signing.xcconfig` 变量为空：重新跑一次导入即自动填好

### 2. 构建失败

- `flutter clean` / 删 `ios/Pods` 重装
- 编译卡死不动：keychain 锁了（导入脚本已关自动锁定；手动动过就重跑导入）
- **编译机上任何需要联系 Apple 的操作都会失败**（`developerservices2.apple.com`
  等已被 /etc/hosts 阻断）——这是离线加固的预期行为，不要去修

### 3. 上传失败

- TestFlight 说 build 已存在：忘了 `ios:build:bump`
- 处理中报 ITMS 错误：看 appuploader 里 Apple 返回的具体错误码
- 元数据不全：在 App Store Connect 网页补齐（见 `docs/app_store_release_guide_ZH.md`）

## 发布检查清单

- [ ] Bundle ID 配置正确（com.gonewx.mindra.app）
- [ ] 应用图标已生成
- [ ] 启动画面配置
- [ ] 权限说明已添加
- [ ] `mise run ios:vm:signing:status` 三项全绿
- [ ] 真机安装测试（`mise run ios:ipa:install`）
- [ ] App Store Connect 元数据准备完成
- [ ] 应用截图准备完成
- [ ] 隐私政策和服务条款准备完成

## 注意事项

1. **版本号管理**：每次上传 TestFlight 前递增 build number（`ios:build:bump`）
2. **审核时间**：App Store 审核通常需要 1-7 天
3. **测试**：建议先通过 TestFlight 进行内部测试
4. **合规性**：确保应用符合相关法律法规和 App Store 指南

## 相关链接

- [iOS 发布链路完整文档](../docs/ios_release_pipeline.md)
- [Flutter iOS 部署文档](https://docs.flutter.dev/deployment/ios)
- [App Store Connect API](https://developer.apple.com/app-store-connect/api/)
- [App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
