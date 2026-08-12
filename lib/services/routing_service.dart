import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_result_model.dart';

/// Abstraction over a walking-directions provider, so `OsmPoiMapScreen`
/// doesn't depend on a concrete routing backend directly. The only
/// production implementation is [OpenRouteServiceRouting]; tests provide a
/// fake/mock implementing this interface instead of hitting the network.
abstract class RoutingService {
  /// Fetches a real, street-following walking route between [start] and
  /// [end]. Throws a [RoutingException] on any failure — callers must
  /// handle it and show a graceful error state rather than letting it
  /// propagate as a crash.
  Future<RouteResult> getWalkingRoute(LatLng start, LatLng end);
}

/// What kind of failure a [RoutingException] represents, so UI code can
/// show a tailored message (e.g. distinguishing "try again later" from
/// "no walking path exists between these points").
enum RoutingErrorType { network, rateLimited, noRoute, invalidApiKey, unknown }

class RoutingException implements Exception {
  final RoutingErrorType type;
  final String message;
  final Object? cause;

  const RoutingException(this.type, this.message, {this.cause});

  @override
  String toString() => 'RoutingException(${type.name}): $message';
}

/// [RoutingService] backed by the OpenRouteService Directions API
/// (foot-walking profile), a free-tier keyed API that returns routes
/// snapped to real streets/paths — unlike the app's previous
/// straight-line / static hop-graph approximation.
///
/// The API key is never hardcoded: it's read from a compile-time
/// `--dart-define=ORS_API_KEY=...` value (see README for setup), so it's
/// never checked into source control.
class OpenRouteServiceRouting implements RoutingService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  final http.Client _client;
  final String _apiKey;

  /// [apiKey] defaults to the `ORS_API_KEY` compile-time define. [client]
  /// is injectable for testing (so tests can supply a fake `http.Client`
  /// instead of making real network calls).
  // ignore: prefer_initializing_formals -- public `apiKey` param is kept
  // distinct from the private `_apiKey` field name for API clarity.
  OpenRouteServiceRouting({
    http.Client? client,
    String apiKey = const String.fromEnvironment('ORS_API_KEY'),
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey;

  @override
  Future<RouteResult> getWalkingRoute(LatLng start, LatLng end) async {
    if (_apiKey.isEmpty) {
      throw const RoutingException(
        RoutingErrorType.invalidApiKey,
        'Routing is not configured: missing ORS_API_KEY. Run with '
            '--dart-define=ORS_API_KEY=your_key.',
      );
    }

    final uri = Uri.parse(_baseUrl);
    final body = jsonEncode({
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
    });

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
              'Accept':
                  'application/geo+json, application/json; charset=utf-8',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw RoutingException(
        RoutingErrorType.network,
        'Could not reach the routing service. Check your connection and '
            'try again.',
        cause: e,
      );
    }

    if (response.statusCode == 429) {
      throw RoutingException(
        RoutingErrorType.rateLimited,
        'The routing service is temporarily rate-limited. Please try '
            'again in a moment.',
        cause: response.body,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RoutingException(
        RoutingErrorType.invalidApiKey,
        'Routing service rejected the API key.',
        cause: response.body,
      );
    }

    if (response.statusCode == 404) {
      // ORS returns 404 with an error payload when no route can be found
      // between the given coordinates (e.g. across water, disconnected
      // graph segments).
      throw RoutingException(
        RoutingErrorType.noRoute,
        'No walking route could be found between these two points.',
        cause: response.body,
      );
    }

    if (response.statusCode != 200) {
      throw RoutingException(
        RoutingErrorType.unknown,
        'Routing request failed (HTTP ${response.statusCode}).',
        cause: response.body,
      );
    }

    try {
      return _parseGeoJson(response.body);
    } on RoutingException {
      rethrow;
    } catch (e) {
      throw RoutingException(
        RoutingErrorType.unknown,
        'Could not parse the routing response.',
        cause: e,
      );
    }
  }

  RouteResult _parseGeoJson(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final features = decoded['features'] as List?;
    if (features == null || features.isEmpty) {
      throw const RoutingException(
        RoutingErrorType.noRoute,
        'No walking route could be found between these two points.',
      );
    }

    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = (geometry['coordinates'] as List)
        .cast<List<dynamic>>();
    final points = coordinates
        .map(
          (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        )
        .toList();

    final properties = feature['properties'] as Map<String, dynamic>?;
    final summary = properties?['summary'] as Map<String, dynamic>?;
    final distance = (summary?['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (summary?['duration'] as num?)?.toDouble() ?? 0.0;

    if (points.isEmpty) {
      throw const RoutingException(
        RoutingErrorType.noRoute,
        'No walking route could be found between these two points.',
      );
    }

    return RouteResult(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }
}
