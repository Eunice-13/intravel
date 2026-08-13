import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:intravel/models/route_result_model.dart';
import 'package:intravel/screens/osm_poi_map_screen.dart';
import 'package:intravel/services/routing_service.dart';

class _FakeRoutingService implements RoutingService {
  @override
  Future<RouteResult> getWalkingRoute(LatLng start, LatLng end) async {
    return RouteResult(
      points: [start, end],
      distanceMeters: 100,
      durationSeconds: 90,
    );
  }
}

void main() {
  testWidgets('OsmPoiMapScreen loads POIs and renders the map + picker panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OsmPoiMapScreen(routingService: _FakeRoutingService()),
      ),
    );

    // Initial frame: loading state for POIs.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the asset load complete.
    await tester.pumpAndSettle();

    expect(find.text('Explore Intramuros'), findsOneWidget);
    expect(find.text('Walking route'), findsOneWidget);
    expect(find.text('Get walking route'), findsOneWidget);
    // "Get walking route" should be disabled until both start & end picked.
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Get walking route'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'shows the map-unavailable fallback and a browsable POI list if '
    'onMapCreated never fires within the timeout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OsmPoiMapScreen(routingService: _FakeRoutingService()),
        ),
      );
      await tester.pumpAndSettle();

      // In the test environment GoogleMap's platform view never calls
      // onMapCreated, so advancing past the screen's load timeout should
      // trip the failsafe rather than leaving an infinite loader.
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.textContaining('Map unavailable'), findsOneWidget);
      // POI list stays browsable even though the map failed to load.
      expect(find.text('Fort Santiago'), findsOneWidget);
    },
  );
}
