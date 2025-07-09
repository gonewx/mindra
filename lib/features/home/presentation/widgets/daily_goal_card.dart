import 'package:flutter/material.dart';
import '../../../../shared/widgets/goal_setting_dialog.dart';

class DailyGoalCard extends StatelessWidget {
  final double? cardPadding; // 卡片内边距控制
  final double? borderRadius; // 圆角控制

  const DailyGoalCard({
    super.key,
    this.cardPadding, // 默认为 null，使用内置默认值 20
    this.borderRadius, // 默认为 null，使用内置默认值 12
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 使用可配置的参数，如果没有提供则使用默认值
    final effectivePadding = cardPadding ?? 20.0; // 默认 20px 匹配原型
    final effectiveBorderRadius = borderRadius ?? 12.0; // 默认 12px 匹配原型

    return InkWell(
      onTap: () => GoalSettingDialog.show(context),
      borderRadius: BorderRadius.circular(effectiveBorderRadius),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100, // 确保最小高度，避免内容挤压
        ),
        padding: EdgeInsets.all(effectivePadding), // 可配置的内边距
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
          borderRadius: BorderRadius.circular(effectiveBorderRadius), // 可配置的圆角
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 防止 Column 占用过多空间
                  children: [
                    Flexible(
                      child: Text(
                        '今日目标',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          // 移除额外的fontWeight，使用主题默认的w500
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        '20分钟冥想',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16), // 添加间距避免挤压
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: 0.75, // 75% progress
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '75%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
}
