// ignore_for_file: avoid_print
//
// One-time Overpass API fetch utility for the OSM POI map demo.
//
// Queries the Overpass API for schools, places of worship, tourist
// attractions, and historic sites within the Intramuros bounding box, and
// writes the results to `assets/data/pois.json`.
//
// This is a *build-time* tool only — the app itself never calls Overpass
// at runtime (see `lib/services/poi_service.dart`), per the demo's
// reliability requirement. Run it manually whenever the POI set needs
// refreshing:
//
//   dart run tool/fetch_pois.dart
//
// Overpass returns raw OSM tags with no photos, so this script merges any
// existing `photoPath` values from the current `assets/data/pois.json`
// (matched by OSM id) into the newly fetched records, so re-running it
// doesn't wipe out manually curated photos. New POIs are written with an
// empty `photoPath` that must be filled in by hand afterward.
import 'dart:convert';
import 'dart:io';

/// Intramuros bounding box: south, west, north, east — derived from the
/// gate/landmark coordinates already used elsewhere in the app
/// (lib/services/gate_service.dart, assets/data/walking_paths.json).
const double _south = 14.583;
const double _west = 120.970;
const double _north = 14.596;
const double _east = 120.980;

const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

const String _outputPath = 'assets/data/pois.json';

/// Maps an OSM element's tags to a demo [PoiCategory]. Returns null if the
/// element doesn't match any of the tag combinations we care about.
String? _categoryForTags(Map<String, dynamic> tags) {
  if (tags['amenity'] == 'school') return 'school';
  if (tags['amenity'] == 'place_of_worship') return 'church';
  if (tags['tourism'] == 'attraction') return 'attraction';
  if (tags.containsKey('historic')) return 'historic';
  return null;
}

String _buildQuery() {
  final bbox = '$_south,$_west,$_north,$_east';
  return '''
[out:json][timeout:25];
(
  node["amenity"="school"]($bbox);
  way["amenity"="school"]($bbox);
  node["amenity"="place_of_worship"]($bbox);
  way["amenity"="place_of_worship"]($bbox);
  node["tourism"="attraction"]($bbox);
  way["tourism"="attraction"]($bbox);
  node["historic"]($bbox);
  way["historic"]($bbox);
);
out center tags;
''';
}

Future<void> main() async {
  final query = _buildQuery();
  print('Querying Overpass API for Intramuros bbox: '
      '$_south,$_west,$_north,$_east ...');

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
      'intravel-hackathon-poi-fetch/1.0 (build-time tool; contact: n/a)',
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

  // Load existing pois.json (if any) so we can preserve manually curated
  // photoPath values across re-runs, keyed by OSM id.
  final existingPhotosById = <String, String>{};
  final outputFile = File(_outputPath);
  if (outputFile.existsSync()) {
    try {
      final existing = jsonDecode(outputFile.readAsStringSync())
          as Map<String, dynamic>;
      final existingPois =
          (existing['pois'] as List).cast<Map<String, dynamic>>();
      for (final poi in existingPois) {
        final id = poi['id'] as String?;
        final photoPath = poi['photoPath'] as String?;
        if (id != null && photoPath != null && photoPath.isNotEmpty) {
          existingPhotosById[id] = photoPath;
        }
      }
    } catch (e) {
      stderr.writeln(
        'Warning: could not parse existing $_outputPath, photoPath values '
        'will not be preserved: $e',
      );
    }
  }

  final pois = <Map<String, dynamic>>[];
  for (final element in elements) {
    final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? {};
    final category = _categoryForTags(tags);
    if (category == null) continue;

    final name = tags['name'] as String? ?? 'Unnamed';
    final osmType = element['type'] as String; // node | way
    final osmId = element['id'];
    final id = '$osmType/$osmId';

    // Nodes have lat/lon directly; ways use the "center" field requested
    // via `out center`.
    double? lat;
    double? lng;
    if (element['lat'] != null && element['lon'] != null) {
      lat = (element['lat'] as num).toDouble();
      lng = (element['lon'] as num).toDouble();
    } else if (element['center'] != null) {
      final center = element['center'] as Map<String, dynamic>;
      lat = (center['lat'] as num).toDouble();
      lng = (center['lon'] as num).toDouble();
    }
    if (lat == null || lng == null) continue;

    pois.add({
      'id': id,
      'name': name,
      'category': category,
      'lat': lat,
      'lng': lng,
      'photoPath': existingPhotosById[id] ?? '',
    });
  }

  print('Mapped ${pois.length} POIs matching demo categories.');

  final missingPhotos = pois.where((p) => (p['photoPath'] as String).isEmpty);
  if (missingPhotos.isNotEmpty) {
    print(
      'Warning: ${missingPhotos.length} POI(s) have no photoPath set. '
      'Edit $_outputPath by hand to add a curated photo asset/URL for each.',
    );
  }

  final output = {
    '_comment':
        'OSM POIs for the Intramuros demo, fetched via Overpass API by '
            'tool/fetch_pois.dart. photoPath values are manually curated '
            '(OSM has no photo data) and preserved across re-runs by OSM id. '
            'Never fetched live at runtime -- see lib/services/poi_service.dart.',
    'generatedAt': DateTime.now().toIso8601String(),
    'bbox': {'south': _south, 'west': _west, 'north': _north, 'east': _east},
    'pois': pois,
  };

  outputFile.parent.createSync(recursive: true);
  final encoder = JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync(encoder.convert(output));
  print('Wrote ${pois.length} POIs to $_outputPath');
}
