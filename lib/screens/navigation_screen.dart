import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/tts_service.dart';
import '../services/gate_selection_service.dart';
import '../services/gate_service.dart';
import '../services/location_service.dart';
import '../services/walking_path_service.dart';
import 'location_details_screen.dart';

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
  GoogleMapController? _mapController;
  final TtsService _ttsService = TtsService();
  Position? _currentPosition;
  LocationModel? _targetLocation;
  StreamSubscription<Position>? _positionStream;

  // Accessibility toggles — mirrors the branch's three default-active modes.
  bool _vegetarianMode = true;
  bool _brailleVoiceMode = true;
  bool _rampsMode = true;

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
    _mapController?.dispose();
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
  }

  bool _isModeActive(AccessibilityType type) {
    switch (type) {
      case AccessibilityType.vegetarian:
        return _vegetarianMode;
      case AccessibilityType.ramps:
        return _rampsMode;
      case AccessibilityType.brailleVoice:
        return _brailleVoiceMode;
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

  // ─── Turn-by-turn routing math (straight-line, no live Directions API) ────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_targetLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId(_targetLocation!.id),
          position: _targetLocation!.coordinates,
          infoWindow: InfoWindow(title: _targetLocation!.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    if (_targetLocation != null) {
      for (final feature in _targetLocation!.accessibilityFeatures) {
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
          Marker(
            markerId: MarkerId('filter-${site.id}'),
            position: site.coordinates,
            infoWindow: InfoWindow(
              title: site.name,
              snippet: site.category,
              onTap: () => _openLocationDetails(site),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getCategoryMarkerHue(site.category),
            ),
          ),
        );
      }
      if (_focusedSearchResult != null) {
        final site = _focusedSearchResult!;
        markers.add(
          Marker(
            markerId: MarkerId('search-${site.id}'),
            position: site.coordinates,
            infoWindow: InfoWindow(
              title: site.name,
              snippet: 'Tap for details',
              onTap: () => _openLocationDetails(site),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose,
            ),
          ),
        );
      }
    }
    return markers;
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
  Set<Polyline> _buildRouteLine() {
    if (_routeStartPosition == null || _targetLocation == null) return {};
    final start = LatLng(
      _routeStartPosition!.latitude,
      _routeStartPosition!.longitude,
    );
    final end = _targetLocation!.coordinates;
    final pathWaypoints = WalkingPathService().findPath(start, end);
    return {
      Polyline(
        polylineId: const PolylineId('active-route'),
        points: pathWaypoints ?? [start, end],
        color: AppTheme.accent,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
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
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentPosition!.latitude < _targetLocation!.coordinates.latitude
                  ? _currentPosition!.latitude
                  : _targetLocation!.coordinates.latitude,
              _currentPosition!.longitude <
                      _targetLocation!.coordinates.longitude
                  ? _currentPosition!.longitude
                  : _targetLocation!.coordinates.longitude,
            ),
            northeast: LatLng(
              _currentPosition!.latitude > _targetLocation!.coordinates.latitude
                  ? _currentPosition!.latitude
                  : _targetLocation!.coordinates.latitude,
              _currentPosition!.longitude >
                      _targetLocation!.coordinates.longitude
                  ? _currentPosition!.longitude
                  : _targetLocation!.coordinates.longitude,
            ),
          ),
          80,
        ),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_targetLocation!.coordinates, 16),
      );
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
              GoogleMap(
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
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _targetLocation?.coordinates ?? _fallbackCameraTarget,
                  zoom: 16,
                ),
                markers: _buildMarkers(),
                polylines: _buildRouteLine(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (c) => _mapController = c,
                onCameraMoveStarted: () {},
              ),
              // Turn-by-turn route card overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
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
                    (_isOffRoute ? 190 : 148),
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
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 21, 24, 20),
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
                    top: BorderSide(color: colors.muted.withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(
                  'ACCESSIBILITY MODES',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
              _AccessibilityModeButton(
                icon: Icons.restaurant_outlined,
                label: 'Vegetarian',
                isActive: _vegetarianMode,
                onToggle: () => setState(() {
                  _vegetarianMode = !_vegetarianMode;
                  _rebuildLiveUpdates();
                }),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              _AccessibilityModeButton(
                icon: Icons.accessible_rounded,
                label: 'Ramps & Elevators',
                isActive: _rampsMode,
                onToggle: () => setState(() {
                  _rampsMode = !_rampsMode;
                  _rebuildLiveUpdates();
                }),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
              size: 26,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppTheme.forest : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
