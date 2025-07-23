# Privacy Policy URL Internationalization Configuration Guide

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](privacy_policy_url_configuration_ZH.md)

---

## Configuration Overview

Privacy policy supports multiple configuration methods. You can choose the appropriate configuration method based on different deployment environments and requirements.

## 1. Local Configuration

### 1.1 Directly Modify Default Configuration

Modify in `lib/core/config/app_config_service.dart`:

```dart
static const Map<String, String> _defaultConfig = {
  // Default privacy policy URL (Chinese)
  'privacy_policy_url': 'https://yoursite.com/privacy_policy.md',
  // Chinese privacy policy URL
  'privacy_policy_url_zh': 'https://yoursite.com/privacy_policy_zh.md',
  // English privacy policy URL
  'privacy_policy_url_en': 'https://yoursite.com/privacy_policy_en.md',
};
```

### 1.2 Use ConfigManager Utility Class

```dart
import 'package:mindra/core/config/config_manager.dart';

// Configure at app startup
await ConfigManager.setPrivacyPolicyUrls(
  defaultUrl: 'https://yoursite.com/privacy_policy.md',
  zhUrl: 'https://yoursite.com/privacy_policy_zh.md',
  enUrl: 'https://yoursite.com/privacy_policy_en.md',
);
```

## 2. Remote Configuration

### 2.1 Create Remote Configuration File

Create `app_config.json` file on your server:

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

### 2.2 Set Remote Configuration URL

```dart
await ConfigManager.setRemoteConfigUrl('https://yoursite.com/config/app_config.json');
await ConfigManager.refreshRemoteConfig();
```

## 3. Preset Configuration Templates

### 3.1 GitHub Pages Configuration

If you use GitHub Pages to host documentation:

```dart
await ConfigManager.useGitHubPagesConfig(
  repoOwner: 'your-username',
  repoName: 'your-repo',
);
```

This will automatically configure to:
- Privacy Policy: `https://your-username.github.io/your-repo/privacy_policy.md`
- Chinese version: `https://your-username.github.io/your-repo/privacy_policy_zh.md`
- English version: `https://your-username.github.io/your-repo/privacy_policy_en.md`

### 3.2 GitHub Raw Configuration

If you directly use GitHub repository raw files:

```dart
await ConfigManager.useGitHubRawConfig(
  repoOwner: 'your-username',
  repoName: 'your-repo',
  branch: 'main',
  docsPath: 'docs',
);
```

### 3.3 Custom Domain Configuration

If you have your own domain:

```dart
await ConfigManager.useCustomDomainConfig(
  domain: 'docs.yourapp.com',
  path: '/legal',
);
```

### 3.4 Local Test Configuration

For development and testing:

```dart
await ConfigManager.useLocalTestConfig();
```

## 4. Locale Matching Rules

The system automatically selects corresponding URLs based on user's locale:

1. **Chinese Environment** (`zh`, `zh-CN`, `zh-TW`, etc.)
   - Priority use: `privacy_policy_url_zh`
   - Fallback to: `privacy_policy_url`

2. **English Environment** (`en`, `en-US`, `en-GB`, etc.)
   - Priority use: `privacy_policy_url_en`
   - Fallback to: `privacy_policy_url`

3. **Other Locales**
   - Use: `privacy_policy_url`

## 5. Configuration Priority

Configuration loading priority (from high to low):

1. **Remote Configuration** - Configuration loaded from remote JSON file
2. **Local Cache** - Previously saved configuration
3. **Default Configuration** - Default values defined in code

## 6. Practical Usage Examples

### Example 1: Enterprise Deployment

```dart
// Initialization code in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure enterprise privacy policy URLs
  await ConfigManager.setPrivacyPolicyUrls(
    defaultUrl: 'https://company.com/legal/privacy-policy.md',
    zhUrl: 'https://company.com/legal/privacy-policy-zh.md',
    enUrl: 'https://company.com/legal/privacy-policy-en.md',
  );
  
  // Set remote configuration
  await ConfigManager.setRemoteConfigUrl('https://company.com/config/mindra-config.json');
  
  runApp(MyApp());
}
```

### Example 2: Open Source Project

```dart
// Use GitHub Pages to host documentation
await ConfigManager.useGitHubPagesConfig(
  repoOwner: 'mindra-app',
  repoName: 'mindra-docs',
);
```

### Example 3: Dynamic Configuration

```dart
// Dynamic configuration based on environment
if (kDebugMode) {
  // Development environment uses local files
  await ConfigManager.useLocalTestConfig();
} else {
  // Production environment uses remote configuration
  await ConfigManager.useCustomDomainConfig(
    domain: 'legal.mindra.app',
  );
}
```

## 7. Configuration Management Best Practices

### 7.1 Version Control

Include version information in privacy policy files:

```markdown
# Privacy Policy

*Last Updated: January 2025*
*Version: v1.0*

...
```

### 7.2 Cache Strategy

- Remote configuration is automatically cached locally
- App startup will attempt to refresh remote configuration
- Use cached configuration when network fails

### 7.3 Error Handling

- If URL for specified language doesn't exist, fallback to default URL
- If all URLs are inaccessible, show friendly error message
- Provide retry functionality

### 7.4 Testing Recommendations

1. **Local Testing**: Use `useLocalTestConfig()` for development testing
2. **Network Testing**: Test loading under different network conditions
3. **Language Testing**: Switch different locales to verify URL selection
4. **Error Testing**: Test error handling with invalid URLs

## 8. Troubleshooting

### Common Issues

1. **Privacy policy page shows loading failed**
   - Check if URL is correct
   - Confirm network connection
   - Verify file exists

2. **Still shows wrong language content after language switch**
   - Check corresponding language URL configuration
   - Confirm file naming is correct

3. **Remote configuration not taking effect**
   - Check remote configuration file format
   - Confirm remote configuration URL is accessible
   - Manually call `refreshRemoteConfig()`

### Debugging Methods

Enable debug logs to view configuration loading process:

```dart
// View all current configurations
debugPrint('Current configs: ${ConfigManager.getAllConfigs()}');

// Manually refresh remote configuration
await ConfigManager.refreshRemoteConfig();
```

## 9. Extended Features

More features can be extended based on existing architecture:

- Terms of Service page
- Help documentation
- User agreements
- Version update notes

All of these can use the same configuration pattern and internationalization support.