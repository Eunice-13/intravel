import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:intravel/services/routing_service.dart';

/// Fake [http.Client] that records the request it received (specifically
/// the `Authorization` header) instead of making a real network call, so
/// tests can verify which key source [OpenRouteServiceRouting] actually
/// used without depending on the live API.
class _RecordingHttpClient extends http.BaseClient {
  String? capturedAuthHeader;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    capturedAuthHeader = request.headers['Authorization'];
    const body = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[120.9787, 14.5920], [120.9770, 14.5892]]
      },
      "properties": { "summary": { "distance": 100.0, "duration": 80.0 } }
    }
  ]
}
''';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/geo+json'},
    );
  }
}

/// Regression coverage for the runtime env.json fallback: the ORS key
/// must load correctly whether it's supplied at compile time via
/// --dart-define (the original mechanism) or, when that's empty, from
/// the bundled env.json asset at runtime -- the fallback specifically
/// added so the key doesn't silently disappear when the app is launched
/// any way other than with that exact --dart-define flag (IDE Run
/// button, hot restart, a plain `flutter run`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the compile-time --dart-define key when one is provided, '
      'without touching the env.json asset fallback', () async {
    final client = _RecordingHttpClient();
    final service = OpenRouteServiceRouting(
      apiKey: 'compile-time-key',
      client: client,
    );

    await service.getWalkingRoute(
      const LatLng(14.5920, 120.9787),
      const LatLng(14.5892, 120.9770),
    );

    expect(client.capturedAuthHeader, 'compile-time-key');
  });

  test('falls back to loading ORS_API_KEY from the bundled env.json asset '
      'when no compile-time key was provided', () async {
    // Simulates the bundled env.json asset via Flutter's test asset
    // mocking, exactly mirroring how rootBundle.loadString resolves it
    // in a real app run.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          const fakeEnvJson = '{"ORS_API_KEY": "asset-fallback-key"}';
          return utf8.encode(fakeEnvJson).buffer.asByteData();
        });

    final client = _RecordingHttpClient();
    final service = OpenRouteServiceRouting(apiKey: '', client: client);

    await service.getWalkingRoute(
      const LatLng(14.5920, 120.9787),
      const LatLng(14.5892, 120.9770),
    );

    expect(client.capturedAuthHeader, 'asset-fallback-key');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}
