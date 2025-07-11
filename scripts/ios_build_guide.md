# iOS 发布包构建指南

## 前提条件

1. **macOS 环境**：iOS 应用只能在 macOS 上构建
2. **Xcode**：安装最新版本的 Xcode
3. **Apple 开发者账户**：需要付费的 Apple Developer Program 账户
4. **iOS 证书**：Distribution Certificate 和 Provisioning Profile

## 构建步骤

### 1. 环境准备

```bash
# 确保 Flutter 和 iOS 工具链已安装
flutter doctor

# 检查 iOS 设备连接（可选）
flutter devices
```

### 2. 配置 iOS 项目

```bash
# 进入项目目录
cd mindra

# 打开 iOS 项目进行配置
open ios/Runner.xcworkspace
```

### 3. 在 Xcode 中配置

1. **Bundle Identifier**：设置为 `com.mindra.app`
2. **Team**：选择您的 Apple Developer Team
3. **Signing & Capabilities**：
   - 启用 "Automatically manage signing"
   - 或手动配置 Distribution Certificate 和 Provisioning Profile
4. **Deployment Target**：设置最低支持的 iOS 版本

### 4. 构建发布版本

```bash
# 构建 iOS 发布版本
flutter build ios --release

# 或者构建 IPA 文件（需要配置好签名）
flutter build ipa --release
```

### 5. 通过 Xcode 构建和上传

1. 在 Xcode 中选择 "Product" > "Archive"
2. 等待构建完成
3. 在 Organizer 中选择构建的 Archive
4. 点击 "Distribute App"
5. 选择 "App Store Connect"
6. 按照向导完成上传

## 重要配置文件

### ios/Runner/Info.plist

确保以下配置正确：

```xml
<key>CFBundleDisplayName</key>
<string>Mindra</string>
<key>CFBundleIdentifier</key>
<string>com.mindra.app</string>
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

## 常见问题

### 1. 签名问题

- 确保 Apple Developer 账户有效
- 检查证书是否过期
- 确认 Bundle ID 在 Apple Developer Portal 中已注册

### 2. 构建失败

- 运行 `flutter clean` 清理项目
- 删除 `ios/Pods` 目录并重新运行 `flutter pub get`
- 检查 Xcode 版本是否与 Flutter 兼容

### 3. 上传失败

- 检查应用版本号是否唯一
- 确认所有必需的元数据已在 App Store Connect 中填写
- 检查应用是否符合 App Store 审核指南

## 自动化构建（可选）

可以使用 Fastlane 来自动化 iOS 构建和发布流程：

```bash
# 安装 Fastlane
sudo gem install fastlane

# 在 ios 目录中初始化 Fastlane
cd ios
fastlane init
```

## 发布检查清单

- [ ] Bundle ID 配置正确
- [ ] 应用图标已生成
- [ ] 启动画面配置
- [ ] 权限说明已添加
- [ ] 签名配置正确
- [ ] 在真实设备上测试
- [ ] App Store Connect 元数据准备完成
- [ ] 应用截图准备完成
- [ ] 隐私政策和服务条款准备完成

## 注意事项

1. **版本号管理**：每次提交到 App Store 都需要递增版本号
2. **审核时间**：App Store 审核通常需要 1-7 天
3. **测试**：建议先通过 TestFlight 进行内部测试
4. **合规性**：确保应用符合相关法律法规和 App Store 指南

## 相关链接

- [Flutter iOS 部署文档](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Portal](https://developer.apple.com/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
