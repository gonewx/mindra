# 隐私政策功能实现文档

## 功能概述

在个人中心页面添加了隐私政策栏，支持通过配置的URL获取markdown格式的隐私政策内容并展示，同时支持国际化。

## 实现的功能

### 1. 应用配置服务 (AppConfigService)

**文件位置**: `lib/core/config/app_config_service.dart`

**主要功能**:
- 管理应用的各种配置项，包括隐私政策URL
- 支持本地存储和远程配置
- 支持多语言URL配置
- 自动从远程加载配置并缓存到本地

**核心方法**:
- `initialize()` - 初始化配置服务
- `getPrivacyPolicyUrl(locale)` - 根据语言环境获取隐私政策URL
- `refreshRemoteConfig()` - 刷新远程配置

### 2. 隐私政策页面 (PrivacyPolicyPage)

**文件位置**: `lib/features/settings/presentation/pages/privacy_policy_page.dart`

**主要功能**:
- 从配置的URL获取markdown内容
- 使用flutter_markdown渲染markdown内容
- 支持加载状态、错误状态和重试功能
- 响应式设计，适配不同屏幕尺寸
- 完整的markdown样式支持（标题、段落、列表、链接、代码、引用、表格等）

**UI特性**:
- 加载中显示进度指示器
- 网络错误时显示友好的错误信息
- 支持重试功能
- 内容可选择和复制

### 3. 路由配置

**文件位置**: `lib/core/router/app_router.dart`

**更新内容**:
- 添加了隐私政策页面路由 `/privacy-policy`
- 路由配置在ShellRoute之外，确保独立的页面导航

### 4. 个人中心页面更新

**文件位置**: `lib/features/settings/presentation/pages/settings_page.dart`

**更新内容**:
- 在"关于"部分添加了隐私政策入口
- 使用隐私图标 (Icons.privacy_tip)
- 点击后导航到隐私政策页面

### 5. 国际化支持

**文件位置**: `lib/core/localization/app_localizations.dart`

**添加的文本**:
- `privacy_policy` - 隐私政策
- `privacy_policy_loading` - 正在加载隐私政策...
- `privacy_policy_error` - 加载隐私政策失败
- `privacy_policy_retry` - 重试
- `privacy_policy_offline` - 离线状态下无法查看隐私政策

### 6. 依赖管理

**文件位置**: `pubspec.yaml`

**添加的依赖**:
- `flutter_markdown: ^0.7.4+1` - 用于渲染markdown内容

## 配置说明

### 默认配置

```dart
static const Map<String, String> _defaultConfig = {
  _privacyPolicyUrlKey: 'test_privacy_policy.md',
  _termsOfServiceUrlKey: 'https://raw.githubusercontent.com/mindra-app/mindra/main/docs/terms_of_service_zh.md',
  _remoteConfigUrlKey: 'https://raw.githubusercontent.com/mindra-app/mindra/main/config/app_config.json',
};
```

### 多语言支持

配置服务支持根据语言环境自动选择对应的URL：
- 中文: `privacy_policy_url_zh`
- 英文: `privacy_policy_url_en`
- 默认: `privacy_policy_url`

### 远程配置

可以通过远程JSON配置文件动态更新隐私政策URL，配置格式：

```json
{
  "privacy_policy_url": "https://example.com/privacy_policy.md",
  "privacy_policy_url_zh": "https://example.com/privacy_policy_zh.md",
  "privacy_policy_url_en": "https://example.com/privacy_policy_en.md"
}
```

## 使用方法

1. **访问隐私政策**:
   - 打开应用
   - 进入个人中心页面（点击右上角头像）
   - 在"关于"部分点击"隐私政策"

2. **更新隐私政策URL**:
   - 修改 `AppConfigService` 中的默认配置
   - 或通过远程配置文件动态更新

3. **自定义样式**:
   - 修改 `PrivacyPolicyPage` 中的 `MarkdownStyleSheet` 配置

## 技术特点

- **响应式设计**: 适配不同屏幕尺寸
- **错误处理**: 完善的网络错误处理和用户反馈
- **性能优化**: 配置缓存和异步加载
- **用户体验**: 加载状态指示和重试功能
- **可维护性**: 模块化设计，易于扩展和维护
- **国际化**: 完整的多语言支持

## 测试

应用已成功编译并可以在Web平台运行。可以通过以下步骤测试：

1. 运行 `flutter build web`
2. 启动本地服务器
3. 在浏览器中访问应用
4. 导航到个人中心 > 隐私政策

## 后续扩展

1. **服务条款**: 可以类似地添加服务条款页面
2. **帮助文档**: 扩展为完整的帮助文档系统
3. **版本管理**: 添加隐私政策版本管理功能
4. **用户同意**: 添加用户同意隐私政策的功能
