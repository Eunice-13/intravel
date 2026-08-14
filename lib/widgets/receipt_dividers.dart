import 'package:flutter/material.dart';

// ─── Receipt Dividers ───────────────────────────────────────────────────────
// Small custom-painted dividers that mimic a printed receipt's dashed rule
// and double rule. Originally local to the Plans page's itinerary receipt
// dialog; extracted here so any other receipt-styled surface (e.g. the
// Home page's Transport & Access option popup) reuses the exact same
// treatment instead of redrawing its own near-copy.

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: const Color(0xFF9C9C9C)),
    );
  }
}

class DoubleDivider extends StatelessWidget {
  const DoubleDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1.5, color: const Color(0xFF9C9C9C)),
        const SizedBox(height: 3),
        Container(height: 1.5, color: const Color(0xFF9C9C9C)),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}
