import '../models/route_model.dart';

/// Curated routes and transport pricing, ported verbatim from the
/// Eunice-branch `routeList` / transport cards in assets/intravel/index.html.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  List<CuratedRoute> getAllRoutes() {
    return const [
      CuratedRoute(
        id: 'religious-heritage',
        name: 'Religious Heritage Trail',
        emoji: '⛪',
        groupSize: 'All group sizes',
        priceRange: '₱210–₱500',
        duration: '~4 hrs',
        category: 'Churches',
        addToBudget: 500,
<<<<<<< HEAD
        qualifyingCategories: ['Churches'],
        hours: 4,
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
      ),
      CuratedRoute(
        id: 'military-defense',
        name: 'Military Defense Walk',
        emoji: '🏰',
        groupSize: 'All group sizes',
        priceRange: '₱75–₱150',
        duration: '~3 hrs',
        category: 'Fortifications',
        addToBudget: 150,
<<<<<<< HEAD
        qualifyingCategories: ['Fortifications'],
        hours: 3,
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
      ),
      CuratedRoute(
        id: 'students-budget',
        name: "Student's Budget Tour",
        emoji: '🎒',
        groupSize: 'All group sizes',
        priceRange: 'Free–₱100',
        duration: '~2.5 hrs',
        category: 'Landmarks',
        addToBudget: 100,
<<<<<<< HEAD
        qualifyingCategories: ['Landmarks', 'Parks'],
        hours: 2.5,
        maxPerPersonBudget: 100,
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
      ),
      CuratedRoute(
        id: 'plazas-open',
        name: 'Plazas & Open Spaces',
        emoji: '🌿',
        groupSize: 'All group sizes',
        priceRange: 'Free',
        duration: '~2 hrs',
        category: 'Parks',
        addToBudget: 0,
<<<<<<< HEAD
        qualifyingCategories: ['Parks'],
        hours: 2,
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
      ),
    ];
  }

  List<CuratedRoute> getRoutesByCategory(String category) {
    if (category == 'all') return getAllRoutes();
    return getAllRoutes().where((r) => r.category == category).toList();
  }

  List<TransportOption> getTransportOptions() {
    return const [
      TransportOption(
        id: 'tranvia',
        name: 'Tranvia Rental',
        emoji: '🚋',
        pricing: 'PHP 1,200/hr · PHP 4,000/4hrs · PHP 8,000/8hrs',
        discountNote: 'Includes driver & fuel',
      ),
      TransportOption(
        id: 'kalesa',
        name: 'Kalesa',
        emoji: '🐴',
        pricing: 'PHP 1,000/hr (Regular)',
        discountNote: 'PHP 800/hr — Seniors/PWD/Students',
      ),
      TransportOption(
        id: 'pedicab',
        name: 'Pedicab / E-Trike',
        emoji: '🛺',
        pricing: 'PHP 20 per passenger',
        legalNote: 'Per Ordinance No. 8979',
      ),
      TransportOption(
        id: 'parking',
        name: 'Parking',
        emoji: '🅿️',
        pricing: 'PHP 50.00 Flat Rate',
        discountNote: 'IA-managed parking areas',
      ),
    ];
  }
}
