import 'package:flutter/material.dart';

/// 2x2 grid of circular quick add buttons with icon and label inside the circle, clickable and highlightable.
class QuickAddButtons extends StatefulWidget {
  const QuickAddButtons({super.key});

  @override
  State<QuickAddButtons> createState() => _QuickAddButtonsState();
}

class _QuickAddButtonsState extends State<QuickAddButtons> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      {'icon': Icons.shopping_cart, 'color': Color(0xFFE0F7FA), 'label': 'Shopping'},
      {'icon': Icons.note, 'color': Color(0xFFEDE0FF), 'label': 'Note'},
      {'icon': Icons.event, 'color': Color(0xFFFFF9E0), 'label': 'Event'},
      {'icon': Icons.check_circle, 'color': Color(0xFFE0FFE6), 'label': 'Task'},
    ];
    final double gridWidth = MediaQuery.of(context).size.width * 0.7; // Responsive width
    final double buttonSize = 56;
    final double spacing = 8;
    final double gridHeight = (buttonSize * 2) + spacing; // 2 rows + 1 spacing
    return SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        mainAxisSpacing: spacing, // Reduced spacing
        crossAxisSpacing: spacing, // Reduced spacing
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(4, (i) {
          return _QuickAddButton(
            icon: buttons[i]['icon'] as IconData,
            color: buttons[i]['color'] as Color,
            label: buttons[i]['label'] as String,
            selected: _selectedIndex == i,
            onTap: () {
              setState(() => _selectedIndex = i);
            },
          );
        }),
      ),
    );
  }
}

/// Private widget for a single circular quick add button with icon and label inside, clickable and highlightable.
class _QuickAddButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickAddButton({required this.icon, required this.color, required this.label, required this.selected, required this.onTap});

  @override
  State<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<_QuickAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        width: 56, // Slightly smaller for mobile
        height: 56, // Slightly smaller for mobile
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_pressed ? 0.7 : 1.0),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: widget.selected
              ? Border.all(color: Colors.red, width: 3)
              : null,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: widget.selected
                ? Text(
                    widget.label,
                    key: const ValueKey('label'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.center,
                  )
                : Icon(
                    widget.icon,
                    key: const ValueKey('icon'),
                    size: 24,
                    color: Colors.black54,
                  ),
          ),
        ),
      ),
    );
  }
} 