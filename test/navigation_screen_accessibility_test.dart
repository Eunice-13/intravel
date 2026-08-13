import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/models/nav_target.dart';
import 'package:intravel/screens/navigation_screen.dart';
import 'package:intravel/services/accessibility_settings_service.dart';
import 'package:intravel/services/location_service.dart';

void main() {
  setUp(() {
    // Reset the shared singleton to its default (enabled) before each test.
    AccessibilitySettingsService.instance.toggle(true);
  });

  testWidgets('shows all 6 accessibility mode buttons in a 2-column grid when '
      'Accessibility Support is enabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Vegetarian'), findsWidgets);
    expect(find.text('Braille / Voice'), findsWidgets);
    expect(find.text('Ramps & Elevators'), findsWidgets);
    expect(find.text('Rest Areas & Seating Nearby'), findsOneWidget);
    expect(find.text('PWD & Senior Priority Assistance'), findsOneWidget);
    expect(find.text('Audio-Described Directions'), findsWidgets);

    // Reflowed into a 2-column grid rather than a vertical list.
    expect(find.byType(GridView), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets(
    'hides the Live Updates / Accessibility Modes panel entirely when '
    'Accessibility Support is turned off',
    (tester) async {
      AccessibilitySettingsService.instance.toggle(false);

      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Live Updates'), findsNothing);
      expect(find.text('Vegetarian'), findsNothing);
      expect(find.byType(GridView), findsNothing);
    },
  );

  testWidgets(
    'active navigation mode shows a back button that pops the route',
    (tester) async {
      final target = LocationService().getAllLocations().first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NavigationScreen(
                    navTarget: NavTarget.fromLocation(target),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    },
  );
}
