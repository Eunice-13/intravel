import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/tts_service.dart';
import '../services/gate_selection_service.dart';
import '../services/gate_service.dart';
import '../services/location_service.dart';
import '../services/walking_path_service.dart';
import '../services/accessibility_settings_service.dart';
import '../widgets/location_photo.dart';
import 'location_details_screen.dart';
import 'osm_poi_map_screen.dart';

/// Navigation screen. Visual language (route-card overlay, recenter button,
/// Live Updates list, black accessibility-mode pills) is ported from the
/// Eunice-branch `#screen-navigation` markup, while the actual mapping is
/// backed by the native Google Maps SDK, geolocator GPS stream, and the
/// flutter_tts voice-mode integration already wired up in this build.
///
/// Two modes (spec Section 2.2):
///  - Browse mode (`targetLocation == null`, reached from the bottom nav
///    tab): shows a persistent, always-visible search bar and multi-select
///    category filter row above the map.
///  - Active navigation mode (`targetLocation` set via "Navigate Now" on
///    the details screen): shows a live turn-by-turn style card with a
///    walking route line, compass heading, distance, and ETA instead.
///
/// Routing note: distance/heading/ETA are computed directly from the
/// coordinates already in [LocationService] (haversine distance + great
/// circle bearing) rather than pulled from the Google Directions API. This
/// keeps the route "as the crow flies" instead of snapped to actual streets
/// — a deliberate tradeoff to avoid introducing a billed, live API
/// dependency, consistent with the spec's stated preference elsewhere to
/// keep photos/reviews as static, cost-free content.
class NavigationScreen extends StatefulWidget {
  final LocationModel? targetLocation;

  const NavigationScreen({super.key, this.targetLocation});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _isSatelliteView = false;
  bool _isPanelExpanded = true;
  final TtsService _ttsService = TtsService();
  Position? _currentPosition;
  LocationModel? _targetLocation;
  StreamSubscription<Position>? _positionStream;

  /// The location whose photo+name popup is currently shown above its pin
  /// (spec Section 5) — set by tapping any marker that has an associated
  /// [LocationModel] (target, browse-mode filtered pins, focused search
  /// result); cleared by tapping the popup itself, another pin, or the map
  /// background. Not used for the "You are here" marker, which has no
  /// associated location record/photo.
  LocationModel? _selectedPinLocation;

  // Accessibility toggles — mirrors the branch's three default-active modes.
  bool _vegetarianMode = true;
  bool _brailleVoiceMode = true;
  bool _rampsMode = true;

  // 3 additional confirmed modes (addendum spec Section 4.2) — default to
  // active, matching the existing three's default-on behavior.
  bool _restAreasMode = true;
  bool _pwdSeniorPriorityMode = true;
  bool _audioDescribedDirectionsMode = true;

  final List<_LiveUpdate> _liveUpdates = [];

  /// The user's position when active navigation started, used as the fixed
  /// start point of the rendered route line so off-route detection has a
  /// stable line to measure deviation against (a line redrawn from the
  /// live position every update would never register as "off route").
  Position? _routeStartPosition;

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

  bool get _isBrowseMode => _targetLocation == null;

  @override
  void initState() {
    super.initState();
    _targetLocation = widget.targetLocation;
    _initializeLocation();
    _rebuildLiveUpdates();
    WalkingPathService().ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _setRouteStartIfNeeded(Position position) {
    if (_targetLocation != null && _routeStartPosition == null) {
      _routeStartPosition = position;
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _rebuildLiveUpdates() {
    _liveUpdates.clear();
    if (_targetLocation != null &&
        _targetLocation!.accessibilityFeatures.isNotEmpty) {
      for (final feature in _targetLocation!.accessibilityFeatures) {
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
      _setRouteStartIfNeeded(position);
      if (mounted) setState(() => _currentPosition = position);
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((Position position) {
            if (mounted) {
              setState(() {
                _currentPosition = position;
                _checkOffRoute();
              });
            }
          });
    } catch (_) {}
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
    _mapController.move(site.coordinates, 17);
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

  // ─── Turn-by-turn routing math (straight-line, no live Directions API) ────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_targetLocation != null) {
      markers.add(_locationPinMarker(_targetLocation!, color: _hueToColor(_HueColors.green)));
    }
    if (_currentPosition != null) {
      markers.add(
        _pinMarker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          color: _hueToColor(_HueColors.blue),
          onTap: () => _showMarkerInfo(title: 'You are here'),
        ),
      );
    }
    if (_targetLocation != null) {
      for (final feature in _targetLocation!.accessibilityFeatures) {
        if (feature.location == null) continue;
        if (_isModeActive(feature.type)) {
          markers.add(
            _pinMarker(
              point: feature.location!,
              color: _hueToColor(_getMarkerHue(feature.type)),
              onTap: () => _showMarkerInfo(
                title: feature.name,
                snippet: feature.description,
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
          _locationPinMarker(
            site,
            color: _hueToColor(_getCategoryMarkerHue(site.category)),
          ),
        );
      }
      if (_focusedSearchResult != null) {
        markers.add(
          _locationPinMarker(
            _focusedSearchResult!,
            color: _hueToColor(_HueColors.rose),
          ),
        );
      }
    }
    return markers;
  }

  /// Builds a flutter_map [Marker] for a location pin (spec Section 5):
  /// tapping it shows [_selectedPinLocation]'s photo+name popup above the
  /// pin (see [_LocationPinPopup]) instead of google_maps_flutter's
  /// text-only `InfoWindow`, which can't display an image. Used for every
  /// marker that has an associated [LocationModel] — target location,
  /// browse-mode filtered pins, and the focused search result — but not
  /// the "You are here" current-position marker, which has no location
  /// record/photo of its own (see [_pinMarker] for that one).
  Marker _locationPinMarker(LocationModel location, {required Color color}) {
    return _pinMarker(
      point: location.coordinates,
      color: color,
      onTap: () => setState(() => _selectedPinLocation = location),
    );
  }

  /// Builds a single flutter_map [Marker] rendered as a colored pin icon.
  /// [onTap] replaces google_maps_flutter's `InfoWindow`/`InfoWindow.onTap`
  /// — flutter_map has no built-in info-bubble widget, so tapping a marker
  /// either opens details directly (matching the original `onTap` pins) or
  /// shows a bottom sheet with the same title/snippet text the InfoWindow
  /// used to display (see `_showMarkerInfo`).
  Marker _pinMarker({
    required LatLng point,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(
          Icons.location_on,
          color: color,
          size: 40,
        ),
      ),
    );
  }

  /// Shows the same title/snippet text an `InfoWindow` bubble used to
  /// display, in a bottom sheet — flutter_map has no inline map-anchored
  /// info-bubble equivalent (see migration note on [_pinMarker]). Still
  /// used for accessibility-feature markers, which have no associated
  /// [LocationModel]/photo and so don't qualify for [_LocationPinPopup]
  /// (spec Section 5 only covers markers that represent a real location).
  void _showMarkerInfo({required String title, String? snippet}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (snippet != null) ...[
                const SizedBox(height: 6),
                Text(snippet, style: const TextStyle(fontSize: 13)),
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

  /// The floating photo+name popup for [_selectedPinLocation] (spec
  /// Section 5), positioned above whichever pin was tapped by converting
  /// its map coordinate to a screen offset via [MapCamera]. Rebuilds on
  /// every map event so the popup tracks the pin as the user pans/zooms;
  /// returns an empty widget when no pin is selected. Insert this as the
  /// last child of each mode's map [Stack] so it floats above the
  /// [FlutterMap] and its other overlays.
  Widget _buildPinPopupOverlay() {
    final selected = _selectedPinLocation;
    if (selected == null) return const SizedBox.shrink();
    return StreamBuilder<MapEvent>(
      stream: _mapController.mapEventStream,
      builder: (context, _) {
        // Uses the controller's own `camera` getter rather than
        // `MapCamera.of(context)` — this widget is placed as a sibling of
        // `FlutterMap` in the enclosing `Stack`, not inside its
        // `children`, so there's no `FlutterMap` ancestor in this
        // context for `MapCamera.of` to find (it throws a `StateError`
        // otherwise). `_mapController.camera` needs no such ancestor.
        final camera = _mapController.camera;
        final offset = camera.latLngToScreenOffset(selected.coordinates);
        return Positioned(
          left: offset.dx - 90,
          top: offset.dy - 108,
          child: _LocationPinPopup(
            location: selected,
            onTap: () {
              setState(() => _selectedPinLocation = null);
              _openLocationDetails(selected);
            },
            onClose: () => setState(() => _selectedPinLocation = null),
          ),
        );
      },
    );
  }

  /// Renders the user's live position as a blue dot, replacing
  /// google_maps_flutter's built-in `myLocationEnabled` blue-dot layer —
  /// flutter_map has no built-in "my location" layer, so it's driven
  /// directly from the same geolocator position stream used elsewhere on
  /// this screen (unchanged).
  Marker _currentPositionMarker() {
    return Marker(
      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4285F4),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  /// The active base tile layer — OpenStreetMap standard tiles, or Esri
  /// World Imagery satellite tiles when [_isSatelliteView] is toggled on.
  /// Both are free, keyless tile sources (no Google Maps billing
  /// dependency).
  TileLayer _tileLayer() {
    if (_isSatelliteView) {
      return TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.example.intravel',
      );
    }
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.intravel',
      subdomains: const [],
    );
  }

  _HueColors _getCategoryMarkerHue(String category) {
    switch (category) {
      case 'Fortifications':
        return _HueColors.red;
      case 'Landmarks':
        return _HueColors.orange;
      case 'Schools':
        return _HueColors.yellow;
      case 'Parks':
        return _HueColors.green;
      default:
        return _HueColors.azure;
    }
  }

  _HueColors _getMarkerHue(AccessibilityType type) {
    switch (type) {
      case AccessibilityType.vegetarian:
        return _HueColors.green;
      case AccessibilityType.ramps:
        return _HueColors.violet;
      case AccessibilityType.brailleVoice:
        return _HueColors.orange;
      default:
        return _HueColors.red;
    }
  }

  /// Maps the marker "hue" categories this screen used with
  /// `BitmapDescriptor.defaultMarkerWithHue` to concrete pin colors for the
  /// flutter_map `Icon`-based markers (flutter_map has no built-in
  /// hue-tinted default-pin equivalent, so colors are chosen to closely
  /// match each named Google Maps hue).
  Color _hueToColor(_HueColors hue) {
    switch (hue) {
      case _HueColors.green:
        return const Color(0xFF34A853);
      case _HueColors.blue:
        return const Color(0xFF4285F4);
      case _HueColors.red:
        return const Color(0xFFEA4335);
      case _HueColors.orange:
        return const Color(0xFFFF9800);
      case _HueColors.yellow:
        return const Color(0xFFFBBC04);
      case _HueColors.violet:
        return const Color(0xFF8E24AA);
      case _HueColors.azure:
        return const Color(0xFF4FC3F7);
      case _HueColors.rose:
        return const Color(0xFFE91E63);
    }
  }

  double? get _distanceMeters {
    if (_currentPosition == null || _targetLocation == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _targetLocation!.coordinates.latitude,
      _targetLocation!.coordinates.longitude,
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
  /// distance computed above.
  String _calculateEta() {
    final d = _distanceMeters;
    if (d == null) return '—';
    final minutes = (d / 1.3 / 60).ceil();
    if (minutes < 1) return '<1 min';
    return '$minutes min';
  }

  /// Compass bearing from the user's current position to the target,
  /// converted into a plain-language walking instruction. This is the
  /// straight-line equivalent of Google's turn-by-turn text since there is
  /// no street-graph routing engine wired in (see routing note above).
  String _turnInstruction() {
    if (_currentPosition == null || _targetLocation == null) {
      return 'Waiting for your location…';
    }
    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _targetLocation!.coordinates.latitude,
      _targetLocation!.coordinates.longitude,
    );
    final normalized = (bearing + 360) % 360;
    const directions = [
      'north',
      'northeast',
      'east',
      'southeast',
      'south',
      'southwest',
      'west',
      'northwest',
    ];
    final index = ((normalized + 22.5) / 45).floor() % 8;
    final d = _distanceMeters ?? 0;
    if (d < 15) return 'You have arrived at ${_targetLocation!.name}';
    return 'Head ${directions[index]} toward ${_targetLocation!.name}';
  }

  IconData _turnIcon() {
    if (_currentPosition == null || _targetLocation == null) {
      return Icons.navigation_outlined;
    }
    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _targetLocation!.coordinates.latitude,
      _targetLocation!.coordinates.longitude,
    );
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

  /// The route line rendered on the map between where navigation started
  /// and the target. When both points are near the shared static
  /// walking-path graph (assets/data/walking_paths.json, loaded via
  /// [WalkingPathService]), this traces the graph's walkable segments
  /// instead of a raw straight line; otherwise it falls back to the
  /// original direct-line behavior. Either way, the line is fixed at
  /// route-start — a stable reference the user can be measured as deviating
  /// from, unlike a line that redraws from the live position every update
  /// (which could never register as off-route).
  List<Polyline> _buildRouteLine() {
    if (_routeStartPosition == null || _targetLocation == null) return [];
    final start = LatLng(
      _routeStartPosition!.latitude,
      _routeStartPosition!.longitude,
    );
    final end = _targetLocation!.coordinates;
    final pathWaypoints = WalkingPathService().findPath(start, end);
    return [
      Polyline(
        points: pathWaypoints ?? [start, end],
        color: AppTheme.accent,
        strokeWidth: 5,
        pattern: StrokePattern.dashed(segments: [20.0, 10.0]),
      ),
    ];
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
    if (_currentPosition == null ||
        _targetLocation == null ||
        _routeStartPosition == null) {
      return;
    }
    final deviation = _perpendicularDistanceMeters(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(_routeStartPosition!.latitude, _routeStartPosition!.longitude),
      _targetLocation!.coordinates,
    );
    final nowOffRoute = deviation > _offRouteThresholdMeters;
    if (nowOffRoute != _isOffRoute) {
      setState(() => _isOffRoute = nowOffRoute);
    }
  }

  /// "Return to route": re-anchors the route line to the user's current
  /// position (like Google Maps recalculating after you stray) and
  /// re-centers the camera to show both the user and the destination.
  void _recenterOnRoute() {
    if (_targetLocation == null) return;
    if (_currentPosition != null) {
      _routeStartPosition = _currentPosition;
      final southWest = LatLng(
        _currentPosition!.latitude < _targetLocation!.coordinates.latitude
            ? _currentPosition!.latitude
            : _targetLocation!.coordinates.latitude,
        _currentPosition!.longitude < _targetLocation!.coordinates.longitude
            ? _currentPosition!.longitude
            : _targetLocation!.coordinates.longitude,
      );
      final northEast = LatLng(
        _currentPosition!.latitude > _targetLocation!.coordinates.latitude
            ? _currentPosition!.latitude
            : _targetLocation!.coordinates.latitude,
        _currentPosition!.longitude > _targetLocation!.coordinates.longitude
            ? _currentPosition!.longitude
            : _targetLocation!.coordinates.longitude,
      );
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(southWest, northEast),
          padding: const EdgeInsets.all(80),
        ),
      );
    } else {
      _mapController.move(_targetLocation!.coordinates, 16);
    }
    setState(() => _isOffRoute = false);
  }

  /// Resolves where the map should center when there's no specific
  /// [_targetLocation] to navigate to: the user's selected starting gate
  /// (spec Section 1.2) if one was chosen, otherwise the previous
  /// Fort Santiago-area default.
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
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _fallbackCameraTarget,
                  initialZoom: 16,
                  onTap: (_, _) =>
                      setState(() => _selectedPinLocation = null),
                ),
                children: [
                  _tileLayer(),
                  MarkerLayer(
                    markers: [
                      ..._buildMarkers(),
                      if (_currentPosition != null)
                        _currentPositionMarker(),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 14,
                right: 20,
                child: _MapLayerToggleButton(
                  isSatelliteView: _isSatelliteView,
                  onToggle: () =>
                      setState(() => _isSatelliteView = !_isSatelliteView),
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
              _buildPinPopupOverlay(),
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
    final targetName = _targetLocation?.name ?? '';
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _targetLocation?.coordinates ?? _fallbackCameraTarget,
                  initialZoom: 16,
                  onTap: (_, _) =>
                      setState(() => _selectedPinLocation = null),
                ),
                children: [
                  _tileLayer(),
                  PolylineLayer(polylines: _buildRouteLine()),
                  MarkerLayer(
                    markers: [
                      ..._buildMarkers(),
                      if (_currentPosition != null)
                        _currentPositionMarker(),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 14,
                right: 20,
                child: _MapLayerToggleButton(
                  isSatelliteView: _isSatelliteView,
                  onToggle: () =>
                      setState(() => _isSatelliteView = !_isSatelliteView),
                ),
              ),
              // Back button (addendum spec 2.1) — this screen has no
              // AppBar of its own (full-bleed map + floating controls), so
              // the back affordance is a floating circular button matching
              // the style of the other floating map controls on this
              // screen, rather than the "‹" text-link pattern used on
              // scrollable-content screens elsewhere in the app. Placed
              // above the turn-by-turn route card so the two don't overlap.
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                child: _MapBackButton(
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
              _buildPinPopupOverlay(),
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: colors.paper,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              targetName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _calculateDistance(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(_turnIcon(), size: 16, color: colors.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _turnInstruction(),
                              style: TextStyle(fontSize: 11, color: colors.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ETA ${_calculateEta()}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (_isOffRoute) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _recenterOnRoute,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
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
                                const Text(
                                  'You\'ve strayed from the route — tap to recenter',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Recenter button
              Positioned(
                top:
                    MediaQuery.of(context).padding.top +
                    (_isOffRoute ? 242 : 200),
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
            ],
          ),
        ),
        _buildAccessibilityPanel(colors),
      ],
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
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        _AccessibilityModeButton(
                          icon: Icons.restaurant_outlined,
                          label: 'Vegetarian',
                          isActive: _vegetarianMode,
                          onToggle: () => setState(() {
                            _vegetarianMode = !_vegetarianMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
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
                          icon: Icons.accessible_rounded,
                          label: 'Ramps & Elevators',
                          isActive: _rampsMode,
                          onToggle: () => setState(() {
                            _rampsMode = !_rampsMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          icon: Icons.chair_outlined,
                          label: 'Rest Areas & Seating Nearby',
                          isActive: _restAreasMode,
                          onToggle: () => setState(() {
                            _restAreasMode = !_restAreasMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
                          icon: Icons.accessible_forward_rounded,
                          label: 'PWD & Senior Priority Assistance',
                          isActive: _pwdSeniorPriorityMode,
                          onToggle: () => setState(() {
                            _pwdSeniorPriorityMode = !_pwdSeniorPriorityMode;
                            _rebuildLiveUpdates();
                          }),
                        ),
                        _AccessibilityModeButton(
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

  const _NavFilterChipRow({
    required this.colors,
    required this.categories,
    required this.activeCategories,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = activeCategories.contains(category);
          return GestureDetector(
            onTap: () => onToggle(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1D6B4A) : colors.card,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF1D6B4A)
                      : const Color(0xFFE5E7EB),
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
                      color: isActive
                          ? const Color(0xFFF7FFFF)
                          : const Color(0xFF555555),
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
      default:
        return Icons.info_outline;
    }
  }

  Color _iconBg(int index) {
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

// ─── Marker Hue Categories ───────────────────────────────────────────────────
// Mirrors the named-hue categories used with google_maps_flutter's
// `BitmapDescriptor.defaultMarkerWithHue` (see `_hueToColor` for the actual
// color mapping used by the flutter_map pin icons).

enum _HueColors { green, blue, red, orange, yellow, violet, azure, rose }

// ─── Location Pin Popup ─────────────────────────────────────────────────────
// Photo + name bubble shown above a tapped pin (spec Section 5), replacing
// google_maps_flutter's text-only `InfoWindow` — which can't display an
// image by design — for every marker with an associated [LocationModel].
// Reuses the same single canonical photo (`LocationModel.imageUrl`) and
// fallback treatment as the rest of the app via [LocationPhoto].

class _LocationPinPopup extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _LocationPinPopup({
    required this.location,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: LocationPhoto(
                  imagePath: location.imageUrl,
                  fallbackColor: colors.forest.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                location.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.close_rounded, size: 16, color: colors.muted),
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
// Standard/satellite tile switch. Visually matches the app's existing
// black accessibility-mode pill style (`_AccessibilityModeButton`), sized
// down for a floating map control.

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
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onToggle;

  const _AccessibilityModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE1EEE5) : const Color(0xFF050505),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? const Color(0xFFA8C4B0) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.forest : Colors.white,
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
                  color: isActive ? AppTheme.forest : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
