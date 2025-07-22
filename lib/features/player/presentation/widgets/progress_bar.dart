import 'package:flutter/material.dart';
import '../../../../shared/widgets/animated_progress_bar.dart';

class ProgressBar extends StatelessWidget {
  final double currentPosition;
  final double totalDuration;
  final Function(double)? onSeek;
  final double bufferProgress;

  const ProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    this.onSeek,
    this.bufferProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedProgressBar(
          currentPosition: currentPosition,
          totalDuration: totalDuration,
          bufferProgress: bufferProgress,
          onSeek: onSeek,
        ),
        AnimatedTimeDisplay(
          currentPosition: currentPosition,
          totalDuration: totalDuration,
        ),
      ],
    );
  }
}
