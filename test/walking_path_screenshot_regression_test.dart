import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:intravel/services/walking_path_service.dart';

/// Direct regression check against the two real-device screenshots that
/// prompted the walking-path graph rework: a straight line between
/// Puerta del Parian and Manila High School, and a route that visibly
/// crossed the Pasig River. With the OSM-sourced graph
/// (tool/fetch_walking_paths.dart), both should now resolve to a
/// multi-point path that actually follows the district's real streets
/// instead of a raw two-point line.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WalkingPathService().ensureLoaded();
  });

  test('Puerta del Parian to Manila High School follows the street graph, '
      'not a straight line', () {
    const puertaDelParian = LatLng(14.5920, 120.9787);
    const manilaHighSchool = LatLng(14.5920, 120.9770);

    final path = WalkingPathService().findPath(
      puertaDelParian,
      manilaHighSchool,
    );

    expect(path, isNotNull);
    // A real street-following path between two points ~150m apart
    // should have several intermediate waypoints tracing actual
    // intersections, not just the two raw endpoints (which would be
    // indistinguishable from the straight-line fallback this rework
    // was meant to eliminate).
    expect(
      path!.length,
      greaterThan(4),
      reason:
          'Expected a real multi-point street-following path, not a '
          'near-straight line.',
    );
  });

  test('a route near Plaza Roma / Manila Cathedral does not need to cross '
      'the Pasig River', () {
    const nearPlazaRoma = LatLng(14.5917, 120.9731);
    const nearManilaCathedral = LatLng(14.5916, 120.9733);

    final path = WalkingPathService().findPath(
      nearPlazaRoma,
      nearManilaCathedral,
    );

    expect(path, isNotNull);
    // The Pasig River runs along Intramuros' northern edge, well above
    // latitude ~14.596. Every waypoint on this short central-Intramuros
    // route should stay well south of that, confirming the route
    // doesn't detour toward/through the riverside area the way the
    // previous drifted `ayuntamiento-de-manila` node caused.
    for (final point in path!) {
      expect(
        point.latitude,
        lessThan(14.596),
        reason:
            'Waypoint $point unexpectedly reaches toward the '
            'Pasig River / northern district edge for a short, central '
            'route.',
      );
    }
  });
}
