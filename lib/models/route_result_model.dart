import 'package:latlong2/latlong.dart';

/// A single real turn-by-turn maneuver within a [RouteResult], decoded from
/// the routing provider's own step data (e.g. OpenRouteService's
/// `properties.segments[].steps[]`) rather than approximated from the
/// route polyline's raw vertices.
///
/// [wayPointStart]/[wayPointEnd] are indices into the parent
/// [RouteResult.points] list: [wayPointStart] is where this instruction
/// begins (typically the previous maneuver's location), and [wayPointEnd]
/// is where the *next* maneuver happens — i.e. the point a turn-by-turn UI
/// should treat as "the next turn" while the user is still executing this
/// step. This is what makes each reported turn correspond to an actual
/// walkable decision point in the routed path, instead of just the next
/// vertex along the polyline (which could be any point along a straight
/// stretch of the same street).
class RouteStep {
  final String instruction;

  /// Street/path name for this step, or `-` when the provider has none
  /// (e.g. an unnamed path segment) — callers should fall back to a
  /// proxy (like the nearest known landmark) in that case rather than
  /// display the placeholder directly.
  final String name;
  final double distanceMeters;
  final double durationSeconds;
  final int wayPointStart;
  final int wayPointEnd;

  const RouteStep({
    required this.instruction,
    required this.name,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.wayPointStart,
    required this.wayPointEnd,
  });

  /// Whether [name] is a real street/path name rather than the routing
  /// provider's "no name available" placeholder.
  bool get hasRealName => name.isNotEmpty && name != '-';
}

/// A decoded walking route returned by a [RoutingService] implementation
/// (see `lib/services/routing_service.dart`).
///
/// Distinct from [CuratedRoute] in `route_model.dart`, which models curated
/// themed *tour* routes (Plans page) — this models a single point-to-point
/// turn-free walking path (start POI → end POI) used by `OsmPoiMapScreen`.
class RouteResult {
  /// Ordered path points, decoded from the routing provider's response,
  /// ready to hand directly to a flutter_map `Polyline`.
  final List<LatLng> points;

  /// Total route distance in meters.
  final double distanceMeters;

  /// Total estimated walking duration in seconds.
  final double durationSeconds;

  /// Real turn-by-turn maneuvers for this route, in order, when the
  /// routing provider returned step data — empty if the provider didn't
  /// supply steps, or (for a fallback route with no provider response at
  /// all, e.g. the static walking-path graph) none exist to parse. Callers
  /// needing turn-by-turn guidance should treat an empty list as "no real
  /// maneuver data available" and fall back to their own approximation,
  /// same as when the whole route itself came from a fallback source.
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes < 1) return '<1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return remMinutes == 0 ? '${hours}h' : '${hours}h ${remMinutes}min';
  }
}
