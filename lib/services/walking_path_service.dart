import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// A named point in the shared static walking-path graph (a gate or major
/// landmark with verified coordinates).
class WalkingPathNode {
  final String id;
  final String name;
  final String kind;
  final LatLng coordinates;

  const WalkingPathNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.coordinates,
  });
}

/// Loads and queries the shared static walking-path graph defined in
/// `assets/data/walking_paths.json` — the same file the HTML/JS dashboard
/// (assets/intravel/index.html) reads, so both platforms draw from one
/// hand-authored source instead of two independently maintained copies.
///
/// This models straight walkable segments between a small set of gates and
/// major landmarks (see the JSON file's own `_comment` field for scope and
/// sourcing notes) — a reasonable approximation for Intramuros' small, fixed
/// walking area, not a live-routed path. Any two nodes not directly
/// connected are reached by walking the shortest hop-chain through the
/// graph; a start/end point that isn't in the graph at all falls back to a
/// direct straight line, matching the app's existing behavior before this
/// graph was added.
class WalkingPathService {
  static final WalkingPathService _instance = WalkingPathService._internal();
  factory WalkingPathService() => _instance;
  WalkingPathService._internal();

  static const String _assetPath = 'assets/data/walking_paths.json';

  List<WalkingPathNode>? _nodes;
  Map<String, Set<String>>? _adjacency;
  bool _loadFailed = false;

  /// Loads and parses the shared JSON graph once. Safe to call repeatedly;
  /// subsequent calls are no-ops once loaded (or once loading has failed).
  Future<void> ensureLoaded() async {
    if (_nodes != null || _loadFailed) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final nodesJson = (parsed['nodes'] as List).cast<Map<String, dynamic>>();
      final segmentsJson = (parsed['segments'] as List)
          .cast<Map<String, dynamic>>();

      final nodes = nodesJson
          .map(
            (n) => WalkingPathNode(
              id: n['id'] as String,
              name: n['name'] as String,
              kind: n['kind'] as String,
              coordinates: LatLng(
                (n['lat'] as num).toDouble(),
                (n['lng'] as num).toDouble(),
              ),
            ),
          )
          .toList();

      final adjacency = <String, Set<String>>{};
      for (final node in nodes) {
        adjacency[node.id] = <String>{};
      }
      for (final segment in segmentsJson) {
        final from = segment['from'] as String;
        final to = segment['to'] as String;
        adjacency.putIfAbsent(from, () => <String>{}).add(to);
        adjacency.putIfAbsent(to, () => <String>{}).add(from);
      }

      _nodes = nodes;
      _adjacency = adjacency;
    } catch (_) {
      // Missing/malformed asset: leave `_nodes` null so callers fall back to
      // a direct straight line instead of throwing.
      _loadFailed = true;
    }
  }

  WalkingPathNode? _nearestNodeTo(LatLng point, {double maxMeters = 60}) {
    final nodes = _nodes;
    if (nodes == null || nodes.isEmpty) return null;
    WalkingPathNode? nearest;
    var nearestDistance = double.infinity;
    for (final node in nodes) {
      final distance = _distanceMeters(point, node.coordinates);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = node;
      }
    }
    if (nearest == null || nearestDistance > maxMeters) return null;
    return nearest;
  }

  /// Returns an ordered list of waypoints (as [LatLng]) tracing the shared
  /// walkable graph from [start] to [end], via a breadth-first shortest hop
  /// path between whichever graph nodes are closest to each endpoint.
  ///
  /// Returns `null` if the graph isn't loaded, or if either endpoint isn't
  /// near any known node — callers should fall back to a direct line in
  /// that case, exactly as the app already did before this graph existed.
  List<LatLng>? findPath(LatLng start, LatLng end) {
    final nodes = _nodes;
    final adjacency = _adjacency;
    if (nodes == null || adjacency == null) return null;

    final startNode = _nearestNodeTo(start);
    final endNode = _nearestNodeTo(end);
    if (startNode == null || endNode == null) return null;

    if (startNode.id == endNode.id) {
      return [start, startNode.coordinates, end];
    }

    // Breadth-first search for the shortest hop-count path between the two
    // nearest graph nodes — the graph is small (single-digit nodes), so BFS
    // is more than sufficient and keeps this dependency-free.
    final visited = <String>{startNode.id};
    final queue = <List<String>>[
      [startNode.id],
    ];
    List<String>? hopPath;
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;
      if (current == endNode.id) {
        hopPath = path;
        break;
      }
      for (final neighbor in adjacency[current] ?? const <String>{}) {
        if (visited.contains(neighbor)) continue;
        visited.add(neighbor);
        queue.add([...path, neighbor]);
      }
    }
    if (hopPath == null) return null;

    final nodeById = {for (final n in nodes) n.id: n};
    final waypoints = <LatLng>[start];
    for (final id in hopPath) {
      waypoints.add(nodeById[id]!.coordinates);
    }
    waypoints.add(end);
    return waypoints;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const metersPerDegreeLat = 111320.0;
    final avgLatRad = (a.latitude + b.latitude) / 2 * (math.pi / 180);
    final metersPerDegreeLng = 111320.0 * math.cos(avgLatRad);
    final dy = (a.latitude - b.latitude) * metersPerDegreeLat;
    final dx = (a.longitude - b.longitude) * metersPerDegreeLng;
    return math.sqrt(dx * dx + dy * dy);
  }
}
