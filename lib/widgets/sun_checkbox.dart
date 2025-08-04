import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class SunCheckbox extends StatelessWidget {
  final double size;
  const SunCheckbox({Key? key, this.size = 28}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SunCheckboxPainter(themeProvider: themeProvider),
          ),
        );
      },
    );
  }
}

class _SunCheckboxPainter extends CustomPainter {
  final ThemeProvider themeProvider;
  
  _SunCheckboxPainter({required this.themeProvider});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;
    final sunPaint = Paint()
      ..color = themeProvider.successColor
      ..style = PaintingStyle.fill;
    // Draw main circle
    canvas.drawCircle(center, radius, sunPaint);

    // Draw sun rays
    final rayPaint = Paint()
      ..color = themeProvider.successColor
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    const rays = 8;
    final rayLength = size.width * 0.04;
    for (int i = 0; i < rays; i++) {
      final angle = (i / rays) * 2 * 3.1415926;
      final start = Offset(
        center.dx + radius * 0.85 * cos(angle),
        center.dy + radius * 0.85 * sin(angle),
      );
      final end = Offset(
        center.dx + (radius + rayLength) * cos(angle),
        center.dy + (radius + rayLength) * sin(angle),
      );
      canvas.drawLine(start, end, rayPaint);
    }

    // Draw white checkmark in the center
    final checkPaint = Paint()
      ..color = themeProvider.cardColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final Path checkPath = Path();
    final double checkStartX = center.dx - radius * 0.32;
    final double checkStartY = center.dy + radius * 0.08;
    final double checkMidX = center.dx - radius * 0.05;
    final double checkMidY = center.dy + radius * 0.32;
    final double checkEndX = center.dx + radius * 0.36;
    final double checkEndY = center.dy - radius * 0.22;
    checkPath.moveTo(checkStartX, checkStartY);
    checkPath.lineTo(checkMidX, checkMidY);
    checkPath.lineTo(checkEndX, checkEndY);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 