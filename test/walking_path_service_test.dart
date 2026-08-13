import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:intravel/services/walking_path_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WalkingPathService().ensureLoaded();
  });

  group('findPath edge-snapping', () {
    test(
      'routes between two points that are each near a walkway edge, not '
      'just near a node center',
      () {
        // Roughly along the Manila Cathedral <-> Plaza Roma segment, but
        // offset from both endpoints so neither point is close enough to
        // count as "at" either named node.
        const start = LatLng(14.5916, 120.97305);
        const end = LatLng(14.59165, 120.973075);

        final path = WalkingPathService().findPath(start, end);

        expect(path, isNotNull);
        expect(path!.first, start);
        expect(path.last, end);
        // A real graph-traced path should have more than just the two
        // raw endpoints — otherwise this is indistinguishable from the
        // straight-line fallback this fix was meant to eliminate.
        expect(path.length, greaterThan(2));
      },
    );

    test(
      'still connects two points that are only near a node center (legacy '
      'node-snap behavior keeps working)',
      () {
        const fortSantiago = LatLng(14.5941, 120.9725);
        const manilaCathedral = LatLng(14.5915, 120.9730);

        final path = WalkingPathService().findPath(
          fortSantiago,
          manilaCathedral,
        );

        expect(path, isNotNull);
        expect(path!.length, greaterThanOrEqualTo(2));
      },
    );

    test(
      'falls back to null when a point is far outside the graph\'s '
      'covered area',
      () {
        const farAway = LatLng(14.0, 121.5);
        const fortSantiago = LatLng(14.5941, 120.9725);

        final path = WalkingPathService().findPath(farAway, fortSantiago);

        expect(path, isNull);
      },
    );

    test(
      'both endpoints snapping to the same edge produces a short direct '
      'path through that edge rather than requiring a full node hop',
      () {
        // Two points close together, both near the same walkway segment.
        const pointA = LatLng(14.5916, 120.97305);
        const pointB = LatLng(14.59162, 120.97307);

        final path = WalkingPathService().findPath(pointA, pointB);

        expect(path, isNotNull);
        expect(path!.first, pointA);
        expect(path.last, pointB);
      },
    );
  });
}
