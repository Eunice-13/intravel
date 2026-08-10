import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/itinerary_model.dart';
import '../models/location_model.dart';
import 'location_service.dart';

/// Persists user-created itineraries (spec Section 3.3-3.5): CRUD
/// operations plus nearest-neighbor route sequencing from a given starting
/// position. Mirrors [SavedPlacesService]'s ChangeNotifier +
/// SharedPreferences persistence pattern used elsewhere in this app.
class ItineraryService extends ChangeNotifier {
  static final ItineraryService instance = ItineraryService._internal();
  ItineraryService._internal();

  static const String _storageKey = 'intravel.itineraries.v1';

  List<ItineraryModel> _itineraries = [];
  bool _isLoaded = false;

  List<ItineraryModel> get itineraries => List.unmodifiable(_itineraries);

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final decoded = jsonDecode(stored) as List;
        _itineraries = decoded
            .map((e) => ItineraryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Keep an empty list if persistence is unavailable or corrupted.
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_itineraries.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  ItineraryModel? getById(String id) {
    final matches = _itineraries.where((i) => i.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Creates a new itinerary with the given name and initial set of
  /// location IDs, and persists it.
  Future<ItineraryModel> createItinerary({
    required String name,
    required List<String> locationIds,
  }) async {
    final itinerary = ItineraryModel(
      id: 'itin-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      locationIds: locationIds,
      createdAt: DateTime.now(),
    );
    _itineraries.add(itinerary);
    notifyListeners();
    await _persist();
    return itinerary;
  }

  Future<void> renameItinerary(String id, String newName) async {
    _updateItinerary(id, (i) => i.copyWith(name: newName));
    await _persist();
  }

  Future<void> deleteItinerary(String id) async {
    _itineraries.removeWhere((i) => i.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> addLocation(String itineraryId, String locationId) async {
    _updateItinerary(itineraryId, (i) {
      if (i.locationIds.contains(locationId)) return i;
      return i.copyWith(locationIds: [...i.locationIds, locationId]);
    });
    await _persist();
  }

  Future<void> removeLocation(String itineraryId, String locationId) async {
    _updateItinerary(
      itineraryId,
      (i) => i.copyWith(
        locationIds: i.locationIds.where((id) => id != locationId).toList(),
      ),
    );
    await _persist();
  }

  /// Manually reorders a stop within an itinerary by moving the item at
  /// [oldIndex] to [newIndex] (spec 3.5 — manual reordering in addition to
  /// the auto-suggested nearest-neighbor order).
  Future<void> reorderLocation(
    String itineraryId,
    int oldIndex,
    int newIndex,
  ) async {
    _updateItinerary(itineraryId, (i) {
      final ids = [...i.locationIds];
      final item = ids.removeAt(oldIndex);
      ids.insert(newIndex, item);
      return i.copyWith(locationIds: ids);
    });
    await _persist();
  }

  Future<void> setLocationOrder(
    String itineraryId,
    List<String> newOrder,
  ) async {
    _updateItinerary(itineraryId, (i) => i.copyWith(locationIds: newOrder));
    await _persist();
  }

  void _updateItinerary(
    String id,
    ItineraryModel Function(ItineraryModel) update,
  ) {
    final index = _itineraries.indexWhere((i) => i.id == id);
    if (index == -1) return;
    _itineraries[index] = update(_itineraries[index]);
    notifyListeners();
  }

  // ─── Nearest-neighbor route sequencing (spec 3.4) ──────────────────────────

  /// Attempts to read the device's current GPS position. Returns `null` if
  /// location services/permissions are unavailable, letting callers fall
  /// back to sequencing from the first stop instead.
  Future<LatLng?> resolveCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Produces a nearest-neighbor-ordered list of [LocationModel]s for the
  /// given itinerary, starting from whichever saved stop is nearest to
  /// [startPosition], then always continuing to the next-nearest unvisited
  /// stop until all locations are ordered (spec 3.4). This is a heuristic
  /// approximation, not a guaranteed shortest overall path — true optimal
  /// multi-stop routing is a traveling-salesman-style problem out of scope
  /// here, as the spec explicitly acknowledges.
  List<LocationModel> sequenceByNearestNeighbor(
    ItineraryModel itinerary,
    LatLng startPosition,
  ) {
    final remaining = itinerary.locationIds
        .map((id) {
          try {
            return LocationService().getLocationById(id);
          } catch (_) {
            return null;
          }
        })
        .whereType<LocationModel>()
        .toList();

    final ordered = <LocationModel>[];
    var currentPoint = startPosition;

    while (remaining.isNotEmpty) {
      var nearestIndex = 0;
      var nearestDistance = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final distance = Geolocator.distanceBetween(
          currentPoint.latitude,
          currentPoint.longitude,
          remaining[i].coordinates.latitude,
          remaining[i].coordinates.longitude,
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }
      final nearest = remaining.removeAt(nearestIndex);
      ordered.add(nearest);
      currentPoint = nearest.coordinates;
    }

    return ordered;
  }

  /// Convenience list of resolved [LocationModel]s in the itinerary's
  /// currently-saved order (manual order, or whatever order was last set),
  /// without recomputing nearest-neighbor sequencing.
  List<LocationModel> resolveLocations(ItineraryModel itinerary) {
    return itinerary.locationIds
        .map((id) {
          try {
            return LocationService().getLocationById(id);
          } catch (_) {
            return null;
          }
        })
        .whereType<LocationModel>()
        .toList();
  }
}
