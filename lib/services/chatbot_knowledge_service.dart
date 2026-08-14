import '../models/location_model.dart';
import '../models/gate_model.dart';
import '../models/itinerary_model.dart';
import 'location_service.dart';
import 'gate_service.dart';
import 'gate_selection_service.dart';
import 'itinerary_service.dart';

/// Read-only data-grounding facade for the IntraBadi assistant (chatbot
/// spec Section 3): "The assistant should draw its answers from the
/// app's own curated dataset (locations, gates, itinerary features,
/// budget data) ... not from live open-ended web search or general model
/// knowledge that could contradict what's actually in the app."
///
/// This wraps the app's existing data services ([LocationService],
/// [GateService], [GateSelectionService], [ItineraryService]) behind a
/// single query surface purpose-built for conversational lookups (fuzzy
/// name matching, category filters, "does this fact exist at all")
/// rather than duplicating or re-deriving any of that data. The
/// conversation engine should only ever go through here for facts, so an
/// answer about e.g. an entrance fee is always sourced from the exact
/// same place the Plans/details screens read it from.
class ChatbotKnowledgeService {
  ChatbotKnowledgeService({
    LocationService? locationService,
    GateService? gateService,
    GateSelectionService? gateSelectionService,
    ItineraryService? itineraryService,
  }) : _locationService = locationService ?? LocationService(),
       _gateService = gateService ?? GateService(),
       _gateSelectionService =
           gateSelectionService ?? GateSelectionService.instance,
       _itineraryService = itineraryService ?? ItineraryService.instance;

  final LocationService _locationService;
  final GateService _gateService;
  final GateSelectionService _gateSelectionService;
  final ItineraryService _itineraryService;

  // ─── Locations ──────────────────────────────────────────────────────────

  List<LocationModel> get allLocations => _locationService.getAllLocations();

  LocationModel? findLocationById(String id) {
    try {
      return _locationService.getLocationById(id);
    } catch (_) {
      return null;
    }
  }

  /// Best-effort fuzzy lookup by name for resolving a location mentioned
  /// in free-text chat (e.g. "fort santiago", "Fort Santiago!", "the fort
  /// santiago museum"). Matches on exact name, then substring either
  /// direction, case-insensitively. Returns `null` if nothing plausible
  /// is found rather than guessing.
  LocationModel? findLocationByName(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;

    final locations = allLocations;
    for (final loc in locations) {
      if (_normalize(loc.name) == normalized) return loc;
    }
    for (final loc in locations) {
      final locName = _normalize(loc.name);
      if (locName.contains(normalized) || normalized.contains(locName)) {
        return loc;
      }
    }
    return null;
  }

  /// All distinct category labels currently in the dataset (e.g.
  /// "Fortifications", "Museums", "Parks", "Landmarks", "Churches",
  /// "Schools") — used to validate/ground a "filter by category" action
  /// request against real categories instead of whatever the user typed.
  List<String> get allCategories =>
      allLocations.map((l) => l.category).toSet().toList();

  /// Case-insensitive match of [query] against a known category, e.g.
  /// "fortification" / "fortifications" -> "Fortifications". Returns
  /// `null` if it doesn't resolve to a real category in the dataset.
  String? resolveCategory(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;
    for (final category in allCategories) {
      final normalizedCategory = _normalize(category);
      if (normalizedCategory == normalized ||
          normalizedCategory == '${normalized}s' ||
          '${normalizedCategory}s' == normalized ||
          normalizedCategory.contains(normalized)) {
        return category;
      }
    }
    return null;
  }

  List<LocationModel> locationsInCategory(String category) {
    final normalized = _normalize(category);
    return allLocations
        .where((l) => _normalize(l.category) == normalized)
        .toList();
  }

  // ─── Gates ──────────────────────────────────────────────────────────────

  List<GateModel> get allGates => _gateService.getAllGates();

  GateModel? findGateById(String id) => _gateService.getGateById(id);

  GateModel? findGateByName(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;
    for (final gate in allGates) {
      final gateName = _normalize(gate.name);
      if (gateName == normalized ||
          gateName.contains(normalized) ||
          normalized.contains(gateName)) {
        return gate;
      }
    }
    return null;
  }

  /// The user's currently selected starting gate, if any (spec Section
  /// 1). `null` if onboarding hasn't set one yet.
  GateModel? get currentGate {
    final id = _gateSelectionService.selectedGateId;
    if (id == null) return null;
    return findGateById(id);
  }

  // ─── Itinerary ──────────────────────────────────────────────────────────

  List<ItineraryModel> get userItineraries => _itineraryService.itineraries;

  ItineraryModel? findItineraryById(String id) =>
      _itineraryService.getById(id);

  List<LocationModel> resolveItineraryStops(ItineraryModel itinerary) =>
      _itineraryService.resolveLocations(itinerary);

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
}
