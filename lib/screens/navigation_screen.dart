import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../models/nav_target.dart';
import '../models/route_result_model.dart';
import '../services/routing_service.dart';
import '../services/tts_service.dart';
import '../services/gate_selection_service.dart';
import '../services/gate_service.dart';
import '../services/live_tracking_activation_service.dart';
import '../services/location_service.dart';
import '../services/walking_path_service.dart';
import '../services/accessibility_settings_service.dart';
import '../widgets/location_photo.dart';
import 'location_details_screen.dart';
import 'osm_poi_map_screen.dart';
import 'favorites_screen.dart';

/// Navigation screen. Visual language (route-card overlay, recenter button,
/// Live Updates list, black accessibility-mode pills) is ported from the
/// Eunice-branch `#screen-navigation` markup, while the actual mapping is
/// backed by the native Google Maps SDK, geolocator GPS stream, and the
/// flutter_tts voice-mode integration already wired up in this build.
///
/// Two modes (spec Section 2.2):
///  - Browse mode (`navTarget == null`, reached from the bottom nav tab):
///    shows a persistent, always-visible search bar and multi-select
///    category filter row above the map.
///  - Active navigation mode (`navTarget` set): shows either a bird's-eye
///    overview or a live turn-by-turn experience, per [viewMode] (addendum
///    spec Section 1). Always reached through [NavFlowLauncher] rather
///    than pushed directly, so the view-mode (and, for itineraries,
///    transport-mode) choice is identical everywhere.
///
/// Routing note: the rendered route line prefers a real, street/path-
/// following route fetched from [RoutingService] (OpenRouteService,
/// `foot-walking` profile — the same provider already used by the
/// standalone Explore POIs screen), since the app's small hand-authored
/// walking-path graph only covers a handful of landmarks and otherwise
/// produces a straight line that can cut through buildings/walls with no
/// real path between them. If the API call fails (no key configured, no
/// network, etc.), this falls back to that static graph, and finally to a
/// direct straight line — see [_fetchRealRoute] and [_buildRouteLine].
class NavigationScreen extends StatefulWidget {
  final NavTarget? navTarget;
  final NavViewMode viewMode;
  final TransportModeOption transportMode;

  /// Injectable for testing (so tests can supply a fake [RoutingService]
  /// instead of making real network calls) — defaults to
  /// [OpenRouteServiceRouting] otherwise, mirroring [OsmPoiMapScreen]'s
  /// existing pattern for the same abstraction.
  final RoutingService? routingService;

  const NavigationScreen({
    super.key,
    this.navTarget,
    this.viewMode = NavViewMode.turnByTurn,
    this.transportMode = TransportModeOption.walk,
    this.routingService,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _isPanelExpanded = true;
  final TtsService _ttsService = TtsService();
  Position? _currentPosition;
  NavTarget? _navTarget;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassSubscription;

  /// Live magnetometer heading in degrees (0 = north), used for the
  /// turn-by-turn view's heading indicator (addendum spec Section 1).
  /// `null` on devices without a compass sensor or before the first
  /// reading arrives — callers fall back to the bearing-derived arrow in
  /// that case.
  ///
  /// Deliberately a [ValueNotifier], not a plain field driving
  /// `setState()`: the compass stream fires tens of times per second, far
  /// more often than GPS. Routing this through `setState()` would rebuild
  /// the entire screen — including the `GoogleMap` widget and its
  /// marker/polyline sets — on every single reading, which is what caused
  /// severe lag. Only the small heading-arrow widget listens to this via
  /// [ValueListenableBuilder], so nothing else on screen rebuilds when it
  /// changes.
  final ValueNotifier<double?> _headingNotifier = ValueNotifier(null);

  // Accessibility toggles — mirrors the branch's three default-active modes.
  bool _vegetarianMode = true;
  bool _brailleVoiceMode = true;
  bool _rampsMode = true;

  // 3 additional confirmed modes (addendum spec Section 4.2) — default to
  // active, matching the existing three's default-on behavior.
  bool _restAreasMode = true;
  bool _pwdSeniorPriorityMode = true;
  bool _audioDescribedDirectionsMode = true;

  // Cafe (WiFi & Sockets) filter toggle (addendum spec 3 Section 1.1) —
  // defaults to active like the other modes above.
  bool _cafeMode = true;

  final List<_LiveUpdate> _liveUpdates = [];

  /// The fixed anchor the active route line and off-route detection are
  /// measured from (addendum spec Section 2.2): the user's *effective*
  /// position at the moment navigation started — which, per
  /// [_effectiveUserLatLng], is the selected gate's fixed coordinates
  /// until live GPS activates, or the live position immediately if no
  /// gate was selected. Kept fixed thereafter so off-route detection has
  /// a stable reference (a line redrawn from the live position every
  /// update would never register as "off route").
  LatLng? _routeStartPosition;

  /// Cached waypoints of the current route line (either the walking-path
  /// graph's hop chain, or a direct two-point line as a fallback),
  /// recomputed whenever [_buildRouteLine] runs. Used as a last-resort
  /// proxy for "turns" only when [_realRouteSteps] has no real maneuver
  /// data for the current route (e.g. the ORS fetch failed and this
  /// fell back to the static graph/straight line).
  List<LatLng>? _routeWaypoints;

  /// Index into [_routeWaypoints] of the next waypoint treated as the
  /// upcoming "turn" — only used by the [_routeWaypoints] fallback path.
  /// Advances as the user's effective position comes within range of the
  /// current one.
  int _nextWaypointIndex = 1;

  /// Real turn-by-turn maneuvers for the currently active real route
  /// (see [RouteResult.steps]), indexed against [_realRouteWaypoints].
  /// `null`/empty whenever there's no real route (fallback graph/straight
  /// line in effect) — in that case, turn-by-turn falls back to the
  /// waypoint-hop proxy instead, since there's no real maneuver data to
  /// show. Each step's `way_points` already indexes directly into
  /// [_realRouteWaypoints], so "next turn" here is an actual decision
  /// point on the real, street-following route, not just the next raw
  /// vertex along it.
  List<RouteStep> _realRouteSteps = const [];

  /// Index into [_realRouteSteps] of the step currently being executed.
  /// Advances as the user's effective position passes each step's end
  /// waypoint, mirroring [_nextWaypointIndex]'s role for the fallback
  /// path.
  int _currentStepIndex = 0;

  /// Cached result of the last [_computeRouteLine] call, keyed by the
  /// [_routeStartPosition] it was computed for. [_buildRouteLine] is
  /// called from `build()`, which re-runs on every GPS update (every ~5m)
  /// — recomputing the walking-path graph's BFS search that often would
  /// be wasted work, since the line only actually needs to change when
  /// [_routeStartPosition] itself changes (initial set, or a manual
  /// "recenter"/"return to route"). This cache avoids repeating that
  /// search on updates that don't touch the route start at all.
  Set<Polyline>? _cachedRouteLine;
  LatLng? _cachedRouteLineStart;

  /// [RoutingService] used to fetch a real, street/path-following route
  /// (see class doc) — defaults to [OpenRouteServiceRouting] unless a
  /// fake is injected for testing via [NavigationScreen.routingService].
  late final RoutingService _routingService;

  /// The real routed waypoints last fetched for [_routeStartPosition],
  /// once [_fetchRealRoute] resolves successfully. `null` until a fetch
  /// completes (or if it fails/is never attempted), in which case
  /// [_buildRouteLine] falls back to the static walking-path graph and
  /// then a direct line, exactly as before real routing existed.
  List<LatLng>? _realRouteWaypoints;

  /// Guards against redundant/overlapping real-route fetches: only one
  /// fetch should be in flight for a given [_routeStartPosition] at a
  /// time, and a fetch already completed for the current start shouldn't
  /// be repeated on every subsequent GPS-driven rebuild.
  LatLng? _realRouteFetchedForStart;
  bool _isFetchingRealRoute = false;

  /// Short, user-facing reason the real ORS route fetch fell back to the
  /// static walking-path graph / straight line for [_realRouteFetchedForStart]
  /// — `null` when the last fetch succeeded (or hasn't run yet). Any
  /// fallback must be visible, not silent: this drives a small on-screen
  /// indicator (see [_buildRouteFallbackBadge]) alongside the existing
  /// debug-console logging in [OpenRouteServiceRouting] and here.
  String? _realRouteFailureReason;

  // ─── Distinct per-view-mode camera behavior ────────────────────────────
  // Bird's-eye and turn-by-turn deliberately do NOT share camera logic:
  // bird's-eye fits both the route start and destination once and then
  // stays static/north-up; turn-by-turn continuously follows the user
  // with a tight, heading-rotated camera. Mixing these (e.g. one shared
  // "fit bounds" camera under different UI chrome) was the bug being
  // fixed here — the two modes need to feel structurally different, not
  // just show different overlays on the same map behavior.

  /// Tight, street-level zoom for the turn-by-turn following camera —
  /// deliberately much closer than bird's-eye's full-route overview, so
  /// only the immediate road/intersection ahead is visible, matching
  /// Google Maps' walking-navigation feel.
  static const double _followCameraZoom = 18.5;

  /// Slight forward-looking perspective for the turn-by-turn camera
  /// (rather than a flat top-down view), matching the reference
  /// navigation UI.
  static const double _followCameraTilt = 45;

  /// Last heading applied to the turn-by-turn following camera, in
  /// degrees — the map is rotated so this direction reads as "up" on
  /// screen, instead of a fixed north-up orientation. Tracked so
  /// compass-driven updates can skip re-issuing a camera command for
  /// insignificant jitter (see [_onCompassFollowUpdate]).
  double _followCameraBearing = 0;

  /// Throttle gate for compass-driven camera rotation: the compass fires
  /// far more often than a rotating camera actually needs to move, so
  /// updates are limited to roughly every [_followBearingThrottle] and
  /// only applied once the heading has changed by more than a few
  /// degrees — otherwise `GoogleMapController.moveCamera` would be
  /// invoked continuously for no visible benefit (and real cost).
  DateTime? _lastFollowBearingUpdate;
  static const Duration _followBearingThrottle = Duration(milliseconds: 200);
  static const double _followBearingMinDeltaDegrees = 3;

  /// Whether bird's-eye's one-time "fit both start and destination"
  /// camera framing has already been applied. Bird's-eye is deliberately
  /// static after that single fit — this guards against re-fitting (and
  /// so silently turning into a follow camera) on later rebuilds.
  bool _hasFitBirdsEyeBounds = false;

  // ─── Browse-mode state (search + persistent multi-select filters) ────────
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  final Set<String> _activeCategoryFilters = {};
  LocationModel? _focusedSearchResult;

  static const List<String> _navFilterCategories = [
    'Fortifications',
    'Landmarks',
    'Schools',
    'Parks',
  ];

  // ─── Active navigation mode state (route line + off-route detection) ─────
  bool _isOffRoute = false;
  static const double _offRouteThresholdMeters = 40;
  static const double _waypointArrivalThresholdMeters = 15;

  bool get _isBrowseMode => _navTarget == null;

  bool get _isTurnByTurn =>
      !_isBrowseMode && widget.viewMode == NavViewMode.turnByTurn;

  @override
  void initState() {
    super.initState();
    _navTarget = widget.navTarget;
    _routingService = widget.routingService ?? OpenRouteServiceRouting();
    LiveTrackingActivationService.instance.addListener(_onActivationChanged);
    _initializeLocation();
    _listenToCompass();
    _rebuildLiveUpdates();
    WalkingPathService().ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Fetches a real, street/path-following route from [start] to [end]
  /// via [_routingService] and stores it in [_realRouteWaypoints] once it
  /// resolves, triggering a rebuild so [_buildRouteLine] picks it up. A
  /// no-op if a fetch for this exact [start] is already in flight or has
  /// already completed (see the guard fields' docs) — callers can call
  /// this unconditionally on every rebuild without worrying about
  /// duplicate network calls. Any failure (missing API key, no network,
  /// no route found, etc.) is swallowed here: [_buildRouteLine] already
  /// has a graceful fallback chain, so this screen never needs to show a
  /// routing error to the user the way the standalone Explore POIs screen
  /// does — a route line is a "nice to have" precision improvement here,
  /// not a feature the user explicitly requested and needs error
  /// feedback for.
  Future<void> _fetchRealRoute(LatLng start, LatLng end) async {
    if (_isFetchingRealRoute || _realRouteFetchedForStart == start) return;
    _isFetchingRealRoute = true;
    try {
      final result = await _routingService.getWalkingRoute(
        ll.LatLng(start.latitude, start.longitude),
        ll.LatLng(end.latitude, end.longitude),
      );
      if (!mounted) return;
      setState(() {
        _realRouteWaypoints = result.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        _realRouteSteps = result.steps;
        _currentStepIndex = 0;
        _realRouteFetchedForStart = start;
        _realRouteFailureReason = null;
        // Invalidate the cached polyline so _buildRouteLine picks up the
        // newly fetched real route on the next build instead of
        // continuing to serve the previously cached fallback line.
        _cachedRouteLine = null;
      });
    } catch (e) {
      // Leave _realRouteWaypoints as-is (null, or a previous route) —
      // _buildRouteLine's fallback chain handles this gracefully. This
      // failure must never be silent: it's always logged to the debug
      // console (below) *and* surfaced as a small visible badge in the
      // UI (see [_realRouteFailureReason] / [_buildRouteFallbackBadge]) —
      // a fallback to the static graph/straight line should be something
      // the person testing can actually see, not something they have to
      // infer from the map just looking "off".
      final reason = e is RoutingException
          ? e.message
          : 'Could not fetch a real walking route.';
      debugPrint(
        '[NavigationScreen] Real route fetch failed, falling back '
        'to the static walking-path graph: $e',
      );
      if (mounted) {
        setState(() {
          _realRouteFetchedForStart = start;
          _realRouteFailureReason = reason;
          // No real route means no real maneuver data either — clear any
          // steps from a previous successful fetch so turn-by-turn falls
          // back to the waypoint-hop proxy against whichever fallback
          // line _buildRouteLine ends up using, instead of showing stale
          // steps computed against a route that's no longer displayed.
          _realRouteSteps = const [];
          _currentStepIndex = 0;
        });
      }
    } finally {
      _isFetchingRealRoute = false;
    }
  }

  void _onActivationChanged() {
    if (mounted) setState(() {});
  }

  void _listenToCompass() {
    try {
      final events = FlutterCompass.events;
      if (events == null) return;
      _compassSubscription = events.listen((event) {
        // Updates the notifier directly — no setState() — so this
        // high-frequency stream only repaints the small heading arrow,
        // not the whole screen (see [_headingNotifier] doc for why).
        if (event.heading != null) {
          _headingNotifier.value = event.heading;
          // Turn-by-turn's camera rotates to match the device heading
          // (addendum spec Section 1 / user-confirmed decision) — bird's-
          // eye stays north-up regardless, so this only ever runs while
          // actively in turn-by-turn.
          _maybeRotateFollowCamera(event.heading!);
        }
      });
    } catch (_) {
      // No compass sensor available — heading indicator falls back to the
      // bearing-derived arrow computed from GPS movement, and the
      // following camera simply stays north-up rather than rotating.
    }
  }

  /// Rotates the turn-by-turn following camera to match the live device
  /// heading, throttled so the (very high-frequency) compass stream
  /// doesn't spam `GoogleMapController.moveCamera` — see the throttle
  /// fields' docs for the rationale. No-ops entirely outside turn-by-turn
  /// mode, or before the camera has an initial position to rotate around.
  void _maybeRotateFollowCamera(double heading) {
    if (!_isTurnByTurn || _mapController == null) return;
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null) return;

    final now = DateTime.now();
    final headingDelta = (heading - _followCameraBearing).abs();
    final normalizedDelta = headingDelta > 180
        ? 360 - headingDelta
        : headingDelta;
    if (normalizedDelta < _followBearingMinDeltaDegrees) return;
    if (_lastFollowBearingUpdate != null &&
        now.difference(_lastFollowBearingUpdate!) < _followBearingThrottle) {
      return;
    }
    _lastFollowBearingUpdate = now;
    _followCameraBearing = heading;
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userPoint,
          zoom: _followCameraZoom,
          tilt: _followCameraTilt,
          bearing: heading,
        ),
      ),
    );
  }

  /// Moves the turn-by-turn following camera to the user's latest
  /// effective position, keeping the current heading-derived bearing and
  /// tight zoom — called on every GPS update while in turn-by-turn mode
  /// so the camera continuously tracks the user, unlike bird's-eye's
  /// one-time bounds fit. No-ops entirely outside turn-by-turn mode.
  void _followUserIfTurnByTurn(LatLng point) {
    if (!_isTurnByTurn || _mapController == null) return;
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: _followCameraZoom,
          tilt: _followCameraTilt,
          bearing: _followCameraBearing,
        ),
      ),
    );
  }

  /// One-time camera framing for bird's-eye mode: fits both the route
  /// start and the destination in view, then leaves the camera alone —
  /// deliberately not re-applied on later GPS updates, since bird's-eye
  /// is meant to stay a static, zoomed-out overview rather than follow
  /// the user (that following behavior belongs to turn-by-turn only).
  void _fitBirdsEyeBoundsOnce() {
    if (_hasFitBirdsEyeBounds || _mapController == null || _navTarget == null) {
      return;
    }
    final start = _routeStartPosition ?? _effectiveUserLatLng;
    if (start == null) return;
    _hasFitBirdsEyeBounds = true;
    final end = _navTarget!.coordinates;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            start.latitude < end.latitude ? start.latitude : end.latitude,
            start.longitude < end.longitude ? start.longitude : end.longitude,
          ),
          northeast: LatLng(
            start.latitude > end.latitude ? start.latitude : end.latitude,
            start.longitude > end.longitude ? start.longitude : end.longitude,
          ),
        ),
        80,
      ),
    );
  }

  /// Initializes the turn-by-turn following camera the first time a
  /// position becomes available (mirrors [_fitBirdsEyeBoundsOnce]'s
  /// "apply once a position exists" pattern, but for the continuously
  /// following camera instead of a static bounds fit).
  void _maybeStartFollowingCamera(LatLng point) {
    if (!_isTurnByTurn || _mapController == null) return;
    _followUserIfTurnByTurn(point);
  }

  /// Resolves the "current position" every marker/route/distance
  /// calculation should treat as the user's location (addendum spec
  /// Section 2.2/2.3): while a starting gate is selected and live
  /// tracking hasn't activated yet (user not yet within ~50m of it),
  /// this returns the gate's fixed coordinates rather than raw GPS — so
  /// the marker doesn't jump to wherever the user actually is yet (e.g.
  /// elsewhere in Metro Manila). Once activated (or if no gate was ever
  /// selected), returns the live GPS position instead.
  LatLng? get _effectiveUserLatLng {
    if (!LiveTrackingActivationService.instance.isActive) {
      final gateId = GateSelectionService.instance.selectedGateId;
      if (gateId != null) {
        final gate = GateService().getGateById(gateId);
        if (gate != null) return gate.coordinates;
      }
    }
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return null;
  }

  void _setRouteStartIfNeeded() {
    if (_navTarget != null && _routeStartPosition == null) {
      final point = _effectiveUserLatLng;
      if (point != null) _routeStartPosition = point;
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassSubscription?.cancel();
    _headingNotifier.dispose();
    LiveTrackingActivationService.instance.removeListener(_onActivationChanged);
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _rebuildLiveUpdates() {
    _liveUpdates.clear();
    if (_navTarget != null && _navTarget!.accessibilityFeatures.isNotEmpty) {
      for (final feature in _navTarget!.accessibilityFeatures) {
        _liveUpdates.add(
          _LiveUpdate(
            title: feature.name,
            subtitle: feature.description,
            type: feature.type,
            isActive: _isModeActive(feature.type),
          ),
        );
      }
      return;
    }
    // Fall back to the branch's generic default modes when a site has no
    // location-specific accessibility features configured yet.
    if (_vegetarianMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Vegetarian',
          subtitle: '67m — open now',
          type: AccessibilityType.vegetarian,
          isActive: true,
        ),
      );
    }
    // Cafe (WiFi & Sockets) status line (addendum spec 3 Section 1.3):
    // placed directly under Vegetarian in this feed too, mirroring its
    // "directly under Vegetarian" placement in the Accessibility Modes
    // grid — every mode after it (Braille/Voice onward) shifts down one
    // spot in the feed accordingly.
    if (_cafeMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Cafe (WiFi & Sockets)',
          subtitle: '3 cafes nearby — WiFi & sockets',
          type: AccessibilityType.cafe,
          isActive: true,
        ),
      );
    }
    if (_brailleVoiceMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Braille / Voice',
          subtitle: 'Voiceover mode active',
          type: AccessibilityType.brailleVoice,
          isActive: true,
        ),
      );
    }
    if (_rampsMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Ramps & Elevators',
          subtitle: 'Located near Main Entrance',
          type: AccessibilityType.ramps,
          isActive: true,
        ),
      );
    }
    if (_restAreasMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Rest Areas & Seating',
          subtitle: '2 benches — 40m ahead',
          type: AccessibilityType.restAreas,
          isActive: true,
        ),
      );
    }
    if (_pwdSeniorPriorityMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'PWD & Senior Priority',
          subtitle: 'Priority assistance available on request',
          type: AccessibilityType.pwdSeniorPriority,
          isActive: true,
        ),
      );
    }
    if (_audioDescribedDirectionsMode) {
      _liveUpdates.add(
        const _LiveUpdate(
          title: 'Audio-Described Directions',
          subtitle: 'Narrated turn-by-turn active',
          type: AccessibilityType.audioDescribedDirections,
          isActive: true,
        ),
      );
    }
  }

  bool _isModeActive(AccessibilityType type) {
    switch (type) {
      case AccessibilityType.vegetarian:
        return _vegetarianMode;
      case AccessibilityType.ramps:
        return _rampsMode;
      case AccessibilityType.brailleVoice:
        return _brailleVoiceMode;
      case AccessibilityType.restAreas:
        return _restAreasMode;
      case AccessibilityType.pwdSeniorPriority:
        return _pwdSeniorPriorityMode;
      case AccessibilityType.audioDescribedDirections:
        return _audioDescribedDirectionsMode;
      case AccessibilityType.cafe:
        return _cafeMode;
      default:
        return true;
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      LiveTrackingActivationService.instance.evaluate(position);
      if (mounted) setState(() => _currentPosition = position);
      _setRouteStartIfNeeded();
      _applyModeSpecificCamera();
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((Position position) {
            LiveTrackingActivationService.instance.evaluate(position);
            if (mounted) {
              setState(() {
                _currentPosition = position;
                _setRouteStartIfNeeded();
                _updateWaypointProgress();
                _checkOffRoute();
              });
              // Turn-by-turn's camera follows every GPS update
              // (addendum spec Section 1); bird's-eye deliberately does
              // nothing here — it was already fit once and stays static.
              _followUserIfTurnByTurn(
                LatLng(position.latitude, position.longitude),
              );
            }
          });
    } catch (_) {}
  }

  /// Applies each view mode's distinct initial camera framing once a
  /// position is available: bird's-eye fits the full route once and
  /// stays put; turn-by-turn immediately snaps to its tight, following
  /// camera instead of inheriting bird's-eye's overview framing. Safe to
  /// call multiple times — both underlying methods are idempotent/no-op
  /// once already applied or outside their respective mode.
  void _applyModeSpecificCamera() {
    if (_isBrowseMode) return;
    if (_isTurnByTurn) {
      final point = _effectiveUserLatLng;
      if (point != null) _maybeStartFollowingCamera(point);
    } else {
      _fitBirdsEyeBoundsOnce();
    }
  }

  // ─── Search (scoped to this app's own dataset only, per spec 2.3) ─────────

  List<LocationModel> get _searchResults {
    if (_searchTerm.trim().isEmpty) return const [];
    final term = _searchTerm.trim().toLowerCase();
    return LocationService()
        .getAllLocations()
        .where((site) => site.name.toLowerCase().contains(term))
        .take(8)
        .toList();
  }

  void _onSearchResultTapped(LocationModel site) {
    setState(() {
      _focusedSearchResult = site;
      _searchController.text = site.name;
      _searchTerm = '';
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(site.coordinates, 17),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchTerm = '';
      _focusedSearchResult = null;
    });
  }

  // ─── Multi-select category filters (spec 2.2, persistent + union) ────────

  void _toggleCategoryFilter(String category) {
    setState(() {
      if (_activeCategoryFilters.contains(category)) {
        _activeCategoryFilters.remove(category);
      } else {
        _activeCategoryFilters.add(category);
      }
    });
  }

  List<LocationModel> get _filteredCategoryLocations {
    if (_activeCategoryFilters.isEmpty) return const [];
    return LocationService()
        .getAllLocations()
        .where((site) => _activeCategoryFilters.contains(site.category))
        .toList();
  }

  /// Opens the Itinerary Hub (Your Hub → Itineraries tab) directly from
  /// the Navigation screen's filter row, so saved itineraries aren't only
  /// reachable through Settings → Saved Places, which buried them behind
  /// an extra navigation step.
  void _openItinerariesHub() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FavoritesScreen(initialTab: 'Itineraries'),
      ),
    );
  }

  // ─── Marker building (native GoogleMap Marker/InfoWindow) ─────────────────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_navTarget != null) {
      markers.add(_navTargetMarker(_navTarget!));
    }
    final userPoint = _effectiveUserLatLng;
    if (userPoint != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: userPoint,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    if (_navTarget != null) {
      for (final feature in _navTarget!.accessibilityFeatures) {
        if (feature.location == null) continue;
        if (_isModeActive(feature.type)) {
          markers.add(
            Marker(
              markerId: MarkerId(feature.id),
              position: feature.location!,
              infoWindow: InfoWindow(
                title: feature.name,
                snippet: feature.description,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(feature.type),
              ),
            ),
          );
        }
      }
    }
    // Browse mode: pins for every location matching the active category
    // filters (union across filters) plus the focused search result.
    if (_isBrowseMode) {
      for (final site in _filteredCategoryLocations) {
        markers.add(
          _locationPinMarker(site, _getCategoryMarkerHue(site.category)),
        );
      }
      if (_focusedSearchResult != null) {
        markers.add(
          _locationPinMarker(_focusedSearchResult!, BitmapDescriptor.hueRose),
        );
      }
    }
    // Cafe (WiFi & Sockets) pin highlighting (addendum spec 3 Section 2.1)
    // — deliberately a separate, independent filter path from
    // [_activeCategoryFilters]/[_filteredCategoryLocations] above, per
    // explicit instruction, rather than folding "Cafe" into that
    // category-filter machinery. Driven solely by [_cafeMode] (the
    // Accessibility Modes grid toggle), scoped to browse mode like the
    // other location pins above so it doesn't appear mid-navigation to an
    // unrelated target.
    if (_isBrowseMode) {
      for (final site in _cafeFilteredLocations) {
        markers.add(_locationPinMarker(site, _getCafeMarkerHue()));
      }
    }
    return markers;
  }

  /// Independent Cafe pin filter (addendum spec 3 Section 2.1): returns
  /// every catalogued Cafe-category location when [_cafeMode] is active,
  /// or an empty list otherwise. Kept entirely separate from
  /// [_filteredCategoryLocations]/[_activeCategoryFilters] so toggling the
  /// existing category filters can never turn Cafe pins on/off, and vice
  /// versa.
  List<LocationModel> get _cafeFilteredLocations {
    if (!_cafeMode) return const [];
    return LocationService()
        .getAllLocations()
        .where((site) => site.category == 'Cafe')
        .toList();
  }

  /// Marker hue for Cafe pins (addendum spec 3 Section 2.1), kept as its
  /// own helper distinct from [_getCategoryMarkerHue] since Cafe pins are
  /// driven by the independent [_cafeFilteredLocations] path above rather
  /// than the shared category-filter marker loop.
  double _getCafeMarkerHue() => BitmapDescriptor.hueMagenta;

  /// Builds a marker for a location pin (spec Section 5): tapping it shows
  /// a photo + name bottom sheet (see [_showLocationPinSheet]) instead of
  /// google_maps_flutter's text-only `InfoWindow`, which can't display an
  /// image. Used for browse-mode filtered pins and the focused search
  /// result — not the "You are here" current-position marker, which has
  /// no location record/photo of its own.
  Marker _locationPinMarker(LocationModel location, double hue) {
    return Marker(
      markerId: MarkerId(location.id),
      position: location.coordinates,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      onTap: () => _showLocationPinSheet(location),
    );
  }

  /// Marker for the active navigation target (spec Section 5), which may
  /// or may not have a full catalogued [LocationModel] behind it — e.g. a
  /// Transport & Access pickup point (addendum spec Section 4.3) has only
  /// a name and coordinates. See [_showNavTargetPinSheet].
  Marker _navTargetMarker(NavTarget target) {
    return Marker(
      markerId: const MarkerId('nav-target'),
      position: target.coordinates,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      onTap: () => _showNavTargetPinSheet(target),
    );
  }

  /// Photo + name bottom sheet shown when a browse-mode location pin is
  /// tapped (spec Section 5) — google_maps_flutter's `InfoWindow` is
  /// text-only by design, so a photo can't be shown inline above the pin
  /// the way `flutter_map`'s custom overlay widgets can. A bottom sheet
  /// keeps the same "tap pin → see photo" outcome without depending on a
  /// screen-coordinate conversion that would need to be recomputed on
  /// every camera move (`GoogleMapController.getScreenCoordinate` is
  /// async and has no continuous camera-move stream to drive it from).
  void _showLocationPinSheet(LocationModel location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: LocationPhoto(
                    imagePath: location.imageUrl,
                    fallbackColor: AppTheme.forest.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                location.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // WiFi / Sockets amenity indicators (addendum spec 3 Section
              // 2.2) — only rendered for Cafe locations, so the popup for
              // standard historical sites/landmarks is untouched.
              if (location.category == 'Cafe') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _AmenityChip(
                      icon: location.hasWifi ? Icons.wifi : Icons.wifi_off,
                      label: location.hasWifi
                          ? 'WiFi available'
                          : 'No WiFi',
                      available: location.hasWifi,
                    ),
                    const SizedBox(width: 8),
                    _AmenityChip(
                      icon: location.hasSockets
                          ? Icons.power
                          : Icons.power_off,
                      label: location.hasSockets
                          ? 'Sockets available'
                          : 'No sockets',
                      available: location.hasSockets,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openLocationDetails(location);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet for the active navigation target's own marker. Shows a
  /// photo when available and a "View details" action only when this
  /// target has a real catalogued [LocationModel] behind it — a
  /// Transport & Access pickup point has neither.
  void _showNavTargetPinSheet(NavTarget target) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (target.imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: LocationPhoto(
                      imagePath: target.imagePath!,
                      fallbackColor: AppTheme.forest.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                target.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (target.sourceLocation != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openLocationDetails(target.sourceLocation!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View details'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openLocationDetails(LocationModel site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LocationDetailsScreen(location: site)),
    );
  }

  double _getCategoryMarkerHue(String category) {
    switch (category) {
      case 'Fortifications':
        return BitmapDescriptor.hueRed;
      case 'Landmarks':
        return BitmapDescriptor.hueOrange;
      case 'Schools':
        return BitmapDescriptor.hueYellow;
      case 'Parks':
        return BitmapDescriptor.hueGreen;
      case 'Cafe':
        // addendum spec 3 Section 2.1 — matches [_getCafeMarkerHue], kept
        // here too so any caller that reaches Cafe sites through this
        // shared helper (rather than the independent [_cafeFilteredLocations]
        // path) still renders a distinct, consistent pin color.
        return BitmapDescriptor.hueMagenta;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  double _getMarkerHue(AccessibilityType type) {
    switch (type) {
      case AccessibilityType.vegetarian:
        return BitmapDescriptor.hueGreen;
      case AccessibilityType.ramps:
        return BitmapDescriptor.hueViolet;
      case AccessibilityType.brailleVoice:
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  double? get _distanceMeters {
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null || _navTarget == null) return null;
    return Geolocator.distanceBetween(
      userPoint.latitude,
      userPoint.longitude,
      _navTarget!.coordinates.latitude,
      _navTarget!.coordinates.longitude,
    );
  }

  String _calculateDistance() {
    final d = _distanceMeters;
    if (d == null) return '—';
    if (d > 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.toInt()}m';
  }

  /// Average adult walking speed of ~1.3 m/s (~4.7 km/h), matching Google
  /// Maps' typical walking-ETA assumption, applied to the straight-line
  /// distance computed above. Used for every transport mode (addendum
  /// spec Section 6): routing/timing is identical across modes since the
  /// mode choice is a visual distinction only, not a different
  /// calculated path.
  String _calculateEta() {
    final d = _distanceMeters;
    if (d == null) return '—';
    final minutes = (d / 1.3 / 60).ceil();
    if (minutes < 1) return '<1 min';
    return '$minutes min';
  }

  IconData _iconForBearing(double bearing) {
    final normalized = (bearing + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) {
      return Icons.arrow_upward_rounded;
    }
    if (normalized < 67.5) return Icons.north_east_rounded;
    if (normalized < 112.5) return Icons.arrow_forward_rounded;
    if (normalized < 157.5) return Icons.south_east_rounded;
    if (normalized < 202.5) return Icons.arrow_downward_rounded;
    if (normalized < 247.5) return Icons.south_west_rounded;
    if (normalized < 292.5) return Icons.arrow_back_rounded;
    return Icons.north_west_rounded;
  }

  // ─── Turn-by-turn data (addendum spec Section 1) ───────────────────────
  // Prefers real maneuver data from the routing provider (_realRouteSteps,
  // populated only when a real ORS route was fetched — see
  // _fetchRealRoute) so each reported "next turn" corresponds to an actual
  // walkable decision point on the real, street-following route. Only
  // when there's no real route in effect (ORS fetch failed, so
  // _buildRouteLine fell back to the static walking-path graph or a
  // direct line) does this fall back to the coarser waypoint-hop proxy —
  // the next unreached waypoint on whichever fallback line is showing,
  // and the nearest named graph node as a "current street" stand-in (per
  // the user-confirmed design decision to use that proxy over reverse
  // geocoding). A route built from a fallback source has no real step
  // data to show turns for in the first place, so this distinction isn't
  // optional — it's what keeps "next turn" honest about what it's
  // actually derived from.

  bool get _hasRealSteps => _realRouteSteps.isNotEmpty;

  RouteStep? get _currentStep {
    if (!_hasRealSteps) return null;
    final index = _currentStepIndex.clamp(0, _realRouteSteps.length - 1);
    return _realRouteSteps[index];
  }

  LatLng? get _nextTurnPoint {
    final step = _currentStep;
    final realWaypoints = _realRouteWaypoints;
    if (step != null && realWaypoints != null) {
      final index = step.wayPointEnd.clamp(0, realWaypoints.length - 1);
      return realWaypoints[index];
    }
    final waypoints = _routeWaypoints;
    if (waypoints == null || waypoints.length < 2) {
      return _navTarget?.coordinates;
    }
    final index = _nextWaypointIndex.clamp(0, waypoints.length - 1);
    return waypoints[index];
  }

  bool get _nextTurnIsFinalDestination {
    if (_hasRealSteps) {
      return _currentStepIndex >= _realRouteSteps.length - 1;
    }
    final waypoints = _routeWaypoints;
    if (waypoints == null || waypoints.length < 2) return true;
    return _nextWaypointIndex >= waypoints.length - 1;
  }

  double? get _distanceToNextTurnMeters {
    final userPoint = _effectiveUserLatLng;
    final turnPoint = _nextTurnPoint;
    if (userPoint == null || turnPoint == null) return null;
    return Geolocator.distanceBetween(
      userPoint.latitude,
      userPoint.longitude,
      turnPoint.latitude,
      turnPoint.longitude,
    );
  }

  String _formatDistanceToNextTurn() {
    final d = _distanceToNextTurnMeters;
    if (d == null) return '—';
    if (d > 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.toInt()}m';
  }

  IconData _nextTurnIcon() {
    final userPoint = _effectiveUserLatLng;
    final turnPoint = _nextTurnPoint;
    if (userPoint == null || turnPoint == null) {
      return Icons.navigation_outlined;
    }
    final bearing = Geolocator.bearingBetween(
      userPoint.latitude,
      userPoint.longitude,
      turnPoint.latitude,
      turnPoint.longitude,
    );
    return _iconForBearing(bearing);
  }

  String _nextTurnLabel() {
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null || _navTarget == null) {
      return 'Waiting for your location…';
    }
    final step = _currentStep;
    if (step != null && step.instruction.isNotEmpty) {
      // Real maneuver text from the routing provider (e.g. "Turn sharp
      // left onto Esplanade - Fort Santiago"), not an approximation.
      return step.instruction;
    }
    final d = _distanceToNextTurnMeters ?? 0;
    if (_nextTurnIsFinalDestination) {
      if (d < 15) return 'You have arrived at ${_navTarget!.name}';
      return 'Continue toward ${_navTarget!.name}';
    }
    return 'Continue toward the next waypoint';
  }

  /// "Current street" — the real step's own street/path name when a real
  /// route with maneuver data is active and that step actually has one;
  /// otherwise the nearest named node in the shared walking-path graph
  /// (e.g. "Near Fort Santiago") as a proxy, falling back to a generic
  /// district label when nothing is close enough or the graph hasn't
  /// loaded.
  String _currentStreetProxy() {
    final step = _currentStep;
    if (step != null && step.hasRealName) return step.name;
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null) return 'Intramuros';
    final node = WalkingPathService().nearestLandmarkTo(userPoint);
    return node != null ? 'Near ${node.name}' : 'Intramuros';
  }

  /// Advances [_currentStepIndex] (real steps) or [_nextWaypointIndex]
  /// (fallback proxy) as the effective position passes each one's end
  /// point, so "next turn" always refers to an upcoming, not-yet-reached
  /// maneuver/waypoint rather than one the user has already walked past.
  void _updateWaypointProgress() {
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null) return;

    if (_hasRealSteps) {
      final realWaypoints = _realRouteWaypoints;
      if (realWaypoints == null) return;
      while (_currentStepIndex < _realRouteSteps.length - 1) {
        final endIndex = _realRouteSteps[_currentStepIndex].wayPointEnd.clamp(
          0,
          realWaypoints.length - 1,
        );
        final endPoint = realWaypoints[endIndex];
        final distance = Geolocator.distanceBetween(
          userPoint.latitude,
          userPoint.longitude,
          endPoint.latitude,
          endPoint.longitude,
        );
        if (distance >= _waypointArrivalThresholdMeters) break;
        _currentStepIndex++;
      }
      return;
    }

    final waypoints = _routeWaypoints;
    if (waypoints == null || waypoints.length < 2) {
      return;
    }
    while (_nextWaypointIndex < waypoints.length - 1 &&
        Geolocator.distanceBetween(
              userPoint.latitude,
              userPoint.longitude,
              waypoints[_nextWaypointIndex].latitude,
              waypoints[_nextWaypointIndex].longitude,
            ) <
            _waypointArrivalThresholdMeters) {
      _nextWaypointIndex++;
    }
  }

  /// The route line rendered on the map between where navigation started
  /// and the target. When both points are near the shared static
  /// walking-path graph (assets/data/walking_paths.json, loaded via
  /// [WalkingPathService]), this traces the graph's walkable segments
  /// instead of a raw straight line; otherwise it falls back to the
  /// original direct-line behavior. Either way, the line is fixed at
  /// route-start — a stable reference the user can be measured as deviating
  /// from, unlike a line that redraws from the live position every update
  /// (which could never register as off-route).
  ///
  /// Routing is identical for every [TransportModeOption] (addendum spec
  /// Section 6) — only the line's color changes — since there's no
  /// separate vehicle road network to route on; the mode choice is a
  /// visual distinction, not a different calculated path.
  Set<Polyline> _buildRouteLine() {
    if (_routeStartPosition == null || _navTarget == null) return {};
    final start = _routeStartPosition!;
    final end = _navTarget!.coordinates;

    // Kick off (or continue waiting on) a real-route fetch for this
    // start/end pair. Deliberately fire-and-forget from inside build():
    // _fetchRealRoute is idempotent per start point (see its guard
    // fields) and calls setState itself once it resolves, which is what
    // actually delivers the improved route — this call here just ensures
    // the request has been made at all. Scheduled after the current
    // frame so it never triggers setState synchronously during build.
    if (_realRouteFetchedForStart != start) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchRealRoute(start, end);
      });
    }

    // Reuse the cached result unless the start point has actually moved
    // (recenter/return-to-route) or a real route just arrived for this
    // start — see [_cachedRouteLine] doc. This is what keeps `build()`
    // cheap on every GPS/compass-driven rebuild instead of re-running
    // graph pathfinding (or worse, refetching the network route) dozens
    // of times a second.
    if (_cachedRouteLine != null &&
        _cachedRouteLineStart == _routeStartPosition) {
      return _cachedRouteLine!;
    }

    // Fallback chain: prefer the real, street/path-following route (see
    // class doc) when it's been fetched for this exact start; otherwise
    // fall back to the static walking-path graph; otherwise a direct
    // line — matching the app's original behavior before either
    // improvement existed.
    final realRoute = _realRouteFetchedForStart == start
        ? _realRouteWaypoints
        : null;
    final pathWaypoints =
        realRoute ?? WalkingPathService().findPath(start, end);
    _routeWaypoints = pathWaypoints ?? [start, end];
    final line = {
      Polyline(
        polylineId: const PolylineId('active-route'),
        points: _routeWaypoints!,
        color: widget.transportMode.routeColor,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
    _cachedRouteLine = line;
    _cachedRouteLineStart = start;
    return line;
  }

  /// Perpendicular distance in meters from [point] to the straight line
  /// between [start] and [end], using an equirectangular approximation
  /// (accurate enough at Intramuros' small scale — a ~1km-wide district).
  double _perpendicularDistanceMeters(LatLng point, LatLng start, LatLng end) {
    const metersPerDegreeLat = 111320.0;
    final avgLat =
        (start.latitude + end.latitude) / 2 * (3.141592653589793 / 180);
    final metersPerDegreeLng = 111320.0 * _cos(avgLat);

    final x = (point.longitude - start.longitude) * metersPerDegreeLng;
    final y = (point.latitude - start.latitude) * metersPerDegreeLat;
    final dx = (end.longitude - start.longitude) * metersPerDegreeLng;
    final dy = (end.latitude - start.latitude) * metersPerDegreeLat;

    final lineLengthSquared = dx * dx + dy * dy;
    if (lineLengthSquared == 0) {
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        start.latitude,
        start.longitude,
      );
    }

    var t = (x * dx + y * dy) / lineLengthSquared;
    t = t.clamp(0.0, 1.0);

    final projX = t * dx;
    final projY = t * dy;
    final diffX = x - projX;
    final diffY = y - projY;
    return _sqrt(diffX * diffX + diffY * diffY);
  }

  double _cos(double radians) {
    // Small-angle-safe cosine via Dart's math library import below.
    return math.cos(radians);
  }

  double _sqrt(double value) => math.sqrt(value);

  /// Detects whether the user has wandered far enough from the fixed route
  /// line to warrant a "return to route" nudge, mirroring Google Maps'
  /// re-centering behavior when you pan or stray away (spec 2.1).
  void _checkOffRoute() {
    final userPoint = _effectiveUserLatLng;
    if (userPoint == null ||
        _navTarget == null ||
        _routeStartPosition == null) {
      return;
    }
    final deviation = _perpendicularDistanceMeters(
      userPoint,
      _routeStartPosition!,
      _navTarget!.coordinates,
    );
    final nowOffRoute = deviation > _offRouteThresholdMeters;
    if (nowOffRoute != _isOffRoute) {
      setState(() => _isOffRoute = nowOffRoute);
    }
  }

  /// "Return to route": re-anchors the route line to the user's effective
  /// position (like Google Maps recalculating after you stray). Camera
  /// behavior on recenter deliberately still matches each view mode's own
  /// logic — turn-by-turn snaps back to its tight following camera at the
  /// user's position, while bird's-eye re-fits both endpoints — rather
  /// than always doing a bounds-fit regardless of mode.
  void _recenterOnRoute() {
    if (_navTarget == null) return;
    final userPoint = _effectiveUserLatLng;
    if (userPoint != null) {
      _routeStartPosition = userPoint;
      _nextWaypointIndex = 1;
      _currentStepIndex = 0;
      if (_isTurnByTurn) {
        _followUserIfTurnByTurn(userPoint);
      } else {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                userPoint.latitude < _navTarget!.coordinates.latitude
                    ? userPoint.latitude
                    : _navTarget!.coordinates.latitude,
                userPoint.longitude < _navTarget!.coordinates.longitude
                    ? userPoint.longitude
                    : _navTarget!.coordinates.longitude,
              ),
              northeast: LatLng(
                userPoint.latitude > _navTarget!.coordinates.latitude
                    ? userPoint.latitude
                    : _navTarget!.coordinates.latitude,
                userPoint.longitude > _navTarget!.coordinates.longitude
                    ? userPoint.longitude
                    : _navTarget!.coordinates.longitude,
              ),
            ),
            80,
          ),
        );
      }
    } else if (_isTurnByTurn) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _navTarget!.coordinates,
            zoom: _followCameraZoom,
            tilt: _followCameraTilt,
            bearing: _followCameraBearing,
          ),
        ),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_navTarget!.coordinates, 16),
      );
    }
    setState(() => _isOffRoute = false);
  }

  /// Resolves where the map should center when there's no specific
  /// [_navTarget] to navigate to: the user's selected starting gate (spec
  /// Section 1.2) if one was chosen, otherwise the previous Fort
  /// Santiago-area default.
  LatLng get _fallbackCameraTarget {
    final gateId = GateSelectionService.instance.selectedGateId;
    if (gateId != null) {
      final gate = GateService().getGateById(gateId);
      if (gate != null) return gate.coordinates;
    }
    return const LatLng(14.5951, 120.9718);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: _isBrowseMode
          ? _buildBrowseMode(context, colors)
          : _buildActiveNavigationMode(context, colors),
    );
  }

  // ─── Browse Mode ──────────────────────────────────────────────────────────

  Widget _buildBrowseMode(BuildContext context, AppColors colors) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              GoogleMap(
                mapType: _mapType,
                initialCameraPosition: CameraPosition(
                  target: _fallbackCameraTarget,
                  zoom: 16,
                ),
                markers: _buildMarkers(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (c) => _mapController = c,
              ),
              Positioned(
                bottom: 14,
                right: 20,
                child: _MapLayerToggleButton(
                  isSatelliteView: _mapType == MapType.satellite,
                  onToggle: () => setState(() {
                    _mapType = _mapType == MapType.satellite
                        ? MapType.normal
                        : MapType.satellite;
                  }),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 20,
                child: _ExplorePoiMapButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OsmPoiMapScreen()),
                  ),
                ),
              ),
              // Persistent search bar + filter chip row (always visible,
              // per spec: not tap-to-reveal).
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NavSearchBar(
                      colors: colors,
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchTerm = v),
                      onClear: _clearSearch,
                    ),
                    if (_searchTerm.trim().isNotEmpty)
                      _NavSearchResultsList(
                        colors: colors,
                        searchTerm: _searchTerm.trim(),
                        results: _searchResults,
                        onSelect: _onSearchResultTapped,
                      ),
                    const SizedBox(height: 10),
                    _NavFilterChipRow(
                      colors: colors,
                      categories: _navFilterCategories,
                      activeCategories: _activeCategoryFilters,
                      onToggle: _toggleCategoryFilter,
                      onOpenItineraries: _openItinerariesHub,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildAccessibilityPanel(colors),
      ],
    );
  }

  // ─── Active Navigation Mode ───────────────────────────────────────────────

  Widget _buildActiveNavigationMode(BuildContext context, AppColors colors) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              GoogleMap(
                mapType: _mapType,
                // Initial framing is a placeholder only — whichever of
                // [_fitBirdsEyeBoundsOnce] / the turn-by-turn following
                // camera applies takes over as soon as a position is
                // available (from `onMapCreated` below, or from
                // `_initializeLocation` if GPS resolves first).
                initialCameraPosition: CameraPosition(
                  target: _navTarget?.coordinates ?? _fallbackCameraTarget,
                  zoom: _isTurnByTurn ? _followCameraZoom : 16,
                  tilt: _isTurnByTurn ? _followCameraTilt : 0,
                ),
                markers: _buildMarkers(),
                polylines: _buildRouteLine(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (c) {
                  _mapController = c;
                  _applyModeSpecificCamera();
                },
              ),
              Positioned(
                bottom: 14,
                right: 20,
                child: _MapLayerToggleButton(
                  isSatelliteView: _mapType == MapType.satellite,
                  onToggle: () => setState(() {
                    _mapType = _mapType == MapType.satellite
                        ? MapType.normal
                        : MapType.satellite;
                  }),
                ),
              ),
              // Back button (addendum spec 2.1) — this screen has no
              // AppBar of its own (full-bleed map + floating controls), so
              // the back affordance is a floating circular button matching
              // the style of the other floating map controls on this
              // screen, rather than the "‹" text-link pattern used on
              // scrollable-content screens elsewhere in the app.
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                child: _MapBackButton(onTap: () => Navigator.maybePop(context)),
              ),
              // Recenter button
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                right: 17,
                child: GestureDetector(
                  onTap: _recenterOnRoute,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isOffRoute ? colors.forest : colors.card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.navigation_outlined,
                      color: _isOffRoute ? Colors.white : colors.forest,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Route-fallback indicator: whenever the real, street-
              // following ORS route couldn't be fetched (missing/invalid
              // key, network error, rate limit, no route found, etc.),
              // this must be visible on screen — not just logged to the
              // debug console — so a fallback to the static walking-path
              // graph / straight line is never silent. Shown in both view
              // modes since both render whichever route line
              // [_buildRouteLine] resolved to. Sits above the maneuver
              // card in turn-by-turn view (which shifts down to make room
              // for it, below) and at the maneuver card's usual position
              // in bird's-eye view, which has no maneuver card of its own.
              if (_realRouteFailureReason != null)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      (_isTurnByTurn ? 12 : 64),
                  left: 68,
                  right: 68,
                  child: _buildRouteFallbackBadge(colors),
                ),
              // Top maneuver card (addendum spec Section 1, Google NavSDK
              // reference): maneuver icon, distance to the next turn, and
              // the current street/waypoint name — positioned near the
              // top of the map like Google's turn-by-turn card, not
              // living inside the bottom sheet. Sized smaller than the
              // reference since this app's card doesn't need the same
              // visual weight. Only shown in turn-by-turn view, same
              // condition as the bottom sheet below. Shifts down when the
              // fallback badge above is also showing, so the two never
              // overlap.
              if (_isTurnByTurn)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      (_realRouteFailureReason != null ? 64 : 12) +
                      52,
                  left: 68,
                  right: 68,
                  child: _buildTopManeuverCard(colors),
                ),
              // Turn-by-turn draggable directions panel (addendum spec
              // Section 1) — deliberately absent in bird's-eye mode,
              // which is meant to stay a clean overview map with just the
              // route line (per user-confirmed decision: view mode
              // controls this panel; the separate Accessibility/Live
              // Updates panel below is orthogonal and shown/hidden purely
              // by its own Settings toggle regardless of view mode). Now
              // holds only the ETA/distance summary and target name — the
              // maneuver card itself lives at the top of the screen
              // instead (see above).
              if (_isTurnByTurn) _buildTurnByTurnPanel(colors),
            ],
          ),
        ),
        _buildAccessibilityPanel(colors),
      ],
    );
  }

  /// Small, visible indicator shown whenever the real ORS route fetch
  /// failed and the rendered route line fell back to the static
  /// walking-path graph (or, if that also can't resolve, a direct
  /// straight line). A fallback here must never be silent — the
  /// underlying reason (from [_realRouteFailureReason]) is shown directly
  /// rather than just logged to the debug console.
  Widget _buildRouteFallbackBadge(AppColors colors) {
    final reason = _realRouteFailureReason;
    if (reason == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB25E00),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Approximate route: $reason',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Top-of-screen maneuver card for turn-by-turn view (addendum spec
  /// Section 1, Google NavSDK reference style): maneuver icon, distance
  /// to the next turn, and the current street/waypoint name proxy,
  /// anchored near the top of the map rather than inside the bottom
  /// sheet. Deliberately smaller/lighter-weight than Google's own card —
  /// this app's version doesn't need the same visual prominence — but
  /// keeps the same information and general layout (icon + distance up
  /// top, street/waypoint name below).
  Widget _buildTopManeuverCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.forest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_nextTurnIcon(), color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDistanceToNextTurn(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _nextTurnLabel(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.signpost_outlined,
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _currentStreetProxy(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Live heading indicator (addendum spec Section 1): rotates to
          // point in the direction the device is physically facing,
          // sourced from the magnetometer via flutter_compass rather than
          // GPS course-over-ground, so it still updates while the user is
          // standing still reading a plaque (user-confirmed decision).
          //
          // Isolated in its own ValueListenableBuilder so only this small
          // widget repaints on every compass tick — not the surrounding
          // card or the map (see [_headingNotifier] doc for why this
          // matters).
          ValueListenableBuilder<double?>(
            valueListenable: _headingNotifier,
            builder: (context, heading, _) {
              return Transform.rotate(
                angle: (heading ?? 0) * (math.pi / 180),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Collapsible/draggable live directions panel for turn-by-turn view
  /// (addendum spec Section 1): swipe down to shrink it and reveal more
  /// of the map, swipe back up to restore it — styled with this app's
  /// existing card/shadow language rather than a new component. Carries
  /// the ETA/distance summary and target name; the turn maneuver
  /// icon/distance/street name live in the separate top-of-screen
  /// maneuver card instead (see [_buildTopManeuverCard]).
  Widget _buildTurnByTurnPanel(AppColors colors) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.09,
        maxChildSize: 0.42,
        snap: true,
        snapSizes: const [0.09, 0.3, 0.42],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colors.paper,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.transportMode.routeColor.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.transportMode.emoji} ${widget.transportMode.label}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.transportMode.routeColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _calculateDistance(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ETA ${_calculateEta()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _navTarget?.name ?? '',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                // The turn maneuver icon, next-turn distance, and current
                // street/waypoint name have moved to the top-of-screen
                // maneuver card (see [_buildTopManeuverCard]) — this sheet
                // now only carries the ETA/distance summary and target
                // name above, plus the off-route nudge below, matching
                // the reference's split between a top maneuver card and
                // a bottom ETA summary sheet.
                if (_isOffRoute) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _recenterOnRoute,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.forest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'You\'ve strayed from the route — tap to recenter',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Shared "Live Updates" / "Accessibility Modes" panel ──────────────────

  Widget _buildAccessibilityPanel(AppColors colors) {
    return AnimatedBuilder(
      animation: AccessibilitySettingsService.instance,
      builder: (context, _) {
        // Addendum spec 4.2: when Accessibility Support is OFF in Settings,
        // the entire Live Updates / Accessibility Modes panel is hidden
        // from the Navigate flow rather than just disabling its contents.
        // This is independent of the bird's-eye/turn-by-turn view-mode
        // choice (per user-confirmed decision): the two are orthogonal —
        // view mode controls the map/route presentation, this toggle
        // alone controls whether this panel exists at all.
        if (!AccessibilitySettingsService.instance.isEnabled) {
          return const SizedBox.shrink();
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isPanelExpanded
              ? _buildExpandedPanelContent(colors)
              : _buildCollapsedPanelBar(colors),
        );
      },
    );
  }

  /// Full "Live Updates" + "Accessibility Modes" panel content, shown when
  /// [_isPanelExpanded] is true. Wrapped in a fixed-viewport-height
  /// [SizedBox] (rather than [Expanded]) so it works inside the
  /// [AnimatedSize] used to animate the collapse/expand transition —
  /// [Expanded] requires a [Flex] ancestor, which [AnimatedSize] isn't.
  Widget _buildExpandedPanelContent(AppColors colors) {
    return SizedBox(
      height: 460,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _panelHandle(colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Live Updates',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: colors.ink,
                          ),
                        ),
                        Text(
                          '${_liveUpdates.where((u) => u.isActive).length} active',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    if (_liveUpdates.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.paper,
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: Text(
                          'No accessibility modes are active.',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      )
                    else
                      ..._liveUpdates.map(
                        (update) => _LiveUpdateCard(
                          colors: colors,
                          update: update,
                          onTap: () {
                            if (update.type == AccessibilityType.brailleVoice) {
                              _ttsService.speak(
                                '${update.title}. ${update.subtitle}',
                              );
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.only(bottom: 13),
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: colors.muted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Text(
                        'ACCESSIBILITY MODES',
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ),
                    // Two-column grid (addendum spec 4.2) — same button
                    // styling as before, just reflowed from a vertical
                    // stack into a 2-across grid to fit all 6 modes.
                    // Cafe (addendum spec 3 Section 1.1) is inserted at
                    // index 2 so it sits directly under Vegetarian
                    // (row 2, column 1); every mode after it shifts down
                    // one slot.
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.restaurant_outlined,
                          label: 'Vegetarian',
                          isActive: _vegetarianMode,
                          onToggle: () => setState(() {
                            _vegetarianMode = !_vegetarianMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        // Cafe (WiFi & Sockets) — addendum spec 3 Section
                        // 1.1/1.2: placed directly under Vegetarian, styled
                        // identically to every other mode button in this
                        // grid, including the shared light-green active
                        // background (no per-instance color override) —
                        // Cafe's distinct light-brown treatment lives in
                        // the Live Updates feed instead (see
                        // _LiveUpdateCard._iconBg).
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.local_cafe_outlined,
                          label: 'Cafe (WiFi & Sockets)',
                          isActive: _cafeMode,
                          onToggle: () => setState(() {
                            _cafeMode = !_cafeMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.touch_app_outlined,
                          label: 'Braille / Voice',
                          isActive: _brailleVoiceMode,
                          onToggle: () {
                            setState(() {
                              _brailleVoiceMode = !_brailleVoiceMode;
                              _rebuildLiveUpdates();
                            });
                            if (_brailleVoiceMode) {
                              _ttsService.speak('Voice mode activated');
                            } else {
                              _ttsService.stop();
                            }
                          },
                        ),
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.accessible_rounded,
                          label: 'Ramps & Elevators',
                          isActive: _rampsMode,
                          onToggle: () => setState(() {
                            _rampsMode = !_rampsMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.chair_outlined,
                          label: 'Rest Areas & Seating Nearby',
                          isActive: _restAreasMode,
                          onToggle: () => setState(() {
                            _restAreasMode = !_restAreasMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.accessible_forward_rounded,
                          label: 'PWD & Senior Priority Assistance',
                          isActive: _pwdSeniorPriorityMode,
                          onToggle: () => setState(() {
                            _pwdSeniorPriorityMode = !_pwdSeniorPriorityMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          colors: colors,
                          icon: Icons.record_voice_over_outlined,
                          label: 'Audio-Described Directions',
                          isActive: _audioDescribedDirectionsMode,
                          onToggle: () {
                            setState(() {
                              _audioDescribedDirectionsMode =
                                  !_audioDescribedDirectionsMode;
                              _rebuildLiveUpdates();
                            });
                            if (_audioDescribedDirectionsMode) {
                              _ttsService.speak(
                                'Audio-described directions activated',
                              );
                            } else {
                              _ttsService.stop();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collapsed bar shown when [_isPanelExpanded] is false: just the handle
  /// and the "Live Updates" label/active count, so the map above can take
  /// up the freed space.
  Widget _buildCollapsedPanelBar(AppColors colors) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _panelHandle(colors),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Live Updates',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
          ),
          Text(
            '${_liveUpdates.where((u) => u.isActive).length} active',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }

  /// Chevron/handle control toggling [_isPanelExpanded] — tapping it
  /// collapses the Live Updates/Accessibility Modes panel down to a thin
  /// bar so the map can take up more of the screen, or restores it.
  /// Placed at the panel's top edge in both states, matching the card's
  /// existing rounded-top-corner style.
  Widget _panelHandle(AppColors colors) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            _isPanelExpanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: colors.muted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─── Nav Search Bar ─────────────────────────────────────────────────────────────
// Visually matches the existing Home screen search field (rounded pill,
// same border/line color, same hint style) — persistent and always visible
// above the map per spec 2.2/2.3, not tap-to-reveal.

class _NavSearchBar extends StatelessWidget {
  final AppColors colors;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _NavSearchBar({
    required this.colors,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 19, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search Intramuros...',
                hintStyle: TextStyle(
                  color: colors.muted.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 18, color: colors.muted),
            ),
        ],
      ),
    );
  }
}

// ─── Nav Search Results List ────────────────────────────────────────────────────
// Search-as-you-type dropdown, scoped exclusively to this app's own dataset
// (spec 2.3) — never pulls in general Google Maps results.

class _NavSearchResultsList extends StatelessWidget {
  final AppColors colors;
  final String searchTerm;
  final List<LocationModel> results;
  final ValueChanged<LocationModel> onSelect;

  const _NavSearchResultsList({
    required this.colors,
    required this.searchTerm,
    required this.results,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Center(
                child: Text(
                  'No results for "$searchTerm"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colors.line),
              itemBuilder: (context, index) {
                final site = results[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: colors.forest,
                  ),
                  title: Text(
                    site.name,
                    style: TextStyle(fontSize: 13, color: colors.ink),
                  ),
                  subtitle: Text(
                    site.category,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                  onTap: () => onSelect(site),
                );
              },
            ),
    );
  }
}

// ─── Nav Filter Chip Row ────────────────────────────────────────────────────────
// Persistent, always-visible, multi-select category filter bar (spec 2.2).
// Visually matches the existing Home screen category chips (same pill
// shape, active-state color, and typography), but supports multiple active
// selections at once instead of Home's single-select behavior.

class _NavFilterChipRow extends StatelessWidget {
  final AppColors colors;
  final List<String> categories;
  final Set<String> activeCategories;
  final ValueChanged<String> onToggle;
  final VoidCallback onOpenItineraries;

  const _NavFilterChipRow({
    required this.colors,
    required this.categories,
    required this.activeCategories,
    required this.onToggle,
    required this.onOpenItineraries,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // +1 for the leading "Itineraries" entry point, kept in the same
        // scrollable row as the category filter chips per design so it
        // reads as sitting alongside Fortifications/Landmarks/Schools/
        // Parks rather than as a separate control below them. Placed
        // first in the row (per updated order: Itineraries, then
        // Fortifications/Landmarks/Schools/Parks).
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: onOpenItineraries,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.forest,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Itineraries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          final category = categories[index - 1];
          final isActive = activeCategories.contains(category);
          return GestureDetector(
            onTap: () => onToggle(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? colors.accent : const Color(0xFF1D6B4A))
                    : colors.card,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isActive
                      ? (isDark ? colors.accent : const Color(0xFF1D6B4A))
                      : (isDark ? colors.line : const Color(0xFFE5E7EB)),
                ),
                boxShadow: isActive
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : (isActive
                                ? const Color(0xFFF7FFFF)
                                : const Color(0xFF555555)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Live Update Model ──────────────────────────────────────────────────────────

class _LiveUpdate {
  final String title;
  final String subtitle;
  final AccessibilityType type;
  final bool isActive;
  const _LiveUpdate({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.isActive,
  });
}

// ─── Live Update Card ───────────────────────────────────────────────────────────

class _LiveUpdateCard extends StatelessWidget {
  final AppColors colors;
  final _LiveUpdate update;
  final VoidCallback onTap;

  const _LiveUpdateCard({
    required this.colors,
    required this.update,
    required this.onTap,
  });

  IconData _icon() {
    switch (update.type) {
      case AccessibilityType.vegetarian:
        return Icons.restaurant_outlined;
      case AccessibilityType.brailleVoice:
        return Icons.touch_app_outlined;
      case AccessibilityType.ramps:
        return Icons.accessible_rounded;
      case AccessibilityType.restAreas:
        return Icons.chair_outlined;
      case AccessibilityType.pwdSeniorPriority:
        return Icons.accessible_forward_rounded;
      case AccessibilityType.audioDescribedDirections:
        return Icons.record_voice_over_outlined;
      case AccessibilityType.cafe:
        // Same glyph as the Cafe button in Accessibility Modes (addendum
        // spec 3 Section 1.1/1.2), so the same feature reads identically
        // in both places.
        return Icons.local_cafe_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _iconBg(int index) {
    // Cafe (WiFi & Sockets) gets its own fixed light-brown icon
    // background here in the Live Updates feed, regardless of its
    // position in the cycle below — distinct from the Accessibility
    // Modes grid, where Cafe's button now uses the shared light-green
    // active color like every other mode.
    if (update.type == AccessibilityType.cafe) {
      return const Color(0xFFEAD9C9);
    }
    const colorsCycle = [
      Color(0xFFB7EDB4),
      Color(0xFFFAC0C3),
      Color(0xFFC4D5FF),
    ];
    return colorsCycle[index % colorsCycle.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _iconBg(update.type.index),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(), color: const Color(0xFF1C4034), size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    update.subtitle,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map Back Button ────────────────────────────────────────────────────────
// Floating circular back control for active-navigation mode (addendum spec
// 2.1) — this screen has no AppBar, so the back affordance is styled as a
// floating circular button matching this screen's other map controls
// (recenter button, layer toggle) instead of an AppBar's leading icon.

class _MapBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MapBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF1C4034),
          size: 20,
        ),
      ),
    );
  }
}

// ─── Explore POI Map Button ─────────────────────────────────────────────────
// Entry point into the standalone OsmPoiMapScreen (OSM POI browser + real
// walking-route lookup via OpenRouteService) — additive, doesn't replace
// this screen's own live-GPS turn-by-turn guidance flow.

class _ExplorePoiMapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExplorePoiMapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Explore POIs',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map Layer Toggle Button ────────────────────────────────────────────────
// Standard/satellite view switch, wired to GoogleMap's native `mapType`
// property. Visually matches the app's existing black accessibility-mode
// pill style (`_AccessibilityModeButton`), sized down for a floating map
// control.

class _MapLayerToggleButton extends StatelessWidget {
  final bool isSatelliteView;
  final VoidCallback onToggle;

  const _MapLayerToggleButton({
    required this.isSatelliteView,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSatelliteView
                  ? Icons.map_outlined
                  : Icons.satellite_alt_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isSatelliteView ? 'Standard' : 'Satellite',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Accessibility Mode Button ──────────────────────────────────────────────────
// Black pill in the branch design; turns a soft mint when active.

class _AccessibilityModeButton extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onToggle;

  const _AccessibilityModeButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? (isActive ? const Color(0xFF333333) : colors.card)
              : (isActive ? const Color(0xFFE1EEE5) : const Color(0xFF050505)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? (isActive ? colors.accent : colors.card)
                : (isActive ? const Color(0xFFA8C4B0) : Colors.transparent),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark || !isActive ? Colors.white : AppTheme.forest,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark || !isActive ? Colors.white : AppTheme.forest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small boolean amenity indicator chip (addendum spec 3 Section 2.2),
/// used in [_NavigationScreenState._showLocationPinSheet] to show WiFi and
/// Sockets availability for Cafe locations only. Deliberately minimal —
/// icon + short label, colored green/grey to read as available/unavailable
/// at a glance without introducing new design language.
class _AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool available;

  const _AmenityChip({
    required this.icon,
    required this.label,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? AppTheme.forest : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
