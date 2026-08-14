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

  // addendum spec 3 Section 1.1/1.3: Cafe (WiFi & Sockets) toggle mirrors
  // the existing Vegetarian toggle's Live Updates behavior. The grid
  // button's own label always renders regardless of active state (only
  // its color changes), so "on" shows the label twice (grid button +
  // Live Updates entry) and "off" shows it once (grid button only, with
  // its Live Updates entry removed).
  testWidgets(
    'toggling Cafe mode off removes its Live Updates entry, and toggling '
    'it back on restores it',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      // Defaults to active (addendum spec 3 Section 1.1): shown once in
      // the grid button and once in the Live Updates panel.
      expect(find.text('Cafe (WiFi & Sockets)'), findsNWidgets(2));

      // The panel is scrollable (SingleChildScrollView), so ensure the
      // Cafe button's icon is actually on-screen before tapping it. The
      // Live Updates card now uses the same Icons.local_cafe_outlined
      // glyph as the grid button (so the same feature reads identically
      // in both places), so the finder must be scoped to the GridView to
      // find only the grid button's icon rather than matching both.
      final cafeIcon = find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.local_cafe_outlined),
      );
      await tester.ensureVisible(cafeIcon);
      await tester.pumpAndSettle();
      await tester.tap(cafeIcon);
      await tester.pumpAndSettle();

      // Live Updates entry removed; grid button label remains (inactive
      // styling, but still rendered) — down to a single match.
      expect(find.text('Cafe (WiFi & Sockets)'), findsOneWidget);

      await tester.ensureVisible(cafeIcon);
      await tester.pumpAndSettle();
      await tester.tap(cafeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Cafe (WiFi & Sockets)'), findsNWidgets(2));
    },
  );

  // Fix requested: Cafe must sit directly under Vegetarian in the Live
  // Updates feed (mirroring its grid placement), with every other mode
  // shifting down one spot, and it must use the same icon as the Cafe
  // button in Accessibility Modes.
  testWidgets(
    'Cafe appears directly after Vegetarian in the Live Updates feed, '
    'using the same icon as its Accessibility Modes button',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      // Live Updates cards are the ones rendering inside colors.paper
      // rounded containers with a title/subtitle Column — easiest way to
      // assert order here is to check the vertical position (dy) of each
      // title Text relative to the others, since they're all default-on
      // and thus all present at the same time.
      final vegetarianCenter = tester
          .getTopLeft(find.text('Vegetarian').first)
          .dy;
      final cafeLiveUpdateFinder = find
          .text('Cafe (WiFi & Sockets)')
          .first; // Live Updates entry renders before the grid button.
      final cafeCenter = tester.getTopLeft(cafeLiveUpdateFinder).dy;
      final brailleCenter = tester
          .getTopLeft(find.text('Braille / Voice').first)
          .dy;

      // Cafe must be below Vegetarian and above Braille/Voice in the
      // feed's vertical order.
      expect(cafeCenter, greaterThan(vegetarianCenter));
      expect(brailleCenter, greaterThan(cafeCenter));

      // The Live Updates card's icon must match the Cafe grid button's
      // icon (Icons.local_cafe_outlined) — now expected to appear twice
      // (once in each surface).
      expect(find.byIcon(Icons.local_cafe_outlined), findsNWidgets(2));
    },
  );
}
