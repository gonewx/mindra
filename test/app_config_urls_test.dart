import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/config/app_config_service.dart';

void main() {
  group('AppConfigService 默认 URL（发布站点 mindra.gonewx.com）', () {
    test('默认隐私政策 URL 指向新站点英文版', () {
      expect(
        AppConfigService.getPrivacyPolicyUrl(),
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',
      );
    });

    test('隐私政策语言版本 URL 指向新站点', () {
      expect(
        AppConfigService.getConfig('privacy_policy_url_zh'),
        'https://mindra.gonewx.com/policy/privacy_policy_zh.md',
      );
      expect(
        AppConfigService.getConfig('privacy_policy_url_en'),
        'https://mindra.gonewx.com/policy/privacy_policy_en.md',
      );
    });

    test('服务条款 URL 指向新站点', () {
      expect(
        AppConfigService.getTermsOfServiceUrl(),
        'https://mindra.gonewx.com/policy/terms_of_service_zh.md',
      );
    });
  });
}
