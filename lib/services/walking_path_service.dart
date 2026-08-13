import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

/// Result of projecting a point onto the nearest walkable edge: which two
/// nodes that edge connects, and the exact projected point along it.
class _EdgeSnap {
  final String fromId;
  final String toId;
  final LatLng projected;

  const _EdgeSnap({
    required this.fromId,
    required this.toId,
    required this.projected,
  });
}

/// Where a real-world point (route start/end) actually enters the shared
/// walking-path graph: either exactly at a node, or projected onto an
/// edge between two nodes. [bracketNodeIds] is what pathfinding searches
/// from/to — a single node when snapped to a node, or both endpoints of
/// the edge when snapped onto one (since the true shortest route could
/// reasonably travel via either end of that edge).
class _GraphEntry {
  final LatLng point;
  final List<String> bracketNodeIds;

  const _GraphEntry._(this.point, this.bracketNodeIds);

  factory _GraphEntry.atNode(WalkingPathNode node) =>
      _GraphEntry._(node.coordinates, [node.id]);

  factory _GraphEntry.onEdge(_EdgeSnap edge) =>
      _GraphEntry._(edge.projected, [edge.fromId, edge.toId]);
}

/// Loads and queries the shared static walking-path graph defined in
/// `assets/data/walking_paths.json` — the same file the HTML/JS dashboard
/// (assets/intravel/index.html) reads, so both platforms draw from one
/// hand-authored source instead of two independently maintained copies.
///
/// This models straight walkable segments between a small set of gates and
/// major landmarks (see the JSON file's own `_comment` field for scope and
/// sourcing notes) — a reasonable approximation for Intramuros' small, fixed
/// walking area, not a live-routed path.
///
/// Entry into the graph is resolved by snapping to either the nearest
/// *node* (when a point is essentially standing at a landmark) or, more
/// commonly, the nearest *edge* — the point is projected onto the closest
/// walkable segment and enters the graph from there. Edge-snapping matters
/// because most real start/end points (most tourist sites, and most live
/// GPS fixes) aren't within a few meters of one of the graph's handful of
/// named nodes, but they usually *are* reasonably close to one of the
/// walkway segments connecting those nodes — snapping only to node centers
/// caused routes to fall back to a straight line far more often than
/// necessary, including lines that cut straight through walls/buildings
/// with no real path between them. Only when a point is too far from
/// every node *and* every edge (i.e. genuinely outside the graph's
/// covered area) does this fall back to a direct straight line, matching
/// the app's original behavior before this graph was added.
class WalkingPathService {
  static final WalkingPathService _instance = WalkingPathService._internal();
  factory WalkingPathService() => _instance;
  WalkingPathService._internal();

  static const String _assetPath = 'assets/data/walking_paths.json';

  List<WalkingPathNode>? _nodes;
  Map<String, Set<String>>? _adjacency;

  /// Every walkable segment as a pair of node IDs, kept alongside
  /// [_adjacency] so [_nearestEdgeTo] can project a point onto each
  /// segment individually (adjacency alone only tells you *that* two
  /// nodes connect, not the geometry of the segment between them).
  List<(String, String)>? _edges;

  /// Real-world segment length in meters, keyed the same way as
  /// [_adjacency] (`fromId -> {toId: meters}`) — used to weight
  /// pathfinding by actual distance instead of hop count. With the small
  /// ~10-node hand-authored graph this used to be, hop count and distance
  /// were roughly interchangeable; with the denser OSM-sourced graph
  /// (thousands of unevenly-spaced nodes), an unweighted BFS could easily
  /// prefer a route with fewer-but-longer edges over a genuinely shorter
  /// one, so this is now load-bearing for producing an accurate route.
  Map<String, Map<String, double>>? _edgeWeights;
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

      final nodeById = {for (final n in nodes) n.id: n};
      final adjacency = <String, Set<String>>{};
      final weights = <String, Map<String, double>>{};
      for (final node in nodes) {
        adjacency[node.id] = <String>{};
        weights[node.id] = <String, double>{};
      }
      final edges = <(String, String)>[];
      for (final segment in segmentsJson) {
        final from = segment['from'] as String;
        final to = segment['to'] as String;
        final fromNode = nodeById[from];
        final toNode = nodeById[to];
        if (fromNode == null || toNode == null) continue;
        final distance = _distanceMeters(
          fromNode.coordinates,
          toNode.coordinates,
        );
        adjacency.putIfAbsent(from, () => <String>{}).add(to);
        adjacency.putIfAbsent(to, () => <String>{}).add(from);
        weights.putIfAbsent(from, () => <String, double>{})[to] = distance;
        weights.putIfAbsent(to, () => <String, double>{})[from] = distance;
        edges.add((from, to));
      }

      _nodes = nodes;
      _adjacency = adjacency;
      _edgeWeights = weights;
      _edges = edges;
    } catch (_) {
      // Missing/malformed asset: leave `_nodes` null so callers fall back to
      // a direct straight line instead of throwing.
      _loadFailed = true;
    }
  }

  /// Finds the nearest walking-path node/landmark to [point], used as a
  /// "current street" proxy for turn-by-turn navigation (addendum spec
  /// Section 1): this app has no street/road dataset, so the nearest
  /// named gate/landmark is shown instead (e.g. "Near Fort Santiago").
  /// Returns `null` if the graph isn't loaded or nothing is within
  /// [maxMeters] — a wider radius than path-snapping's default since this
  /// is a rough proxy, not exact-position matching.
  WalkingPathNode? nearestLandmarkTo(LatLng point, {double maxMeters = 150}) {
    return _nearestNodeTo(point, maxMeters: maxMeters);
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

  /// Finds the closest point of approach onto any walkable *edge* (not
  /// just node centers), by projecting [point] onto each segment and
  /// keeping whichever projection is nearest — this is what lets a point
  /// standing anywhere along a walkway (not just at one of its two named
  /// endpoints) actually enter the graph. Returns `null` if the graph
  /// isn't loaded or [point] is farther than [maxMeters] from every edge.
  _EdgeSnap? _nearestEdgeTo(LatLng point, {double maxMeters = 90}) {
    final nodes = _nodes;
    final edges = _edges;
    if (nodes == null || edges == null || edges.isEmpty) return null;
    final nodeById = {for (final n in nodes) n.id: n};

    _EdgeSnap? nearest;
    var nearestDistance = double.infinity;
    for (final edge in edges) {
      final from = nodeById[edge.$1];
      final to = nodeById[edge.$2];
      if (from == null || to == null) continue;
      final projection = _projectOntoSegment(
        point,
        from.coordinates,
        to.coordinates,
      );
      final distance = _distanceMeters(point, projection);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = _EdgeSnap(
          fromId: edge.$1,
          toId: edge.$2,
          projected: projection,
        );
      }
    }
    if (nearest == null || nearestDistance > maxMeters) return null;
    return nearest;
  }

  /// Projects [point] onto the segment between [segmentStart] and
  /// [segmentEnd] using the same equirectangular local-plane
  /// approximation as the perpendicular-distance math already used
  /// elsewhere in navigation (accurate enough at Intramuros' small,
  /// ~1km-wide scale), clamped to the segment itself so the projection
  /// never lands past either endpoint.
  LatLng _projectOntoSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    const metersPerDegreeLat = 111320.0;
    final avgLatRad =
        (segmentStart.latitude + segmentEnd.latitude) / 2 * (math.pi / 180);
    final metersPerDegreeLng = 111320.0 * math.cos(avgLatRad);

    final dx =
        (segmentEnd.longitude - segmentStart.longitude) * metersPerDegreeLng;
    final dy =
        (segmentEnd.latitude - segmentStart.latitude) * metersPerDegreeLat;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return segmentStart;

    final px = (point.longitude - segmentStart.longitude) * metersPerDegreeLng;
    final py = (point.latitude - segmentStart.latitude) * metersPerDegreeLat;
    var t = (px * dx + py * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);

    return LatLng(
      segmentStart.latitude + (t * dy) / metersPerDegreeLat,
      segmentStart.longitude + (t * dx) / metersPerDegreeLng,
    );
  }

  /// Resolves how [point] enters the graph: as a specific point along an
  /// edge (preferred — see [_nearestEdgeTo]'s doc for why), falling back
  /// to snapping directly to a node if it happens to be extremely close
  /// to one already. Returns `null` if [point] is too far from the
  /// graph's covered area entirely.
  _GraphEntry? _resolveEntry(LatLng point) {
    final edgeSnap = _nearestEdgeTo(point);
    final nodeSnap = _nearestNodeTo(point);
    if (edgeSnap == null && nodeSnap == null) return null;
    if (edgeSnap == null) {
      return _GraphEntry.atNode(nodeSnap!);
    }
    if (nodeSnap != null) {
      // Prefer an exact node hit only when it's genuinely closer than the
      // best edge projection (e.g. standing right at a landmark).
      final nodeDistance = _distanceMeters(point, nodeSnap.coordinates);
      final edgeDistance = _distanceMeters(point, edgeSnap.projected);
      if (nodeDistance <= edgeDistance) {
        return _GraphEntry.atNode(nodeSnap);
      }
    }
    return _GraphEntry.onEdge(edgeSnap);
  }

  /// Returns an ordered list of waypoints (as [LatLng]) tracing the shared
  /// walkable graph from [start] to [end]. Each endpoint is snapped onto
  /// whichever edge or node it's actually closest to (see
  /// [_resolveEntry]), then a breadth-first shortest hop path is found
  /// between the graph nodes bracketing each entry point, and the two
  /// edge-projected points are spliced onto the ends of that hop chain so
  /// the rendered line starts/ends at [start]/[end] exactly.
  ///
  /// Returns `null` if the graph isn't loaded, or if either endpoint is
  /// too far from every node *and* every edge — callers should fall back
  /// to a direct line in that case, exactly as the app already did before
  /// this graph existed.
  List<LatLng>? findPath(LatLng start, LatLng end) {
    final nodes = _nodes;
    final adjacency = _adjacency;
    if (nodes == null || adjacency == null) return null;

    final startEntry = _resolveEntry(start);
    final endEntry = _resolveEntry(end);
    if (startEntry == null || endEntry == null) return null;

    final nodeById = {for (final n in nodes) n.id: n};

    // Both endpoints snapped onto the exact same node/edge: no graph
    // traversal needed, just connect through that shared geometry
    // directly (covers both "same node" and "same edge" cases without
    // needing to special-case them separately).
    final startBrackets = startEntry.bracketNodeIds.toSet();
    final endBrackets = endEntry.bracketNodeIds.toSet();
    if (startBrackets.length == endBrackets.length &&
        startBrackets.containsAll(endBrackets)) {
      return [start, startEntry.point, endEntry.point, end];
    }

    final hopPath = _shortestWeightedPath(
      startEntry.bracketNodeIds,
      endEntry.bracketNodeIds,
    );
    if (hopPath == null) return null;

    final waypoints = <LatLng>[start, startEntry.point];
    for (final id in hopPath) {
      waypoints.add(nodeById[id]!.coordinates);
    }
    waypoints.add(endEntry.point);
    waypoints.add(end);
    return waypoints;
  }

  /// Dijkstra shortest-*distance* path (not shortest hop-count) between
  /// any node in [sourceIds] and any node in [targetIds], using
  /// [_edgeWeights] as real-world segment lengths. Distance-weighting
  /// matters once the graph is dense and irregularly spaced (as the
  /// OSM-sourced network is) — an unweighted hop-count search could
  /// otherwise prefer a route through fewer-but-much-longer edges over a
  /// genuinely shorter one. Supports multiple sources/targets at once so
  /// an edge-snapped entry point (bracketed by both of that edge's
  /// endpoints) can search from/to either side without an artificial
  /// zero-cost node merge.
  List<String>? _shortestWeightedPath(
    List<String> sourceIds,
    List<String> targetIds,
  ) {
    final weights = _edgeWeights;
    if (weights == null) return null;
    final targets = targetIds.toSet();

    final distances = <String, double>{};
    final previous = <String, String>{};
    final visited = <String>{};

    // Simple array-backed priority queue is unnecessary for this graph's
    // size (thousands, not millions, of nodes) — a linear scan for the
    // minimum-distance unvisited node per iteration is fast enough here
    // and keeps this dependency-free, matching the rest of this service.
    final frontier = <String>{};
    for (final id in sourceIds) {
      distances[id] = 0;
      frontier.add(id);
    }

    while (frontier.isNotEmpty) {
      String? current;
      var currentDistance = double.infinity;
      for (final id in frontier) {
        final d = distances[id] ?? double.infinity;
        if (d < currentDistance) {
          currentDistance = d;
          current = id;
        }
      }
      if (current == null) break;
      frontier.remove(current);
      visited.add(current);

      if (targets.contains(current)) {
        final path = <String>[current];
        var node = current;
        while (previous.containsKey(node)) {
          node = previous[node]!;
          path.insert(0, node);
        }
        return path;
      }

      for (final entry
          in weights[current]?.entries ?? const <MapEntry<String, double>>[]) {
        final neighbor = entry.key;
        if (visited.contains(neighbor)) continue;
        final candidateDistance = currentDistance + entry.value;
        final existingDistance = distances[neighbor] ?? double.infinity;
        if (candidateDistance < existingDistance) {
          distances[neighbor] = candidateDistance;
          previous[neighbor] = current;
          frontier.add(neighbor);
        }
      }
    }
    return null;
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
