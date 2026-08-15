import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/screens/itinerary_create_screen.dart';
import 'package:intravel/screens/location_details_screen.dart';
import 'package:intravel/services/location_service.dart';

/// Improvement-batch spec Section 7 — the Location Details "Directions"
/// button, which used to be a literal `onTap: () {}`.
void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    // Tall so the lazily-built slivers can be scrolled to, and wide enough
    // that the test environment's fallback font (which renders every glyph as
    // a full em square, so text measures far wider than on a real device)
    // doesn't overflow the details screen's header Rows.
    view.physicalSize = const Size(900, 1600);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('tapping Directions opens the itinerary builder with the '
      'originating location already included', (tester) async {
    final location = LocationService().getAllLocations().first;

    await tester.pumpWidget(
      MaterialApp(home: LocationDetailsScreen(location: location)),
    );
    await tester.pumpAndSettle();

    // The action row lives inside a lazily-built sliver, so it isn't in the
    // tree until scrolled to.
    final directions = find.text('Directions');
    await tester.dragUntilVisible(
      directions,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(directions, findsOneWidget);
    await tester.tap(directions);
    await tester.pumpAndSettle();

    // Landed on the builder…
    expect(find.byType(ItineraryCreateScreen), findsOneWidget);
    expect(find.text('Build Your Trip'), findsOneWidget);

    // …with this location seeded as the one selected stop.
    final screen = tester.widget<ItineraryCreateScreen>(
      find.byType(ItineraryCreateScreen),
    );
    expect(screen.seedLocation?.id, location.id);
    expect(
      find.text('1 selected'),
      findsOneWidget,
      reason: 'the pre-included stop should already count toward the trip',
    );
    // Name pre-filled so Save isn't blocked by the empty-name guard.
    expect(find.text('Trip to ${location.name}'), findsOneWidget);
  });

  testWidgets('the seeded stop is floated to the top of the location list so '
      'the pre-inclusion is visible', (tester) async {
    final all = LocationService().getAllLocations();
    // Pick something that is NOT already first, otherwise the assertion
    // would pass without the reordering doing any work.
    final seed = all[5];

    await tester.pumpWidget(
      MaterialApp(home: ItineraryCreateScreen(seedLocation: seed)),
    );
    await tester.pumpAndSettle();

    final firstCardName = find.text(seed.name);
    expect(firstCardName, findsWidgets);
    final seedY = tester.getTopLeft(firstCardName.first).dy;
    final otherY = tester.getTopLeft(find.text(all.first.name).first).dy;
    expect(
      seedY,
      lessThan(otherY),
      reason: 'seeded stop must render above the list\'s normal first entry',
    );
  });

  testWidgets(
    'the pre-included stop is removable, exactly like a manually added one',
    (tester) async {
      final seed = LocationService().getAllLocations().first;

      await tester.pumpWidget(
        MaterialApp(home: ItineraryCreateScreen(seedLocation: seed)),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text(seed.name).first);
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsOneWidget);
    },
  );

  testWidgets('with no seed the builder is unchanged — empty name, nothing '
      'selected (existing call sites must not regress)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ItineraryCreateScreen()));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, isEmpty);
  });
}
