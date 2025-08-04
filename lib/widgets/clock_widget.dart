import 'package:flutter/material.dart';
import 'dart:math';

/// Analog clock inside a rounded rectangle card, matching other cards.
class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      margin: EdgeInsets.zero,
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ClockPainter(now, isDark),
                  ),
                ),
                // City label
                Positioned(
                  top: 28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Dubai',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                // Center text
                Center(
                  child: Text(
                    'Daily Quest',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.18)
                          : Colors.black.withOpacity(0.13),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for the analog clock hands.
class _ClockPainter extends CustomPainter {
  final DateTime now;
  final bool isDark;
  _ClockPainter(this.now, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final handColor = isDark ? Colors.white70 : Colors.black54;
    final tickColor = isDark ? Colors.white24 : Colors.black26;
    final numberColor = isDark ? Colors.white : Colors.black;
    final paint = Paint()
      ..color = handColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    // Draw hour tick marks and numbers
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2;
    final numberStyle = TextStyle(
      color: numberColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final numberMap = {0: '12', 3: '3', 6: '6', 9: '9'};
    for (int i = 0; i < 12; i++) {
      final angle = 2 * pi * (i / 12);
      if (numberMap.containsKey(i)) {
        // Draw number instead of tick mark
        final number = numberMap[i]!;
        final numberRadius = radius - 18;
        final offset = Offset(
          center.dx + numberRadius * sin(angle),
          center.dy - numberRadius * cos(angle),
        );
        final tp = TextPainter(
          text: TextSpan(text: number, style: numberStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
      } else {
        // Draw tick mark
        final start = Offset(
          center.dx + (radius - 4) * sin(angle),
          center.dy - (radius - 4) * cos(angle),
        );
        final end = Offset(
          center.dx + radius * sin(angle),
          center.dy - radius * cos(angle),
        );
        canvas.drawLine(start, end, tickPaint);
      }
    }

    // Hour hand
    final hourAngle = 2 * pi * ((now.hour % 12) / 12) + 2 * pi * (now.minute / 720);
    final hourHand = Offset(
      center.dx + radius * 0.5 * sin(hourAngle),
      center.dy - radius * 0.5 * cos(hourAngle),
    );
    canvas.drawLine(center, hourHand, paint..strokeWidth = 5);

    // Minute hand
    final minAngle = 2 * pi * (now.minute / 60);
    final minHand = Offset(
      center.dx + radius * 0.7 * sin(minAngle),
      center.dy - radius * 0.7 * cos(minAngle),
    );
    canvas.drawLine(center, minHand, paint..strokeWidth = 3);

    // Second hand
    final secAngle = 2 * pi * (now.second / 60);
    final secHand = Offset(
      center.dx + radius * 0.8 * sin(secAngle),
      center.dy - radius * 0.8 * cos(secAngle),
    );
    canvas.drawLine(center, secHand, paint..strokeWidth = 1..color = Colors.redAccent);

    // Center dot
    canvas.drawCircle(center, 4, Paint()..color = numberColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 