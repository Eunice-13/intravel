import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/itinerary_model.dart';
import '../models/location_model.dart';
import '../models/route_model.dart';
import 'location_service.dart';

/// A system-generated candidate itinerary for a curated route (addendum
/// spec 3.4): a themed, roughly duration-matched sequence of qualifying
/// sites the user can review and save. Not persisted on its own — saving
/// converts it into a normal [ItineraryModel] via
/// [ItineraryService.createItinerary].
class PlanOption {
  final String label;
  final List<LocationModel> stops;
  final double hours;

  const PlanOption({
    required this.label,
    required this.stops,
    required this.hours,
  });
}

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

  // ─── Curated-route plan generation (addendum spec 3.4) ─────────────────────

  /// Average minutes budgeted per stop when sizing how many stops a
  /// generated plan option should have for a route's target duration.
  static const int _avgMinutesPerSite = 45;

  /// Sites that qualify for [route]'s theme: matching one of its
  /// [CuratedRoute.qualifyingCategories], and — if set — no more expensive
  /// than [CuratedRoute.maxPerPersonBudget] per person.
  List<LocationModel> qualifyingSitesForRoute(CuratedRoute route) {
    if (route.qualifyingCategories.isEmpty) return const [];
    final allSites = LocationService().getAllLocations();
    return allSites.where((site) {
      final matchesCategory = route.qualifyingCategories.contains(
        site.category,
      );
      final withinCap =
          route.maxPerPersonBudget == null ||
          site.budgetRange.max <= route.maxPerPersonBudget!;
      return matchesCategory && withinCap;
    }).toList();
  }

  /// Generates a set of distinct, roughly duration-matched [PlanOption]s
  /// for [route], built from its qualifying sites. The number of options
  /// scales with how many qualifying sites exist — no fixed count is
  /// forced, per the addendum's explicit guidance (spec 3.4).
  List<PlanOption> buildPlanOptions(CuratedRoute route) {
    final sites = qualifyingSitesForRoute(route);
    if (sites.length < 2) return const [];

<<<<<<< HEAD
    final targetCount = ((route.hours * 60) / _avgMinutesPerSite)
        .round()
        .clamp(2, sites.length);
=======
    final targetCount = ((route.hours * 60) / _avgMinutesPerSite).round().clamp(
      2,
      sites.length,
    );
>>>>>>> 1bf5e9873516450c381783a752bdee7f035f10a7
    final stopsPerOption = targetCount.clamp(2, sites.length);
    final optionCount = (sites.length / stopsPerOption).ceil().clamp(1, 4);

    final options = <PlanOption>[];
    for (var optionIndex = 0; optionIndex < optionCount; optionIndex++) {
      final stops = <LocationModel>[];
      for (var stopIndex = 0; stopIndex < stopsPerOption; stopIndex++) {
        final site =
            sites[(optionIndex * stopsPerOption + stopIndex) % sites.length];
        if (!stops.any((s) => s.id == site.id)) stops.add(site);
      }
      if (stops.length < 2) continue;
      options.add(
        PlanOption(
          label: 'Option ${optionIndex + 1}',
          stops: stops,
          hours: route.hours,
        ),
      );
    }

    if (options.isEmpty) {
      final fallbackStops = sites.take(4).toList();
      return [
        PlanOption(label: 'Option 1', stops: fallbackStops, hours: route.hours),
      ];
    }
    return options;
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
      // Strict `<` (not `<=`) is intentional: on a tie, the first-encountered
      // stop in `remaining`'s current order wins, so ties resolve stably by
      // list order instead of flip-flopping between runs.
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
