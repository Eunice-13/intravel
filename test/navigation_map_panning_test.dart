import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:intravel/models/nav_target.dart';
import 'package:intravel/screens/navigation_screen.dart';
import 'package:intravel/services/location_service.dart';

/// Improvement-batch spec Section 4 — free panning/zooming plus a re-center
/// button.
///
/// The camera itself can't be asserted on here: `GoogleMapController` is only
/// handed over by the platform view's `onMapCreated`, which never fires under
/// `flutter test`. What these tests do cover is the part that actually
/// regressed before: the decision of *whether* a camera move counts as a user
/// pan, and therefore suspends follow mode and reveals the re-center button.
///
/// `onCameraMoveStarted` is invoked directly off the `GoogleMap` widget,
/// because that is exactly what the platform channel does — the plugin's
/// callback is a bare `VoidCallback` with no reason code, which is the whole
/// reason the screen has to infer intent from touch state instead.
void main() {
  // The default 800x600 test surface is landscape, which squeezes the map
  // Expanded down to ~100px and leaves the floating cards covering its
  // centre — so a synthetic drag at the map's centre would land on a card
  // instead of the map. A portrait phone-shaped surface reproduces the real
  // layout these gestures are written against.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(400, 900);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Finder recenterButton() => find.byIcon(Icons.my_location_rounded);

  GoogleMap mapWidget(WidgetTester tester) =>
      tester.widget<GoogleMap>(find.byType(GoogleMap));

  /// Reproduces a real drag on the map: a pointer goes down on the map
  /// surface, moves, and *while it is still down* the platform reports that
  /// the camera started moving.
  Future<void> dragMap(WidgetTester tester, Offset by) async {
    final map = mapWidget(tester);
    expect(
      map.onCameraMoveStarted,
      isNotNull,
      reason: 'pan detection is wired through this callback',
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GoogleMap)),
    );
    await gesture.moveBy(by);
    map.onCameraMoveStarted!();
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('browse mode', () {
    testWidgets('no re-center button until the user has actually panned', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      expect(
        recenterButton(),
        findsNothing,
        reason:
            'the camera is already where it belongs, so the control would '
            'just be dead chrome over the map',
      );
    });

    testWidgets('a camera move made while a finger is down reveals it', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      await dragMap(tester, const Offset(-90, -70));

      expect(recenterButton(), findsOneWidget);
    });

    testWidgets(
      'a camera move with no finger on the map is treated as programmatic '
      'and does NOT reveal it — otherwise the follow camera\'s own moves '
      'would trip pan detection on every GPS fix',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
        await tester.pumpAndSettle();

        mapWidget(tester).onCameraMoveStarted!();
        await tester.pumpAndSettle();

        expect(recenterButton(), findsNothing);
      },
    );

    testWidgets('tapping re-center dismisses it again (follow mode resumed)', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationScreen()));
      await tester.pumpAndSettle();

      await dragMap(tester, const Offset(-90, -70));
      expect(recenterButton(), findsOneWidget);

      await tester.tap(recenterButton());
      await tester.pumpAndSettle();

      expect(
        recenterButton(),
        findsNothing,
        reason: 'follow mode resumed, so the control retires again',
      );
    });
  });

  group('active navigation mode', () {
    Future<void> pumpNavigating(WidgetTester tester) async {
      final target = LocationService().getAllLocations().first;
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(navTarget: NavTarget.fromLocation(target)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the re-center control is no longer permanently on screen — it used to '
      'sit top-right unconditionally and is now pan-triggered',
      (tester) async {
        await pumpNavigating(tester);

        expect(recenterButton(), findsNothing);
      },
    );

    testWidgets('panning during navigation reveals re-center', (tester) async {
      await pumpNavigating(tester);

      await dragMap(tester, const Offset(60, 90));

      expect(recenterButton(), findsOneWidget);
    });

    testWidgets(
      're-center sits above the satellite toggle in the floating stack',
      (tester) async {
        await pumpNavigating(tester);
        await dragMap(tester, const Offset(60, 90));

        final recenterY = tester.getTopLeft(recenterButton()).dy;
        final satelliteY = tester
            .getTopLeft(find.byIcon(Icons.satellite_alt_outlined))
            .dy;
        expect(recenterY, lessThan(satelliteY));
      },
    );
  });
}
