import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/route_service.dart';
import '../services/location_service.dart';
import '../models/route_model.dart';
import '../models/location_model.dart';
import 'location_details_screen.dart';
import 'itinerary_create_screen.dart';

/// Plans screen, ported from the Eunice-branch `#screen-plans` markup:
/// eyebrow header + filter icon, traveler-size row with contextual hints,
/// plan-category chips, curated routes that accumulate a running budget on
/// tap, and the full "All tourist sites" directory list.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _selectedTraveler = 'Solo';
  String _planFilter = 'all';
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
    {'key': 'Schools', 'label': 'Schools'},
  ];

  void _addRouteToBudget(CuratedRoute route) {
    setState(() => _estimatedTotal += route.addToBudget);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${route.name} added'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final routes = RouteService().getRoutesByCategory(_planFilter);
    final sites = LocationService().getAllLocations().where((s) {
      final matchesCategory = _planFilter == 'all' || s.category == _planFilter;
      final matchesBudget =
          _maxBudgetFilter == null ||
          s.ticketInfo.adultPrice <= _maxBudgetFilter!;
      return matchesCategory && matchesBudget;
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
                        '— INTRAMUROS',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Travel Your Way',
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 27,
                          color: colors.ink,
                          letterSpacing: -0.04,
                        ),
                      ),
                    ],
                  ),
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
                            color: isActive
                                ? colors.forest
                                : const Color(0xFFEDE7DC),
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
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                              ? const Color(0xFF1D7654)
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

              // ─── Curated Routes ────────────────────────────────────────
              Text(
                'CURATED ROUTES',
                style: TextStyle(
                  color: const Color(0xFF6E8178),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 11),
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
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
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
                  (site) => _SiteListCard(colors: colors, site: site),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Route Card ─────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final AppColors colors;
  final CuratedRoute route;
  final VoidCallback onTap;

  const _RouteCard({
    required this.colors,
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  route.priceRange,
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

  const _SiteListCard({required this.colors, required this.site});

  ImageProvider _resolveImage() {
    return site.imageUrl.startsWith('http')
        ? NetworkImage(site.imageUrl)
        : AssetImage(site.imageUrl) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
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
                    site.ticketInfo.adultPrice == 0
                        ? (site.ticketInfo.notes ?? 'Free')
                        : site.ticketInfo.formattedAdult,
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
