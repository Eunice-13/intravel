import 'package:google_maps_flutter/google_maps_flutter.dart';
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
        qualifyingCategories: ['Churches'],
        hours: 4,
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
        qualifyingCategories: ['Fortifications'],
        hours: 3,
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
        qualifyingCategories: ['Landmarks', 'Parks'],
        hours: 2.5,
        maxPerPersonBudget: 100,
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
        qualifyingCategories: ['Parks'],
        hours: 2,
      ),
    ];
  }

  List<CuratedRoute> getRoutesByCategory(String category) {
    if (category == 'all') return getAllRoutes();
    return getAllRoutes().where((r) => r.category == category).toList();
  }

  List<TransportOption> getTransportOptions() {
    return const [
      // Coordinates verified via web search (addendum spec Section 4.3),
      // reusing points already established elsewhere in this project
      // rather than inventing new ones: Plaza Roma is the confirmed
      // e-tranvia stop per Intramuros Administration statements, and also
      // this project's existing walking-path graph node
      // (assets/data/walking_paths.json).
      TransportOption(
        id: 'tranvia',
        name: 'Tranvia Rental',
        emoji: '🚋',
        pricing: 'PHP 1,200/hr · PHP 4,000/4hrs · PHP 8,000/8hrs',
        discountNote: 'Includes driver & fuel',
        coordinates: LatLng(14.5917, 120.9731),
        locationLabel: 'Plaza Roma — Tranvia stop',
      ),
      // Fort Santiago is the commonly cited kalesa pickup point (Plaza
      // Moriones, just outside its entrance) per tour operator listings;
      // coordinate matches the already-verified Fort Santiago location in
      // LocationService.
      TransportOption(
        id: 'kalesa',
        name: 'Kalesa',
        emoji: '🐴',
        pricing: 'PHP 1,000/hr (Regular)',
        discountNote: 'PHP 800/hr — Seniors/PWD/Students',
        coordinates: LatLng(14.5941, 120.9725),
        locationLabel: 'Fort Santiago — Kalesa pickup point',
      ),
      // Pedicab/e-trike service in Intramuros is an ambulant "ikot" loop
      // (flagged down anywhere in the district) rather than a single
      // fixed real-world station — confirmed via web search, no exact
      // stop exists to cite. Points at the same central Plaza Roma anchor
      // used for Tranvia, explicitly labeled as a general area rather
      // than an exact address (per user decision).
      TransportOption(
        id: 'pedicab',
        name: 'Pedicab / E-Trike',
        emoji: '🛺',
        pricing: 'PHP 20 per passenger',
        legalNote: 'Per Ordinance No. 8979',
        coordinates: LatLng(14.5917, 120.9731),
        locationLabel: 'General pickup area',
      ),
      // Tripadvisor visitor reports identify Magallanes/Aduana as the
      // actual paid "Intramuros Parking"-marked lot road; coordinate
      // matches the already-verified Aduana/Magallanes gate in
      // GateService.
      TransportOption(
        id: 'parking',
        name: 'Parking',
        emoji: '🅿️',
        pricing: 'PHP 50.00 Flat Rate',
        discountNote: 'IA-managed parking areas',
        coordinates: LatLng(14.594306, 120.974083),
        locationLabel: 'Aduana / Magallanes — IA parking area',
      ),
    ];
  }
}
