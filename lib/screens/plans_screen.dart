import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/route_service.dart';
import '../services/location_service.dart';
<<<<<<< HEAD
import '../services/itinerary_service.dart';
import '../models/route_model.dart';
import '../models/location_model.dart';
import '../widgets/budget_filter_sheet.dart';
import 'location_details_screen.dart';
import 'itinerary_create_screen.dart';
import 'route_plan_options_screen.dart';

/// Plans screen, ported from the Eunice-branch `#screen-plans` markup and
/// extended per the addendum spec (Section 3): eyebrow header + filter
/// icon opening a detailed budget-range sheet, traveler-size row that
/// scales displayed cost estimates only (never filters visible
/// sites/routes), plan-category chips, curated routes that open a
/// system-generated set of plan options to save into the Itinerary Hub,
/// a budget bar shared with the detailed filter sheet, and the full "All
/// tourist sites" directory list.
=======
import '../models/route_model.dart';
import '../models/location_model.dart';
import 'location_details_screen.dart';
import 'itinerary_create_screen.dart';

/// Plans screen, ported from the Eunice-branch `#screen-plans` markup:
/// eyebrow header + filter icon, traveler-size row with contextual hints,
/// plan-category chips, curated routes that accumulate a running budget on
/// tap, and the full "All tourist sites" directory list.
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _selectedTraveler = 'Solo';
  String _planFilter = 'all';
<<<<<<< HEAD

  /// Group-size cost multipliers (addendum spec 3.2): selecting a group
  /// size never filters which sites/routes are visible — it only scales
  /// the displayed per-person cost estimate into a total that reflects the
  /// selected group size.
  static const Map<String, int> _groupMultipliers = {
    'Solo': 1,
    'Couple': 2,
    'Group': 5,
    'Large': 10,
  };

  /// Shared budget-range filter state (addendum spec 3.1, 3.6): both the
  /// bottom budget bar and the detailed filter sheet opened from the
  /// header icon read from and write to this same state.
  PlanBudgetFilter _budgetFilter = PlanBudgetFilter.none;
  final TextEditingController _budgetBarController = TextEditingController();
  String? _budgetBarError;

  @override
  void dispose() {
    _budgetBarController.dispose();
=======
  int _estimatedTotal = 50;

  /// Max entrance fee (per adult) a user is willing to pay, entered in the
  /// dedicated "Filter by budget" field above the site list (spec 3.2).
  /// `null` means no filter is applied. This is intentionally separate from
  /// [_estimatedTotal] above, which only tracks a running total from tapping
  /// curated routes and never filters the site list.
  int? _maxBudgetFilter;
  final TextEditingController _budgetFilterController = TextEditingController();

  @override
  void dispose() {
    _budgetFilterController.dispose();
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    super.dispose();
  }

  static const List<String> _travelers = ['Solo', 'Couple', 'Group', 'Large'];
  static const Map<String, String> _travelerHints = {
    'Solo': 'Narrow walkways & Kalesa tours',
    'Couple': 'Scenic walks & quiet courtyards',
    'Group': 'Shared stops & flexible timing',
    'Large': 'Wide paths & group-friendly sites',
  };
  static const List<Map<String, String>> _planChips = [
    {'key': 'all', 'label': 'All Sites'},
    {'key': 'Fortifications', 'label': 'Fortifications'},
    {'key': 'Landmarks', 'label': 'Landmarks'},
    {'key': 'Museums', 'label': 'Museums'},
    {'key': 'Churches', 'label': 'Churches'},
    {'key': 'Parks', 'label': 'Parks'},
<<<<<<< HEAD
    {'key': 'Schools', 'label': 'Schools'},
  ];

  int get _groupMultiplier => _groupMultipliers[_selectedTraveler] ?? 1;

  /// Scales a site's per-person [LocationModel.budgetRange] by the
  /// selected group size.
  ({double min, double max}) _scaledSiteCost(LocationModel site) {
    final scaled = site.budgetRange.scaledBy(_groupMultiplier);
    return (min: scaled.min, max: scaled.max);
  }

  /// Scales a curated route's displayed cost range by the selected group
  /// size. Mirrors the HTML prototype's logic: the range spans the
  /// cheapest to the most expensive *single* qualifying site (i.e. what one
  /// stop on this route might cost), not a sum across every qualifying
  /// site — summing would make routes with many qualifying sites (e.g.
  /// Fortifications) look far more expensive than any actual visit.
  ({double min, double max})? _scaledRouteCost(CuratedRoute route) {
    final sites = ItineraryService.instance.qualifyingSitesForRoute(route);
    if (sites.isEmpty) return null;
    final mins = sites.map((site) => site.budgetRange.min);
    final maxs = sites.map((site) => site.budgetRange.max);
    final min = mins.reduce((a, b) => a < b ? a : b);
    final max = maxs.reduce((a, b) => a > b ? a : b);
    return (min: min * _groupMultiplier, max: max * _groupMultiplier);
  }

  bool _siteWithinBudget(LocationModel site) {
    if (!_budgetFilter.isActive) return true;
    final cost = _scaledSiteCost(site);
    return _budgetFilter.allowsRange(cost.min, cost.max);
  }

  bool _routeWithinBudget(CuratedRoute route) {
    if (!_budgetFilter.isActive) return true;
    final cost = _scaledRouteCost(route);
    if (cost == null) return true;
    return _budgetFilter.allowsRange(cost.min, cost.max);
  }

  void _applyBudgetFilter(PlanBudgetFilter next, {bool fromSheet = false}) {
    setState(() {
      _budgetFilter = next;
      _budgetBarError = null;
      if (!fromSheet) {
        // Bottom-bar edits only ever set an upper bound, mirroring the
        // single "Type your total budget..." field's intent.
      } else {
        // Sheet edits should also reflect back onto the bottom bar so both
        // controls stay in sync (spec 3.1: entering a value in one is
        // reflected in the other).
        _budgetBarController.text = next.max != null
            ? next.max!.round().toString()
            : (next.min != null ? next.min!.round().toString() : '');
      }
    });
  }

  Future<void> _openBudgetSheet() async {
    final result = await showBudgetFilterSheet(context, _budgetFilter);
    if (result != null) _applyBudgetFilter(result, fromSheet: true);
  }

  Future<void> _openRoutePlanOptions(CuratedRoute route) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutePlanOptionsScreen(route: route)),
=======
  ];

  void _addRouteToBudget(CuratedRoute route) {
    setState(() => _estimatedTotal += route.addToBudget);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${route.name} added'),
        duration: const Duration(seconds: 1),
      ),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
<<<<<<< HEAD
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budgetFieldColor = isDark
        ? const Color(0xFF6E8178)
        : const Color(0xFF65746C);
    final allRoutes = RouteService().getAllRoutes();
    final routes = allRoutes.where(_routeWithinBudget).toList();
    final sites = LocationService().getAllLocations().where((s) {
      final matchesCategory = _planFilter == 'all' || s.category == _planFilter;
      return matchesCategory && _siteWithinBudget(s);
=======
    final routes = RouteService().getRoutesByCategory(_planFilter);
    final sites = LocationService().getAllLocations().where((s) {
      final matchesCategory = _planFilter == 'all' || s.category == _planFilter;
      final matchesBudget =
          _maxBudgetFilter == null ||
          s.ticketInfo.adultPrice <= _maxBudgetFilter!;
      return matchesCategory && matchesBudget;
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    }).toList();

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
<<<<<<< HEAD
                        '— ITINERARY PLANNER',
=======
                        '— INTRAMUROS',
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
<<<<<<< HEAD
                        'Plan Your Way',
=======
                        'Travel Your Way',
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 27,
                          color: colors.ink,
                          letterSpacing: -0.04,
                        ),
                      ),
                    ],
                  ),
<<<<<<< HEAD
                  GestureDetector(
                    onTap: _openBudgetSheet,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _budgetFilter.isActive
                            ? colors.forest
                            : colors.card,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: _budgetFilter.isActive
                            ? Colors.white
                            : colors.ink,
                        size: 22,
                      ),
=======
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEE8DF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: colors.ink,
                      size: 22,
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Traveler Row ──────────────────────────────────────────
              Row(
                children: _travelers.map((traveler) {
                  final isActive = traveler == _selectedTraveler;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: traveler != _travelers.last ? 12 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedTraveler = traveler),
                        child: Container(
                          height: 70,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
<<<<<<< HEAD
                            color: isActive ? colors.forest : colors.card,
=======
                            color: isActive
                                ? colors.forest
                                : const Color(0xFFEDE7DC),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            traveler,
                            style: TextStyle(
                              fontFamily: AppTheme.serifFont,
                              fontSize: 16,
                              color: isActive ? Colors.white : colors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _travelerHints[_selectedTraveler]!,
                  style: TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 14,
                    color: const Color(0xFF6E8178),
                  ),
                ),
              ),
              const SizedBox(height: 27),

              // ─── Plan Chips ────────────────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _planChips.length,
<<<<<<< HEAD
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
=======
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                  itemBuilder: (context, index) {
                    final chip = _planChips[index];
                    final isActive = chip['key'] == _planFilter;
                    return GestureDetector(
                      onTap: () => setState(() => _planFilter = chip['key']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
<<<<<<< HEAD
                              ? (Theme.of(context).brightness == Brightness.dark
                                    ? colors.accent
                                    : const Color(0xFF1D7654))
=======
                              ? const Color(0xFF1D7654)
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                              : colors.card,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          chip['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive ? Colors.white : colors.ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // ─── Build Your Own Itinerary (spec 3.3) ────────────────────
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ItineraryCreateScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.forest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Build your own itinerary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

<<<<<<< HEAD
              // ─── Curated Routes (spec 3.4) ─────────────────────────────
=======
              // ─── Curated Routes ────────────────────────────────────────
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
              Text(
                'CURATED ROUTES',
                style: TextStyle(
                  color: const Color(0xFF6E8178),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 11),
<<<<<<< HEAD
              if (routes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No curated routes match this budget range.',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                )
              else
                ...routes.map(
                  (route) => _RouteCard(
                    colors: colors,
                    route: route,
                    scaledCost: _scaledRouteCost(route),
                    onTap: () => _openRoutePlanOptions(route),
                  ),
                ),
              const SizedBox(height: 20),

              // ─── Budget Bar (spec 3.1, 3.6) ─────────────────────────────
              // Shared with the detailed filter sheet opened from the
              // header icon above: editing either updates the other, and
              // both filter the curated routes and site list live.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? colors.card : const Color(0xFFEDE7DC),
=======
              ...routes.map(
                (route) => _RouteCard(
                  colors: colors,
                  route: route,
                  onTap: () => _addRouteToBudget(route),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Budget ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7DC),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
<<<<<<< HEAD
                        controller: _budgetBarController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 13, color: budgetFieldColor),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '₱ Type your total budget…',
                          hintStyle: TextStyle(color: budgetFieldColor),
                          errorText: _budgetBarError,
                        ),
                        onChanged: (v) {
                          final trimmed = v.trim();
                          final parsed = double.tryParse(trimmed);
                          final nextMax = trimmed.isEmpty
                              ? null
                              : (parsed != null && parsed >= 0
                                    ? parsed
                                    : _budgetFilter.max);
                          // Validation (addendum spec 3.1): the max
                          // budget must be greater than the min budget
                          // set via the detailed filter sheet.
                          if (nextMax != null &&
                              _budgetFilter.min != null &&
                              nextMax <= _budgetFilter.min!) {
                            setState(() {
                              _budgetBarError =
                                  'Max must be greater than min (₱${_budgetFilter.min!.round()}).';
                            });
                            return;
                          }
                          _applyBudgetFilter(
                            PlanBudgetFilter(
                              min: _budgetFilter.min,
                              max: nextMax,
                            ),
                          );
                        },
                      ),
                    ),
                    Text(
                      'Est. total\n${_formatEstimatedTotal(sites)}',
=======
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF65746C),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '₱ Type your total budget…',
                        ),
                        onChanged: (v) => setState(
                          () => _estimatedTotal =
                              int.tryParse(v) ?? _estimatedTotal,
                        ),
                      ),
                    ),
                    Text(
                      'Est. total\n₱$_estimatedTotal',
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFF6E8178),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
<<<<<<< HEAD
              const SizedBox(height: 18),

              // ─── All Tourist Sites ─────────────────────────────────────
=======
              const SizedBox(height: 6),

              // ─── Budget Filter (spec 3.2) ──────────────────────────────
              // Distinct from the curated-route budget tracker above: this
              // one actually filters "All tourist sites" below to only
              // locations whose adult entrance fee is ≤ the entered amount.
              const SizedBox(height: 18),
              Text(
                'FILTER BY BUDGET',
                style: TextStyle(
                  color: const Color(0xFF6E8178),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: colors.forest,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _budgetFilterController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 14, color: colors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '₱ Max entrance fee per site…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                        onChanged: (v) => setState(
                          () => _maxBudgetFilter = v.trim().isEmpty
                              ? null
                              : int.tryParse(v.trim()),
                        ),
                      ),
                    ),
                    if (_maxBudgetFilter != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _budgetFilterController.clear();
                          _maxBudgetFilter = null;
                        }),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (_maxBudgetFilter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Showing sites with entrance fees of ₱$_maxBudgetFilter or less (free sites always included).',
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ),

              // ─── All Tourist Sites ─────────────────────────────────────
              const SizedBox(height: 18),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'All tourist sites',
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 22,
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    '${sites.length} places',
                    style: TextStyle(
                      color: const Color(0xFF6E8178),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (sites.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'No sites match this budget and category combination.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: colors.muted),
                    ),
                  ),
                )
              else
                ...sites.map(
<<<<<<< HEAD
                  (site) => _SiteListCard(
                    colors: colors,
                    site: site,
                    scaledCost: _scaledSiteCost(site),
                  ),
=======
                  (site) => _SiteListCard(colors: colors, site: site),
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                ),
            ],
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD

  String _formatEstimatedTotal(List<LocationModel> visibleSites) {
    if (visibleSites.isEmpty) return '₱0';
    final total =
        visibleSites.fold<double>(
          0,
          (sum, site) => sum + _scaledSiteCost(site).min,
        ) /
        visibleSites.length;
    return '₱${total.round()}';
  }
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
}

// ─── Route Card ─────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final AppColors colors;
  final CuratedRoute route;
<<<<<<< HEAD
  final ({double min, double max})? scaledCost;
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
  final VoidCallback onTap;

  const _RouteCard({
    required this.colors,
    required this.route,
<<<<<<< HEAD
    required this.scaledCost,
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final priceLabel = scaledCost == null
        ? route.priceRange
        : (scaledCost!.min == 0
              ? 'Free–₱${scaledCost!.max.round()}'
              : '₱${scaledCost!.min.round()}–₱${scaledCost!.max.round()}');
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                route.emoji,
                style: TextStyle(fontSize: 25, color: colors.accent),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route.groupSize,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
<<<<<<< HEAD
                  priceLabel,
=======
                  route.priceRange,
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                  style: TextStyle(color: colors.accent, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  route.duration,
                  style: const TextStyle(
                    color: Color(0xFF527163),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Site List Card ─────────────────────────────────────────────────────────────

class _SiteListCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel site;
<<<<<<< HEAD
  final ({double min, double max}) scaledCost;

  const _SiteListCard({
    required this.colors,
    required this.site,
    required this.scaledCost,
  });
=======

  const _SiteListCard({required this.colors, required this.site});
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77

  ImageProvider _resolveImage() {
    return site.imageUrl.startsWith('http')
        ? NetworkImage(site.imageUrl)
        : AssetImage(site.imageUrl) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final costLabel = scaledCost.min == scaledCost.max
        ? '₱${scaledCost.min.round()}'
        : '₱${scaledCost.min.round()}–₱${scaledCost.max.round()}';
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationDetailsScreen(location: site),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(minHeight: 101),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(25),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 115,
                child: Image(
                  image: _resolveImage(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4B6258), Color(0xFF1C4034)],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 8, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        site.type.toUpperCase(),
                        style: TextStyle(
                          color: colors.forest,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        site.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        site.note,
                        style: TextStyle(
                          color: const Color(0xFF65746C),
                          fontSize: 11,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15, bottom: 15),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
<<<<<<< HEAD
                    costLabel,
=======
                    site.ticketInfo.adultPrice == 0
                        ? (site.ticketInfo.notes ?? 'Free')
                        : site.ticketInfo.formattedAdult,
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFB3550E),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
