import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/gate_model.dart';

/// Static catalogue of Intramuros entry points a first-time user can select
/// as their starting gate (spec Section 1.1). Photos are direct Wikimedia
/// Commons image URLs — same hotlinking pattern already used for several
/// locations in [LocationService] — sourced and verified manually rather
/// than pulled live from any API.
class GateService {
  static final GateService _instance = GateService._internal();
  factory GateService() => _instance;
  GateService._internal();

  List<GateModel> getAllGates() => _gates;

  GateModel? getGateById(String id) {
    final matches = _gates.where((g) => g.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  static final List<GateModel> _gates = [
    // ─── Historical gates ──────────────────────────────────────────────────
    GateModel(
      id: 'puerta-santa-lucia',
      name: 'Puerta de Santa Lucia',
      kind: GateKind.historical,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/1/13/Santa_Lucia_Gate%2C_Intramuros%2C_2018_%2801%29.jpg',
      coordinates: const LatLng(14.588417, 120.973500),
    ),
    // Previously pointed at a wikimapia *page* URL (and over plain http),
    // not an image file, so this gate silently rendered its blank fallback
    // box everywhere it was shown. Replaced with a verified Wikimedia
    // Commons image file: categorised under "Royal Gate (Puerta Real) of
    // Intramuros", assessed as a quality image, by Diego Delso
    // (CC BY-SA 4.0).
    GateModel(
      id: 'puerta-real',
      name: 'Puerta Real',
      kind: GateKind.historical,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/a/a8/Puerta_Real%2C_Manila%2C_Filipinas%2C_2023-08-27%2C_DD_55.jpg',
      coordinates: const LatLng(14.587500, 120.974722),
    ),

    // ─── Modern road openings ──────────────────────────────────────────────
    GateModel(
      id: 'victoria-street',
      name: 'Victoria Street',
      kind: GateKind.modernOpening,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/4/4a/Victoria_Street_Entrance_of_Intramuros.jpg',
      coordinates: const LatLng(14.589500, 120.978667),
    ),
    GateModel(
      id: 'aduana-magallanes',
      name: 'Aduana / Magallanes',
      kind: GateKind.modernOpening,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/9/9c/Aduana_Building_4.jpg',
      coordinates: const LatLng(14.594306, 120.974083),
    ),
  ];
}
