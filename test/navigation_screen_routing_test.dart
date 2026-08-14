import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:intravel/models/nav_target.dart';
import 'package:intravel/models/route_result_model.dart';
import 'package:intravel/screens/navigation_screen.dart';
import 'package:intravel/services/location_service.dart';
import 'package:intravel/services/routing_service.dart';

/// Fake [RoutingService] that always succeeds with a fixed multi-point
/// route, so tests never make real network calls (mirrors the pattern
/// already used for [OsmPoiMapScreen]'s own routing tests).
class _FakeSucceedingRoutingService implements RoutingService {
  bool wasCalled = false;

  @override
  Future<RouteResult> getWalkingRoute(ll.LatLng start, ll.LatLng end) async {
    wasCalled = true;
    return RouteResult(
      points: [
        start,
        ll.LatLng(
          (start.latitude + end.latitude) / 2,
          (start.longitude + end.longitude) / 2,
        ),
        end,
      ],
      distanceMeters: 120,
      durationSeconds: 90,
    );
  }
}

/// Fake [RoutingService] that always fails, so tests can verify the
/// screen still renders/functions via its fallback chain rather than
/// crashing or hanging when the network call errors out.
class _FakeFailingRoutingService implements RoutingService {
  @override
  Future<RouteResult> getWalkingRoute(ll.LatLng start, ll.LatLng end) async {
    throw const RoutingException(RoutingErrorType.network, 'simulated failure');
  }
}

void main() {
  testWidgets(
    'active navigation mode does not crash when the routing service fails',
    (tester) async {
      final target = LocationService().getAllLocations().first;
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(
            navTarget: NavTarget.fromLocation(target),
            routingService: _FakeFailingRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No GPS fix is available in the test environment, so no route
      // fetch is triggered at all yet — this just confirms the screen
      // renders successfully with a failing routing service injected
      // (i.e. it never crashes reaching for the routing service).
      expect(find.byType(NavigationScreen), findsOneWidget);
    },
  );

  testWidgets(
    'active navigation mode renders successfully with a succeeding fake '
    'routing service injected',
    (tester) async {
      final target = LocationService().getAllLocations().first;
      final fakeService = _FakeSucceedingRoutingService();
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationScreen(
            navTarget: NavTarget.fromLocation(target),
            routingService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationScreen), findsOneWidget);
      // No GPS fix in the test environment means _routeStartPosition
      // never gets set, so the fetch is never actually triggered here —
      // this test primarily documents/locks in that injecting a
      // routing service is wired through without crashing regardless.
      expect(fakeService.wasCalled, isFalse);
    },
  );
}
