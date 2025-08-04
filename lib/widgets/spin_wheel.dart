import 'package:flutter/material.dart';
import 'dart:math';

/// Wheel of fortune spinner inside a rounded rectangle card, matching other cards.
class SpinWheel extends StatefulWidget {
  const SpinWheel({super.key});

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0.0;
  int? _selectedIndex;
  final List<Map<String, dynamic>> segments = [
    {'label': 'Chores', 'color': Color(0xFF00BCD4)}, // Stronger cyan
    {'label': 'Gym', 'color': Color(0xFF43A047)},    // Stronger green
    {'label': 'Shopping', 'color': Color(0xFFFFC107)}, // Stronger yellow
    {'label': 'Event', 'color': Color(0xFF7C4DFF)},    // Stronger purple
    {'label': 'Task', 'color': Color(0xFFE91E63)},     // Stronger pink
    {'label': 'Relax', 'color': Color(0xFFFF9800)},    // Stronger orange
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate)
      ..addListener(() {
        setState(() {
          _currentAngle = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    final random = Random();
    final spins = 5 + random.nextInt(3); // 5-7 full spins
    final targetIndex = random.nextInt(segments.length);
    final anglePerSegment = 2 * pi / segments.length;
    final targetAngle = (spins * 2 * pi) + (targetIndex * anglePerSegment) + anglePerSegment / 2;
    _animation = Tween<double>(begin: _currentAngle, end: targetAngle)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate))
      ..addListener(() {
        setState(() {
          _currentAngle = _animation.value;
        });
      });
    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _selectedIndex = targetIndex;
        // Normalize angle
        _currentAngle = _currentAngle % (2 * pi);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Only the wheel
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _controller.isAnimating ? null : _spin,
            child: CustomPaint(
                      painter: _WheelPainter(
                        segments,
                        angle: _currentAngle,
                        selectedIndex: _getNeedleSegmentIndex(),
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
            ),
          ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Returns the index of the segment currently under the needle (top center)
  int _getNeedleSegmentIndex() {
    final anglePerSegment = 2 * pi / segments.length;
    // The needle is at -pi/2 (top center), so calculate the segment at that angle
    double normalizedAngle = (_currentAngle) % (2 * pi);
    double needleAngle = (-pi / 2 - normalizedAngle) % (2 * pi);
    if (needleAngle < 0) needleAngle += 2 * pi;
    // Find the segment whose center is closest to the needle angle
    int index = ((needleAngle + anglePerSegment / 2) / anglePerSegment).floor() % segments.length;
    return index;
  }
}

/// Custom painter for the wheel segments.
class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  final double angle;
  final int? selectedIndex;
  _WheelPainter(this.segments, {this.angle = 0.0, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final anglePerSegment = 2 * pi / segments.length;
    var startAngle = -pi / 2 + angle;
    final textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87);

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final paint = Paint()
        ..color = seg['color'] as Color
        ..style = PaintingStyle.fill;
      if (selectedIndex == i) {
        paint.color = paint.color.withOpacity(0.7);
        paint.strokeWidth = 4;
        paint.style = PaintingStyle.stroke;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius + 6),
          startAngle,
          anglePerSegment,
          true,
          Paint()
            ..color = seg['color'].withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12,
        );
        paint.style = PaintingStyle.fill;
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        anglePerSegment,
        true,
        paint,
      );
      // Draw label
      final labelAngle = startAngle + anglePerSegment / 2;
      final labelOffset = Offset(
        center.dx + (radius - 24) * cos(labelAngle),
        center.dy + (radius - 24) * sin(labelAngle),
      );
      final tp = TextPainter(
        text: TextSpan(text: seg['label'], style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      canvas.save();
      canvas.translate(labelOffset.dx, labelOffset.dy);
      canvas.rotate(labelAngle);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      startAngle += anglePerSegment;
    }
    // Draw center dot
    canvas.drawCircle(center, 8, Paint()..color = Colors.black26);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 