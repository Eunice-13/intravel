import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/nav_target.dart';
import '../models/poi_model.dart';
import '../models/route_result_model.dart';
import '../services/poi_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/location_photo.dart';
import '../widgets/nav_flow_launcher.dart';

/// Standalone POI map: Google Maps base layer (Android), category-coded
/// POI markers sourced from the bundled `pois.json` asset (see
/// `PoiService`), and a start/end POI picker that fetches a real
/// street-following walking route via [RoutingService] (OpenRouteService)
/// and renders it as a polyline.
///
/// Base map engine: `google_maps_flutter` (Android only — see README for
/// native API key setup). POI data, marker tap → photo card behavior, and
/// the OpenRouteService routing integration are unchanged from the prior
/// OSM/flutter_map build; only the underlying map widget/rendering APIs
/// changed. If the Google Maps API key is missing/invalid or the map
/// otherwise fails to initialize, [_MapLoadFailsafe] detects it and shows
/// a non-crashing fallback state with the POI list still accessible.
class OsmPoiMapScreen extends StatefulWidget {
  const OsmPoiMapScreen({super.key, RoutingService? routingService})
    : _routingServiceOverride = routingService;

  final RoutingService? _routingServiceOverride;

  @override
  State<OsmPoiMapScreen> createState() => _OsmPoiMapScreenState();
}

enum _PoiLoadState { loading, loaded, error }

enum _RouteLoadState { idle, loading, loaded, error }

enum _MapLoadState { loading, ready, failed }

class _OsmPoiMapScreenState extends State<OsmPoiMapScreen> {
  static const LatLng _defaultCenter = LatLng(14.5906, 120.9750);
  static const double _defaultZoom = 15;

  /// How long to wait for [GoogleMap.onMapCreated] to fire before treating
  /// the map as failed to load (missing/invalid API key, no Play Services,
  /// etc.) — an invalid-but-present key typically renders a blank/gray map
  /// with `onMapCreated` still firing, which this timeout does not catch;
  /// it specifically guards against the map controller never initializing
  /// at all (e.g. no Google Play services, some manifest misconfigurations)
  /// so the screen never gets stuck on an infinite loader.
  static const Duration _mapLoadTimeout = Duration(seconds: 8);

  late final RoutingService _routingService;
  GoogleMapController? _mapController;
  Timer? _mapLoadTimer;
  _MapLoadState _mapState = _MapLoadState.loading;

  _PoiLoadState _poiState = _PoiLoadState.loading;
  List<Poi> _pois = const [];
  String? _poiError;

  Poi? _startPoi;
  Poi? _endPoi;
  _RouteLoadState _routeState = _RouteLoadState.idle;
  RouteResult? _route;
  String? _routeError;

  /// Whether the non-map POI list fallback is being shown — available any
  /// time (toggle button), and shown automatically if the map fails to
  /// load, so the rest of the demo (POI browsing, photos) still works.
  bool _showListFallback = false;

  @override
  void initState() {
    super.initState();
    _routingService =
        widget._routingServiceOverride ?? OpenRouteServiceRouting();
    _startMapLoadTimeout();
    _loadPois();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    super.dispose();
  }

  void _startMapLoadTimeout() {
    _mapLoadTimer = Timer(_mapLoadTimeout, () {
      if (!mounted) return;
      if (_mapState == _MapLoadState.loading) {
        setState(() => _mapState = _MapLoadState.failed);
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapLoadTimer?.cancel();
    _mapController = controller;
    if (!mounted) return;
    setState(() => _mapState = _MapLoadState.ready);
  }

  Future<void> _loadPois() async {
    setState(() {
      _poiState = _PoiLoadState.loading;
      _poiError = null;
    });
    try {
      final pois = await PoiService().loadPois();
      if (!mounted) return;
      setState(() {
        _pois = pois;
        _poiState = _PoiLoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _poiError = e is PoiLoadException
            ? e.message
            : 'Could not load points of interest.';
        _poiState = _PoiLoadState.error;
      });
    }
  }

  Future<void> _fetchRoute() async {
    final start = _startPoi;
    final end = _endPoi;
    if (start == null || end == null) return;

    setState(() {
      _routeState = _RouteLoadState.loading;
      _routeError = null;
      _route = null;
    });

    try {
      final result = await _routingService.getWalkingRoute(
        start.coordinates,
        end.coordinates,
      );
      if (!mounted) return;
      setState(() {
        _route = result;
        _routeState = _RouteLoadState.loaded;
      });
      _fitBoundsToRoute(result.points);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = e is RoutingException
            ? e.message
            : 'Could not calculate a walking route. Please try again.';
        _routeState = _RouteLoadState.error;
      });
    }
  }

  /// [RoutingService.getWalkingRoute] and [RouteResult] operate on
  /// `latlong2`'s `LatLng` (unchanged — routing logic was not touched by
  /// this migration); the map widget itself needs
  /// `google_maps_flutter`'s own `LatLng` type instead, so points are
  /// converted at this boundary only.
  LatLng _toLatLng(ll.LatLng point) => LatLng(point.latitude, point.longitude);

  void _fitBoundsToRoute(List<ll.LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_toLatLng(points.first), 17),
      );
      return;
    }
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final p in points.skip(1)) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        60,
      ),
    );
  }

  /// Hands off to the exact same shared turn-by-turn experience every
  /// other "Navigate" button in the app uses ([NavFlowLauncher] →
  /// [NavigationScreen]) — real ORS steps, the maneuver icon/distance/
  /// street-name card, live heading-following camera — rather than a
  /// second, simplified reimplementation living only on this screen.
  /// [NavigationScreen] always routes from the user's live position (or
  /// selected gate) to the target, so the previewed [_startPoi] here is
  /// only used to draw the preview polyline above; the actual
  /// turn-by-turn session's destination is [_endPoi].
  void _startTurnByTurn() {
    final end = _endPoi;
    if (end == null) return;
    NavFlowLauncher.startWithTarget(
      context,
      target: NavTarget(
        name: end.name,
        coordinates: _toLatLng(end.coordinates),
        imagePath: end.photoPath.isEmpty ? null : end.photoPath,
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _startPoi = null;
      _endPoi = null;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  void _selectStart(Poi poi) {
    setState(() {
      _startPoi = poi;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  void _selectEnd(Poi poi) {
    setState(() {
      _endPoi = poi;
      _route = null;
      _routeState = _RouteLoadState.idle;
      _routeError = null;
    });
  }

  BitmapDescriptor _hueForCategory(PoiCategory category) {
    switch (category) {
      case PoiCategory.school:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case PoiCategory.church:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case PoiCategory.attraction:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case PoiCategory.historic:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// While a route is active (loaded, or in flight), only the start/end
  /// pins should be shown — every other POI pin is hidden so it doesn't
  /// clutter the route line, making it harder to actually follow. Normal
  /// browsing (no route requested/loaded yet, or after the user clears
  /// it via [_clearRoute]) restores the full pin set as before.
  bool get _isRouteActive =>
      _routeState == _RouteLoadState.loading ||
      _routeState == _RouteLoadState.loaded;

  Set<Marker> _buildMarkers() {
    final poisToShow = _isRouteActive
        ? _pois.where((poi) => poi.id == _startPoi?.id || poi.id == _endPoi?.id)
        : _pois;
    return poisToShow.map((poi) {
      final isStart = poi.id == _startPoi?.id;
      final isEnd = poi.id == _endPoi?.id;
      final icon = isStart
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          : isEnd
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : _hueForCategory(poi.category);
      return Marker(
        markerId: MarkerId(poi.id),
        position: _toLatLng(poi.coordinates),
        icon: icon,
        onTap: () => _showPoiSheet(poi),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    final route = _route;
    if (route == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('walking-route'),
        points: route.points.map(_toLatLng).toList(),
        color: AppTheme.accent,
        width: 5,
      ),
    };
  }

  void _showPoiSheet(Poi poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PoiBottomSheet(
        poi: poi,
        onSetStart: () {
          Navigator.of(context).pop();
          _selectStart(poi);
        },
        onSetEnd: () {
          Navigator.of(context).pop();
          _selectEnd(poi);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: const Text('Explore Intramuros'),
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        actions: [
          if (_poiState == _PoiLoadState.loaded)
            IconButton(
              icon: Icon(
                _showListFallback ? Icons.map_outlined : Icons.list_rounded,
              ),
              tooltip: _showListFallback ? 'Show map' : 'Show list',
              onPressed: () =>
                  setState(() => _showListFallback = !_showListFallback),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMapArea(colors)),
          if (!_showListFallback || _mapState != _MapLoadState.failed)
            _buildRoutePickerPanel(colors),
        ],
      ),
    );
  }

  Widget _buildMapArea(AppColors colors) {
    if (_poiState == _PoiLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_poiState == _PoiLoadState.error) {
      return _ErrorState(
        message: _poiError ?? 'Could not load points of interest.',
        onRetry: _loadPois,
      );
    }

    // Map failed to load (missing/invalid key, no Play Services, etc.) —
    // show the graceful fallback instead of a blank screen/crash. POI data
    // and photos remain accessible via the list view either way.
    if (_mapState == _MapLoadState.failed || _showListFallback) {
      return _PoiListFallback(
        pois: _pois,
        mapUnavailable: _mapState == _MapLoadState.failed,
        onPoiTap: _showPoiSheet,
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _defaultCenter,
            zoom: _defaultZoom,
          ),
          onMapCreated: _onMapCreated,
          markers: _buildMarkers(),
          polylines: _buildPolylines(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (_mapState == _MapLoadState.loading)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildRoutePickerPanel(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Walking route',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PoiDropdown(
                  label: 'Start',
                  pois: _pois,
                  selected: _startPoi,
                  onChanged: _selectStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PoiDropdown(
                  label: 'End',
                  pois: _pois,
                  selected: _endPoi,
                  onChanged: _selectEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_startPoi != null &&
                          _endPoi != null &&
                          _startPoi!.id != _endPoi!.id &&
                          _routeState != _RouteLoadState.loading)
                      ? _fetchRoute
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _routeState == _RouteLoadState.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get walking route'),
                ),
              ),
              if (_startPoi != null || _endPoi != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _clearRoute,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                ),
              ],
            ],
          ),
          if (_routeState == _RouteLoadState.error) ...[
            const SizedBox(height: 10),
            Text(
              _routeError ?? 'Could not calculate a walking route.',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_routeState == _RouteLoadState.loaded && _route != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 16,
                  color: colors.forest,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_route!.distanceLabel} · ${_route!.durationLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hands off to the same shared turn-by-turn experience every
            // other "Navigate" button in the app uses — real ORS steps,
            // maneuver card, live heading-following camera — rather than
            // a second, simplified version confined to this screen. The
            // polyline preview above stays as a quick visual aid; this
            // is the actual guided navigation entry point.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startTurnByTurn,
                icon: Icon(Icons.navigation_outlined, color: colors.forest),
                label: Text(
                  'Start turn-by-turn navigation',
                  style: TextStyle(
                    color: colors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.forest),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PoiDropdown extends StatelessWidget {
  final String label;
  final List<Poi> pois;
  final Poi? selected;
  final ValueChanged<Poi> onChanged;

  const _PoiDropdown({
    required this.label,
    required this.pois,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selected?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: pois
          .map(
            (poi) => DropdownMenuItem<String>(
              value: poi.id,
              child: Text(
                poi.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id == null) return;
        final poi = pois.firstWhere((p) => p.id == id);
        onChanged(poi);
      },
    );
  }
}

class _PoiBottomSheet extends StatelessWidget {
  final Poi poi;
  final VoidCallback onSetStart;
  final VoidCallback onSetEnd;

  const _PoiBottomSheet({
    required this.poi,
    required this.onSetStart,
    required this.onSetEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: poi.photoPath.isEmpty
                    ? Container(color: const Color(0xFF264B3C))
                    : LocationPhoto(imagePath: poi.photoPath),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              poi.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              poi.category.label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSetStart,
                    child: const Text('Set as start'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSetEnd,
                    child: const Text('Set as end'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the map when it fails to load (missing/invalid Google
/// Maps API key, no Play Services, etc.) — per the failsafe requirement,
/// the app must not crash or show a blank screen, and POI browsing should
/// keep working even without the map. Also reachable manually via the
/// list/map toggle in the app bar regardless of map load state.
class _PoiListFallback extends StatelessWidget {
  final List<Poi> pois;
  final bool mapUnavailable;
  final ValueChanged<Poi> onPoiTap;

  const _PoiListFallback({
    required this.pois,
    required this.mapUnavailable,
    required this.onPoiTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (mapUnavailable)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB25E00),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Map unavailable — check the Google Maps API key. '
                    'Points of interest are still browsable below.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A4200)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pois.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final poi = pois[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: poi.photoPath.isEmpty
                        ? Container(color: const Color(0xFF264B3C))
                        : LocationPhoto(imagePath: poi.photoPath),
                  ),
                ),
                title: Text(
                  poi.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(poi.category.label),
                onTap: () => onPoiTap(poi),
              );
            },
          ),
        ),
      ],
    );
  }
}
