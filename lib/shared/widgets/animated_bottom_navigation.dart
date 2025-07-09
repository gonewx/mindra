import 'package:flutter/material.dart';

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
          height: 58, // 明确设定导航栏高度，提供足够点击区域
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

  void _onHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
  }

  Color _getItemColor(ThemeData theme) {
    if (_isHovered) {
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
