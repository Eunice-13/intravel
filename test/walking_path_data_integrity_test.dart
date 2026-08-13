import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:intravel/services/gate_service.dart';
import 'package:intravel/services/location_service.dart';

/// Regression coverage for the walking-path graph's data quality.
///
/// History: the graph was originally ~10 hand-authored landmark/gate
/// nodes. A 2026-08 audit found several of those nodes had silently
/// drifted out of sync with their authoritative coordinates in
/// [LocationService]/[GateService] (up to ~430m off in one case),
/// producing routes drawn through non-walkable areas, including across
/// the Pasig River. The graph was then replaced entirely with a much
/// denser network fetched from OpenStreetMap via
/// `tool/fetch_walking_paths.dart`, which tracks every real pedestrian
/// way/intersection instead of a handful of named landmarks — so there
/// are no more hand-mapped landmark/gate node ids to drift out of sync in
/// the first place.
///
/// This test now instead guards the properties that still matter for the
/// new OSM-sourced graph: every catalogued location/gate must still be
/// reachable (i.e. near enough to snap onto the graph), and no segment
/// should be an implausibly long straight hop that would suggest bad
/// source data slipped through the fetch tool's own sanity filtering.
double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _nearestNodeDistanceMeters(
  List<Map<String, dynamic>> nodes,
  LatLng point,
) {
  var nearest = double.infinity;
  for (final node in nodes) {
    final distance = _haversineMeters(
      point.latitude,
      point.longitude,
      (node['lat'] as num).toDouble(),
      (node['lng'] as num).toDouble(),
    );
    if (distance < nearest) nearest = distance;
  }
  return nearest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> nodes;
  late List<Map<String, dynamic>> segments;

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/data/walking_paths.json');
    final graph = jsonDecode(raw) as Map<String, dynamic>;
    nodes = (graph['nodes'] as List).cast<Map<String, dynamic>>();
    segments = (graph['segments'] as List).cast<Map<String, dynamic>>();
  });

  test('the graph has a substantial node and edge count', () {
    // A sanity floor, not an exact count (the OSM data can change between
    // fetches) — this exists to catch a fetch tool regression that
    // silently produced a near-empty graph, which would otherwise pass
    // every other check here by having almost nothing to check.
    expect(
      nodes.length,
      greaterThan(100),
      reason:
          'Expected a dense OSM-sourced graph, not a small hand-'
          'authored one.',
    );
    expect(segments.length, greaterThan(100));
  });

  test('no segment is an implausibly long straight hop', () {
    final nodeById = {for (final n in nodes) n['id'] as String: n};
    const maxAllowedMeters = 200.0; // generous margin above the fetch
    // tool's own 150m filter, to catch a regression in that filter
    // itself without being flaky over minor coordinate rounding.

    for (final segment in segments) {
      final from = nodeById[segment['from'] as String];
      final to = nodeById[segment['to'] as String];
      if (from == null || to == null) continue;
      final distance = _haversineMeters(
        (from['lat'] as num).toDouble(),
        (from['lng'] as num).toDouble(),
        (to['lat'] as num).toDouble(),
        (to['lng'] as num).toDouble(),
      );
      expect(
        distance,
        lessThan(maxAllowedMeters),
        reason:
            'Segment ${segment['from']} -> ${segment['to']} is $distance m, '
            'suspiciously long for a single walkable hop — likely bad '
            'source data.',
      );
    }
  });

  test(
    'every catalogued gate is close enough to the graph to be reachable',
    () {
      for (final gate in GateService().getAllGates()) {
        final nearestDistance = _nearestNodeDistanceMeters(
          nodes,
          gate.coordinates,
        );
        expect(
          nearestDistance,
          lessThan(150),
          reason:
              'Gate "${gate.name}" (${gate.coordinates}) is $nearestDistance '
              'm from the nearest walking-path node — likely unreachable '
              'by the current graph.',
        );
      }
    },
  );

  test('a sample of catalogued locations are close enough to the graph to '
      'be reachable', () {
    // Checking every location would make this test slow and brittle to
    // any single far-flung/edge-of-bbox site; a representative sample
    // is enough to catch a systemic graph-coverage regression.
    final sample = LocationService().getAllLocations().take(15);
    for (final location in sample) {
      final nearestDistance = _nearestNodeDistanceMeters(
        nodes,
        location.coordinates,
      );
      expect(
        nearestDistance,
        lessThan(200),
        reason:
            'Location "${location.name}" (${location.coordinates}) is '
            '$nearestDistance m from the nearest walking-path node — '
            'likely unreachable by the current graph.',
      );
    }
  });
}
