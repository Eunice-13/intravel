import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_result_model.dart';

String _truncate(String value, int maxLength) {
  return value.length <= maxLength
      ? value
      : '${value.substring(0, maxLength)}…';
}

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
/// The API key is never hardcoded as a literal in source: it's read from
/// a compile-time `--dart-define=ORS_API_KEY=...` value when one is
/// provided, and otherwise falls back to loading the gitignored
/// `env.json` asset at runtime (see [_loadKeyFromAssetFallback]) — that
/// fallback is what lets the key load automatically no matter how the app
/// is launched (IDE Run button, hot restart, a plain `flutter run` with
/// no flags), instead of only working when that exact `--dart-define`
/// flag is remembered on every single run. `env.json` itself is never
/// committed to source control either way (see .gitignore) — this only
/// changes *when* it's read (build-time define vs. runtime asset), not
/// whether the real key value ends up in version control.
class OpenRouteServiceRouting implements RoutingService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  final http.Client _client;
  final String _compileTimeApiKey;

  /// Resolved lazily on first use: the compile-time define if present,
  /// otherwise the key loaded from the bundled `env.json` asset. Cached
  /// so the asset is only read/parsed once per app run, not on every
  /// request.
  String? _resolvedApiKey;
  Future<String>? _resolveKeyFuture;

  /// [apiKey] defaults to the `ORS_API_KEY` compile-time define, used
  /// only when non-empty — otherwise resolution falls through to the
  /// runtime asset fallback on first use (see class doc). [client] is
  /// injectable for testing (so tests can supply a fake `http.Client`
  /// instead of making real network calls).
  // ignore: prefer_initializing_formals -- public `apiKey` param is kept
  // distinct from the private `_compileTimeApiKey` field name for API
  // clarity.
  OpenRouteServiceRouting({
    http.Client? client,
    String apiKey = const String.fromEnvironment('ORS_API_KEY'),
  }) : _client = client ?? http.Client(),
       _compileTimeApiKey = apiKey {
    // Diagnostic only (debug builds; stripped from release) — logs
    // whether a key was compiled in via --dart-define at construction
    // time, without logging the key value itself. If empty here, the
    // runtime asset fallback still gets a chance on first request (see
    // _resolveApiKey) before anything is treated as a real failure.
    debugPrint(
      _compileTimeApiKey.isEmpty
          ? '[OpenRouteServiceRouting] No ORS_API_KEY compiled in via '
                '--dart-define — will attempt to load it from the bundled '
                'env.json asset on first request instead.'
          : '[OpenRouteServiceRouting] ORS_API_KEY compiled in via '
                '--dart-define (${_compileTimeApiKey.length} chars). Key '
                'value itself is never logged.',
    );
  }

  /// Resolves the API key to use for this and all subsequent requests:
  /// the compile-time define if one was provided, otherwise the value
  /// loaded from the bundled `env.json` asset (parsed once and cached).
  /// Returns an empty string if neither source has a usable key, letting
  /// [getWalkingRoute] report the existing "not configured" error exactly
  /// as before.
  Future<String> _resolveApiKey() async {
    if (_compileTimeApiKey.isNotEmpty) return _compileTimeApiKey;
    if (_resolvedApiKey != null) return _resolvedApiKey!;
    // Multiple concurrent requests during startup should share a single
    // in-flight asset load rather than each parsing env.json separately.
    _resolveKeyFuture ??= _loadKeyFromAssetFallback();
    _resolvedApiKey = await _resolveKeyFuture;
    return _resolvedApiKey!;
  }

  /// Reads and parses the bundled `env.json` asset for `ORS_API_KEY`,
  /// used only when no compile-time define was supplied. `env.json` is
  /// gitignored (see .gitignore) but declared as a bundled asset in
  /// pubspec.yaml specifically so this fallback works — the real key
  /// value still never touches source control either way.
  Future<String> _loadKeyFromAssetFallback() async {
    try {
      final raw = await rootBundle.loadString('env.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final key = decoded['ORS_API_KEY'] as String? ?? '';
      debugPrint(
        key.isEmpty
            ? '[OpenRouteServiceRouting] env.json asset loaded but '
                  'ORS_API_KEY is empty/missing in it.'
            : '[OpenRouteServiceRouting] ORS_API_KEY loaded from the '
                  'bundled env.json asset (${key.length} chars). Key value '
                  'itself is never logged.',
      );
      return key;
    } catch (e) {
      debugPrint(
        '[OpenRouteServiceRouting] Could not load the env.json asset '
        'fallback (missing file, invalid JSON, or not declared as a '
        'bundled asset in pubspec.yaml): $e',
      );
      return '';
    }
  }

  @override
  Future<RouteResult> getWalkingRoute(LatLng start, LatLng end) async {
    final apiKey = await _resolveApiKey();
    if (apiKey.isEmpty) {
      debugPrint(
        '[OpenRouteServiceRouting] getWalkingRoute() aborted before any '
        'network call: no ORS_API_KEY available from --dart-define or the '
        'env.json asset fallback.',
      );
      throw const RoutingException(
        RoutingErrorType.invalidApiKey,
        'Routing is not configured: missing ORS_API_KEY. Add it to '
        'env.json in the project root and rebuild, or run with '
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

    debugPrint(
      '[OpenRouteServiceRouting] Requesting foot-walking route: '
      '($start) -> ($end)',
    );

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/geo+json, application/json; charset=utf-8',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint(
        '[OpenRouteServiceRouting] Request threw before a response '
        'was received (network/timeout): $e',
      );
      throw RoutingException(
        RoutingErrorType.network,
        'Could not reach the routing service. Check your connection and '
        'try again.',
        cause: e,
      );
    }

    // Always logged, success or failure — this is what answers "is the
    // call happening at all, and what does the raw response actually
    // look like?" without needing to reproduce the failure blind.
    debugPrint(
      '[OpenRouteServiceRouting] Response: HTTP ${response.statusCode}, '
      '${response.body.length} bytes'
      '${response.statusCode == 200 ? '' : ' — body: ${_truncate(response.body, 500)}'}',
    );

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
    final coordinates = (geometry['coordinates'] as List).cast<List<dynamic>>();
    final points = coordinates
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
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
      steps: _parseSteps(properties),
    );
  }

  /// Extracts real turn-by-turn maneuvers from ORS's
  /// `properties.segments[].steps[]` — each `way_points: [start, end]`
  /// pair already indexes directly into the same coordinate list decoded
  /// above, so these maneuvers correspond to actual points along the
  /// real, street-following route rather than an approximation over the
  /// raw polyline. A single route can have multiple segments only when
  /// multiple waypoints were requested; this app always requests exactly
  /// one start/end pair, so segments are flattened in order.
  List<RouteStep> _parseSteps(Map<String, dynamic>? properties) {
    final segments = properties?['segments'] as List?;
    if (segments == null) return const [];
    final steps = <RouteStep>[];
    for (final segment in segments) {
      final segmentMap = segment as Map<String, dynamic>;
      final segmentSteps = segmentMap['steps'] as List?;
      if (segmentSteps == null) continue;
      for (final step in segmentSteps) {
        final stepMap = step as Map<String, dynamic>;
        final wayPoints = (stepMap['way_points'] as List?)
            ?.cast<num>()
            .map((n) => n.toInt())
            .toList();
        if (wayPoints == null || wayPoints.length < 2) continue;
        steps.add(
          RouteStep(
            instruction: stepMap['instruction'] as String? ?? '',
            name: stepMap['name'] as String? ?? '-',
            distanceMeters: (stepMap['distance'] as num?)?.toDouble() ?? 0.0,
            durationSeconds: (stepMap['duration'] as num?)?.toDouble() ?? 0.0,
            wayPointStart: wayPoints[0],
            wayPointEnd: wayPoints[1],
          ),
        );
      }
    }
    return steps;
  }
}
