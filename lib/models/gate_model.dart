import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Classification shown as the small label on each gate card, matching the
/// spec's "historical vs. modern opening" distinction.
enum GateKind { historical, modernOpening }

/// An Intramuros entry point the user can select on first launch to set
/// their starting position/orientation for navigation (spec Section 1).
class GateModel {
  final String id;
  final String name;
  final GateKind kind;
  final String imageUrl;
  final LatLng coordinates;

  const GateModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.imageUrl,
    required this.coordinates,
  });

  String get kindLabel =>
      kind == GateKind.historical ? 'Historical Gate' : 'Modern Opening';
}
