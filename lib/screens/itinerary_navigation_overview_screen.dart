import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/location_model.dart';
import '../theme/app_theme.dart';
import '../widgets/nav_flow_launcher.dart';

/// Shows every stop in the currently selected itinerary order on one map.
///
/// Each connecting polyline represents a leg. Selecting a leg reveals its
/// action, which opens the existing live navigation experience for that leg's
/// destination using the device's current position.
class ItineraryNavigationOverviewScreen extends StatefulWidget {
  final String itineraryName;
  final List<LocationModel> stops;

  const ItineraryNavigationOverviewScreen({
    super.key,
    required this.itineraryName,
    required this.stops,
  });

  @override
  State<ItineraryNavigationOverviewScreen> createState() =>
      _ItineraryNavigationOverviewScreenState();
}

class _ItineraryNavigationOverviewScreenState
    extends State<ItineraryNavigationOverviewScreen> {
  GoogleMapController? _mapController;
  int? _selectedLegIndex;
  MapType _mapType = MapType.normal;

  Set<Marker> _buildMarkers() {
    return {
      for (var index = 0; index < widget.stops.length; index++)
        Marker(
          markerId: MarkerId('itinerary-stop-${widget.stops[index].id}'),
          position: widget.stops[index].coordinates,
          infoWindow: InfoWindow(
            title: '#${index + 1} ${widget.stops[index].name}',
            snippet: index == 0
                ? 'Start of itinerary'
                : index == widget.stops.length - 1
                ? 'Final stop'
                : 'Stop ${index + 1} of ${widget.stops.length}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            index == widget.stops.length - 1
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
        ),
    };
  }

  Set<Polyline> _buildLegPolylines() {
    return {
      for (var index = 0; index < widget.stops.length - 1; index++)
        Polyline(
          polylineId: PolylineId('itinerary-leg-$index'),
          points: [
            widget.stops[index].coordinates,
            widget.stops[index + 1].coordinates,
          ],
          color: _selectedLegIndex == index ? AppTheme.forest : AppTheme.accent,
          width: _selectedLegIndex == index ? 7 : 5,
          consumeTapEvents: true,
          onTap: () => setState(() => _selectedLegIndex = index),
        ),
    };
  }

  void _fitStops() {
    if (_mapController == null || widget.stops.isEmpty) return;

    if (widget.stops.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(widget.stops.first.coordinates, 16),
      );
      return;
    }

    var south = widget.stops.first.coordinates.latitude;
    var north = south;
    var west = widget.stops.first.coordinates.longitude;
    var east = west;

    for (final stop in widget.stops.skip(1)) {
      south = stop.coordinates.latitude < south
          ? stop.coordinates.latitude
          : south;
      north = stop.coordinates.latitude > north
          ? stop.coordinates.latitude
          : north;
      west = stop.coordinates.longitude < west
          ? stop.coordinates.longitude
          : west;
      east = stop.coordinates.longitude > east
          ? stop.coordinates.longitude
          : east;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        58,
      ),
    );
  }

  void _openLiveGuidance(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= widget.stops.length) return;
    // Per-leg transport choice (addendum spec Section 6, user-confirmed
    // decision): each leg independently runs the transport-mode picker
    // then the shared view-mode picker, rather than choosing one
    // transport mode for the whole itinerary session.
    NavFlowLauncher.startFromItinerary(
      context,
      location: widget.stops[targetIndex],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (widget.stops.isEmpty) {
      return Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Add stops to this itinerary before starting navigation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Text(
                      '‹',
                      style: TextStyle(
                        fontSize: 36,
                        height: 1,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '— ROUTE OVERVIEW',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.itineraryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.serifFont,
                            fontSize: 24,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: _mapType,
                    initialCameraPosition: CameraPosition(
                      target: widget.stops.first.coordinates,
                      zoom: 15,
                    ),
                    markers: _buildMarkers(),
                    polylines: _buildLegPolylines(),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onTap: (_) => setState(() => _selectedLegIndex = null),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _fitStops();
                      });
                    },
                  ),
                  Positioned(
                    top: 14,
                    left: 20,
                    right: 20,
                    child: _OverviewMapCallout(
                      colors: colors,
                      stops: widget.stops,
                      selectedLegIndex: _selectedLegIndex,
                      onNavigate: () => _openLiveGuidance(
                        _selectedLegIndex == null ? 0 : _selectedLegIndex! + 1,
                      ),
                    ),
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
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 21, 24, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stops in sequence',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            ),
                          ),
                          Text(
                            widget.stops.length == 1
                                ? '1 stop'
                                : '${widget.stops.length - 1} legs',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        itemCount: widget.stops.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) => _ItineraryStopCard(
                          colors: colors,
                          index: index,
                          stop: widget.stops[index],
                          previousStop: index == 0
                              ? null
                              : widget.stops[index - 1],
                          isSelectedLeg:
                              index > 0 && _selectedLegIndex == index - 1,
                          onTap: () {
                            setState(
                              () => _selectedLegIndex = index == 0
                                  ? null
                                  : index - 1,
                            );
                          },
                          onNavigate: () => _openLiveGuidance(index),
                        ),
                      ),
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
}

class _OverviewMapCallout extends StatelessWidget {
  final AppColors colors;
  final List<LocationModel> stops;
  final int? selectedLegIndex;
  final VoidCallback onNavigate;

  const _OverviewMapCallout({
    required this.colors,
    required this.stops,
    required this.selectedLegIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelectedLeg = selectedLegIndex != null;
    final targetIndex = hasSelectedLeg ? selectedLegIndex! + 1 : 0;
    final title = hasSelectedLeg
        ? 'Leg ${selectedLegIndex! + 1}: ${stops[selectedLegIndex!].name} → ${stops[targetIndex].name}'
        : 'Start with stop 1: ${stops.first.name}';

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasSelectedLeg ? Icons.alt_route_rounded : Icons.route_rounded,
            color: colors.accent,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNavigate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.forest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryStopCard extends StatelessWidget {
  final AppColors colors;
  final int index;
  final LocationModel stop;
  final LocationModel? previousStop;
  final bool isSelectedLeg;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const _ItineraryStopCard({
    required this.colors,
    required this.index,
    required this.stop,
    required this.previousStop,
    required this.isSelectedLeg,
    required this.onTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isFirstStop = index == 0;
    final legLabel = isFirstStop
        ? 'Start itinerary'
        : 'Leg $index · ${previousStop!.name} → ${stop.name}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
        decoration: BoxDecoration(
          color: isSelectedLeg ? colors.paper : colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelectedLeg ? colors.forest : colors.line,
            width: isSelectedLeg ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFirstStop ? colors.forest : colors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    legLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onNavigate,
              child: Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.forest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 17,
                ),
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
// pill style (see `_AccessibilityModeButton` in navigation_screen.dart),
// sized down for a floating map control.

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
