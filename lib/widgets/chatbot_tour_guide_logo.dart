import 'package:flutter/material.dart';

/// The IntraBadi assistant's logo: a friendly, smiling local tour
/// guide's portrait (neck up), wearing a salakot — the wide, conical
/// woven hat traditionally worn by Filipino farmers and tour guides —
/// replacing the previous generic [Icons.chat_bubble_rounded] glyph.
///
/// The face is drawn in a webtoon/webcomic style: large open eyes with
/// dark pupils and a small white highlight glint, simple curved
/// eyebrows, flat cheek blush, and a bold-outlined smile — rather than
/// simple closed-arc "happy squint" eyes. Only the face changed; the
/// neck, collar/shirt, and salakot hat are unchanged from before.
///
/// Drawn entirely with [CustomPainter] primitives rather than a bundled
/// image asset, since the project has no existing character-art pipeline
/// (`assets/images` is empty) — this keeps the new logo dependency-free,
/// crisp at any size (vector, not raster), and trivially recolorable to
/// match the surrounding UI, while still precisely matching the request:
/// just the head/neck with a smiling face under a salakot, nothing else.
///
/// Deliberately a *content-only* replacement — every call site keeps its
/// own existing circular background color/size (spec: "keep the
/// background of the logo the same"); this widget only paints the
/// portrait meant to sit inside that circle, mirroring how the old
/// `Icon(Icons.chat_bubble_rounded, ...)` was just the glyph inside the
/// same unchanged `CircleAvatar`/`Container` background at each site.
class ChatbotTourGuideLogo extends StatelessWidget {
  /// Overall square size of the portrait (matches the old icon's
  /// `size` parameter at each call site).
  final double size;

  const ChatbotTourGuideLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TourGuidePainter()),
    );
  }
}

/// Paints a simple, warm, smiling tour-guide portrait — neck, head,
/// smiling face, and a salakot hat — scaled to fill the given canvas
/// size so it drops into any existing circular icon slot.
class _TourGuidePainter extends CustomPainter {
  // Warm skin tone, working on any background color the surrounding
  // circle already uses (spec: background stays unchanged).
  static const Color _skin = Color(0xFFE0A872);
  static const Color _skinShadow = Color(0xFFC98A56);
  static const Color _hatCrown = Color(0xFFE9C46A);
  static const Color _hatBrim = Color(0xFFD4A94A);
  static const Color _hatBand = Color(0xFF8B5E34);
  static const Color _cheek = Color(0xFFDE8B7A);
  static const Color _eye = Color(0xFF2B1B12);
  static const Color _neckShirt = Color(0xFFF4F1EA);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ─── Neck + shoulders (collar), anchored to the bottom edge ─────────
    final neckPaint = Paint()..color = _skin;
    final shirtPaint = Paint()..color = _neckShirt;

    final shoulders = Path()
      ..moveTo(cx - w * 0.34, h * 1.02)
      ..quadraticBezierTo(cx - w * 0.30, h * 0.74, cx - w * 0.16, h * 0.70)
      ..lineTo(cx + w * 0.16, h * 0.70)
      ..quadraticBezierTo(cx + w * 0.30, h * 0.74, cx + w * 0.34, h * 1.02)
      ..close();
    canvas.drawPath(shoulders, shirtPaint);

    final neckRect = Rect.fromLTWH(cx - w * 0.13, h * 0.60, w * 0.26, h * 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, Radius.circular(w * 0.05)),
      neckPaint,
    );

    // ─── Head (rounded, slightly taller than wide) ───────────────────────
    final headCenter = Offset(cx, h * 0.50);
    final headRadiusX = w * 0.26;
    final headRadiusY = h * 0.24;
    final headRect = Rect.fromCenter(
      center: headCenter,
      width: headRadiusX * 2,
      height: headRadiusY * 2,
    );
    canvas.drawOval(headRect, Paint()..color = _skin);
    // Soft jaw shadow for a touch of depth, not a flat cutout.
    canvas.drawArc(
      headRect,
      0.35,
      2.4,
      false,
      Paint()
        ..color = _skinShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // ─── Rosy cheeks (flat, webtoon-style blush) ─────────────────────────
    final cheekY = headCenter.dy + headRadiusY * 0.22;
    canvas.drawCircle(
      Offset(headCenter.dx - headRadiusX * 0.52, cheekY),
      w * 0.05,
      Paint()..color = _cheek.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headRadiusX * 0.52, cheekY),
      w * 0.05,
      Paint()..color = _cheek.withValues(alpha: 0.45),
    );

    // ─── Webtoon-style eyes: large open ovals with a dark pupil and a
    // small white highlight glint, instead of thin closed-arc lines —
    // this is the single biggest visual signal of the "webtoon" look
    // requested, versus the previous simple happy-squint eyes. Face
    // only; hat/clothes below are unchanged.
    final eyeY = headCenter.dy - headRadiusY * 0.05;
    final eyeWidth = w * 0.135;
    final eyeHeight = h * 0.145;
    final leftEyeCenter = Offset(
      headCenter.dx - headRadiusX * 0.44,
      eyeY,
    );
    final rightEyeCenter = Offset(
      headCenter.dx + headRadiusX * 0.44,
      eyeY,
    );

    void drawEye(Offset center) {
      final eyeRect = Rect.fromCenter(
        center: center,
        width: eyeWidth,
        height: eyeHeight,
      );
      // White of the eye.
      canvas.drawOval(eyeRect, Paint()..color = Colors.white);
      // Bold outline, characteristic of the clean webtoon line style.
      canvas.drawOval(
        eyeRect,
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.016,
      );
      // Large dark pupil, slightly lowered so the character reads as
      // looking forward/down at the viewer, warm rather than blank.
      canvas.drawCircle(
        Offset(center.dx, center.dy + eyeHeight * 0.08),
        eyeHeight * 0.34,
        Paint()..color = _eye,
      );
      // Small white highlight glint on the pupil — the signature
      // webtoon/anime-adjacent sparkle that makes eyes read as alive
      // rather than flat dots.
      canvas.drawCircle(
        Offset(
          center.dx - eyeHeight * 0.14,
          center.dy - eyeHeight * 0.08,
        ),
        eyeHeight * 0.11,
        Paint()..color = Colors.white,
      );
    }

    drawEye(leftEyeCenter);
    drawEye(rightEyeCenter);

    // Simple curved eyebrows above each eye for a touch of warm
    // expressiveness, matching the soft/rounded webtoon line weight.
    final browPaint = Paint()
      ..color = _eye.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(leftEyeCenter.dx, leftEyeCenter.dy - eyeHeight * 0.85),
        width: eyeWidth * 0.9,
        height: eyeHeight * 0.5,
      ),
      3.5,
      2.2,
      false,
      browPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(
          rightEyeCenter.dx,
          rightEyeCenter.dy - eyeHeight * 0.85,
        ),
        width: eyeWidth * 0.9,
        height: eyeHeight * 0.5,
      ),
      3.5,
      2.2,
      false,
      browPaint,
    );

    // Wide, open, bold-outlined smile — thicker stroke than before to
    // match the cleaner, bolder linework typical of webtoon art.
    final smileRect = Rect.fromCenter(
      center: Offset(headCenter.dx, headCenter.dy + headRadiusY * 0.42),
      width: headRadiusX * 1.1,
      height: headRadiusY * 0.85,
    );
    canvas.drawArc(
      smileRect,
      0.25,
      2.65,
      false,
      Paint()
        ..color = _eye
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.036
        ..strokeCap = StrokeCap.round,
    );

    // ─── Salakot hat: wide conical brim + domed crown + band ─────────────
    final brimCenter = Offset(headCenter.dx, headCenter.dy - headRadiusY * 0.62);
    final brimRect = Rect.fromCenter(
      center: brimCenter,
      width: w * 0.98,
      height: h * 0.30,
    );
    canvas.drawOval(brimRect, Paint()..color = _hatBrim);
    // Brim rim highlight for a woven-edge feel.
    canvas.drawArc(
      brimRect,
      3.05,
      3.2,
      false,
      Paint()
        ..color = _hatCrown.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018,
    );

    final crownCenter = Offset(
      headCenter.dx,
      brimCenter.dy - h * 0.09,
    );
    final crownRect = Rect.fromCenter(
      center: crownCenter,
      width: w * 0.62,
      height: h * 0.30,
    );
    canvas.drawArc(crownRect, 3.14159, 3.14159, true, Paint()..color = _hatCrown);

    // Small apex knot at the very top of the crown, and a hat band where
    // the crown meets the brim — both classic salakot details.
    canvas.drawCircle(
      Offset(crownCenter.dx, crownRect.top + h * 0.015),
      w * 0.03,
      Paint()..color = _hatBand,
    );
    canvas.drawLine(
      Offset(crownRect.left, crownCenter.dy),
      Offset(crownRect.right, crownCenter.dy),
      Paint()
        ..color = _hatBand
        ..strokeWidth = h * 0.02,
    );
  }

  @override
  bool shouldRepaint(covariant _TourGuidePainter oldDelegate) => false;
}
