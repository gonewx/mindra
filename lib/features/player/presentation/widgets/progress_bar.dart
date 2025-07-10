import 'package:flutter/material.dart';
import '../../../../shared/widgets/animated_progress_bar.dart';

class ProgressBar extends StatelessWidget {
  final double currentPosition;
  final double totalDuration;
  final Function(double)? onSeek;

  const ProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedProgressBar(
          currentPosition: currentPosition,
          totalDuration: totalDuration,
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
