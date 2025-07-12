# 隐私政策URL国际化配置指南

## 配置方式概览

隐私政策支持多种配置方式，可以根据不同的部署环境和需求选择合适的配置方法。

## 1. 本地配置方式

### 1.1 直接修改默认配置

在 `lib/core/config/app_config_service.dart` 中修改：

```dart
static const Map<String, String> _defaultConfig = {
  // 默认隐私政策URL（中文）
  'privacy_policy_url': 'https://yoursite.com/privacy_policy.md',
  // 中文隐私政策URL
  'privacy_policy_url_zh': 'https://yoursite.com/privacy_policy_zh.md',
  // 英文隐私政策URL
  'privacy_policy_url_en': 'https://yoursite.com/privacy_policy_en.md',
};
```

### 1.2 使用ConfigManager工具类

```dart
import 'package:mindra/core/config/config_manager.dart';

// 在应用启动时配置
await ConfigManager.setPrivacyPolicyUrls(
  defaultUrl: 'https://yoursite.com/privacy_policy.md',
  zhUrl: 'https://yoursite.com/privacy_policy_zh.md',
  enUrl: 'https://yoursite.com/privacy_policy_en.md',
);
```

## 2. 远程配置方式

### 2.1 创建远程配置文件

在您的服务器上创建 `app_config.json` 文件：

```json
{
  "privacy_policy_url": "https://yoursite.com/privacy_policy.md",
  "privacy_policy_url_zh": "https://yoursite.com/privacy_policy_zh.md",
  "privacy_policy_url_en": "https://yoursite.com/privacy_policy_en.md",
  "terms_of_service_url": "https://yoursite.com/terms_of_service.md",
  "terms_of_service_url_zh": "https://yoursite.com/terms_of_service_zh.md",
  "terms_of_service_url_en": "https://yoursite.com/terms_of_service_en.md"
}
```

### 2.2 设置远程配置URL

```dart
await ConfigManager.setRemoteConfigUrl('https://yoursite.com/config/app_config.json');
await ConfigManager.refreshRemoteConfig();
```

## 3. 预设配置模板

### 3.1 GitHub Pages配置

如果您使用GitHub Pages托管文档：

```dart
await ConfigManager.useGitHubPagesConfig(
  repoOwner: 'your-username',
  repoName: 'your-repo',
);
```

这将自动配置为：
- 隐私政策: `https://your-username.github.io/your-repo/privacy_policy.md`
- 中文版: `https://your-username.github.io/your-repo/privacy_policy_zh.md`
- 英文版: `https://your-username.github.io/your-repo/privacy_policy_en.md`

### 3.2 GitHub Raw配置

如果您直接使用GitHub仓库的原始文件：

```dart
await ConfigManager.useGitHubRawConfig(
  repoOwner: 'your-username',
  repoName: 'your-repo',
  branch: 'main',
  docsPath: 'docs',
);
```

### 3.3 自定义域名配置

如果您有自己的域名：

```dart
await ConfigManager.useCustomDomainConfig(
  domain: 'docs.yourapp.com',
  path: '/legal',
);
```

### 3.4 本地测试配置

用于开发和测试：

```dart
await ConfigManager.useLocalTestConfig();
```

## 4. 语言环境匹配规则

系统会根据用户的语言环境自动选择对应的URL：

1. **中文环境** (`zh`, `zh-CN`, `zh-TW` 等)
   - 优先使用: `privacy_policy_url_zh`
   - 回退到: `privacy_policy_url`

2. **英文环境** (`en`, `en-US`, `en-GB` 等)
   - 优先使用: `privacy_policy_url_en`
   - 回退到: `privacy_policy_url`

3. **其他语言环境**
   - 使用: `privacy_policy_url`

## 5. 配置优先级

配置的加载优先级（从高到低）：

1. **远程配置** - 从远程JSON文件加载的配置
2. **本地缓存** - 之前保存的配置
3. **默认配置** - 代码中定义的默认值

## 6. 实际使用示例

### 示例1：企业部署

```dart
// 在main.dart中的初始化代码
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 配置企业隐私政策URL
  await ConfigManager.setPrivacyPolicyUrls(
    defaultUrl: 'https://company.com/legal/privacy-policy.md',
    zhUrl: 'https://company.com/legal/privacy-policy-zh.md',
    enUrl: 'https://company.com/legal/privacy-policy-en.md',
  );
  
  // 设置远程配置
  await ConfigManager.setRemoteConfigUrl('https://company.com/config/mindra-config.json');
  
  runApp(MyApp());
}
```

### 示例2：开源项目

```dart
// 使用GitHub Pages托管文档
await ConfigManager.useGitHubPagesConfig(
  repoOwner: 'mindra-app',
  repoName: 'mindra-docs',
);
```

### 示例3：动态配置

```dart
// 根据环境动态配置
if (kDebugMode) {
  // 开发环境使用本地文件
  await ConfigManager.useLocalTestConfig();
} else {
  // 生产环境使用远程配置
  await ConfigManager.useCustomDomainConfig(
    domain: 'legal.mindra.app',
  );
}
```

## 7. 配置管理最佳实践

### 7.1 版本控制

在隐私政策文件中包含版本信息：

```markdown
# 隐私政策

*最后更新时间：2025年1月*
*版本：v1.0*

...
```

### 7.2 缓存策略

- 远程配置会自动缓存到本地
- 应用启动时会尝试刷新远程配置
- 网络失败时使用缓存的配置

### 7.3 错误处理

- 如果指定语言的URL不存在，会回退到默认URL
- 如果所有URL都无法访问，会显示友好的错误信息
- 提供重试功能

### 7.4 测试建议

1. **本地测试**: 使用 `useLocalTestConfig()` 进行开发测试
2. **网络测试**: 测试不同网络条件下的加载情况
3. **语言测试**: 切换不同语言环境验证URL选择
4. **错误测试**: 测试无效URL的错误处理

## 8. 故障排除

### 常见问题

1. **隐私政策页面显示加载失败**
   - 检查URL是否正确
   - 确认网络连接
   - 验证文件是否存在

2. **语言切换后仍显示错误语言的内容**
   - 检查对应语言的URL配置
   - 确认文件命名是否正确

3. **远程配置不生效**
   - 检查远程配置文件格式
   - 确认远程配置URL可访问
   - 手动调用 `refreshRemoteConfig()`

### 调试方法

启用调试日志查看配置加载过程：

```dart
// 查看当前所有配置
debugPrint('Current configs: ${ConfigManager.getAllConfigs()}');

// 手动刷新远程配置
await ConfigManager.refreshRemoteConfig();
```

## 9. 扩展功能

可以基于现有架构扩展更多功能：

- 服务条款页面
- 帮助文档
- 用户协议
- 版本更新说明

所有这些都可以使用相同的配置模式和国际化支持。
