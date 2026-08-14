import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:intravel/services/routing_service.dart';

/// Fake [http.Client] that returns a fixed, realistic ORS
/// foot-walking/geojson response (matching the shape confirmed against
/// the live API earlier: a `properties.segments[].steps[]` list with
/// `way_points` indexing into the feature's own `geometry.coordinates`),
/// so [OpenRouteServiceRouting] can be tested without a real network call.
class _FakeHttpClient extends http.BaseClient {
  final String responseBody;
  final int statusCode;

  // ignore: unused_element_parameter
  _FakeHttpClient({required this.responseBody, this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(responseBody);
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      headers: {'content-type': 'application/geo+json'},
    );
  }
}

const _sampleGeoJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [120.9787, 14.5920],
          [120.9781, 14.5915],
          [120.9775, 14.5910],
          [120.9770, 14.5892]
        ]
      },
      "properties": {
        "summary": { "distance": 276.3, "duration": 199.0 },
        "segments": [
          {
            "distance": 276.3,
            "duration": 199.0,
            "steps": [
              {
                "distance": 82.2,
                "duration": 59.2,
                "type": 11,
                "instruction": "Head south",
                "name": "-",
                "way_points": [0, 1]
              },
              {
                "distance": 68.5,
                "duration": 49.3,
                "type": 1,
                "instruction": "Turn right onto Real Street",
                "name": "Real Street",
                "way_points": [1, 2]
              },
              {
                "distance": 125.6,
                "duration": 90.5,
                "type": 0,
                "instruction": "Turn left onto Victoria Street",
                "name": "Victoria Street",
                "way_points": [2, 3]
              },
              {
                "distance": 0.0,
                "duration": 0.0,
                "type": 10,
                "instruction": "Arrive at your destination",
                "name": "-",
                "way_points": [3, 3]
              }
            ]
          }
        ]
      }
    }
  ]
}
''';

void main() {
  group('OpenRouteServiceRouting real turn-by-turn step parsing', () {
    test(
      'decodes each real step with its instruction, name, and waypoint '
      'indices into the route\'s own coordinate list',
      () async {
        final service = OpenRouteServiceRouting(
          apiKey: 'test-key',
          client: _FakeHttpClient(responseBody: _sampleGeoJson),
        );

        final result = await service.getWalkingRoute(
          const LatLng(14.5920, 120.9787),
          const LatLng(14.5892, 120.9770),
        );

        expect(result.points, hasLength(4));
        expect(result.steps, hasLength(4));

        final firstStep = result.steps[0];
        expect(firstStep.instruction, 'Head south');
        expect(firstStep.hasRealName, isFalse);
        expect(firstStep.wayPointStart, 0);
        expect(firstStep.wayPointEnd, 1);

        final secondStep = result.steps[1];
        expect(secondStep.instruction, 'Turn right onto Real Street');
        expect(secondStep.name, 'Real Street');
        expect(secondStep.hasRealName, isTrue);
        expect(secondStep.wayPointEnd, 2);

        final thirdStep = result.steps[2];
        expect(thirdStep.instruction, 'Turn left onto Victoria Street');
        expect(thirdStep.wayPointEnd, 3);

        // Each step's wayPointEnd must be a valid index into the route's
        // own points list -- this is the property that makes "next turn"
        // correspond to an actual point on the real routed path, not an
        // arbitrary approximation.
        for (final step in result.steps) {
          expect(step.wayPointEnd, lessThan(result.points.length));
          expect(step.wayPointStart, lessThan(result.points.length));
        }
      },
    );

    test(
      'a route with no segments/steps in the response yields an empty '
      'steps list rather than throwing',
      () async {
        const noStepsGeoJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[120.9787, 14.5920], [120.9770, 14.5892]]
      },
      "properties": {
        "summary": { "distance": 100.0, "duration": 80.0 }
      }
    }
  ]
}
''';
        final service = OpenRouteServiceRouting(
          apiKey: 'test-key',
          client: _FakeHttpClient(responseBody: noStepsGeoJson),
        );

        final result = await service.getWalkingRoute(
          const LatLng(14.5920, 120.9787),
          const LatLng(14.5892, 120.9770),
        );

        expect(result.steps, isEmpty);
      },
    );
  });
}
