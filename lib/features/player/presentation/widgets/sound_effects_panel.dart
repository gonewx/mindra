import 'package:flutter/material.dart';
import '../../services/sound_effects_player.dart';
import '../../../../core/localization/app_localizations.dart';

class SoundEffectsPanel extends StatefulWidget {
  const SoundEffectsPanel({super.key});

  @override
  State<SoundEffectsPanel> createState() => _SoundEffectsPanelState();
}

class _SoundEffectsPanelState extends State<SoundEffectsPanel> {
  final SoundEffectsPlayer _soundPlayer = SoundEffectsPlayer();

  // 简化的音效状态管理
  final Map<String, double> _effectVolumes = {
    'rain': 0.0,
    'ocean': 0.0,
    'wind_chimes': 0.0,
    'birds': 0.0,
  };

  // 保存原始设置用于取消时恢复
  final Map<String, double> _originalEffectVolumes = {
    'rain': 0.0,
    'ocean': 0.0,
    'wind_chimes': 0.0,
    'birds': 0.0,
  };

  // 试听状态管理
  final Map<String, bool> _previewingEffects = {
    'rain': false,
    'ocean': false,
    'wind_chimes': false,
    'birds': false,
  };

  double _masterVolume = 0.5;
  double _originalMasterVolume = 0.5;
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
          _originalEffectVolumes[entry.key] = entry.value;
        }
      }

      // 同步主音量
      _masterVolume = currentMasterVolume;
      _originalMasterVolume = currentMasterVolume;
    });

    // 自动恢复当前选中音效的播放状态
    _restoreCurrentlySelectedEffects();

    debugPrint('Synced sound effects state: $_effectVolumes');
    debugPrint('Synced master volume: $_masterVolume');
  }

  // 恢复当前选中音效的播放状态
  Future<void> _restoreCurrentlySelectedEffects() async {
    try {
      for (final entry in _effectVolumes.entries) {
        if (entry.value > 0) {
          // 标记为试听状态并开始播放
          setState(() {
            _previewingEffects[entry.key] = true;
          });

          // 恢复播放当前选中的音效
          await _soundPlayer.previewEffect(entry.key, entry.value);
          debugPrint('Restored playback for selected effect: ${entry.key}');
        }
      }
    } catch (e) {
      debugPrint('Error restoring selected effects playback: $e');
    }
  }

  // 停止试听
  Future<void> _stopPreview(String effectId) async {
    try {
      // 使用新的停止预览方法
      await _soundPlayer.stopPreview();
      if (mounted) {
        setState(() {
          _previewingEffects[effectId] = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping preview for $effectId: $e');
    }
  }

  // 停止所有试听
  Future<void> _stopAllPreviews() async {
    try {
      // 使用统一的停止预览方法，适用于所有平台
      await _soundPlayer.stopPreview();
      if (mounted) {
        setState(() {
          for (final effectId in _previewingEffects.keys) {
            _previewingEffects[effectId] = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error stopping all previews: $e');
    }
  }

  // 切换音效选择状态并试听
  Future<void> _toggleEffectSelection(String effectId) async {
    final isSelected = (_effectVolumes[effectId] ?? 0.0) > 0;

    if (isSelected) {
      // 取消选择，停止试听
      setState(() {
        _effectVolumes[effectId] = 0.0;
        _previewingEffects[effectId] = false;
      });

      // 停止预览播放
      await _soundPlayer.stopPreview();

      // 立即更新音效播放器状态以触发UI更新
      await _soundPlayer.toggleEffect(effectId, 0.0);
    } else {
      // 先停止当前预览（一次只能预览一个音效）
      await _stopAllPreviews();

      // 选择音效，开始试听
      setState(() {
        _effectVolumes[effectId] = 0.5;
        _previewingEffects[effectId] = true;
      });

      // 开始试听当前音效
      await _soundPlayer.previewEffect(effectId, 0.5);
      debugPrint('Started previewing effect: $effectId');
    }
  }

  // 确认设置
  Future<void> _confirmSettings() async {
    try {
      // 停止所有试听
      await _stopAllPreviews();

      // 应用选择的音效设置
      for (final entry in _effectVolumes.entries) {
        await _soundPlayer.toggleEffect(entry.key, entry.value);
      }

      // 应用主音量设置
      await _soundPlayer.setMasterVolume(_masterVolume);

      debugPrint('Sound effects confirmed with settings: $_effectVolumes');
      debugPrint('Master volume: $_masterVolume');

      // 显示确认消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.soundEffectsSettingsSaved,
            ),
            duration: const Duration(seconds: 2),
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
      debugPrint('Error confirming settings: $e');
    }
  }

  // 取消设置
  Future<void> _cancelSettings() async {
    try {
      // 停止所有试听
      await _stopAllPreviews();

      // 恢复原始设置
      for (final entry in _originalEffectVolumes.entries) {
        await _soundPlayer.toggleEffect(entry.key, entry.value);
      }

      // 恢复原始主音量
      await _soundPlayer.setMasterVolume(_originalMasterVolume);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error canceling settings: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    // 停止所有试听
    _stopAllPreviews();
    super.dispose();
  }

  // 音效配置
  List<Map<String, dynamic>> _getEffects(AppLocalizations localizations) {
    return [
      {
        'id': 'rain',
        'name': localizations.soundEffectsRain,
        'icon': Icons.grain,
      },
      {
        'id': 'ocean',
        'name': localizations.soundEffectsOcean,
        'icon': Icons.waves,
      },
      {
        'id': 'wind_chimes',
        'name': localizations.soundEffectsWindChimes,
        'icon': Icons.air,
      },
      {
        'id': 'birds',
        'name': localizations.soundEffectsBirds,
        'icon': Icons.flutter_dash,
      },
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
            // 根据屏幕宽度调整列数和比例
            int crossAxisCount;
            double childAspectRatio;

            if (constraints.maxWidth > 400) {
              crossAxisCount = 4;
              childAspectRatio = 3;
            } else if (constraints.maxWidth > 300) {
              crossAxisCount = 2;
              childAspectRatio = 2.8;
            } else {
              crossAxisCount = 2;
              childAspectRatio = 2.5;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: effects.length,
              itemBuilder: (context, index) {
                final effect = effects[index];
                final effectId = effect['id'] as String;
                final isSelected = (_effectVolumes[effectId] ?? 0.0) > 0;
                final isPreviewing = _previewingEffects[effectId] ?? false;

                return _SoundEffectButton(
                  effect: effectId,
                  name: effect['name'] as String,
                  icon: effect['icon'] as IconData,
                  isSelected: isSelected,
                  isPreviewing: isPreviewing,
                  onTap: () => _toggleEffectSelection(effectId),
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

              // 立即应用音量变化到正在播放的音效
              await _soundPlayer.setMasterVolume(value);
            },
            min: 0.0,
            max: 1.0,
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            // Cancel Button
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelSettings,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  localizations.actionCancel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Confirm Button
            Expanded(
              child: ElevatedButton(
                onPressed: _confirmSettings,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SoundEffectButton extends StatelessWidget {
  final String effect;
  final String name;
  final IconData icon;
  final bool isSelected;
  final bool isPreviewing;
  final VoidCallback onTap;

  const _SoundEffectButton({
    required this.effect,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.isPreviewing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // 确保整个区域都能响应点击
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF32B8C6)
                : (isPreviewing
                      ? const Color(0xFF32B8C6).withValues(alpha: 0.3)
                      : (isDark
                            ? const Color(0xFF3A4A5C)
                            : Colors.grey.withValues(alpha: 0.1))),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected || isPreviewing
                  ? const Color(0xFF32B8C6)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.3)),
              width: 1,
            ),
          ),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[600]),
                size: 20,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey[600]),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPreviewing) ...[
                const SizedBox(height: 2),
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
