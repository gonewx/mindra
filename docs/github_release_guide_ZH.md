# GitHub 发布指南

**Language / 语言:** [🇨🇳 中文](#中文) | [🇺🇸 English](github_release_guide.md)

---

本指南详细介绍如何在GitHub上发布Mindra应用的Android和Linux平台版本。

## 目录

- [准备工作](#准备工作)
- [自动化发布（推荐）](#自动化发布推荐)
- [手动发布](#手动发布)
- [发布后操作](#发布后操作)
- [故障排除](#故障排除)

## 准备工作

### 1. 配置GitHub Secrets

在GitHub仓库设置中配置以下Secrets：

#### Android发布所需：
```
ANDROID_KEYSTORE_BASE64        # 发布密钥库的Base64编码
ANDROID_STORE_PASSWORD         # 密钥库密码
ANDROID_KEY_PASSWORD          # 密钥密码
ANDROID_KEY_ALIAS             # 密钥别名
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  # Google Play服务账号JSON（可选）
```

#### iOS发布所需：
```
IOS_BUILD_CERTIFICATE_BASE64   # iOS构建证书Base64编码
IOS_P12_PASSWORD              # P12证书密码
IOS_BUILD_PROVISION_PROFILE_BASE64  # 配置文件Base64编码
IOS_KEYCHAIN_PASSWORD         # 密钥链密码
APPLE_ID                      # Apple ID
APP_SPECIFIC_PASSWORD         # 应用专用密码
```

### 2. 创建发布密钥库（Android）

```bash
# 在mindra目录下运行
keytool -genkey -v -keystore android/release-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias mindra-key
```

### 3. 配置签名文件（Android）

创建 `android/key.properties` 文件：
```properties
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=mindra-key
storeFile=release-keystore.jks
```

## 自动化发布（推荐）

### 方法1：标签触发发布

1. **创建版本标签**：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **自动构建和发布**：
   - GitHub Actions会自动触发
   - 构建Android AAB和APK
   - 构建Linux DEB和TAR.GZ包
   - 构建iOS IPA（如果在macOS上）
   - 创建GitHub Release

### 方法2：手动触发工作流

1. **在GitHub网页上**：
   - 进入仓库的"Actions"页面
   - 选择"Release"工作流
   - 点击"Run workflow"
   - 填写版本号和发布轨道
   - 选择目标平台

2. **参数说明**：
   - **Version**: 版本号（如：1.0.0）
   - **Track**: 发布轨道
     - `internal`: 内部测试
     - `alpha`: 封闭测试  
     - `beta`: 开放测试
     - `production`: 正式发布
   - **Platform**: 目标平台
     - `android`: 仅Android
     - `ios`: 仅iOS
     - `linux`: 仅Linux
     - `all`: 所有平台

## 手动发布

### Android平台

1. **构建APK和AAB**：
   ```bash
   cd mindra
   ./scripts/build_android.sh -b  # 构建AAB
   ./scripts/build_android.sh     # 构建APK和AAB
   ```

2. **发布到Google Play**：
   ```bash
   # 发布到内部测试
   ./scripts/release_android.sh -t internal
   
   # 发布到测试版
   ./scripts/release_android.sh -t beta
   
   # 模拟发布
   ./scripts/release_android.sh -t beta --dry-run
   ```

3. **手动上传**：
   - 访问 [Google Play Console](https://play.google.com/console)
   - 选择应用
   - 进入"发布"→"应用版本"
   - 上传AAB文件
   - 填写版本说明
   - 提交审核

### Linux平台

1. **构建Linux应用**：
   ```bash
   cd mindra
   ./scripts/build_linux.sh -p    # 构建并创建安装包
   ./scripts/build_linux.sh --appimage  # 创建AppImage
   ```

2. **发布选项**：

   #### 选项1：GitHub Releases
   - 构建产物会自动上传到GitHub Releases
   - 用户可以直接下载DEB、TAR.GZ或AppImage文件

   #### 选项2：Linux软件仓库
   ```bash
   # Ubuntu/Debian仓库
   # 1. 创建GPG密钥
   gpg --gen-key
   
   # 2. 签名DEB包
   dpkg-sig --sign builder build/linux/*.deb
   
   # 3. 上传到仓库
   # 具体步骤取决于仓库提供商
   ```

   #### 选项3：Snap Store
   ```bash
   # 需要先创建snapcraft.yaml
   snapcraft
   snapcraft upload *.snap
   ```

   #### 选项4：Flathub
   ```bash
   # 需要创建Flatpak manifest
   flatpak-builder build com.mindra.app.json
   ```

### iOS平台

1. **构建iOS应用**：
   ```bash
   cd mindra
   ./scripts/build_ios.sh -a      # 创建Archive
   ```

2. **发布到TestFlight**：
   ```bash
   ./scripts/release_ios.sh -t
   ```

3. **发布到App Store**：
   ```bash
   ./scripts/release_ios.sh -s
   ```

## 发布后操作

### 1. 验证发布

#### Android：
- 检查Google Play Console中的版本状态
- 测试内部测试版本
- 监控崩溃报告

#### Linux：
- 在不同发行版上测试安装包
- 验证桌面集成
- 检查依赖项

#### iOS：
- 检查TestFlight状态
- 测试外部测试版本
- 准备App Store审核

### 2. 更新文档

- 更新CHANGELOG.md
- 更新版本号说明
- 准备发布公告

### 3. 社区通知

- 发布GitHub Release说明
- 更新项目README
- 通知用户和贡献者

## 故障排除

### 常见问题

#### 1. Android构建失败
```bash
# 检查签名配置
ls -la android/release-keystore.jks
cat android/key.properties

# 清理后重新构建
flutter clean
flutter pub get
./scripts/build_android.sh -c -b
```

#### 2. Linux依赖问题
```bash
# 安装必要依赖
sudo apt update
sudo apt install -y libgtk-3-dev libglib2.0-dev ninja-build cmake

# 启用Linux桌面支持
flutter config --enable-linux-desktop
```

#### 3. iOS证书问题
```bash
# 检查证书状态
security find-identity -v -p codesigning

# 在Xcode中重新配置
open ios/Runner.xcworkspace
```

#### 4. GitHub Actions失败
- 检查Secrets配置
- 查看构建日志
- 验证工作流语法
- 检查权限设置

### 调试技巧

1. **本地测试**：
   ```bash
   # 测试构建脚本
   ./scripts/build_all.sh --dry-run
   
   # 验证签名
   jarsigner -verify build/app/outputs/bundle/release/app-release.aab
   ```

2. **查看详细日志**：
   ```bash
   # 启用详细输出
   flutter build apk --verbose
   flutter build linux --verbose
   ```

3. **模拟发布**：
   ```bash
   # 模拟Android发布
   ./scripts/release_android.sh -t beta --dry-run
   
   # 模拟iOS发布  
   ./scripts/release_ios.sh -t --dry-run
   ```

## 发布轨道说明

| 轨道 | Android | iOS | Linux | 用途 |
|------|---------|-----|-------|------|
| internal | 内部测试 | TestFlight内部 | GitHub Pre-release | 开发团队测试 |
| alpha | 封闭测试 | TestFlight外部 | GitHub Pre-release | 小范围用户测试 |
| beta | 开放测试 | TestFlight公开 | GitHub Pre-release | 大范围用户测试 |
| production | 正式发布 | App Store | GitHub Release | 所有用户 |

## 最佳实践

1. **版本管理**：
   - 使用语义化版本号（如：1.0.0）
   - 为每个发布创建Git标签
   - 维护详细的CHANGELOG

2. **测试流程**：
   - 先发布到内部测试轨道
   - 收集反馈后发布到测试轨道
   - 最后发布到生产环境

3. **自动化**：
   - 使用GitHub Actions自动化构建
   - 配置自动化测试
   - 设置通知机制

4. **文档维护**：
   - 及时更新发布说明
   - 维护用户安装指南
   - 记录已知问题和解决方案

## 相关链接

- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [GitHub Actions文档](https://docs.github.com/en/actions)
- [Flutter发布指南](https://flutter.dev/docs/deployment)
- [Linux软件打包指南](https://packaging.ubuntu.com/) 