import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/widgets/bottom_nav_scaffold.dart';

/// Regression test for the bottom-nav active-pill bug: the active tab must
/// render its full label text (e.g. "Navigation"), not collapse into an
/// ellipsis or throw a RenderFlex overflow that aborts the frame.
void main() {
  testWidgets(
    'active bottom nav tab renders its full label without overflow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BottomNavScaffold(initialIndex: 1)),
      );
      await tester.pumpAndSettle();

      // The "Navigation" tab is active (initialIndex: 1); its label must be
      // present as real text, not truncated to an ellipsis character.
      expect(_findNavPillLabel('Navigation'), findsOneWidget);
      expect(find.text('…'), findsNothing);

      // No RenderFlex overflow (or any other) exception should have been
      // recorded while laying out/painting the bar.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching tabs updates which label is expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BottomNavScaffold(initialIndex: 1)),
    );
    await tester.pumpAndSettle();
    expect(_findNavPillLabel('Navigation'), findsOneWidget);
    expect(_findNavPillLabel('Settings'), findsNothing);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();

    expect(_findNavPillLabel('Settings'), findsOneWidget);
    expect(_findNavPillLabel('Navigation'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Finds the bottom-nav pill's own label [Text] — white, 14px, Georgia —
/// as opposed to any same-named heading a screen's own content might show
/// (e.g. the Settings/Profile screen's "Settings" page title).
Finder _findNavPillLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data == label &&
        widget.style?.fontSize == 14 &&
        widget.style?.color == Colors.white,
  );
}
