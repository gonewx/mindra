# Privacy Policy Feature Implementation Documentation

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](privacy_policy_implementation_ZH.md)

---

## Feature Overview

Added a privacy policy section to the personal center page that supports fetching markdown-formatted privacy policy content through configured URLs and displaying it with internationalization support.

## Implemented Features

### 1. App Configuration Service (AppConfigService)

**File Location**: `lib/core/config/app_config_service.dart`

**Main Functions**:
- Manages various application configuration items, including privacy policy URLs
- Supports local storage and remote configuration
- Supports multi-language URL configuration
- Automatically loads configuration from remote and caches locally

**Core Methods**:
- `initialize()` - Initialize configuration service
- `getPrivacyPolicyUrl(locale)` - Get privacy policy URL based on locale
- `refreshRemoteConfig()` - Refresh remote configuration

### 2. Privacy Policy Page (PrivacyPolicyPage)

**File Location**: `lib/features/settings/presentation/pages/privacy_policy_page.dart`

**Main Functions**:
- Fetch markdown content from configured URL
- Render markdown content using flutter_markdown
- Support loading states, error states, and retry functionality
- Responsive design, adapts to different screen sizes
- Complete markdown style support (headers, paragraphs, lists, links, code, quotes, tables, etc.)

**UI Features**:
- Shows progress indicator during loading
- Displays friendly error messages on network errors
- Supports retry functionality
- Content is selectable and copyable

### 3. Route Configuration

**File Location**: `lib/core/router/app_router.dart`

**Updates**:
- Added privacy policy page route `/privacy-policy`
- Route configuration outside ShellRoute ensures independent page navigation

### 4. Personal Center Page Updates

**File Location**: `lib/features/settings/presentation/pages/settings_page.dart`

**Updates**:
- Added privacy policy entry in the "About" section
- Uses privacy icon (Icons.privacy_tip)
- Navigates to privacy policy page on tap

### 5. Internationalization Support

**File Location**: `lib/core/localization/app_localizations.dart`

**Added Text**:
- `privacy_policy` - Privacy Policy
- `privacy_policy_loading` - Loading privacy policy...
- `privacy_policy_error` - Failed to load privacy policy
- `privacy_policy_retry` - Retry
- `privacy_policy_offline` - Cannot view privacy policy offline

### 6. Dependency Management

**File Location**: `pubspec.yaml`

**Added Dependencies**:
- `flutter_markdown: ^0.7.4+1` - For rendering markdown content

## Configuration Instructions

### Default Configuration

```dart
static const Map<String, String> _defaultConfig = {
  _privacyPolicyUrlKey: 'test_privacy_policy.md',
  _termsOfServiceUrlKey: 'https://raw.githubusercontent.com/mindra-app/mindra/main/docs/terms_of_service_zh.md',
  _remoteConfigUrlKey: 'https://raw.githubusercontent.com/mindra-app/mindra/main/config/app_config.json',
};
```

### Multi-language Support

The configuration service supports automatically selecting corresponding URLs based on locale:
- Chinese: `privacy_policy_url_zh`
- English: `privacy_policy_url_en`
- Default: `privacy_policy_url`

### Remote Configuration

Privacy policy URLs can be dynamically updated through remote JSON configuration files. Configuration format:

```json
{
  "privacy_policy_url": "https://example.com/privacy_policy.md",
  "privacy_policy_url_zh": "https://example.com/privacy_policy_zh.md",
  "privacy_policy_url_en": "https://example.com/privacy_policy_en.md"
}
```

## Usage

1. **Access Privacy Policy**:
   - Open the app
   - Go to personal center page (tap avatar in top right)
   - Click "Privacy Policy" in the "About" section

2. **Update Privacy Policy URL**:
   - Modify default configuration in `AppConfigService`
   - Or update dynamically through remote configuration file

3. **Customize Styles**:
   - Modify `MarkdownStyleSheet` configuration in `PrivacyPolicyPage`

## Technical Features

- **Responsive Design**: Adapts to different screen sizes
- **Error Handling**: Complete network error handling and user feedback
- **Performance Optimization**: Configuration caching and asynchronous loading
- **User Experience**: Loading state indicators and retry functionality
- **Maintainability**: Modular design, easy to extend and maintain
- **Internationalization**: Complete multi-language support

## Testing

The app has been successfully compiled and can run on web platform. Test with the following steps:

1. Run `flutter build web`
2. Start local server
3. Access app in browser
4. Navigate to Personal Center > Privacy Policy

## Future Extensions

1. **Terms of Service**: Can similarly add terms of service page
2. **Help Documentation**: Extend to complete help documentation system
3. **Version Management**: Add privacy policy version management functionality
4. **User Consent**: Add functionality for users to consent to privacy policy