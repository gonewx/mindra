import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

/// 应用配置服务
/// 管理应用的各种配置项，包括隐私政策URL等
class AppConfigService {
  static const String _configKey = 'app_config';
  static const String _privacyPolicyUrlKey = 'privacy_policy_url';
  static const String _termsOfServiceUrlKey = 'terms_of_service_url';
  static const String _remoteConfigUrlKey = 'remote_config_url';

  // 默认配置
  static const Map<String, String> _defaultConfig = {
    // 默认隐私政策URL（中文）
    _privacyPolicyUrlKey:
        'https://ycmindra.oss-cn-shanghai.aliyuncs.com/privacy_policy_en.md',
    // 中文隐私政策URL
    '${_privacyPolicyUrlKey}_zh':
        'https://ycmindra.oss-cn-shanghai.aliyuncs.com/privacy_policy_zh.md',
    // 英文隐私政策URL
    '${_privacyPolicyUrlKey}_en':
        'https://ycmindra.oss-cn-shanghai.aliyuncs.com/privacy_policy_en.md',

    _termsOfServiceUrlKey:
        'https://raw.githubusercontent.com/mindra-app/mindra/main/docs/terms_of_service_zh.md',
    _remoteConfigUrlKey:
        'https://raw.githubusercontent.com/mindra-app/mindra/main/config/app_config.json',
  };

  static final Dio _dio = Dio();
  static Map<String, String> _config = Map.from(_defaultConfig);
  static bool _initialized = false;

  /// 初始化配置服务
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadLocalConfig();
      await _loadRemoteConfig();
      _initialized = true;
      debugPrint('AppConfigService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AppConfigService: $e');
      // 使用默认配置
      _config = Map.from(_defaultConfig);
      _initialized = true;
    }
  }

  /// 从本地存储加载配置
  static Future<void> _loadLocalConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson != null && configJson.isNotEmpty) {
        final localConfig = Map<String, String>.from(
          json.decode(configJson) as Map<String, dynamic>,
        );
        _config.addAll(localConfig);
        debugPrint('Loaded local config: $localConfig');
      }
    } catch (e) {
      debugPrint('Error loading local config: $e');
    }
  }

  /// 从远程加载配置
  static Future<void> _loadRemoteConfig() async {
    try {
      final remoteConfigUrl = _config[_remoteConfigUrlKey];
      if (remoteConfigUrl == null || remoteConfigUrl.isEmpty) {
        return;
      }

      final response = await _dio.get(
        remoteConfigUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final remoteConfig = Map<String, String>.from(
          response.data as Map<String, dynamic>,
        );

        // 合并远程配置
        _config.addAll(remoteConfig);

        // 保存到本地
        await _saveLocalConfig();

        debugPrint('Loaded remote config: $remoteConfig');
      }
    } catch (e) {
      debugPrint('Error loading remote config: $e');
      // 远程配置加载失败不影响应用运行
    }
  }

  /// 保存配置到本地存储
  static Future<void> _saveLocalConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, json.encode(_config));
      debugPrint('Saved local config');
    } catch (e) {
      debugPrint('Error saving local config: $e');
    }
  }

  /// 获取隐私政策URL
  static String getPrivacyPolicyUrl([String? locale]) {
    if (!_initialized) {
      debugPrint('AppConfigService not initialized, using default URL');
      return _defaultConfig[_privacyPolicyUrlKey]!;
    }

    // 根据语言环境选择对应的URL
    String key = _privacyPolicyUrlKey;
    if (locale != null) {
      if (locale.startsWith('en')) {
        key = '${_privacyPolicyUrlKey}_en';
      } else if (locale.startsWith('zh')) {
        key = '${_privacyPolicyUrlKey}_zh';
      }
    }

    return _config[key] ??
        _config[_privacyPolicyUrlKey] ??
        _defaultConfig[_privacyPolicyUrlKey]!;
  }

  /// 获取服务条款URL
  static String getTermsOfServiceUrl([String? locale]) {
    if (!_initialized) {
      debugPrint('AppConfigService not initialized, using default URL');
      return _defaultConfig[_termsOfServiceUrlKey]!;
    }

    // 根据语言环境选择对应的URL
    String key = _termsOfServiceUrlKey;
    if (locale != null) {
      if (locale.startsWith('en')) {
        key = '${_termsOfServiceUrlKey}_en';
      } else if (locale.startsWith('zh')) {
        key = '${_termsOfServiceUrlKey}_zh';
      }
    }

    return _config[key] ??
        _config[_termsOfServiceUrlKey] ??
        _defaultConfig[_termsOfServiceUrlKey]!;
  }

  /// 获取配置项
  static String? getConfig(String key) {
    if (!_initialized) {
      debugPrint('AppConfigService not initialized');
      return _defaultConfig[key];
    }
    return _config[key];
  }

  /// 设置配置项
  static Future<void> setConfig(String key, String value) async {
    _config[key] = value;
    await _saveLocalConfig();
    debugPrint('Set config: $key = $value');
  }

  /// 刷新远程配置
  static Future<void> refreshRemoteConfig() async {
    try {
      await _loadRemoteConfig();
      debugPrint('Remote config refreshed');
    } catch (e) {
      debugPrint('Error refreshing remote config: $e');
    }
  }

  /// 重置为默认配置
  static Future<void> resetToDefault() async {
    _config = Map.from(_defaultConfig);
    await _saveLocalConfig();
    debugPrint('Config reset to default');
  }

  /// 获取所有配置
  static Map<String, String> getAllConfig() {
    return Map.from(_config);
  }
}
