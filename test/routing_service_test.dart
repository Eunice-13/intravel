import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:intravel/services/routing_service.dart';

void main() {
  const start = LatLng(14.5906, 120.9750);
  const end = LatLng(14.5915, 120.9736);

  group('OpenRouteServiceRouting', () {
    test('throws invalidApiKey RoutingException when no API key is set', () async {
      final service = OpenRouteServiceRouting(
        apiKey: '',
        client: MockClient((request) async {
          fail('should not make a network call without an API key');
        }),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.invalidApiKey,
          ),
        ),
      );
    });

    test('parses a successful GeoJSON response into a RouteResult', () async {
      final geoJson = jsonEncode({
        'features': [
          {
            'geometry': {
              'coordinates': [
                [120.9750, 14.5906],
                [120.9740, 14.5910],
                [120.9736, 14.5915],
              ],
            },
            'properties': {
              'summary': {'distance': 250.5, 'duration': 180.0},
            },
          },
        ],
      });

      final service = OpenRouteServiceRouting(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'test-key');
          return http.Response(geoJson, 200);
        }),
      );

      final result = await service.getWalkingRoute(start, end);

      expect(result.points.length, 3);
      expect(result.points.first.latitude, 14.5906);
      expect(result.distanceMeters, 250.5);
      expect(result.durationSeconds, 180.0);
      expect(result.distanceLabel, '251 m');
    });

    test('throws rateLimited RoutingException on HTTP 429', () async {
      final service = OpenRouteServiceRouting(
        apiKey: 'test-key',
        client: MockClient((request) async => http.Response('', 429)),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.rateLimited,
          ),
        ),
      );
    });

    test('throws noRoute RoutingException on HTTP 404', () async {
      final service = OpenRouteServiceRouting(
        apiKey: 'test-key',
        client: MockClient((request) async => http.Response('{}', 404)),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.noRoute,
          ),
        ),
      );
    });

    test('throws invalidApiKey RoutingException on HTTP 401', () async {
      final service = OpenRouteServiceRouting(
        apiKey: 'bad-key',
        client: MockClient((request) async => http.Response('', 401)),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.invalidApiKey,
          ),
        ),
      );
    });

    test('throws network RoutingException when the request throws', () async {
      final service = OpenRouteServiceRouting(
        apiKey: 'test-key',
        client: MockClient((request) async {
          throw Exception('connection refused');
        }),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.network,
          ),
        ),
      );
    });

    test('throws noRoute RoutingException when features list is empty', () async {
      final service = OpenRouteServiceRouting(
        apiKey: 'test-key',
        client: MockClient(
          (request) async => http.Response(jsonEncode({'features': []}), 200),
        ),
      );

      await expectLater(
        service.getWalkingRoute(start, end),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.type,
            'type',
            RoutingErrorType.noRoute,
          ),
        ),
      );
    });
  });
}
