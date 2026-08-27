import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<AnimatedBottomNavigationItem> items;

  const AnimatedBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      // 移除固定高度，让内部的SizedBox控制高度
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.8),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 16, // 0 -4px 16px var(--app-shadow)
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 49, // 对齐 iOS 原生 TabBar（49pt）；SafeArea 会在下方再补
          // 34px Home 指示器安全区，固定值给太大会让 tab 整体显得悬空偏高
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return _AnimatedNavItem(
                icon: item.icon,
                label: item.label,
                isSelected: index == currentIndex,
                onTap: () => onTap(index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class AnimatedBottomNavigationItem {
  final IconData icon;
  final String label;

  const AnimatedBottomNavigationItem({required this.icon, required this.label});
}

class _AnimatedNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _onHoverChange(bool isHovered) {
    if (mounted) {
      setState(() {
        _isHovered = isHovered;
      });
    }
  }

  void _onPressedChange(bool isPressed) {
    if (mounted) {
      setState(() {
        _isPressed = isPressed;
      });
    }
  }

  Color _getItemColor(ThemeData theme) {
    if (_isPressed) {
      // 按下时的颜色，比选中状态稍深
      return widget.isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.8)
          : theme.colorScheme.secondary.withValues(alpha: 0.8);
    } else if (_isHovered) {
      // .nav-item:hover { color: var(--app-secondary); }
      // 悬停时始终显示次级颜色，不管是否选中
      return theme.colorScheme.secondary;
    } else if (widget.isSelected) {
      // .nav-item.active { color: var(--app-primary); }
      return theme.colorScheme.primary;
    }
    // Default: color: var(--color-text-secondary);
    return theme.brightness == Brightness.dark
        ? const Color(0xFFA7A9A9).withValues(
            alpha: 0.7,
          ) // --color-text-secondary dark
        : const Color(0xFF626871); // --color-text-secondary light 匹配原型
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _onHoverChange(true),
        onExit: (_) => _onHoverChange(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // 确保整个区域都可以响应点击
          onTap: () {
            // 添加触觉反馈
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapDown: (_) => _onPressedChange(true),
          onTapUp: (_) => _onPressedChange(false), // 直接重置，去除延迟
          onTapCancel: () => _onPressedChange(false),
          child: Container(
            height: 49, // 必须与外层 SizedBox 一致，否则子项撑破父约束报溢出
            padding: const EdgeInsets.symmetric(
              horizontal: 2, // 减小水平内边距，增加点击区域
              vertical: 2, // 49 高度下收紧垂直边距，避免内容溢出/留白过大
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 25, color: _getItemColor(theme)),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: _getItemColor(theme),
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 11,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
