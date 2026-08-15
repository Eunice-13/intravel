import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../services/review_service.dart';
import '../services/location_rating_service.dart';
import 'location_details_screen.dart';

/// How the Ratings list is currently ordered.
enum RatingSortOrder {
  /// Highest average rating first (ties broken by review count, most
  /// reviews first) — the default, since "browse by rating" implies
  /// starting from the best-reviewed sites.
  highestRated,

  /// Most-reviewed first, regardless of score — useful for finding the
  /// most popular/well-established sites rather than the highest-scoring
  /// ones.
  mostReviewed,

  /// Alphabetical by name — a stable, predictable fallback ordering.
  name,
}

/// Browse-by-rating screen (Plans → "Browse by Rating"): every location,
/// each showing its name, canonical photo, aggregate star rating, and
/// review count — sortable by rating/review count/name and filterable by
/// the same site categories used on the Plans screen. Ratings are the
/// live aggregate of each location's seeded + user-submitted reviews (see
/// [computeLocationRatingSummary]), not a separate hand-curated dataset —
/// so this list updates immediately as new reviews come in, including the
/// one just submitted from this session, without needing a rebuild.
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  RatingSortOrder _sortOrder = RatingSortOrder.highestRated;
  String _categoryFilter = 'all';

  static const List<Map<String, String>> _categoryChips = [
    {'key': 'all', 'label': 'All Sites'},
    {'key': 'Fortifications', 'label': 'Fortifications'},
    {'key': 'Landmarks', 'label': 'Landmarks'},
    {'key': 'Museums', 'label': 'Museums'},
    {'key': 'Churches', 'label': 'Churches'},
    {'key': 'Parks', 'label': 'Parks'},
    {'key': 'Schools', 'label': 'Schools'},
  ];

  static const Map<RatingSortOrder, String> _sortLabels = {
    RatingSortOrder.highestRated: 'Highest rated',
    RatingSortOrder.mostReviewed: 'Most reviewed',
    RatingSortOrder.name: 'Name (A–Z)',
  };

  List<({LocationModel location, LocationRatingSummary summary})>
  _sortedFilteredEntries() {
    final all = LocationService().getAllLocations();
    final filtered = _categoryFilter == 'all'
        ? all
        : all.where((l) => l.category == _categoryFilter).toList();
    final entries = filtered
        .map(
          (l) => (location: l, summary: computeLocationRatingSummary(l)),
        )
        .toList();

    switch (_sortOrder) {
      case RatingSortOrder.highestRated:
        entries.sort((a, b) {
          // Locations with no ratings yet sort after every rated
          // location, regardless of score, rather than competing on an
          // average of 0.0.
          if (a.summary.hasRatings != b.summary.hasRatings) {
            return a.summary.hasRatings ? -1 : 1;
          }
          if (!a.summary.hasRatings) {
            return a.location.name.compareTo(b.location.name);
          }
          final byRating = b.summary.average.compareTo(a.summary.average);
          if (byRating != 0) return byRating;
          return b.summary.count.compareTo(a.summary.count);
        });
        break;
      case RatingSortOrder.mostReviewed:
        entries.sort((a, b) {
          final byCount = b.summary.count.compareTo(a.summary.count);
          if (byCount != 0) return byCount;
          return a.location.name.compareTo(b.location.name);
        });
        break;
      case RatingSortOrder.name:
        entries.sort((a, b) => a.location.name.compareTo(b.location.name));
        break;
    }
    return entries;
  }

  Future<void> _openSortSheet() async {
    final colors = AppColors.of(context);
    final selected = await showModalBottomSheet<RatingSortOrder>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 18,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                ...RatingSortOrder.values.map(
                  (order) => ListTile(
                    title: Text(
                      _sortLabels[order]!,
                      style: TextStyle(color: colors.ink),
                    ),
                    trailing: order == _sortOrder
                        ? Icon(Icons.check_rounded, color: colors.forest)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(order),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) setState(() => _sortOrder = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      // Rebuilds live as reviews are submitted/loaded, so a rating just
      // left on the details screen (or Settings → Reviews) is reflected
      // here immediately without needing to leave and re-enter this
      // screen.
      animation: ReviewService.instance,
      builder: (context, _) {
        final entries = _sortedFilteredEntries();
        return Scaffold(
          backgroundColor: colors.paper,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header ──────────────────────────────────────
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            child: Text(
                              '‹',
                              style: TextStyle(
                                fontSize: 36,
                                height: 1,
                                color: colors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '— BROWSE BY RATING',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 12,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Top Rated Sites',
                                  style: TextStyle(
                                    fontFamily: AppTheme.serifFont,
                                    fontSize: 27,
                                    color: colors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Sort control ────────────────────────────────
                      GestureDetector(
                        onTap: _openSortSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.sort_rounded,
                                    size: 18,
                                    color: colors.forest,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sort: ${_sortLabels[_sortOrder]}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ─── Category filter chips ───────────────────────
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categoryChips.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final chip = _categoryChips[index];
                            final isActive = chip['key'] == _categoryFilter;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _categoryFilter = chip['key']!,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? colors.accent
                                            : const Color(0xFF1D7654))
                                      : colors.card,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  chip['label']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isActive
                                        ? Colors.white
                                        : colors.ink,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${entries.length} place${entries.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: const Color(0xFF6E8178),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 11),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'No sites match this category.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.muted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _RatingListCard(
                              colors: colors,
                              location: entry.location,
                              summary: entry.summary,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Rating List Card ───────────────────────────────────────────────────────

class _RatingListCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel location;
  final LocationRatingSummary summary;

  const _RatingListCard({
    required this.colors,
    required this.location,
    required this.summary,
  });

  ImageProvider _resolveImage() {
    return location.imageUrl.startsWith('http')
        ? NetworkImage(location.imageUrl)
        : AssetImage(location.imageUrl) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationDetailsScreen(location: location),
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
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        location.type.toUpperCase(),
                        style: TextStyle(
                          color: colors.forest,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        location.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (summary.hasRatings)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.starColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              summary.average.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${summary.count})',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'No ratings yet',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.muted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
