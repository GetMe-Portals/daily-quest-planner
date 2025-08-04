import 'package:flutter/material.dart';

/// Circular progress bar widget showing percent in the center.
class ProgressTracker extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double? current;
  final double? total;
  const ProgressTracker({super.key, this.progress = 0.75, this.current, this.total});

  static const Color percentColor = Color(0xFFE0F7FA); // Shopping quick add color

  Color _getColor(double value) {
    if (value < 0.5) {
      return Colors.redAccent;
    } else if (value < 0.75) {
      return Colors.amber;
    } else {
      // Green gradient: light to strong
      return Color.lerp(Colors.lightGreenAccent, Colors.green, (value - 0.75) / 0.25)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = _getColor(progress);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
          '${(progress * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 14,
            width: double.infinity,
            color: Colors.grey[300],
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: ringColor,
                    ),
            ),
          ),
        ],
      ),
          ),
        ),
        if (current != null && total != null) ...[
          const SizedBox(height: 6),
          Text(
            '${current!.toStringAsFixed(0)} / ${total!.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }
} 