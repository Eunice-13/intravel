import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/models/poi_model.dart';
import 'package:intravel/services/poi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PoiService', () {
    setUp(() {
      PoiService().clearCache();
    });

    test('loads and parses pois.json into a non-empty list of Poi', () async {
      final pois = await PoiService().loadPois();

      expect(pois, isNotEmpty);
      expect(pois, everyElement(isA<Poi>()));
      expect(
        pois.every((p) => p.id.isNotEmpty && p.name.isNotEmpty),
        isTrue,
      );
    });

    test('caches the result across repeated calls', () async {
      final first = await PoiService().loadPois();
      final second = await PoiService().loadPois();

      expect(identical(first, second), isTrue);
    });

    test('a known seeded POI (Fort Santiago) is present with valid coordinates', () async {
      final pois = await PoiService().loadPois();
      final fortSantiago = pois.where((p) => p.name == 'Fort Santiago');

      expect(fortSantiago, isNotEmpty);
      final poi = fortSantiago.first;
      expect(poi.coordinates.latitude, closeTo(14.5945, 0.01));
      expect(poi.coordinates.longitude, closeTo(120.9701, 0.01));
      expect(poi.category, PoiCategory.historic);
    });
  });
}
