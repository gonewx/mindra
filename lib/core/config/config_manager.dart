import 'package:flutter/foundation.dart';
import 'app_config_service.dart';

/// 配置管理工具类
/// 提供便捷的方法来设置和管理应用配置
class ConfigManager {
  
  /// 设置隐私政策URL（支持多语言）
  /// 
  /// [defaultUrl] 默认URL
  /// [zhUrl] 中文URL（可选）
  /// [enUrl] 英文URL（可选）
  static Future<void> setPrivacyPolicyUrls({
    required String defaultUrl,
    String? zhUrl,
    String? enUrl,
  }) async {
    // 设置默认URL
    await AppConfigService.setConfig('privacy_policy_url', defaultUrl);
    
    // 设置中文URL
    if (zhUrl != null) {
      await AppConfigService.setConfig('privacy_policy_url_zh', zhUrl);
    }
    
    // 设置英文URL
    if (enUrl != null) {
      await AppConfigService.setConfig('privacy_policy_url_en', enUrl);
    }
    
    debugPrint('Privacy policy URLs updated:');
    debugPrint('  Default: $defaultUrl');
    debugPrint('  Chinese: ${zhUrl ?? 'Not set'}');
    debugPrint('  English: ${enUrl ?? 'Not set'}');
  }
  
  /// 设置服务条款URL（支持多语言）
  static Future<void> setTermsOfServiceUrls({
    required String defaultUrl,
    String? zhUrl,
    String? enUrl,
  }) async {
    await AppConfigService.setConfig('terms_of_service_url', defaultUrl);
    
    if (zhUrl != null) {
      await AppConfigService.setConfig('terms_of_service_url_zh', zhUrl);
    }
    
    if (enUrl != null) {
      await AppConfigService.setConfig('terms_of_service_url_en', enUrl);
    }
    
    debugPrint('Terms of service URLs updated:');
    debugPrint('  Default: $defaultUrl');
    debugPrint('  Chinese: ${zhUrl ?? 'Not set'}');
    debugPrint('  English: ${enUrl ?? 'Not set'}');
  }
  
  /// 设置远程配置URL
  static Future<void> setRemoteConfigUrl(String url) async {
    await AppConfigService.setConfig('remote_config_url', url);
    debugPrint('Remote config URL updated: $url');
  }
  
  /// 获取当前所有配置
  static Map<String, String> getAllConfigs() {
    return AppConfigService.getAllConfig();
  }
  
  /// 刷新远程配置
  static Future<void> refreshRemoteConfig() async {
    await AppConfigService.refreshRemoteConfig();
    debugPrint('Remote config refreshed');
  }
  
  /// 重置为默认配置
  static Future<void> resetToDefault() async {
    await AppConfigService.resetToDefault();
    debugPrint('Config reset to default');
  }
  
  /// 批量设置配置
  static Future<void> setBatchConfig(Map<String, String> configs) async {
    for (final entry in configs.entries) {
      await AppConfigService.setConfig(entry.key, entry.value);
    }
    debugPrint('Batch config updated: ${configs.keys.join(', ')}');
  }
  
  /// 预设配置模板
  
  /// 使用GitHub Pages配置
  static Future<void> useGitHubPagesConfig({
    required String repoOwner,
    required String repoName,
    String branch = 'main',
  }) async {
    final baseUrl = 'https://$repoOwner.github.io/$repoName';
    
    await setPrivacyPolicyUrls(
      defaultUrl: '$baseUrl/privacy_policy.md',
      zhUrl: '$baseUrl/privacy_policy_zh.md',
      enUrl: '$baseUrl/privacy_policy_en.md',
    );
    
    await setTermsOfServiceUrls(
      defaultUrl: '$baseUrl/terms_of_service.md',
      zhUrl: '$baseUrl/terms_of_service_zh.md',
      enUrl: '$baseUrl/terms_of_service_en.md',
    );
    
    await setRemoteConfigUrl('$baseUrl/config/app_config.json');
  }
  
  /// 使用GitHub Raw配置
  static Future<void> useGitHubRawConfig({
    required String repoOwner,
    required String repoName,
    String branch = 'main',
    String docsPath = 'docs',
  }) async {
    final baseUrl = 'https://raw.githubusercontent.com/$repoOwner/$repoName/$branch/$docsPath';
    
    await setPrivacyPolicyUrls(
      defaultUrl: '$baseUrl/privacy_policy.md',
      zhUrl: '$baseUrl/privacy_policy_zh.md',
      enUrl: '$baseUrl/privacy_policy_en.md',
    );
    
    await setTermsOfServiceUrls(
      defaultUrl: '$baseUrl/terms_of_service.md',
      zhUrl: '$baseUrl/terms_of_service_zh.md',
      enUrl: '$baseUrl/terms_of_service_en.md',
    );
    
    await setRemoteConfigUrl('https://raw.githubusercontent.com/$repoOwner/$repoName/$branch/config/app_config.json');
  }
  
  /// 使用自定义域名配置
  static Future<void> useCustomDomainConfig({
    required String domain,
    String path = '/docs',
  }) async {
    final baseUrl = 'https://$domain$path';
    
    await setPrivacyPolicyUrls(
      defaultUrl: '$baseUrl/privacy_policy.md',
      zhUrl: '$baseUrl/privacy_policy_zh.md',
      enUrl: '$baseUrl/privacy_policy_en.md',
    );
    
    await setTermsOfServiceUrls(
      defaultUrl: '$baseUrl/terms_of_service.md',
      zhUrl: '$baseUrl/terms_of_service_zh.md',
      enUrl: '$baseUrl/terms_of_service_en.md',
    );
    
    await setRemoteConfigUrl('https://$domain/config/app_config.json');
  }
  
  /// 使用本地测试配置
  static Future<void> useLocalTestConfig() async {
    await setPrivacyPolicyUrls(
      defaultUrl: 'test_privacy_policy.md',
      zhUrl: 'test_privacy_policy.md',
      enUrl: 'privacy_policy_en.md',
    );
    
    await setTermsOfServiceUrls(
      defaultUrl: 'terms_of_service.md',
      zhUrl: 'terms_of_service_zh.md',
      enUrl: 'terms_of_service_en.md',
    );
    
    await setRemoteConfigUrl('app_config.json');
  }
}
