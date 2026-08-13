import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_model.dart';

/// A lightweight navigation destination: just a name and coordinates
/// (plus optional photo/accessibility data when available), decoupled
/// from the full [LocationModel] shape. This lets the shared navigation
/// flow (addendum spec Section 1) target things that aren't catalogued
/// tourist sites — like a transport service's real-world pickup point
/// (Section 4.3) — without inventing a fake [LocationModel] for them.
class NavTarget {
  final String name;
  final LatLng coordinates;
  final String? imagePath;
  final List<AccessibilityFeature> accessibilityFeatures;

  /// The catalogued [LocationModel] this target was built from, if any.
  /// Non-null for every Location Details / itinerary-stop target (which
  /// enables the "View details" action in the map pin popup); null for
  /// targets with no location-details page of their own, like a
  /// transport service's real-world pickup point (addendum spec Section
  /// 4.3), which only carries a name and coordinates.
  final LocationModel? sourceLocation;

  const NavTarget({
    required this.name,
    required this.coordinates,
    this.imagePath,
    this.accessibilityFeatures = const [],
    this.sourceLocation,
  });

  /// Builds a [NavTarget] from an existing catalogued [LocationModel] —
  /// used by every entry point that already has one (Location Details,
  /// itinerary stops), so their existing photo/accessibility data still
  /// flows into the Navigate screen unchanged, and the map pin popup can
  /// still offer "View details" back to that location.
  factory NavTarget.fromLocation(LocationModel location) => NavTarget(
    name: location.name,
    coordinates: location.coordinates,
    imagePath: location.imageUrl,
    accessibilityFeatures: location.accessibilityFeatures,
    sourceLocation: location,
  );
}

/// The two navigation presentation modes a user chooses between before
/// navigation starts (addendum spec Section 1).
enum NavViewMode {
  /// Overview map showing the full route line from current position to
  /// destination, with no step-by-step directions panel.
  birdsEye,

  /// Step-by-step walking directions: live heading, distance to the next
  /// turn, and a nearest-landmark "street" proxy — styled to match
  /// Google Maps' walking-navigation experience.
  turnByTurn,
}

/// Transport modes offered when navigating within an itinerary (addendum
/// spec Section 6), matching Settings > Transport & Access exactly.
enum TransportModeOption { walk, tranvia, kalesa, pedicab }

extension TransportModeOptionDisplay on TransportModeOption {
  String get label {
    switch (this) {
      case TransportModeOption.walk:
        return 'Walk';
      case TransportModeOption.tranvia:
        return 'Tranvia Rental';
      case TransportModeOption.kalesa:
        return 'Kalesa';
      case TransportModeOption.pedicab:
        return 'Pedicab / E-Trike';
    }
  }

  String get emoji {
    switch (this) {
      case TransportModeOption.walk:
        return '🚶';
      case TransportModeOption.tranvia:
        return '🚋';
      case TransportModeOption.kalesa:
        return '🐴';
      case TransportModeOption.pedicab:
        return '🛺';
    }
  }

  /// Route-line color for this mode (addendum spec Section 6): routing
  /// itself is identical for every mode (same shared walking-path graph —
  /// there's no separate vehicle road network to route on), so the mode
  /// choice is deliberately visual-only — a distinct line color/icon,
  /// not a different calculated path.
  Color get routeColor {
    switch (this) {
      case TransportModeOption.walk:
        return const Color(0xFFDF9A43);
      case TransportModeOption.tranvia:
        return const Color(0xFF3B6FB5);
      case TransportModeOption.kalesa:
        return const Color(0xFF8B5E2B);
      case TransportModeOption.pedicab:
        return const Color(0xFFB5563B);
    }
  }
}
