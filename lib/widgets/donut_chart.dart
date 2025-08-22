import 'package:flutter/material.dart';

class DonutChart extends StatelessWidget {
  final int total;
  final int completed;
  final int pending;
  final double size;
  final String label;
  final Color completedColor;
  final Color pendingColor;
  final Color totalColor;

  const DonutChart({
    Key? key,
    required this.total,
    required this.completed,
    required this.pending,
    this.size = 80,
    required this.label,
    this.completedColor = const Color(0xFFE91E63), // Coral
    this.pendingColor = const Color(0xFF009688), // Teal
    this.totalColor = const Color(0xFF3F51B5), // Dark Blue
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine which number to show in the center based on label
    int centerNumber;
    if (label == 'Total') {
      centerNumber = total;
    } else if (label == 'Completed') {
      centerNumber = completed;
    } else if (label == 'Pending') {
      centerNumber = pending;
    } else {
      centerNumber = total;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: DonutChartPainter(
                  total: total,
                  completed: completed,
                  pending: pending,
                  completedColor: completedColor,
                  pendingColor: pendingColor,
                  totalColor: totalColor,
                  label: label,
                ),
              ),
              Text(
                centerNumber.toString(),
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final int total;
  final int completed;
  final int pending;
  final Color completedColor;
  final Color pendingColor;
  final Color totalColor;
  final String label;

  DonutChartPainter({
    required this.total,
    required this.completed,
    required this.pending,
    required this.completedColor,
    required this.pendingColor,
    required this.totalColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.25; // Increased from 0.15 to 0.25 for bolder rings

    // Determine the main color based on the label
    Color mainColor;
    if (label == 'Total') {
      mainColor = totalColor;
    } else if (label == 'Completed') {
      mainColor = completedColor;
    } else if (label == 'Pending') {
      mainColor = pendingColor;
    } else {
      mainColor = totalColor;
    }

    // Calculate angles
    final totalAngle = 2 * 3.14159;
    
    // For each chart type, show different proportions
    double filledAngle;
    if (label == 'Total') {
      // Total chart: show full circle with theme color
      filledAngle = totalAngle;
    } else if (label == 'Completed') {
      // Completed chart: show completed portion
      filledAngle = total > 0 ? (completed / total) * totalAngle : 0.0;
    } else if (label == 'Pending') {
      // Pending chart: show pending portion
      filledAngle = total > 0 ? (pending / total) * totalAngle : 0.0;
    } else {
      filledAngle = totalAngle;
    }

    final remainingAngle = totalAngle - filledAngle;

    // Draw filled segment with theme color
    if (filledAngle > 0) {
      Color fillColor = mainColor;
      // For Total donut, use faded color when no tasks
      if (label == 'Total' && total == 0) {
        fillColor = mainColor.withOpacity(0.2);
      }
      
      final filledPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        0,
        filledAngle,
        false,
        filledPaint,
      );
    }

    // Draw remaining segment with transparent theme color
    if (remainingAngle > 0) {
      final remainingPaint = Paint()
        ..color = mainColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        filledAngle,
        remainingAngle,
        false,
        remainingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 