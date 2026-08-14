import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../models/location_model.dart';
import '../widgets/transport_access_section.dart';
import 'location_details_screen.dart';

/// Home screen, ported from the Eunice-branch `#screen-home` markup:
/// rounded search field, forest-green itinerary planner CTA, horizontally
/// scrolling category chips, and a 2-column grid of photo cards.
///
/// Also hosts the Transport & Access module (relocated here from Settings
/// per `intramuros-app-spec-updates-2.md` Section 2), sitting between the
/// header block and the location list.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenPlans;

  const HomeScreen({super.key, this.onOpenPlans});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeFilter = 'all';
  String _searchTerm = '';

  static const List<Map<String, String>> _chips = [
    {'key': 'all', 'label': 'All'},
    {'key': 'Fortifications', 'label': 'Fortifications'},
    {'key': 'Landmarks', 'label': 'Landmarks'},
    {'key': 'Museums', 'label': 'Museums'},
    {'key': 'Churches', 'label': 'Churches'},
    {'key': 'Parks', 'label': 'Parks'},
    {'key': 'Schools', 'label': 'Schools'},
  ];

  List<LocationModel> get _visibleSites {
    final all = LocationService().getAllLocations();
    return all.where((site) {
      final matchesFilter =
          _activeFilter == 'all' || site.category == _activeFilter;
      final matchesSearch =
          _searchTerm.isEmpty ||
          site.name.toLowerCase().contains(_searchTerm.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  String get _listTitle {
    if (_visibleSites.isEmpty) return 'No locations found';
    const labels = {
      'all': 'All Locations',
      'Fortifications': 'Fortifications',
      'Landmarks': 'Landmarks',
      'Museums': 'Museums',
      'Churches': 'Churches',
      'Parks': 'Parks',
      'Schools': 'Schools',
    };
    return labels[_activeFilter] ?? 'All Locations';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sites = _visibleSites;

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: colors.paper,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 13,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(
                      colors: colors,
                      onChanged: (v) => setState(() => _searchTerm = v),
                    ),
                    const SizedBox(height: 12),
                    _PlannerButton(colors: colors, onTap: widget.onOpenPlans),
                    const SizedBox(height: 16),
                    _CategoryChips(
                      colors: colors,
                      chips: _chips,
                      activeKey: _activeFilter,
                      onSelect: (key) => setState(() => _activeFilter = key),
                    ),
                  ],
                ),
              ),
            ),
            // Transport & Access — its own distinct module below the
            // header block (updates-2 spec Section 2 relocated this out of
            // Settings; improvement-batch Section 3 set the 2-column grid).
            // Deliberately sits outside the elevated header card so the
            // category chips stay visually attached to the location grid
            // they filter.
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(child: TransportAccessSection()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _listTitle,
                  style: TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 25,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 158 / 204,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _LocationCard(site: sites[index], colors: colors),
                  childCount: sites.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Field ───────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final AppColors colors;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 59,
      padding: const EdgeInsets.symmetric(horizontal: 21),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: colors.muted),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(color: colors.ink, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search Intramuros Locations...',
                hintStyle: TextStyle(
                  color: colors.muted.withValues(alpha: 0.7),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Itinerary Planner Button ───────────────────────────────────────────────────

class _PlannerButton extends StatelessWidget {
  final AppColors colors;
  final VoidCallback? onTap;

  const _PlannerButton({required this.colors, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 91,
        padding: const EdgeInsets.symmetric(horizontal: 23),
        decoration: BoxDecoration(
          color: colors.forest,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ITINERARY PLANNER',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Travel Your Way',
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 27,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Chips ─────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final AppColors colors;
  final List<Map<String, String>> chips;
  final String activeKey;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.colors,
    required this.chips,
    required this.activeKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isActive = chip['key'] == activeKey;
          return GestureDetector(
            onTap: () => onSelect(chip['key']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? colors.accent : const Color(0xFF1D6B4A))
                    : colors.card,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isActive
                      ? (isDark ? colors.accent : const Color(0xFF1D6B4A))
                      : (isDark ? colors.line : const Color(0xFFE5E7EB)),
                ),
              ),
              child: Text(
                chip['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white
                      : (isActive
                            ? const Color(0xFFF7FFFF)
                            : const Color(0xFF555555)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Location Card ──────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final LocationModel site;
  final AppColors colors;

  const _LocationCard({required this.site, required this.colors});

  ImageProvider _resolveImage() {
    if (site.imageUrl.startsWith('http')) {
      return NetworkImage(site.imageUrl);
    }
    return AssetImage(site.imageUrl);
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
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: _resolveImage(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4B6258), Color(0xFF1C4034)],
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Verified photo\ncoming soon',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAB091C15)],
                  stops: [0.43, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  site.type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF254438),
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 15,
              left: 15,
              right: 10,
              child: Text(
                site.name,
                style: const TextStyle(
                  fontFamily: AppTheme.serifFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
