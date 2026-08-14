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

  // ─── Structured / composable queries ────────────────────────────────────
  // The improvement spec's acceptance criteria require answering budget
  // ranges ("₱200–₱500") and *combined* filters (budget + category +
  // accessibility) — neither of which was expressible before: price
  // filtering was done ad hoc inside the conversation engine,
  // [LocationModel.budgetRange] was never consulted, and
  // accessibilityFeatures was never surfaced here at all. Everything
  // below reads the same fields the Plans and location-detail screens
  // read, so a chat answer can never disagree with what's on screen.

  /// Locations whose realistic spend range overlaps `[min, max]`.
  ///
  /// Uses [LocationModel.budgetRange] — the "what you'd actually spend
  /// here" figure the Plans page filters on — rather than
  /// [TicketInfo.adultPrice], so a free-entry site with incidental costs
  /// is still matched correctly. Overlap (not containment) matches the
  /// Plans page's own [BudgetRange.overlaps] semantics.
  List<LocationModel> locationsInBudgetRange({
    double min = 0,
    double max = double.infinity,
  }) {
    final effectiveMax = max.isFinite ? max : double.maxFinite;
    final filter = BudgetRange(min: min, max: effectiveMax);
    return allLocations.where((l) => l.budgetRange.overlaps(filter)).toList();
  }

  /// Locations with a formal adult admission fee at or below [maxPrice].
  /// Distinct from [locationsInBudgetRange], which covers total spend.
  List<LocationModel> locationsWithAdmissionUnder(double maxPrice) =>
      allLocations.where((l) => l.ticketInfo.adultPrice <= maxPrice).toList();

  /// Locations offering a student/senior discount, i.e. a student price
  /// genuinely below the adult price.
  List<LocationModel> get locationsWithDiscounts => allLocations
      .where((l) => l.ticketInfo.studentPrice < l.ticketInfo.adultPrice)
      .toList();

  /// Locations exposing an accessibility feature of [type].
  List<LocationModel> locationsWithAccessibility(AccessibilityType type) =>
      allLocations
          .where((l) => l.accessibilityFeatures.any((f) => f.type == type))
          .toList();

  /// Resolves free-text like "wheelchair", "ramp", "braille", "vegetarian"
  /// to a real [AccessibilityType]. Returns `null` rather than guessing
  /// when nothing matches, so an unsupported request declines honestly.
  AccessibilityType? resolveAccessibilityType(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return null;
    const synonyms = <AccessibilityType, List<String>>{
      AccessibilityType.ramps: [
        // Deliberately excludes bare 'senior' and 'pwd': those words show
        // up constantly in *pricing* questions ("discounted
        // student/senior rates"), and treating them as an accessibility
        // filter hijacked such questions away from the discount handler.
        // Priority-assistance phrasing lives under pwdSeniorPriority.
        'ramp',
        'ramps',
        'wheelchair',
        'step free',
        'stepfree',
        'step-free',
        'mobility',
        'accessible entrance',
      ],
      AccessibilityType.elevators: ['elevator', 'elevators', 'lift'],
      AccessibilityType.brailleVoice: [
        'braille',
        'voice',
        'audio',
        'blind',
        'visually impaired',
      ],
      AccessibilityType.vegetarian: ['vegetarian', 'vegan', 'meatless'],
      AccessibilityType.restroom: ['restroom', 'toilet', 'washroom', 'cr'],
      AccessibilityType.parking: ['parking', 'car park'],
      AccessibilityType.restAreas: [
        'rest area',
        'rest areas',
        'seating',
        'bench',
        'benches',
        'somewhere to sit',
        'place to sit',
        'sit down',
      ],
      // Multi-word only, for the same reason as ramps above — a bare
      // 'senior'/'pwd' would swallow senior-discount pricing questions.
      AccessibilityType.pwdSeniorPriority: [
        'priority lane',
        'priority assistance',
        'senior priority',
        'pwd priority',
        'pwd assistance',
      ],
      AccessibilityType.audioDescribedDirections: [
        'audio described',
        'audio description',
        'narrated',
      ],
      AccessibilityType.cafe: [
        'cafe',
        'coffee',
        'wifi',
        'socket',
        'sockets',
        'outlet',
        'work from',
        'laptop',
      ],
    };
    for (final entry in synonyms.entries) {
      for (final term in entry.value) {
        if (q.contains(term)) return entry.key;
      }
    }
    return null;
  }

  /// Locations currently open, per each site's own [OperatingHours].
  List<LocationModel> get locationsOpenNow =>
      allLocations.where((l) => l.isOpenNow).toList();

  /// Locations flagged as cafes with workspace amenities.
  List<LocationModel> locationsWithAmenities({
    bool? requireWifi,
    bool? requireSockets,
  }) => allLocations.where((l) {
    if (requireWifi == true && !l.hasWifi) return false;
    if (requireSockets == true && !l.hasSockets) return false;
    return true;
  }).toList();

  /// The one composable entry point the assistant should prefer: applies
  /// every supplied constraint together (AND), so a question combining
  /// budget + category + accessibility + open-now resolves in a single
  /// grounded query instead of the caller intersecting lists by hand.
  ///
  /// Every parameter is optional; omitted ones simply don't constrain.
  /// Returns an empty list when nothing matches — which the caller should
  /// report honestly rather than widening the filters silently.
  List<LocationModel> queryLocations({
    String? category,
    double? budgetMin,
    double? budgetMax,
    double? maxAdmission,
    AccessibilityType? accessibility,
    bool? openNow,
    bool? requiresWifi,
    bool? requiresSockets,
    bool discountedOnly = false,
  }) {
    var results = allLocations;

    if (category != null && category.trim().isNotEmpty) {
      final resolved = resolveCategory(category);
      if (resolved == null) return const [];
      final normalized = _normalize(resolved);
      results = results
          .where((l) => _normalize(l.category) == normalized)
          .toList();
    }

    if (budgetMin != null || budgetMax != null) {
      final filter = BudgetRange(
        min: budgetMin ?? 0,
        max: budgetMax ?? double.maxFinite,
      );
      results = results.where((l) => l.budgetRange.overlaps(filter)).toList();
    }

    if (maxAdmission != null) {
      results = results
          .where((l) => l.ticketInfo.adultPrice <= maxAdmission)
          .toList();
    }

    if (accessibility != null) {
      results = results
          .where(
            (l) => l.accessibilityFeatures.any((f) => f.type == accessibility),
          )
          .toList();
    }

    if (openNow == true) {
      results = results.where((l) => l.isOpenNow).toList();
    }

    if (requiresWifi == true) {
      results = results.where((l) => l.hasWifi).toList();
    }

    if (requiresSockets == true) {
      results = results.where((l) => l.hasSockets).toList();
    }

    if (discountedOnly) {
      results = results
          .where((l) => l.ticketInfo.studentPrice < l.ticketInfo.adultPrice)
          .toList();
    }

    return results;
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

  ItineraryModel? findItineraryById(String id) => _itineraryService.getById(id);

  List<LocationModel> resolveItineraryStops(ItineraryModel itinerary) =>
      _itineraryService.resolveLocations(itinerary);

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
}
