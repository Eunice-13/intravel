import 'package:latlong2/latlong.dart';

/// Category of a [Poi], derived from the OSM tag it was sourced from
/// (see the Overpass query in `tool/fetch_pois.dart`). Distinct from
/// [LocationModel.category] used elsewhere in the app — this is scoped to
/// the standalone OSM POI map demo (`OsmPoiMapScreen`) only.
enum PoiCategory { school, church, attraction, historic }

extension PoiCategoryX on PoiCategory {
  /// Human-readable label shown in the info bottom sheet.
  String get label {
    switch (this) {
      case PoiCategory.school:
        return 'School';
      case PoiCategory.church:
        return 'Place of Worship';
      case PoiCategory.attraction:
        return 'Attraction';
      case PoiCategory.historic:
        return 'Historic Site';
    }
  }

  static PoiCategory fromJson(String value) {
    switch (value) {
      case 'school':
        return PoiCategory.school;
      case 'church':
        return PoiCategory.church;
      case 'attraction':
        return PoiCategory.attraction;
      case 'historic':
        return PoiCategory.historic;
      default:
        throw ArgumentError('Unknown POI category: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PoiCategory.school:
        return 'school';
      case PoiCategory.church:
        return 'church';
      case PoiCategory.attraction:
        return 'attraction';
      case PoiCategory.historic:
        return 'historic';
    }
  }
}

/// A point of interest sourced from OpenStreetMap via the Overpass API and
/// persisted to `assets/data/pois.json` (see `tool/fetch_pois.dart`).
///
/// OSM does not provide photos, so [photoPath] is a manually curated asset
/// path or network URL paired in afterward when building the JSON file —
/// it is never populated from Overpass itself.
class Poi {
  final String id;
  final String name;
  final PoiCategory category;
  final LatLng coordinates;
  final String photoPath;

  /// True if [photoPath] is a network URL (`http`/`https`) rather than a
  /// bundled asset path, so the UI knows whether to use `Image.network` or
  /// `Image.asset`.
  bool get isNetworkPhoto =>
      photoPath.startsWith('http://') || photoPath.startsWith('https://');

  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.coordinates,
    required this.photoPath,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'] as String,
      name: json['name'] as String,
      category: PoiCategoryX.fromJson(json['category'] as String),
      coordinates: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      photoPath: json['photoPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.toJson(),
    'lat': coordinates.latitude,
    'lng': coordinates.longitude,
    'photoPath': photoPath,
  };
}
