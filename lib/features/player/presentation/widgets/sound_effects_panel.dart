import 'package:flutter/material.dart';

class SoundEffectsPanel extends StatefulWidget {
  const SoundEffectsPanel({super.key});

  @override
  State<SoundEffectsPanel> createState() => _SoundEffectsPanelState();
}

class _SoundEffectsPanelState extends State<SoundEffectsPanel> {
  final Map<String, double> _effectVolumes = {
    'rain': 0.0,
    'ocean': 0.0,
    'forest': 0.0,
    'wind': 0.0,
    'fire': 0.0,
    'birds': 0.0,
    'water': 0.0,
  };

  final Map<String, String> _effectNames = {
    'rain': '雨声',
    'ocean': '海浪',
    'forest': '森林',
    'wind': '风声',
    'fire': '火焰',
    'birds': '鸟鸣',
    'water': '流水',
  };

  final Map<String, IconData> _effectIcons = {
    'rain': Icons.grain,
    'ocean': Icons.waves,
    'forest': Icons.park,
    'wind': Icons.air,
    'fire': Icons.local_fire_department,
    'birds': Icons.flutter_dash,
    'water': Icons.water_drop,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '自然音效',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetAllEffects,
                tooltip: '重置所有音效',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sound Effects Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _effectVolumes.length,
            itemBuilder: (context, index) {
              final effect = _effectVolumes.keys.elementAt(index);
              return _SoundEffectItem(
                effect: effect,
                name: _effectNames[effect]!,
                icon: _effectIcons[effect]!,
                volume: _effectVolumes[effect]!,
                onVolumeChanged: (value) {
                  setState(() {
                    _effectVolumes[effect] = value;
                  });
                  // TODO: Update effect volume in audio service
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Preset Buttons
          Text(
            '预设组合',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetButton(
                label: '雨夜',
                onTap: () => _applyPreset({
                  'rain': 0.7,
                  'wind': 0.3,
                }),
              ),
              _PresetButton(
                label: '海边',
                onTap: () => _applyPreset({
                  'ocean': 0.8,
                  'birds': 0.2,
                }),
              ),
              _PresetButton(
                label: '森林',
                onTap: () => _applyPreset({
                  'forest': 0.6,
                  'birds': 0.4,
                  'water': 0.3,
                }),
              ),
              _PresetButton(
                label: '篝火',
                onTap: () => _applyPreset({
                  'fire': 0.8,
                  'wind': 0.2,
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resetAllEffects() {
    setState(() {
      for (final effect in _effectVolumes.keys) {
        _effectVolumes[effect] = 0.0;
      }
    });
    // TODO: Reset all effects in audio service
  }

  void _applyPreset(Map<String, double> preset) {
    setState(() {
      // Reset all effects first
      for (final effect in _effectVolumes.keys) {
        _effectVolumes[effect] = 0.0;
      }
      // Apply preset values
      for (final entry in preset.entries) {
        _effectVolumes[entry.key] = entry.value;
      }
    });
    // TODO: Apply preset in audio service
  }
}

class _SoundEffectItem extends StatelessWidget {
  final String effect;
  final String name;
  final IconData icon;
  final double volume;
  final Function(double) onVolumeChanged;

  const _SoundEffectItem({
    required this.effect,
    required this.name,
    required this.icon,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = volume > 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive 
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              thumbColor: Theme.of(context).colorScheme.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 2,
            ),
            child: Slider(
              value: volume,
              onChanged: onVolumeChanged,
              min: 0.0,
              max: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }
}