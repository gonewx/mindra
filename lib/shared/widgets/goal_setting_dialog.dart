import 'package:flutter/material.dart';
import '../../features/goals/data/services/goal_service.dart';
import '../../features/goals/domain/entities/user_goal.dart';

class GoalSettingDialog extends StatefulWidget {
  const GoalSettingDialog({super.key});

  @override
  State<GoalSettingDialog> createState() => _GoalSettingDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const GoalSettingDialog(),
    );
  }
}

class _GoalSettingDialogState extends State<GoalSettingDialog> {
  String _selectedDailyGoal = '20分钟';
  String _selectedWeeklyGoal = '7次';
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  final List<String> _dailyGoals = [
    '10分钟',
    '15分钟',
    '20分钟',
    '30分钟',
    '45分钟',
    '60分钟',
  ];
  final List<String> _weeklyGoals = ['3次', '5次', '7次', '10次', '14次'];

  @override
  void initState() {
    super.initState();
    _loadSavedGoals();
  }

  // 加载已保存的目标设置
  Future<void> _loadSavedGoals() async {
    try {
      final savedGoal = await GoalService.getGoal();
      setState(() {
        _selectedDailyGoal = savedGoal.dailyGoal;
        _selectedWeeklyGoal = savedGoal.weeklyGoal;
        _reminderTime = savedGoal.reminderTime;
      });
    } catch (e) {
      debugPrint('Error loading saved goals: $e');
      // 如果加载失败，保持默认值
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3441) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12), // --radius-lg: 12px
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A3441)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '目标设置',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark
                          ? const Color(0xFF32B8C6)
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(shape: const CircleBorder()),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Goal
                  Text(
                    '每日目标',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2329)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3A3F47)
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDailyGoal,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      dropdownColor: isDark ? const Color(0xFF2A3441) : null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.today_outlined,
                          color: isDark
                              ? const Color(0xFF32B8C6)
                              : theme.colorScheme.primary,
                        ),
                      ),
                      items: _dailyGoals.map((goal) {
                        return DropdownMenuItem(
                          value: goal,
                          child: Text(
                            goal,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDailyGoal = value!;
                        });
                      },
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weekly Goal
                  Text(
                    '每周目标',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2329)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3A3F47)
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedWeeklyGoal,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      dropdownColor: isDark ? const Color(0xFF2A3441) : null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: isDark
                              ? const Color(0xFF32B8C6)
                              : theme.colorScheme.primary,
                        ),
                      ),
                      items: _weeklyGoals.map((goal) {
                        return DropdownMenuItem(
                          value: goal,
                          child: Text(
                            goal,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWeeklyGoal = value!;
                        });
                      },
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reminder Time
                  Text(
                    '提醒时间',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _selectTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3F47)
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            color: isDark
                                ? const Color(0xFF32B8C6)
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: isDark
                                ? Colors.white70
                                : theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A3441)
                    : theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF3A3F47)
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF3A3F47)
                              : theme.colorScheme.outline,
                        ),
                        foregroundColor: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface,
                        backgroundColor: isDark
                            ? const Color(0xFF1E2329)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveGoals,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: isDark
                            ? const Color(0xFF32B8C6)
                            : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // --radius-lg: 12px
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _saveGoals() async {
    try {
      // 验证目标设置是否有效
      if (!GoalService.isValidGoal(_selectedDailyGoal, _selectedWeeklyGoal)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目标设置无效，请检查输入')));
        return;
      }

      // 创建新的目标对象
      final now = DateTime.now();
      final newGoal = UserGoal(
        dailyGoal: _selectedDailyGoal,
        weeklyGoal: _selectedWeeklyGoal,
        reminderTime: _reminderTime,
        createdAt: now,
        updatedAt: now,
      );

      // 保存目标设置
      await GoalService.saveGoal(newGoal);

      // 关闭对话框
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目标设置已保存')));
      }
    } catch (e) {
      debugPrint('Error saving goals: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }
}
