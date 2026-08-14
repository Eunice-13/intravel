import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/widgets/budget_filter_sheet.dart';
import 'package:intravel/services/location_service.dart';
import 'package:intravel/services/route_service.dart';
import 'package:intravel/services/itinerary_service.dart';

/// Regression coverage for the Plans page budget filter bug: a min/max
/// range was previously implemented with "does this option's cost range
/// overlap the filter" semantics, which let options whose price exceeded
/// the chosen max still appear (e.g. a ₱500 site passing a ₱100 max
/// filter because its cheapest possible visit was ₱50). The fix compares
/// a single representative price against both bounds with `>=`/`<=`.
void main() {
  group('PlanBudgetFilter.allowsPrice', () {
    test('no bounds set allows every price', () {
      const filter = PlanBudgetFilter.none;
      expect(filter.allowsPrice(0), isTrue);
      expect(filter.allowsPrice(999999), isTrue);
    });

    test('max-only filter excludes prices above max, includes at/below max', () {
      const filter = PlanBudgetFilter(max: 100);
      expect(filter.allowsPrice(100), isTrue); // inclusive upper bound
      expect(filter.allowsPrice(99), isTrue);
      expect(filter.allowsPrice(101), isFalse);
      expect(filter.allowsPrice(500), isFalse);
    });

    test('min-only filter excludes prices below min, includes at/above min', () {
      const filter = PlanBudgetFilter(min: 50);
      expect(filter.allowsPrice(50), isTrue); // inclusive lower bound
      expect(filter.allowsPrice(51), isTrue);
      expect(filter.allowsPrice(49), isFalse);
      expect(filter.allowsPrice(0), isFalse);
    });

    test('min and max together only allow the inclusive band between them', () {
      const filter = PlanBudgetFilter(min: 50, max: 100);
      expect(filter.allowsPrice(50), isTrue);
      expect(filter.allowsPrice(75), isTrue);
      expect(filter.allowsPrice(100), isTrue);
      expect(filter.allowsPrice(49), isFalse);
      expect(filter.allowsPrice(101), isFalse);
    });

    test('a price that could exceed a tight max is correctly excluded', () {
      // This is the exact bug scenario: an option whose cheapest visit is
      // affordable but whose full price is well above the chosen max must
      // not appear once we're checking its actual price, not a range.
      const filter = PlanBudgetFilter(max: 100);
      expect(filter.allowsPrice(500), isFalse);
    });
  });

  group('Plans page budget filtering — tourist sites', () {
    test('sites priced above the chosen max are excluded', () {
      const filter = PlanBudgetFilter(max: 60);
      final sites = LocationService().getAllLocations();
      final visible = sites.where(
        (site) => filter.allowsPrice(site.budgetRange.min),
      );
      expect(visible, isNotEmpty, reason: 'sanity: some sites should pass');
      for (final site in visible) {
        expect(
          site.budgetRange.min,
          lessThanOrEqualTo(60),
          reason: '${site.name} should not appear above the ₱60 max',
        );
      }
      final excluded = sites.where(
        (site) => !filter.allowsPrice(site.budgetRange.min),
      );
      for (final site in excluded) {
        expect(site.budgetRange.min, greaterThan(60));
      }
    });

    test('sites priced below the chosen min are excluded', () {
      const filter = PlanBudgetFilter(min: 100);
      final sites = LocationService().getAllLocations();
      final visible = sites.where(
        (site) => filter.allowsPrice(site.budgetRange.min),
      );
      expect(visible, isNotEmpty, reason: 'sanity: some sites should pass');
      for (final site in visible) {
        expect(site.budgetRange.min, greaterThanOrEqualTo(100));
      }
    });

    test('a min/max range keeps only sites within the inclusive band', () {
      const filter = PlanBudgetFilter(min: 20, max: 100);
      final sites = LocationService().getAllLocations();
      for (final site in sites) {
        final included = filter.allowsPrice(site.budgetRange.min);
        final withinBand =
            site.budgetRange.min >= 20 && site.budgetRange.min <= 100;
        expect(
          included,
          withinBand,
          reason:
              '${site.name} (₱${site.budgetRange.min}) inclusion should match the ₱20-100 band',
        );
      }
    });
  });

  group('Plans page budget filtering — curated routes', () {
    ({double min, double max})? scaledRouteCost(route) {
      final sites = ItineraryService.instance.qualifyingSitesForRoute(route);
      if (sites.isEmpty) return null;
      final mins = sites.map((s) => s.budgetRange.min);
      final maxs = sites.map((s) => s.budgetRange.max);
      return (
        min: mins.reduce((a, b) => a < b ? a : b),
        max: maxs.reduce((a, b) => a > b ? a : b),
      );
    }

    test('routes whose cheapest qualifying site exceeds the max are excluded', () {
      const filter = PlanBudgetFilter(max: 20);
      final routes = RouteService().getAllRoutes();
      for (final route in routes) {
        final cost = scaledRouteCost(route);
        if (cost == null) continue;
        final included = filter.allowsPrice(cost.min);
        expect(included, cost.min <= 20);
      }
    });

    test('the same min/max values applied to routes and sites use identical comparison logic', () {
      // Both categories must be filtered with the same allowsPrice() rule
      // (spec requirement: same min/max values, same inclusion semantics).
      const filter = PlanBudgetFilter(min: 15, max: 150);
      final routes = RouteService().getAllRoutes();
      final sites = LocationService().getAllLocations();

      for (final route in routes) {
        final cost = scaledRouteCost(route);
        if (cost == null) continue;
        expect(
          filter.allowsPrice(cost.min),
          cost.min >= 15 && cost.min <= 150,
        );
      }
      for (final site in sites) {
        expect(
          filter.allowsPrice(site.budgetRange.min),
          site.budgetRange.min >= 15 && site.budgetRange.min <= 150,
        );
      }
    });
  });
}
