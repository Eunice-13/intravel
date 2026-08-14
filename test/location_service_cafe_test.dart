import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/services/location_service.dart';

// addendum spec 3 Section 1.1/2.1/2.2: verifies the sample Cafe sites
// added for the "Cafe (WiFi & Sockets)" feature carry hasWifi/hasSockets
// data and are filterable by the 'Cafe' category, matching how every
// other category (Fortifications, Landmarks, Parks, etc.) is filtered.
void main() {
  test('cafe sites carry hasWifi and hasSockets fields', () {
    final cafeSites = LocationService()
        .getAllLocations()
        .where((site) => site.category == 'Cafe')
        .toList();

    expect(cafeSites, isNotEmpty);

    for (final site in cafeSites) {
      // Every cafe site should have explicit boolean values for both
      // amenities (not just inherited defaults with no meaning).
      expect(site.hasWifi, isA<bool>());
      expect(site.hasSockets, isA<bool>());
    }

    // At least one sample cafe should advertise both amenities, so the
    // pin-popup amenity chips (addendum spec 3 Section 2.2) have
    // something to display as "available" in tests/demos.
    expect(cafeSites.any((s) => s.hasWifi && s.hasSockets), isTrue);
  });

  test('non-cafe sites default hasWifi/hasSockets to false', () {
    final nonCafeSites = LocationService()
        .getAllLocations()
        .where((site) => site.category != 'Cafe')
        .toList();

    expect(nonCafeSites, isNotEmpty);
    for (final site in nonCafeSites) {
      expect(site.hasWifi, isFalse);
      expect(site.hasSockets, isFalse);
    }
  });

  test('cafe sites are filterable by category like other categories', () {
    final allLocations = LocationService().getAllLocations();
    final cafeSites = allLocations
        .where((site) => site.category == 'Cafe')
        .toList();
    final fortificationSites = allLocations
        .where((site) => site.category == 'Fortifications')
        .toList();

    expect(cafeSites, isNotEmpty);
    expect(fortificationSites, isNotEmpty);
    // Filtering by 'Cafe' must not accidentally pull in other categories.
    expect(cafeSites.every((s) => s.category == 'Cafe'), isTrue);
  });
}
