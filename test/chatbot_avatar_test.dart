import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/widgets/chatbot_avatar.dart';

/// Tests for IntraBadi's animated eagle avatar: that every state renders,
/// that it animates, that it carries no background of its own, and that it
/// respects reduced-motion.
void main() {
  Widget host(ChatbotAvatarState state, {double size = 38}) => MaterialApp(
    home: Scaffold(
      body: Center(child: ChatbotAvatar(state: state, size: size)),
    ),
  );

  testWidgets('every state renders without error', (tester) async {
    for (final state in ChatbotAvatarState.values) {
      await tester.pumpWidget(host(state));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byType(ChatbotAvatar),
        findsOneWidget,
        reason: '$state failed to render',
      );
      expect(tester.takeException(), isNull, reason: '$state threw');
    }
  });

  testWidgets('renders at both real call-site sizes', (tester) async {
    // Side handle.
    await tester.pumpWidget(host(ChatbotAvatarState.idle, size: 52));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);

    // Chat header.
    await tester.pumpWidget(host(ChatbotAvatarState.talking, size: 38));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paints no background of its own — character only, transparent behind',
    (tester) async {
      await tester.pumpWidget(host(ChatbotAvatarState.idle));
      await tester.pump(const Duration(milliseconds: 60));

      // The avatar must not introduce any opaque backing shape; the only
      // decorated boxes present should come from the test scaffold, not the
      // avatar's own subtree.
      final decorated = find.descendant(
        of: find.byType(ChatbotAvatar),
        matching: find.byType(DecoratedBox),
      );
      expect(
        decorated,
        findsNothing,
        reason:
            'avatar should be a bare CustomPaint with no card/frame/circle',
      );
      expect(
        find.descendant(
          of: find.byType(ChatbotAvatar),
          matching: find.byType(CircleAvatar),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('animates over time while in an animated state', (tester) async {
    await tester.pumpWidget(host(ChatbotAvatarState.talking));
    await tester.pump();

    // Grab the painter across two frames far enough apart that the beak
    // gape must have changed, and confirm it reports a needed repaint.
    CustomPaint paintAt() => tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(ChatbotAvatar),
            matching: find.byType(CustomPaint),
          )
          .first,
    );

    final first = paintAt().painter;
    await tester.pump(const Duration(milliseconds: 150));
    final second = paintAt().painter;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(
      second!.shouldRepaint(first!),
      isTrue,
      reason: 'talking state should produce a changing pose each frame',
    );
  });

  testWidgets('switching state does not throw and keeps rendering', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChatbotAvatarState.idle));
    await tester.pump(const Duration(milliseconds: 60));

    for (final next in [
      ChatbotAvatarState.waving,
      ChatbotAvatarState.thinking,
      ChatbotAvatarState.talking,
      ChatbotAvatarState.smiling,
      ChatbotAvatarState.idle,
    ]) {
      await tester.pumpWidget(host(next));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'switching to $next threw');
    }

    expect(find.byType(ChatbotAvatar), findsOneWidget);
  });

  testWidgets(
    'holds a still pose when the platform asks for reduced motion',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ChatbotAvatar(
                  state: ChatbotAvatarState.talking,
                  size: 38,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      CustomPaint paintAt() => tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ChatbotAvatar),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      final first = paintAt().painter;
      await tester.pump(const Duration(milliseconds: 300));
      final second = paintAt().painter;

      expect(
        second!.shouldRepaint(first!),
        isFalse,
        reason:
            'with reduced motion the pose is constant, so no repaint should '
            'be requested',
      );
    },
  );
}
