import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _sessionReminderEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localizations = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: themeProvider.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              localizations.personalCenter,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize:
                    theme.textTheme.headlineLarge!.fontSize! *
                    themeProvider.getResponsiveFontScale(context),
              ),
            ),
            const SizedBox(height: 32),

            // Profile Section
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.self_improvement,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Info
                    Text(
                      localizations.meditator,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Settings Sections
            _buildSettingsSection(
              title: localizations.personalizationSettings,
              items: [
                _SettingItem(
                  icon: Icons.palette,
                  title: localizations.themeSettings,
                  onTap: () => _showThemeDialog(themeProvider),
                ),
                _SettingItem(
                  icon: Icons.language,
                  title: localizations.languageSettings,
                  onTap: () => _showLanguageDialog(themeProvider),
                ),
                _SettingItem(
                  icon: Icons.notifications,
                  title: localizations.notificationSettings,
                  onTap: _showNotificationDialog,
                ),
                _SettingItem(
                  icon: Icons.view_module,
                  title: localizations.cardSpacing,
                  onTap: () => _showCardSpacingDialog(themeProvider),
                ),
                _SettingItem(
                  icon: Icons.padding,
                  title: localizations.cardPadding,
                  onTap: () => _showCardPaddingDialog(themeProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSettingsSection(
              title: localizations.about,
              items: [
                _SettingItem(
                  icon: Icons.info,
                  title: localizations.aboutApp,
                  onTap: _showAboutDialog,
                ),
                _SettingItem(
                  icon: Icons.privacy_tip,
                  title: localizations.privacyPolicy,
                  onTap: _navigateToPrivacyPolicy,
                ),
                // 调试选项 - 仅在开发模式下显示
                if (kDebugMode)
                  _SettingItem(
                    icon: Icons.bug_report,
                    title: '数据库调试信息',
                    onTap: _navigateToDatabaseDebug,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showNotificationDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            localizations.notificationSettingsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(
                      localizations.pushNotifications,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      localizations.pushNotificationsDesc,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      this.setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      localizations.dailyReminder,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      localizations.dailyReminderDesc,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: _dailyReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _dailyReminderEnabled = value;
                      });
                      this.setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      localizations.sessionReminder,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      localizations.sessionReminderDesc,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: _sessionReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _sessionReminderEnabled = value;
                      });
                      this.setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.notificationSettingsSaved),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: Text(localizations.confirm),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(ThemeProvider themeProvider) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations.selectTheme,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppThemeMode.values.map((theme) {
                return RadioListTile<AppThemeMode>(
                  title: Text(
                    theme.displayNameLocalized(context),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: theme,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(ThemeProvider themeProvider) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations.selectLanguage,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<Locale>(
                  title: Text(
                    localizations.simplifiedChinese,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: const Locale('zh', 'CN'),
                  groupValue: themeProvider.locale,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setLocale(value);
                    }
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<Locale>(
                  title: Text(
                    localizations.english,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: const Locale('en', 'US'),
                  groupValue: themeProvider.locale,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setLocale(value);
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCardSpacingDialog(ThemeProvider themeProvider) {
    final localizations = AppLocalizations.of(context)!;
    double tempSpacing = themeProvider.cardSpacing;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            localizations.adjustCardSpacing,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.currentSpacing(tempSpacing.round()),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempSpacing,
                    min: 8.0,
                    max: 32.0,
                    divisions: 12,
                    label: '${tempSpacing.round()}px',
                    onChanged: (value) {
                      setState(() {
                        tempSpacing = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          localizations.compact8px,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          localizations.loose32px,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                themeProvider.setCardSpacing(tempSpacing);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.cardSpacingSet(tempSpacing.round()),
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: Text(localizations.confirm),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardPaddingDialog(ThemeProvider themeProvider) {
    final localizations = AppLocalizations.of(context)!;
    double tempPadding = themeProvider.cardPadding;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            localizations.adjustCardPadding,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.currentPadding(tempPadding.round()),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempPadding,
                    min: 12.0,
                    max: 32.0,
                    divisions: 10,
                    label: '${tempPadding.round()}px',
                    onChanged: (value) {
                      setState(() {
                        tempPadding = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          localizations.compact12px,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          localizations.loose32px,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                themeProvider.setCardPadding(tempPadding);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.cardPaddingSet(tempPadding.round()),
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: Text(localizations.confirm),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    final localizations = AppLocalizations.of(context)!;
    showAboutDialog(
      context: context,
      applicationName: 'Mindra',
      applicationVersion: '1.0.0',
      applicationIcon: SizedBox(
        width: 48,
        height: 48,
        child: SvgPicture.asset(
          'assets/images/app_icon.svg',
          width: 48,
          height: 48,
        ),
      ),
      children: [Text(localizations.aboutAppDescription)],
    );
  }

  void _navigateToPrivacyPolicy() {
    context.go(AppRouter.privacyPolicy);
  }

  void _navigateToDatabaseDebug() {
    context.go(AppRouter.databaseDebug);
  }

  Widget _buildSettingsSection({
    required String title,
    required List<_SettingItem> items,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon, color: theme.colorScheme.primary),
                    title: Text(
                      item.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onTap: item.onTap,
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _SettingItem({required this.icon, required this.title, required this.onTap});
}
