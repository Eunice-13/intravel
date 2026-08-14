import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The expression/action states IntraBadi's avatar can be in.
///
/// Adding a new state (e.g. `confused`, `celebrating`) means adding a value
/// here, mapping it in [_ChatbotAvatarState._applyState] and
/// [_AvatarPose.forState], and — only if it needs new geometry — extending
/// the painter. No call site or structural change is required, which is the
/// point of driving the avatar off a single enum rather than swapping
/// one-off assets.
enum ChatbotAvatarState {
  /// Default resting state: slow breathing bob and periodic blinking.
  idle,

  /// Warm, pleased expression — used after a successful answer.
  smiling,

  /// Greeting gesture: a wing raises and waves. Used on chat open.
  waving,

  /// Beak opens and closes rhythmically while a reply is being delivered.
  talking,

  /// Head tilts up and holds a slow pulse while a reply is being awaited.
  thinking,
}

/// IntraBadi's animated avatar: a Philippine eagle wearing a salakot.
///
/// Drawn entirely with [CustomPainter] vector primitives rather than a
/// bundled image, Lottie, or Rive asset. That was a deliberate choice for
/// this character:
///
///  * **Both call sites render small** (22px in the chat header, 30px on the
///    side handle). Fine raster detail is destroyed at that scale, so the
///    only animation signals that actually read are silhouette, head
///    motion, blink, and beak movement — all of which vector code does
///    exactly.
///  * **No new dependency and no asset bytes.** `rive`/`lottie` would each
///    add a package and runtime for a 22px face.
///  * **Per-part animation is only possible in vector.** A baked raster
///    frame cannot blink or open its beak.
///
/// The public API is deliberately just [state] and [size], so the internals
/// could later be swapped for a Rive board without touching a single call
/// site.
///
/// Renders with a **fully transparent background** — the character only, no
/// card, frame, or backing shape. It floats directly on whatever is behind
/// it.
///
/// Honors [MediaQueryData.disableAnimations]: when the platform requests
/// reduced motion, the avatar holds a still, neutral pose instead of
/// animating.
class ChatbotAvatar extends StatefulWidget {
  final ChatbotAvatarState state;

  /// Overall square size of the character.
  final double size;

  /// Whether to run animations at all.
  ///
  /// Pass `false` for a completely static render with **no tickers created**
  /// — used by the persistent side handle, which sits on screen on every
  /// page where continuous motion would be both distracting and a real
  /// battery/frame cost for no benefit. The character still poses according
  /// to [state]; it simply doesn't move.
  final bool animate;

  const ChatbotAvatar({
    super.key,
    this.state = ChatbotAvatarState.idle,
    this.size = 24,
    this.animate = true,
  });

  @override
  State<ChatbotAvatar> createState() => _ChatbotAvatarState();
}

class _ChatbotAvatarState extends State<ChatbotAvatar>
    with TickerProviderStateMixin {
  /// Always-running: drives the breathing bob and blink scheduling that
  /// every state shares.
  late final AnimationController _ambient;

  /// State-specific gesture: the wave sweep, beak chatter, or thinking
  /// pulse. Idle/smiling leave this parked at 0.
  late final AnimationController _gesture;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _gesture = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _applyState();
  }

  @override
  void didUpdateWidget(covariant ChatbotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      didChangeDependencies();
      return;
    }
    if (oldWidget.state != widget.state && _shouldAnimate) _applyState();
  }

  /// False when the caller opted out via [ChatbotAvatar.animate], or the
  /// platform has requested reduced motion. Either way the avatar renders a
  /// single still pose and runs no tickers.
  bool _shouldAnimate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shouldAnimate = widget.animate && !reduceMotion;
    if (!_shouldAnimate) {
      // Stop outright rather than relying on shouldRepaint to bail — a
      // running ticker would rebuild every frame to paint an identical
      // picture.
      _ambient.stop();
      _gesture.stop();
    } else {
      if (!_ambient.isAnimating) _ambient.repeat();
      _applyState();
    }
  }

  void _applyState() {
    switch (widget.state) {
      case ChatbotAvatarState.idle:
      case ChatbotAvatarState.smiling:
        // Ambient bob/blink only — no gesture layer.
        _gesture
          ..stop()
          ..value = 0;
      case ChatbotAvatarState.waving:
        // One-shot greeting sweep (three waves inside the sweep).
        _gesture
          ..stop()
          ..duration = const Duration(milliseconds: 1500)
          ..forward(from: 0);
      case ChatbotAvatarState.talking:
        // Fast repeating beak chatter for as long as this state is set.
        _gesture
          ..stop()
          ..duration = const Duration(milliseconds: 300)
          ..repeat();
      case ChatbotAvatarState.thinking:
        // Slow, calm pulse while waiting.
        _gesture
          ..stop()
          ..duration = const Duration(milliseconds: 1700)
          ..repeat();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) {
      // No AnimatedBuilder and no ticker subscription at all — a single
      // static paint of the state's resting pose.
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _EagleAvatarPainter(_AvatarPose.still(widget.state)),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_ambient, _gesture]),
          builder: (context, _) {
            return CustomPaint(
              painter: _EagleAvatarPainter(
                _AvatarPose.forState(
                  widget.state,
                  ambient: _ambient.value,
                  gesture: _gesture.value,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The resolved, frame-by-frame animation values the painter consumes.
///
/// Keeping this as a plain value object between "what state are we in" and
/// "how do we draw it" is what makes new expressions cheap: a new state maps
/// to new numbers here, and the painter needs no knowledge of states at all.
@immutable
class _AvatarPose {
  /// Vertical breathing offset, in fractions of canvas height.
  final double bob;

  /// Eyelid closure, 0 = wide open, 1 = fully shut.
  final double blink;

  /// Beak gape, 0 = closed, 1 = open.
  final double beakOpen;

  /// Head rotation in radians (positive = tilt right).
  final double headTilt;

  /// Wave progress, 0 = wing hidden, >0 = wing out and waving.
  final double wing;

  /// Pleased expression strength, 0 = neutral, 1 = full smile.
  final double smile;

  /// Upward eye/pupil shift for the "looking up, thinking" read.
  final double lookUp;

  const _AvatarPose({
    this.bob = 0,
    this.blink = 0,
    this.beakOpen = 0,
    this.headTilt = 0,
    this.wing = 0,
    this.smile = 0,
    this.lookUp = 0,
  });

  // Value equality so the painter's shouldRepaint can skip frames where
  // nothing actually moved (notably reduced-motion mode, where the pose is
  // constant).
  @override
  bool operator ==(Object other) =>
      other is _AvatarPose &&
      other.bob == bob &&
      other.blink == blink &&
      other.beakOpen == beakOpen &&
      other.headTilt == headTilt &&
      other.wing == wing &&
      other.smile == smile &&
      other.lookUp == lookUp;

  @override
  int get hashCode =>
      Object.hash(bob, blink, beakOpen, headTilt, wing, smile, lookUp);

  /// A motionless pose per state, for reduced-motion mode: the character
  /// still *reads* as the right expression, it just doesn't move.
  factory _AvatarPose.still(ChatbotAvatarState state) {
    switch (state) {
      case ChatbotAvatarState.idle:
        return const _AvatarPose();
      case ChatbotAvatarState.smiling:
        return const _AvatarPose(smile: 1);
      case ChatbotAvatarState.waving:
        return const _AvatarPose(smile: 0.8, wing: 0.6, headTilt: 0.06);
      case ChatbotAvatarState.talking:
        return const _AvatarPose(beakOpen: 0.5, smile: 0.3);
      case ChatbotAvatarState.thinking:
        return const _AvatarPose(headTilt: -0.10, lookUp: 0.8);
    }
  }

  factory _AvatarPose.forState(
    ChatbotAvatarState state, {
    required double ambient,
    required double gesture,
  }) {
    // Shared breathing bob — one full sine cycle per ambient period.
    final bob = math.sin(ambient * 2 * math.pi) * 0.012;

    // Blink occupies a short window near the end of each ambient cycle, so
    // it reads as an occasional natural blink rather than a constant flutter.
    const blinkStart = 0.90;
    double blink = 0;
    if (ambient > blinkStart) {
      final p = (ambient - blinkStart) / (1 - blinkStart);
      // Up then down: closed at the midpoint of the window.
      blink = math.sin(p * math.pi);
    }

    switch (state) {
      case ChatbotAvatarState.idle:
        return _AvatarPose(bob: bob, blink: blink);

      case ChatbotAvatarState.smiling:
        return _AvatarPose(bob: bob, blink: blink, smile: 1);

      case ChatbotAvatarState.waving:
        // Three waves across the one-shot sweep, eased in and out so the
        // wing rises, waves, then lowers rather than snapping.
        final envelope = math.sin(gesture * math.pi).clamp(0.0, 1.0);
        final flap = math.sin(gesture * 3 * 2 * math.pi);
        return _AvatarPose(
          bob: bob,
          blink: blink,
          smile: 0.85,
          wing: envelope,
          headTilt: 0.05 * envelope + 0.02 * flap * envelope,
        );

      case ChatbotAvatarState.talking:
        // Beak chatter. Uses the repeating gesture value directly so the
        // rhythm is independent of the slower ambient cycle.
        final gape = (math.sin(gesture * 2 * math.pi) + 1) / 2;
        return _AvatarPose(
          bob: bob,
          blink: blink,
          smile: 0.3,
          beakOpen: 0.15 + gape * 0.6,
        );

      case ChatbotAvatarState.thinking:
        // Slow tilt/settle with the eyes drifting upward.
        final pulse = (math.sin(gesture * 2 * math.pi) + 1) / 2;
        return _AvatarPose(
          bob: bob * 0.5,
          blink: blink,
          headTilt: -0.06 - 0.05 * pulse,
          lookUp: 0.55 + 0.35 * pulse,
        );
    }
  }
}

/// Paints the eagle-in-a-salakot character for a single [_AvatarPose].
///
/// Split into one method per body part so a future expression can adjust or
/// add a part without disturbing the rest. Palette is sampled from the
/// reference artwork.
class _EagleAvatarPainter extends CustomPainter {
  final _AvatarPose pose;

  _EagleAvatarPainter(this.pose);

  // ─── Palette (from the reference design) ─────────────────────────────
  static const Color _outline = Color(0xFF4A2C17);
  static const Color _featherLight = Color(0xFFFFFDF8);
  static const Color _featherShade = Color(0xFFE7DCC9);
  static const Color _hatLight = Color(0xFFEBCC98);
  static const Color _hatMid = Color(0xFFD9B27B);
  static const Color _hatWeave = Color(0xFFB98B54);
  static const Color _hatBrimUnder = Color(0xFF9C6B39);
  static const Color _beakLight = Color(0xFFF7C24A);
  static const Color _beakMid = Color(0xFFEDA31C);
  static const Color _beakShade = Color(0xFFC9820F);
  static const Color _iris = Color(0xFF6B3E1B);
  static const Color _pupil = Color(0xFF32200F);
  static const Color _cord = Color(0xFFC89A63);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    // Breathing bob, then head tilt about a pivot near the neck so the
    // whole character rotates naturally rather than spinning about centre.
    canvas.translate(0, h * pose.bob);
    if (pose.headTilt != 0) {
      final pivot = Offset(w * 0.5, h * 0.86);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(pose.headTilt);
      canvas.translate(-pivot.dx, -pivot.dy);
    }

    // Wing sits behind the head so it reads as coming from the body.
    if (pose.wing > 0.01) _drawWing(canvas, w, h);

    _drawHeadAndFeathers(canvas, w, h);
    _drawEyes(canvas, w, h);
    _drawBeak(canvas, w, h);
    _drawSalakot(canvas, w, h);
    _drawChinCord(canvas, w, h);

    canvas.restore();
  }

  Paint get _stroke => Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Cream feathered head: a rounded crown narrowing to a pointed chin,
  /// with jagged feather tufts down each side, matching the reference's
  /// shield-like silhouette.
  void _drawHeadAndFeathers(Canvas canvas, double w, double h) {
    final cx = w * 0.5;

    final head = Path()
      ..moveTo(cx, h * 0.30)
      // Right side down to the chin, with feather tufts.
      ..cubicTo(w * 0.80, h * 0.32, w * 0.86, h * 0.52, w * 0.80, h * 0.66)
      ..lineTo(w * 0.84, h * 0.72)
      ..lineTo(w * 0.74, h * 0.72)
      ..lineTo(w * 0.76, h * 0.80)
      ..lineTo(w * 0.66, h * 0.78)
      ..lineTo(cx, h * 0.96)
      // Left side mirrored back up to the crown.
      ..lineTo(w * 0.34, h * 0.78)
      ..lineTo(w * 0.24, h * 0.80)
      ..lineTo(w * 0.26, h * 0.72)
      ..lineTo(w * 0.16, h * 0.72)
      ..lineTo(w * 0.20, h * 0.66)
      ..cubicTo(w * 0.14, h * 0.52, w * 0.20, h * 0.32, cx, h * 0.30)
      ..close();

    canvas.drawPath(head, Paint()..color = _featherLight);

    // Soft shading along the lower sides for a little volume.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.60)
        ..quadraticBezierTo(w * 0.30, h * 0.82, cx, h * 0.94)
        ..lineTo(cx, h * 0.96)
        ..lineTo(w * 0.34, h * 0.78)
        ..lineTo(w * 0.24, h * 0.80)
        ..lineTo(w * 0.26, h * 0.72)
        ..lineTo(w * 0.16, h * 0.72)
        ..lineTo(w * 0.20, h * 0.66)
        ..close(),
      Paint()..color = _featherShade.withValues(alpha: 0.55),
    );

    canvas.drawPath(head, _stroke..strokeWidth = w * 0.032);
  }

  /// Large brown eyes with a white glint, plus angled brows. Eyelids close
  /// from the top for blinking, and pupils shift up for "thinking".
  void _drawEyes(Canvas canvas, double w, double h) {
    final eyeY = h * 0.50;
    final eyeRx = w * 0.105;
    final eyeRy = h * 0.098;
    final dx = w * 0.165;

    for (final sign in [-1, 1]) {
      final center = Offset(w * 0.5 + sign * dx, eyeY);
      final rect = Rect.fromCenter(
        center: center,
        width: eyeRx * 2,
        height: eyeRy * 2,
      );

      canvas.drawOval(rect, Paint()..color = Colors.white);

      // Iris + pupil, nudged upward when thinking.
      final pupilCenter = Offset(
        center.dx,
        center.dy + eyeRy * 0.10 - eyeRy * 0.45 * pose.lookUp,
      );
      canvas.drawCircle(pupilCenter, eyeRy * 0.62, Paint()..color = _iris);
      canvas.drawCircle(pupilCenter, eyeRy * 0.34, Paint()..color = _pupil);
      canvas.drawCircle(
        Offset(pupilCenter.dx - eyeRx * 0.30, pupilCenter.dy - eyeRy * 0.30),
        eyeRy * 0.20,
        Paint()..color = Colors.white,
      );

      // Smiling narrows the eye from below, a friendlier read than simply
      // curving the beak.
      if (pose.smile > 0.01) {
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left,
            rect.bottom - rect.height * 0.34 * pose.smile,
            rect.right,
            rect.bottom,
          ),
          Paint()..color = _featherLight,
        );
        canvas.restore();
      }

      // Blink: an eyelid sweeping down over the eye.
      if (pose.blink > 0.01) {
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right,
            rect.top + rect.height * pose.blink,
          ),
          Paint()..color = _featherLight,
        );
        canvas.restore();
      }

      canvas.drawOval(rect, _stroke..strokeWidth = w * 0.026);

      // Angled brow — the reference's most characterful feature.
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - sign * eyeRx * 1.05, center.dy - eyeRy * 1.30)
          ..quadraticBezierTo(
            center.dx,
            center.dy - eyeRy * 1.85,
            center.dx + sign * eyeRx * 1.10,
            center.dy - eyeRy * 1.05,
          ),
        _stroke..strokeWidth = w * 0.030,
      );
    }
  }

  /// Golden hooked beak. [_AvatarPose.beakOpen] splits it into an upper and
  /// lower half that hinge apart for talking.
  void _drawBeak(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final topY = h * 0.50;
    final gape = pose.beakOpen * h * 0.055;

    // Upper mandible, hooking down to a point.
    final upper = Path()
      ..moveTo(cx - w * 0.075, topY)
      ..quadraticBezierTo(cx, topY - h * 0.030, cx + w * 0.075, topY)
      ..quadraticBezierTo(
        cx + w * 0.080,
        topY + h * 0.105,
        cx,
        topY + h * 0.150,
      )
      ..quadraticBezierTo(
        cx - w * 0.080,
        topY + h * 0.105,
        cx - w * 0.075,
        topY,
      )
      ..close();

    canvas.drawPath(upper, Paint()..color = _beakMid);
    // Highlight down the ridge.
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.018, topY + h * 0.010)
        ..quadraticBezierTo(cx, topY + h * 0.070, cx, topY + h * 0.130)
        ..quadraticBezierTo(
          cx + w * 0.014,
          topY + h * 0.060,
          cx + w * 0.014,
          topY + h * 0.008,
        )
        ..close(),
      Paint()..color = _beakLight.withValues(alpha: 0.85),
    );
    canvas.drawPath(upper, _stroke..strokeWidth = w * 0.030);

    // Lower mandible, only meaningfully visible once the beak opens.
    if (gape > 0.4) {
      final lower = Path()
        ..moveTo(cx - w * 0.050, topY + h * 0.120 + gape)
        ..quadraticBezierTo(
          cx,
          topY + h * 0.100 + gape,
          cx + w * 0.050,
          topY + h * 0.120 + gape,
        )
        ..quadraticBezierTo(
          cx,
          topY + h * 0.190 + gape,
          cx - w * 0.050,
          topY + h * 0.120 + gape,
        )
        ..close();
      canvas.drawPath(lower, Paint()..color = _beakShade);
      canvas.drawPath(lower, _stroke..strokeWidth = w * 0.026);
    }

    // Nostril dot, a small detail that survives even at 22px.
    canvas.drawCircle(
      Offset(cx - w * 0.030, topY + h * 0.014),
      w * 0.012,
      Paint()..color = _beakShade,
    );
  }

  /// The salakot: wide conical woven brim, domed crown, weave lines.
  void _drawSalakot(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final brimY = h * 0.375;

    // Brim underside first, so the top face overlaps it cleanly.
    final brim = Path()
      ..moveTo(w * 0.045, brimY)
      ..quadraticBezierTo(cx, brimY + h * 0.105, w * 0.955, brimY)
      ..quadraticBezierTo(cx, brimY - h * 0.020, w * 0.045, brimY)
      ..close();
    canvas.drawPath(brim, Paint()..color = _hatBrimUnder);
    canvas.drawPath(brim, _stroke..strokeWidth = w * 0.030);

    // Cone.
    final cone = Path()
      ..moveTo(cx, h * 0.045)
      ..lineTo(w * 0.955, brimY)
      ..quadraticBezierTo(cx, brimY - h * 0.020, w * 0.045, brimY)
      ..close();
    canvas.drawPath(cone, Paint()..color = _hatMid);

    // Lighter left face for a hint of directional light.
    canvas.drawPath(
      Path()
        ..moveTo(cx, h * 0.045)
        ..lineTo(w * 0.045, brimY)
        ..lineTo(cx, brimY - h * 0.006)
        ..close(),
      Paint()..color = _hatLight.withValues(alpha: 0.75),
    );

    // Woven texture: a few radial lines, kept sparse so they don't turn to
    // mud at small sizes.
    final weave = Paint()
      ..color = _hatWeave.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014;
    for (final t in [0.22, 0.42, 0.58, 0.78]) {
      canvas.drawLine(
        Offset(cx, h * 0.045),
        Offset(w * (0.045 + 0.91 * t), brimY),
        weave,
      );
    }
    // Two concentric arcs suggesting the woven rings.
    for (final r in [0.45, 0.72]) {
      canvas.drawPath(
        Path()
          ..moveTo(
            cx - (cx - w * 0.045) * r,
            h * 0.045 + (brimY - h * 0.045) * r,
          )
          ..quadraticBezierTo(
            cx,
            h * 0.045 + (brimY - h * 0.045) * r + h * 0.022,
            cx + (w * 0.955 - cx) * r,
            h * 0.045 + (brimY - h * 0.045) * r,
          ),
        weave,
      );
    }

    canvas.drawPath(cone, _stroke..strokeWidth = w * 0.032);
  }

  /// Chin cord and knot hanging from the brim, as in the reference.
  void _drawChinCord(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final cordPaint = _stroke
      ..strokeWidth = w * 0.022
      ..color = _outline;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.40)
        ..quadraticBezierTo(w * 0.30, h * 0.80, cx - w * 0.03, h * 0.855),
      cordPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.80, h * 0.40)
        ..quadraticBezierTo(w * 0.70, h * 0.80, cx + w * 0.03, h * 0.855),
      cordPaint,
    );
    canvas.drawCircle(Offset(cx, h * 0.875), w * 0.035, Paint()..color = _cord);
    canvas.drawCircle(
      Offset(cx, h * 0.875),
      w * 0.035,
      _stroke..strokeWidth = w * 0.020,
    );
  }

  /// A simple wing that swings out beside the head for the greeting wave.
  void _drawWing(Canvas canvas, double w, double h) {
    final progress = pose.wing;
    canvas.save();

    final pivot = Offset(w * 0.80, h * 0.70);
    canvas.translate(pivot.dx, pivot.dy);
    // Rotates up from tucked to raised as the wave envelope rises.
    canvas.rotate(-0.55 * progress);
    canvas.scale(progress.clamp(0.35, 1.0));

    final wing = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.22, -h * 0.10, w * 0.30, -h * 0.26)
      ..lineTo(w * 0.20, -h * 0.22)
      ..lineTo(w * 0.22, -h * 0.34)
      ..lineTo(w * 0.12, -h * 0.26)
      ..quadraticBezierTo(w * 0.10, -h * 0.10, 0, 0)
      ..close();

    canvas.drawPath(wing, Paint()..color = _featherLight);
    canvas.drawPath(wing, _stroke..strokeWidth = w * 0.030);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EagleAvatarPainter oldDelegate) =>
      oldDelegate.pose != pose;
}
