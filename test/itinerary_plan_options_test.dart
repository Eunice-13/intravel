import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/services/itinerary_service.dart';
import 'package:intravel/services/route_service.dart';

/// Covers the curated-route plan-option generator added for the addendum
/// spec (Section 3.4): option count should scale with how many qualifying
/// sites exist for a route's theme, never forcing a fixed count, and
/// should degrade gracefully when fewer than 2 qualifying sites exist.
void main() {
  final routes = RouteService().getAllRoutes();
  final itineraryService = ItineraryService.instance;

  test('every curated route resolves at least one qualifying site', () {
    for (final route in routes) {
      final sites = itineraryService.qualifyingSitesForRoute(route);
      expect(
        sites,
        isNotEmpty,
        reason: '${route.name} has no qualifying sites in current data',
      );
    }
  });

  test('buildPlanOptions produces distinct, non-empty stop lists', () {
    for (final route in routes) {
      final options = itineraryService.buildPlanOptions(route);
      final qualifyingCount = itineraryService
          .qualifyingSitesForRoute(route)
          .length;

      if (qualifyingCount < 2) {
        expect(
          options,
          isEmpty,
          reason:
              '${route.name} has <2 qualifying sites and should yield no options',
        );
        continue;
      }

      expect(
        options,
        isNotEmpty,
        reason: '${route.name} should generate at least one plan option',
      );
      expect(
        options.length,
        lessThanOrEqualTo(4),
        reason: 'option count should stay within a sensible bound',
      );

      for (final option in options) {
        expect(option.stops.length, greaterThanOrEqualTo(2));
        final ids = option.stops.map((s) => s.id).toSet();
        expect(
          ids.length,
          option.stops.length,
          reason: 'a single plan option must not repeat the same site',
        );
        expect(option.hours, route.hours);
      }
    }
  });

  test('Military Defense Walk pulls only Fortifications sites', () {
    final route = routes.firstWhere((r) => r.id == 'military-defense');
    final sites = itineraryService.qualifyingSitesForRoute(route);
    expect(sites, isNotEmpty);
    for (final site in sites) {
      expect(site.category, 'Fortifications');
    }
  });

  test(
    "Student's Budget Tour respects the maxPerPersonBudget cap",
    () {
      final route = routes.firstWhere((r) => r.id == 'students-budget');
      final sites = itineraryService.qualifyingSitesForRoute(route);
      expect(sites, isNotEmpty);
      for (final site in sites) {
        expect(site.budgetRange.max, lessThanOrEqualTo(100));
      }
    },
  );
}
