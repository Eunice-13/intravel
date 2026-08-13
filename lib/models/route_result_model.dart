import 'package:latlong2/latlong.dart';

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

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
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
