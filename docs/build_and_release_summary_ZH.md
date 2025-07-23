# Mindra 构建和发布系统总结

**Language / 语言:** [🇨🇳 中文](#中文) | [🇺🇸 English](build_and_release_summary.md)

---

本文档总结了为 Mindra 应用创建的完整构建和发布系统。

## 📁 文件结构

```
mindra/
├── scripts/                    # 构建和发布脚本
│   ├── build_android.sh       # Android 构建脚本
│   ├── build_ios.sh           # iOS 构建脚本
│   ├── build_all.sh           # 跨平台构建脚本
│   ├── release_android.sh     # Android 发布脚本
│   ├── release_ios.sh         # iOS 发布脚本
│   ├── version_manager.sh     # 版本管理脚本
│   ├── quick_deploy.sh        # 快速部署脚本
│   └── build_summary.sh       # 构建摘要脚本（已存在）
├── android/fastlane/          # Android Fastlane 配置
│   ├── Fastfile              # Fastlane 主配置
│   └── Appfile               # 应用配置
├── ios/fastlane/              # iOS Fastlane 配置
│   ├── Fastfile              # Fastlane 主配置
│   └── Appfile               # 应用配置
├── .github/workflows/         # GitHub Actions CI/CD
│   ├── build_and_test.yml    # 构建和测试工作流
│   ├── release.yml           # 发布工作流
│   └── code_quality.yml      # 代码质量检查
└── docs/                      # 文档
    ├── app_store_release_guide.md  # 应用商店发布指南
    └── build_and_release_summary.md # 本文档
```

## 🛠️ 构建脚本

### 1. Android 构建 (`build_android.sh`)
- 支持 APK 和 AAB 构建
- 自动签名配置
- 版本号管理
- 构建验证

**使用示例：**
```bash
# 基本构建
./scripts/build_android.sh

# 清理后构建 AAB
./scripts/build_android.sh -c -b

# 指定版本号构建
./scripts/build_android.sh -v 1.0.1+2
```

### 2. iOS 构建 (`build_ios.sh`)
- 支持模拟器和真机构建
- Archive 创建
- 证书验证
- 版本号同步

**使用示例：**
```bash
# 基本构建
./scripts/build_ios.sh

# 创建 Archive
./scripts/build_ios.sh -a

# 清理后构建
./scripts/build_ios.sh -c -a
```

### 3. 跨平台构建 (`build_all.sh`)
- 同时构建 Android 和 iOS
- 统一版本管理
- 并行构建支持
- 自动版本递增

**使用示例：**
```bash
# 构建所有平台
./scripts/build_all.sh

# 自动递增版本并构建
./scripts/build_all.sh --bump-version patch

# 仅构建 Android
./scripts/build_all.sh -a
```

## 🚀 发布脚本

### 1. Android 发布 (`release_android.sh`)
- 支持多个发布轨道
- Google Play Console 集成
- Fastlane 自动化
- 手动上传指导

**使用示例：**
```bash
# 发布到内部测试
./scripts/release_android.sh -t internal

# 模拟发布到测试版
./scripts/release_android.sh -t beta --dry-run
```

### 2. iOS 发布 (`release_ios.sh`)
- TestFlight 和 App Store 支持
- 自动 IPA 导出
- API 密钥认证
- 手动上传指导

**使用示例：**
```bash
# 发布到 TestFlight
./scripts/release_ios.sh -t

# 发布到 App Store
./scripts/release_ios.sh -s
```

## 📋 版本管理 (`version_manager.sh`)

统一的版本号管理工具：

```bash
# 显示当前版本
./scripts/version_manager.sh show

# 设置版本号
./scripts/version_manager.sh set 1.2.0+5

# 递增版本号
./scripts/version_manager.sh bump patch

# 创建 Git 标签
./scripts/version_manager.sh tag
```

## ⚡ 快速部署 (`quick_deploy.sh`)

一键部署解决方案：

```bash
# 部署到开发环境
./scripts/quick_deploy.sh -e dev

# 部署到生产环境并递增版本
./scripts/quick_deploy.sh -e prod --bump-version patch

# 仅部署 Android 到测试环境
./scripts/quick_deploy.sh -e staging -p android
```

## 🤖 自动化 CI/CD

### GitHub Actions 工作流

1. **构建和测试** (`build_and_test.yml`)
   - 代码格式检查
   - 静态分析
   - 单元测试
   - 跨平台构建

2. **发布** (`release.yml`)
   - 自动版本管理
   - 签名构建
   - 应用商店部署
   - GitHub Release 创建

3. **代码质量** (`code_quality.yml`)
   - 代码分析
   - 测试覆盖率
   - 安全检查
   - 性能检查

### Fastlane 集成

- **Android**: 自动化 Google Play Store 发布
- **iOS**: 自动化 TestFlight 和 App Store 发布

## 📖 使用指南

### 首次设置

1. **配置签名**：
   ```bash
   # Android
   ./scripts/create_release_keystore.sh
   
   # iOS - 在 Xcode 中配置证书
   ```

2. **设置环境变量**：
   ```bash
   # Android
   export ANDROID_HOME=/path/to/android/sdk
   
   # iOS
   export APPLE_ID=your-apple-id@example.com
   export APP_SPECIFIC_PASSWORD=your-app-password
   ```

3. **安装依赖**：
   ```bash
   # Fastlane
   gem install fastlane
   
   # Flutter
   flutter doctor
   ```

### 日常开发流程

1. **开发阶段**：
   ```bash
   # 构建和测试
   ./scripts/build_all.sh --skip-tests
   
   # 部署到内部测试
   ./scripts/quick_deploy.sh -e dev
   ```

2. **测试阶段**：
   ```bash
   # 递增版本并部署到测试环境
   ./scripts/quick_deploy.sh -e staging --bump-version patch
   ```

3. **生产发布**：
   ```bash
   # 发布到生产环境
   ./scripts/quick_deploy.sh -e prod --bump-version minor
   ```

### 发布轨道说明

| 轨道 | Android | iOS | 用途 |
|------|---------|-----|------|
| internal | 内部测试 | TestFlight 内部 | 开发团队测试 |
| alpha | 封闭测试 | TestFlight 外部 | 小范围用户测试 |
| beta | 开放测试 | TestFlight 公开 | 大范围用户测试 |
| production | 正式发布 | App Store | 所有用户 |

## 🔧 故障排除

### 常见问题

1. **Android 签名失败**：
   - 检查 `android/key.properties` 配置
   - 验证密钥库文件路径

2. **iOS 证书问题**：
   - 在 Xcode 中重新配置证书
   - 检查配置文件有效期

3. **版本号冲突**：
   - 使用 `version_manager.sh` 统一管理
   - 检查应用商店现有版本

4. **构建失败**：
   - 运行 `flutter doctor` 检查环境
   - 清理构建缓存：`flutter clean`

### 调试技巧

1. **使用 `--dry-run` 模拟运行**
2. **检查构建日志和报告文件**
3. **使用 `build_summary.sh` 查看构建状态**

## 📚 相关文档

- [应用商店发布指南](app_store_release_guide.md)
- [iOS 构建指南](../scripts/ios_build_guide.md)
- [项目需求文档](prd.md)

## 🔄 维护和更新

### 定期维护任务

1. **更新依赖**：
   ```bash
   flutter pub upgrade
   ```

2. **更新 CI/CD 配置**：
   - 检查 Flutter 版本
   - 更新 GitHub Actions

3. **检查证书有效期**：
   - iOS 证书和配置文件
   - Android 密钥库

4. **监控构建性能**：
   - 构建时间
   - 应用大小
   - 测试覆盖率

### 版本发布检查清单

- [ ] 代码审查完成
- [ ] 所有测试通过
- [ ] 版本号正确递增
- [ ] 更新日志已准备
- [ ] 应用商店元数据更新
- [ ] 证书和签名有效
- [ ] 构建产物验证通过

## 🎯 最佳实践

1. **版本管理**：
   - 使用语义化版本号
   - 每次发布递增构建号
   - 为重要版本创建 Git 标签

2. **测试策略**：
   - 内部测试 → 封闭测试 → 开放测试 → 生产发布
   - 每个阶段充分测试后再进入下一阶段

3. **自动化**：
   - 使用 CI/CD 减少手动操作
   - 自动化测试和代码质量检查
   - 自动生成发布报告

4. **安全性**：
   - 妥善保管签名密钥
   - 使用环境变量存储敏感信息
   - 定期更新依赖和工具

## 📞 支持

如有问题，请参考：
- 脚本内置的 `--help` 选项
- [应用商店发布指南](app_store_release_guide.md)
- 项目 Issues 页面

---

**注意**：首次使用前请仔细阅读各脚本的帮助信息，并根据实际环境调整配置。
