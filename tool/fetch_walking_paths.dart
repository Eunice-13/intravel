// ignore_for_file: avoid_print
//
// One-time Overpass API fetch utility for the app's shared walking-path
// graph (assets/data/walking_paths.json).
//
// Queries the Overpass API for every pedestrian-usable way (footways,
// pedestrian streets, paths, steps, and the low-traffic
// residential/service/tertiary/secondary roads that make up Intramuros'
// actual street grid) within the Intramuros bounding box, and rewrites
// them into a routable node/edge graph.
//
// This replaces the previous ~10-node hand-authored approximation, which
// had drifted out of sync with real landmark coordinates and produced
// routes that cut through non-walkable areas (including across the Pasig
// River) because it had no real path data for most of the district.
//
// This is a *build-time* tool only — the app itself never calls Overpass
// at runtime (matching the existing tool/fetch_pois.dart's own stated
// reliability requirement; see lib/services/walking_path_service.dart,
// which only ever reads the committed asset). Run it manually whenever
// the path graph needs refreshing:
//
//   dart run tool/fetch_walking_paths.dart
//
// Every OSM way node becomes a graph node (each intersection/point along
// a path is preserved, not simplified away), so the resulting route lines
// actually trace the real pedestrian network — turning corners, following
// sidewalks and plaza paths — instead of a small number of long straight
// hops between a handful of named landmarks.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Intramuros bounding box: south, west, north, east — same box already
/// used by tool/fetch_pois.dart, matching the district's actual extent.
const double _south = 14.583;
const double _west = 120.970;
const double _north = 14.596;
const double _east = 120.980;

const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

const String _outputPath = 'assets/data/walking_paths.json';

/// OSM highway tag values treated as walkable for this district. Includes
/// the low-traffic road classes (`residential`, `service`, `tertiary`,
/// `secondary`, `unclassified`) alongside the obviously-pedestrian ones,
/// since Intramuros' actual street grid mixes foot traffic with the
/// district's own light vehicle roads (kalesa/tranvia/pedicab routes,
/// per addendum spec Section 6) rather than having fully separated
/// footpaths everywhere.
const Set<String> _walkableHighwayTags = {
  'footway',
  'pedestrian',
  'path',
  'living_street',
  'residential',
  'service',
  'steps',
  'tertiary',
  'secondary',
  'unclassified',
};

String _buildQuery() {
  final bbox = '$_south,$_west,$_north,$_east';
  final tagFilter = _walkableHighwayTags.join('|');
  return '''
[out:json][timeout:60];
(
  way["highway"~"^($tagFilter)\$"]($bbox);
);
(._;>;);
out body;
''';
}

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

Future<void> main() async {
  final query = _buildQuery();
  print(
    'Querying Overpass API for Intramuros pedestrian network bbox: '
    '$_south,$_west,$_north,$_east ...',
  );

  final client = HttpClient();
  Map<String, dynamic> decoded;
  try {
    final request = await client.postUrl(Uri.parse(_overpassUrl));
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'intravel-hackathon-walking-paths-fetch/1.0 (build-time tool; contact: n/a)',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close();

    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      stderr.writeln(
        'Overpass request failed with status ${response.statusCode}: $body',
      );
      exitCode = 1;
      return;
    }

    final body = await response.transform(utf8.decoder).join();
    decoded = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Overpass request failed: $e');
    exitCode = 1;
    return;
  } finally {
    client.close();
  }

  final elements = (decoded['elements'] as List).cast<Map<String, dynamic>>();
  print('Fetched ${elements.length} raw elements.');

  // OSM nodes referenced by the fetched ways (coordinates), and the ways
  // themselves (ordered lists of node ids) — `out body` returns both node
  // and way elements together.
  final nodeCoordsById = <int, (double, double)>{};
  final ways = <Map<String, dynamic>>[];
  for (final element in elements) {
    final type = element['type'] as String;
    if (type == 'node') {
      final id = element['id'] as int;
      final lat = (element['lat'] as num).toDouble();
      final lng = (element['lon'] as num).toDouble();
      nodeCoordsById[id] = (lat, lng);
    } else if (type == 'way') {
      final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final highway = tags['highway'] as String?;
      if (highway == null || !_walkableHighwayTags.contains(highway)) {
        continue;
      }
      ways.add(element);
    }
  }
  print(
    'Resolved ${nodeCoordsById.length} node coordinates across '
    '${ways.length} walkable ways.',
  );

  // Every OSM node actually used by a walkable way becomes a graph node
  // (preserving the real path shape — intersections and bends — instead
  // of collapsing a way down to just its two endpoints), and each
  // consecutive pair along a way becomes a graph edge.
  final usedNodeIds = <int>{};
  final segments = <(int, int)>[];
  for (final way in ways) {
    final wayName = (way['tags'] as Map?)?['name'] as String?;
    final nodeIds = (way['nodes'] as List).cast<int>();
    for (var i = 0; i < nodeIds.length - 1; i++) {
      final fromId = nodeIds[i];
      final toId = nodeIds[i + 1];
      if (!nodeCoordsById.containsKey(fromId) ||
          !nodeCoordsById.containsKey(toId)) {
        continue;
      }
      usedNodeIds.add(fromId);
      usedNodeIds.add(toId);
      segments.add((fromId, toId));
    }
    if (wayName != null) {
      // Node ids belonging to a named way are tracked separately below so
      // the resulting node can carry that name for the app's "current
      // street" proxy (see WalkingPathService.nearestLandmarkTo) —
      // handled in the naming pass further down.
    }
  }
  print(
    '${usedNodeIds.length} distinct path-graph nodes, '
    '${segments.length} edges.',
  );

  // Assign a human-readable name to each node: the name of first named way
  // it participates in, or a generic "Path node" fallback — this powers
  // the turn-by-turn view's nearest-landmark "current street" proxy
  // (addendum spec Section 1) with real street names instead of only the
  // original handful of named landmarks.
  final nameByNodeId = <int, String>{};
  for (final way in ways) {
    final wayName = (way['tags'] as Map?)?['name'] as String?;
    if (wayName == null) continue;
    final nodeIds = (way['nodes'] as List).cast<int>();
    for (final nodeId in nodeIds) {
      nameByNodeId.putIfAbsent(nodeId, () => wayName);
    }
  }

  final sortedNodeIds = usedNodeIds.toList()..sort();
  final nodeIdToGraphId = <int, String>{
    for (final id in sortedNodeIds) id: 'osm-$id',
  };

  final nodesJson = sortedNodeIds.map((id) {
    final (lat, lng) = nodeCoordsById[id]!;
    return {
      'id': nodeIdToGraphId[id],
      'name': nameByNodeId[id] ?? 'Path node',
      'kind': 'path',
      'lat': lat,
      'lng': lng,
    };
  }).toList();

  // De-duplicate edges (a node pair can appear more than once across
  // overlapping ways) and drop zero-length or implausibly long single
  // segments (a sign of a data artifact, e.g. a way that jumps across a
  // gap Overpass still connected) — mirrors the audit fix already applied
  // by hand to the previous small graph, generalized here to the full
  // fetched network.
  const maxSegmentMeters = 150.0;
  final seenPairs = <String>{};
  final segmentsJson = <Map<String, dynamic>>[];
  for (final (fromId, toId) in segments) {
    final key = fromId < toId ? '$fromId-$toId' : '$toId-$fromId';
    if (seenPairs.contains(key)) continue;
    seenPairs.add(key);

    final (fromLat, fromLng) = nodeCoordsById[fromId]!;
    final (toLat, toLng) = nodeCoordsById[toId]!;
    final distance = _haversineMeters(fromLat, fromLng, toLat, toLng);
    if (distance <= 0 || distance > maxSegmentMeters) continue;

    segmentsJson.add({
      'from': nodeIdToGraphId[fromId],
      'to': nodeIdToGraphId[toId],
    });
  }
  print('${segmentsJson.length} de-duplicated, distance-sane edges.');

  final output = {
    '_comment':
        'Shared static walking-path graph for Intramuros, loaded '
            'identically by the Flutter app (lib/screens/navigation_screen.dart '
            'via lib/services/walking_path_service.dart) and the HTML/JS '
            'dashboard (assets/intravel/index.html). Fetched from OpenStreetMap '
            'via the Overpass API by tool/fetch_walking_paths.dart (never '
            'fetched live at runtime -- see the reliability requirement noted '
            'in walking_path_service.dart) and covers every footway, '
            'pedestrian street, path, steps, and low-traffic road within the '
            'Intramuros bounding box below. Every OSM way node is preserved '
            'as its own graph node so route lines follow the real pedestrian '
            'network (turning at actual intersections/bends) rather than a '
            'small number of long straight hops between named landmarks, as '
            'the previous hand-authored ~10-node version did.',
    '_auditNote':
        '2026-08: replaced the previous hand-authored ~10-node graph after '
            'an audit found landmark node coordinates had silently drifted '
            'out of sync with lib/services/location_service.dart (up to '
            '~430m off in one case), producing routes that cut through '
            'non-walkable areas including across the Pasig River. This '
            'OSM-sourced graph is regenerated by running '
            '`dart run tool/fetch_walking_paths.dart`; re-run it if the '
            'district\'s OSM data improves or the bounding box needs to '
            'change. Segments longer than ${maxSegmentMeters.toInt()}m are '
            'dropped as likely data artifacts.',
    'version': 2,
    'generatedAt': DateTime.now().toIso8601String(),
    'bbox': {'south': _south, 'west': _west, 'north': _north, 'east': _east},
    'nodes': nodesJson,
    'segments': segmentsJson,
  };

  final outputFile = File(_outputPath);
  outputFile.parent.createSync(recursive: true);
  final encoder = JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync(encoder.convert(output));
  print(
    'Wrote ${nodesJson.length} nodes and ${segmentsJson.length} edges to '
    '$_outputPath',
  );
}
