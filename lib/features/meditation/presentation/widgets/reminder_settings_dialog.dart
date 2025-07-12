import 'package:flutter/material.dart';
import '../../../goals/domain/entities/user_goal.dart';
import '../../../goals/data/services/goal_service.dart';
import '../../../../core/services/reminder_scheduler_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/weekday.dart';

class ReminderSettingsDialog extends StatefulWidget {
  final UserGoal? currentGoal;
  final Function(UserGoal goal)? onGoalUpdated;

  const ReminderSettingsDialog({
    super.key,
    this.currentGoal,
    this.onGoalUpdated,
  });

  @override
  State<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  late TimeOfDay _selectedReminderTime;
  bool _isReminderEnabled = true;
  bool _isLoading = false;
  List<Weekday> _selectedDays = WeekdayExtension.allWeekdays;
  bool _enableSound = true;
  bool _enableVibration = true;

  final ReminderSchedulerService _reminderService = ReminderSchedulerService();

  @override
  void initState() {
    super.initState();
    _selectedReminderTime =
        widget.currentGoal?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    _isReminderEnabled = widget.currentGoal?.isReminderEnabled ?? false;
    _selectedDays =
        widget.currentGoal?.reminderDays ?? WeekdayExtension.allWeekdays;
    _enableSound = widget.currentGoal?.enableSound ?? true;
    _enableVibration = widget.currentGoal?.enableVibration ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.remindersSettingsTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 开启提醒
              _buildReminderToggle(theme, l10n),
              const SizedBox(height: 24),

              // 提醒时间
              if (_isReminderEnabled) ...[
                _buildSectionTitle(
                  l10n.remindersTime,
                  Icons.access_time_outlined,
                  theme,
                ),
                const SizedBox(height: 12),
                _buildTimeSelector(theme, l10n),
                const SizedBox(height: 24),

                // 提醒日期
                _buildSectionTitle(
                  l10n.remindersDate,
                  Icons.calendar_today_outlined,
                  theme,
                ),
                const SizedBox(height: 12),
                _buildDaySelector(theme, l10n),
                const SizedBox(height: 24),

                // 提醒方式
                _buildSectionTitle(
                  l10n.remindersMethod,
                  Icons.notifications_outlined,
                  theme,
                ),
                const SizedBox(height: 12),
                _buildNotificationOptions(theme, l10n),
                const SizedBox(height: 32),
              ],

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveReminderSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Text(l10n.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderToggle(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.remindersEnable,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.remindersEnableDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '提醒时间可能会有几分钟的偏差，这是为了节省电池并符合系统政策。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _isReminderEnabled,
            onChanged: (value) {
              setState(() {
                _isReminderEnabled = value;
              });
            },
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.remindersTimeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedReminderTime.hour.toString().padLeft(2, '0')}:${_selectedReminderTime.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectTime,
              icon: Icon(Icons.access_time, size: 18),
              label: Text(l10n.remindersSelectTime),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                foregroundColor: theme.colorScheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme, AppLocalizations l10n) {
    final days = WeekdayExtension.allWeekdays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.remindersSelectDates,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: days.map((day) {
              final isSelected = _selectedDays.contains(day);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: BoxConstraints(minWidth: 60, maxWidth: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    day.getDisplayName(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOptions(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.remindersMethodLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationOption(
            l10n.remindersNotification,
            l10n.remindersNotificationDescription,
            Icons.notifications,
            true,
            theme,
            (value) {},
          ),
          const SizedBox(height: 8),
          _buildNotificationOption(
            l10n.remindersSound,
            l10n.remindersSoundDescription,
            Icons.volume_up,
            _enableSound,
            theme,
            (value) {
              setState(() {
                _enableSound = value;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildNotificationOption(
            l10n.remindersVibration,
            l10n.remindersVibrationDescription,
            Icons.vibration,
            _enableVibration,
            theme,
            (value) {
              setState(() {
                _enableVibration = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOption(
    String title,
    String subtitle,
    IconData icon,
    bool isEnabled,
    ThemeData theme,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isEnabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isEnabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: isEnabled,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedReminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedReminderTime) {
      setState(() {
        _selectedReminderTime = picked;
      });
    }
  }

  Future<void> _saveReminderSettings() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
    });

    try {
      // 先请求通知权限
      if (_isReminderEnabled) {
        final hasPermission = await _reminderService
            .requestNotificationPermissions();
        if (!hasPermission) {
          if (mounted) {
            // 显示权限说明对话框
            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.permissionsTitle),
                content: Text(l10n.permissionsDescription),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.actionGoToSettings),
                  ),
                ],
              ),
            );

            if (shouldContinue != true) {
              setState(() {
                _isLoading = false;
                _isReminderEnabled = false;
              });
              return;
            }

            // 打开系统设置
            // 注意：这里只是保存设置，用户需要手动开启权限后重新设置
          }
        }
      }

      // 保存设置到目标服务
      await GoalService.updateGoal(reminderTime: _selectedReminderTime);

      // 获取更新后的目标
      final currentGoal = await GoalService.getGoal();

      // 更新所有提醒设置
      final updatedGoal = currentGoal.copyWith(
        reminderTime: _selectedReminderTime,
        isReminderEnabled: _isReminderEnabled,
        reminderDays: _selectedDays,
        enableSound: _enableSound,
        enableVibration: _enableVibration,
        updatedAt: DateTime.now(),
      );

      await GoalService.saveGoal(updatedGoal);

      // 更新提醒调度
      await _reminderService.updateReminderSettings(updatedGoal);

      // 通知回调
      widget.onGoalUpdated?.call(updatedGoal);

      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isReminderEnabled
                  ? l10n.remindersSettingsSaved
                  : l10n.remindersDisabled,
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.remindersSaveFailed(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// 显示提醒设置对话框的辅助函数
Future<void> showReminderSettingsDialog(
  BuildContext context, {
  UserGoal? currentGoal,
  Function(UserGoal goal)? onGoalUpdated,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return ReminderSettingsDialog(
        currentGoal: currentGoal,
        onGoalUpdated: onGoalUpdated,
      );
    },
  );
}
