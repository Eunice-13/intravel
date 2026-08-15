import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/models/location_model.dart';
import 'package:intravel/services/location_service.dart';

/// Improvement-batch spec Section 6 — the locations dataset.
///
/// The acceptance criteria this guards are the two that were actually being
/// violated: entries falling outside Intramuros, and entries landing in water.
/// Several sites previously sat in the reclaimed land west of the seafront
/// wall, in the middle of the Pasig, or (in one case) across the river in
/// Binondo, which is what put pins nowhere near the real place.
void main() {
  /// Bounds of the Intramuros district, not of the wall line itself.
  ///
  /// The district is the right envelope here because several genuine entries
  /// legitimately sit outside the walls: ravelins are by definition detached
  /// outworks (Revellin de Recoletos, Revellin Real de Bagumbayan), the
  /// Chamber of Commerce building stands on the riverside strip north of the
  /// wall, and the Pasig River Esplanade and Plaza Mexico run along that same
  /// bank. Asserting "inside the walls" would fail all of those for being
  /// correct.
  ///
  /// The northern limit is the operative one for the "not in water" rule: the
  /// Pasig's southern bank along Intramuros sits at roughly 14.5956, so
  /// anything at or beyond that is in the river.
  const double minLat = 14.5845;
  const double maxLat = 14.5955;
  const double minLng = 120.9685;
  const double maxLng = 120.9800;

  final locations = LocationService().getAllLocations();

  test('the catalogue is non-trivial', () {
    expect(locations.length, greaterThanOrEqualTo(50));
  });

  test('every location sits inside the Intramuros district envelope', () {
    final offenders = <String>[];
    for (final site in locations) {
      final c = site.coordinates;
      final inside =
          c.latitude >= minLat &&
          c.latitude <= maxLat &&
          c.longitude >= minLng &&
          c.longitude <= maxLng;
      if (!inside) {
        offenders.add('${site.name} (${c.latitude}, ${c.longitude})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these fall outside Intramuros or in the Pasig:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no two locations share the same coordinate', () {
    // A duplicated pair almost always means a copy-paste rather than a real
    // co-location, and it makes two pins sit exactly on top of each other.
    final seen = <String, String>{};
    final clashes = <String>[];
    for (final site in locations) {
      final key = '${site.coordinates.latitude},${site.coordinates.longitude}';
      final existing = seen[key];
      if (existing != null) {
        clashes.add('$existing and ${site.name} both at $key');
      } else {
        seen[key] = site.name;
      }
    }
    expect(clashes, isEmpty, reason: clashes.join('\n'));
  });

  group(
    'dataset completeness against docs/intramuros-app-spec-locations.md',
    () {
      List<LocationModel> inCategory(String category) =>
          locations.where((l) => l.category == category).toList();

      test('all 12 specified Fortifications are present', () {
        // Matched on a distinctive fragment rather than the full string, since
        // the app uses its own display names (e.g. it spells out
        // "Revellin de Puerta Real de Bagumbayan").
        const required = [
          'Baluarillo de San Juan',
          'Baluarte Plano Luneta de Santa Isabel',
          'Baluartillo de San Eugenio',
          'Baluartillo de San Jose',
          'Reducto de San Pedro',
          'Puerta Real',
          'Baluarte de San Andres',
          'Revellin de Recoletos',
          'Baluarte de Dilao',
          'Puerta del Parian',
          'Baluarte de San Gabriel',
          'Puerta Isabel II',
        ];
        final names = inCategory('Fortifications').map((l) => l.name).toList();
        for (final fragment in required) {
          expect(
            names.any((n) => n.contains(fragment)),
            isTrue,
            reason: '"$fragment" missing from the Fortifications category',
          );
        }
      });

      test('all 8 specified Parks are present', () {
        const required = [
          'Plaza Roma',
          'Plazuela de Santa Isabel',
          'Plaza de Santo Tomas',
          'Plaza España',
          'Plaza Mexico',
          'Plaza Moriones',
          'Plaza de Armas',
          'Galleria de los Presidentes',
        ];
        final names = inCategory('Parks').map((l) => l.name).toList();
        for (final fragment in required) {
          expect(
            names.any((n) => n.contains(fragment)),
            isTrue,
            reason: '"$fragment" missing from the Parks category',
          );
        }
      });

      test('all 5 specified Schools are present', () {
        const required = [
          'Pamantasan ng Lungsod ng Maynila',
          'Manila High School',
          'University', // Mapúa University (Intramuros Campus)
          'Lyceum of the Philippines',
          'Colegio de San Juan de Letran',
        ];
        final names = inCategory('Schools').map((l) => l.name).toList();
        for (final fragment in required) {
          expect(
            names.any((n) => n.contains(fragment)),
            isTrue,
            reason: '"$fragment" missing from the Schools category',
          );
        }
      });
    },
  );

  test('every non-Cafe location is reachable from one of the four Navigation '
      'filter chips', () {
    // Mirrors _NavigationScreenState._navFilterCategoryGroups. The chip row
    // is the four categories the locations spec mandates, while the dataset
    // also uses Museums and Churches — so a chip whose label is matched
    // straight against `category` silently strands those sites with pins no
    // filter can turn on. Asserted on the data because that's where the
    // mismatch originates: it reappears the moment a location is added under
    // a new category string.
    const reachable = {
      'Fortifications',
      'Landmarks',
      'Museums',
      'Churches',
      'Schools',
      'Parks',
    };
    final stranded = locations
        .where((l) => l.category != 'Cafe' && !reachable.contains(l.category))
        .map((l) => '${l.name} -> ${l.category}')
        .toSet()
        .toList();
    expect(
      stranded,
      isEmpty,
      reason:
          'no Navigation filter chip covers these categories:\n'
          '${stranded.join('\n')}',
    );
  });

  test('only the Cafe category still carries placeholder copy — spec Section '
      '6.1 leaves Cafe untouched, 6.2 requires everything else filled in', () {
    final placeholders = locations
        .where(
          (l) =>
              l.category != 'Cafe' &&
              (l.visitNote.toLowerCase().contains('placeholder') ||
                  l.description.toLowerCase().contains('placeholder')),
        )
        .map((l) => '${l.category}/${l.name}')
        .toList();
    expect(placeholders, isEmpty, reason: placeholders.join(', '));
  });
}
