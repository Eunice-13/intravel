/// A user-created itinerary: a named, ordered list of location IDs (spec
/// Section 3.3-3.5). Stop order is either the user's manual arrangement or
/// the nearest-neighbor auto-suggested order computed by
/// `ItineraryService.sequenceByNearestNeighbor`.
class ItineraryModel {
  final String id;
  final String name;
  final List<String> locationIds;
  final DateTime createdAt;

  const ItineraryModel({
    required this.id,
    required this.name,
    required this.locationIds,
    required this.createdAt,
  });

  ItineraryModel copyWith({
    String? name,
    List<String>? locationIds,
  }) {
    return ItineraryModel(
      id: id,
      name: name ?? this.name,
      locationIds: locationIds ?? this.locationIds,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locationIds': locationIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      locationIds: (json['locationIds'] as List).cast<String>(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
