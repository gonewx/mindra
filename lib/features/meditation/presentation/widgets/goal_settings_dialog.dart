import 'package:flutter/material.dart';
import '../../../goals/domain/entities/user_goal.dart';
import '../../../goals/data/services/goal_service.dart';

class GoalSettingsDialog extends StatefulWidget {
  final UserGoal? currentGoal;
  final Function(UserGoal goal)? onGoalUpdated;

  const GoalSettingsDialog({
    super.key,
    this.currentGoal,
    this.onGoalUpdated,
  });

  @override
  State<GoalSettingsDialog> createState() => _GoalSettingsDialogState();
}

class _GoalSettingsDialogState extends State<GoalSettingsDialog> {
  late String _selectedDailyGoal;
  late String _selectedWeeklyGoal;
  late TimeOfDay _selectedReminderTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDailyGoal = widget.currentGoal?.dailyGoal ?? '20分钟';
    _selectedWeeklyGoal = widget.currentGoal?.weeklyGoal ?? '7次';
    _selectedReminderTime = widget.currentGoal?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
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
                Text(
                  '目标设置',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
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

            // 每日目标
            _buildSectionTitle('每日目标', Icons.today_outlined, theme),
            const SizedBox(height: 12),
            _buildGoalSelector(
              '每日目标',
              _selectedDailyGoal,
              GoalService.getDailyGoalOptions(),
              (value) => setState(() => _selectedDailyGoal = value),
              theme,
            ),
            const SizedBox(height: 24),

            // 每周目标
            _buildSectionTitle('每周目标', Icons.calendar_view_week_outlined, theme),
            const SizedBox(height: 12),
            _buildGoalSelector(
              '每周目标',
              _selectedWeeklyGoal,
              GoalService.getWeeklyGoalOptions(),
              (value) => setState(() => _selectedWeeklyGoal = value),
              theme,
            ),
            const SizedBox(height: 24),

            // 提醒时间
            _buildSectionTitle('提醒时间', Icons.access_time_outlined, theme),
            const SizedBox(height: 12),
            _buildTimeSelector(theme),
            const SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveGoals,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      : const Text('保存'),
                ),
              ],
            ),
            ],
          ),
        ),
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

  Widget _buildGoalSelector(
    String label,
    String currentValue,
    List<String> options,
    Function(String) onChanged,
    ThemeData theme,
  ) {
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
            '选择$label',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option == currentValue;
              return InkWell(
                onTap: () => onChanged(option),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    option,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(ThemeData theme) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '每日提醒时间',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
          ElevatedButton.icon(
            onPressed: _selectTime,
            icon: Icon(Icons.access_time, size: 18),
            label: Text('选择时间'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: theme.colorScheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
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
              hourMinuteColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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

  Future<void> _saveGoals() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 验证输入
      if (!GoalService.isValidGoal(_selectedDailyGoal, _selectedWeeklyGoal)) {
        throw Exception('目标设置格式不正确');
      }

      // 更新目标
      await GoalService.updateGoal(
        dailyGoal: _selectedDailyGoal,
        weeklyGoal: _selectedWeeklyGoal,
        reminderTime: _selectedReminderTime,
      );

      // 获取更新后的目标
      final updatedGoal = await GoalService.getGoal();

      // 通知回调
      widget.onGoalUpdated?.call(updatedGoal);

      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('目标设置已保存'),
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
            content: Text('保存失败: ${e.toString()}'),
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

// 显示目标设置对话框的辅助函数
Future<void> showGoalSettingsDialog(
  BuildContext context, {
  UserGoal? currentGoal,
  Function(UserGoal goal)? onGoalUpdated,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return GoalSettingsDialog(
        currentGoal: currentGoal,
        onGoalUpdated: onGoalUpdated,
      );
    },
  );
}