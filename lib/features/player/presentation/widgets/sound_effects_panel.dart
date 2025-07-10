import 'package:flutter/material.dart';
import '../../services/simple_sound_effects_player.dart';
import '../../../../core/localization/app_localizations.dart';

class SoundEffectsPanel extends StatefulWidget {
  const SoundEffectsPanel({super.key});

  @override
  State<SoundEffectsPanel> createState() => _SoundEffectsPanelState();
}

class _SoundEffectsPanelState extends State<SoundEffectsPanel> {
  final SimpleSoundEffectsPlayer _soundPlayer = SimpleSoundEffectsPlayer();

  // 简化的音效状态管理
  final Map<String, double> _effectVolumes = {
    'rain': 0.0,
    'ocean': 0.0,
    'wind_chimes': 0.0,
    'birds': 0.0,
  };

  double _masterVolume = 0.5;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitialize();
  }

  void _checkAndInitialize() async {
    try {
      // 检查音效播放器是否已正确初始化
      final testVolumes = _soundPlayer.currentVolumes;
      if (testVolumes.isEmpty) {
        debugPrint('Sound effects player not initialized, initializing now...');
        await _soundPlayer.initialize();
      }

      // 同步当前音效状态
      _syncCurrentState();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      debugPrint('Sound effects panel ready');
    } catch (e) {
      debugPrint('Failed to verify sound effects player: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true; // 即使失败也标记为已初始化
        });
      }
    }
  }

  // 同步当前音效状态
  void _syncCurrentState() {
    final currentVolumes = _soundPlayer.currentVolumes;
    final currentMasterVolume = _soundPlayer.masterVolume;

    setState(() {
      // 同步各个音效的音量状态
      for (final entry in currentVolumes.entries) {
        if (_effectVolumes.containsKey(entry.key)) {
          _effectVolumes[entry.key] = entry.value;
        }
      }

      // 同步主音量
      _masterVolume = currentMasterVolume;
    });

    debugPrint('Synced sound effects state: $_effectVolumes');
    debugPrint('Synced master volume: $_masterVolume');
  }

  @override
  void dispose() {
    // 注意：不在这里调用 _soundPlayer.dispose()，因为它是单例
    // 音效播放器应该在应用生命周期结束时才被销毁
    super.dispose();
  }

  // 音效配置
  List<Map<String, dynamic>> _getEffects(AppLocalizations localizations) {
    return [
      {'id': 'rain', 'name': localizations.soundEffectsRain, 'icon': Icons.grain},
      {'id': 'ocean', 'name': localizations.soundEffectsOcean, 'icon': Icons.waves},
      {'id': 'wind_chimes', 'name': localizations.soundEffectsWindChimes, 'icon': Icons.air},
      {'id': 'birds', 'name': localizations.soundEffectsBirds, 'icon': Icons.flutter_dash},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;
    final effects = _getEffects(localizations);

    // 显示加载状态
    if (!_isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(localizations.soundEffectsLoading),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Background Sound Effects Section
        Text(
          localizations.soundEffectsBackgroundTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          localizations.soundEffectsBackgroundDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Sound Effects Grid - responsive layout
        LayoutBuilder(
          builder: (context, constraints) {
            // 根据屏幕宽度调整列数
            int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            double childAspectRatio = constraints.maxWidth > 600 ? 2.5 : 2.8;
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: effects.length,
              itemBuilder: (context, index) {
                final effect = effects[index];
                final effectId = effect['id'] as String;
                final isActive = (_effectVolumes[effectId] ?? 0.0) > 0;
                return _SoundEffectButton(
                  effect: effectId,
                  name: effect['name'] as String,
                  icon: effect['icon'] as IconData,
                  isActive: isActive,
                  onTap: () async {
                    final newVolume = isActive ? 0.0 : 0.5;
                    setState(() {
                      _effectVolumes[effectId] = newVolume;
                    });

                    // 实际播放音效
                    await _soundPlayer.toggleEffect(effectId, newVolume);
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),

        // Volume Control Section
        Text(
          localizations.soundEffectsVolumeControl,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        // Volume Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF32B8C6),
            inactiveTrackColor: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.3),
            thumbColor: const Color(0xFF32B8C6),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackHeight: 4,
          ),
          child: Slider(
            value: _masterVolume,
            onChanged: (value) async {
              setState(() {
                _masterVolume = value;
              });

              // 实际设置主音量
              await _soundPlayer.setMasterVolume(value);
            },
            min: 0.0,
            max: 1.0,
          ),
        ),
        const SizedBox(height: 24),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // 确定时保持当前音效设置，不停止播放
              debugPrint(
                'Sound effects confirmed with settings: $_effectVolumes',
              );
              debugPrint('Master volume: $_masterVolume');

              // 显示确认消息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations.soundEffectsSettingsSaved),
                  duration: const Duration(seconds: 2),
                ),
              );

              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF32B8C6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              localizations.actionConfirm,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _SoundEffectButton extends StatelessWidget {
  final String effect;
  final String name;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SoundEffectButton({
    required this.effect,
    required this.name,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minWidth: 100,
            maxWidth: 140,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF32B8C6)
                : (isDark
                      ? const Color(0xFF3A4A5C)
                      : Colors.grey.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF32B8C6)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.3)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[600]),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey[600]),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
