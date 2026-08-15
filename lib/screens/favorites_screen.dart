import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/saved_places_service.dart';
import '../services/itinerary_service.dart';
import '../models/location_model.dart';
import '../models/itinerary_model.dart';
import 'location_details_screen.dart';
import 'itinerary_detail_screen.dart';
import 'itinerary_create_screen.dart';
import 'itinerary_navigation_overview_screen.dart';

/// "Your Hub" saved-places screen, ported from the Eunice-branch
/// `#screen-saved` markup: back chevron, eyebrow + title, Locations /
/// Itineraries hub tabs, and a list of saved-place cards with a heart icon.
/// Backed by [SavedPlacesService] so saves made on the details screen show
/// up here immediately and persist across app restarts.
class FavoritesScreen extends StatefulWidget {
  /// Which hub tab to show first — defaults to 'Locations' to match the
  /// original branch behavior. Pass 'Itineraries' when deep-linking here
  /// from an entry point whose whole purpose is surfacing saved
  /// itineraries (e.g. the Navigation screen's Itineraries chip, or the
  /// Home screen's "View Saved Itineraries" button), so the user lands
  /// straight on the relevant tab instead of Locations.
  final String initialTab;

  const FavoritesScreen({super.key, this.initialTab = 'Locations'});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late String _selectedTab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    SavedPlacesService.instance.load();
    ItineraryService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: SavedPlacesService.instance,
      builder: (context, _) {
        final savedIds = SavedPlacesService.instance.savedIds;
        final savedLocations = LocationService()
            .getAllLocations()
            .where((l) => savedIds.contains(l.id))
            .toList();

        return Scaffold(
          backgroundColor: colors.paper,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              '— SAVED',
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Hub',
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
                  const SizedBox(height: 25),

                  // ─── Hub Tabs ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E3D9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HubTabButton(
                            label: 'Locations',
                            isActive: _selectedTab == 'Locations',
                            onTap: () =>
                                setState(() => _selectedTab = 'Locations'),
                          ),
                        ),
                        Expanded(
                          child: _HubTabButton(
                            label: 'Itineraries',
                            isActive: _selectedTab == 'Itineraries',
                            onTap: () =>
                                setState(() => _selectedTab = 'Itineraries'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ─── Saved List ──────────────────────────────────────
                  if (_selectedTab == 'Itineraries')
                    AnimatedBuilder(
                      animation: ItineraryService.instance,
                      builder: (context, _) {
                        final itineraries =
                            ItineraryService.instance.itineraries;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ItineraryCreateScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.forest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Itinerary',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (itineraries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                child: Center(
                                  child: Text(
                                    'No saved itineraries yet. Tap "Add Itinerary" to build your own trip.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...itineraries.map(
                                (itinerary) => _ItineraryCard(
                                  colors: colors,
                                  itinerary: itinerary,
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  else if (savedLocations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No saved places yet. Open a tourist spot and tap Save place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...savedLocations.map(
                      (location) =>
                          _SavedCard(colors: colors, location: location),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Hub Tab Button ─────────────────────────────────────────────────────────────

class _HubTabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _HubTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF242424), fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Saved Card ─────────────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel location;

  const _SavedCard({required this.colors, required this.location});

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
        margin: const EdgeInsets.only(bottom: 11),
        constraints: const BoxConstraints(minHeight: 102),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 115,
              height: 102,
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
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    location.type.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1F5748),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    location.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.note,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF65746C),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 13),
              child: GestureDetector(
                onTap: () => SavedPlacesService.instance.toggle(location.id),
                child: const Text(
                  '♥',
                  style: TextStyle(color: Color(0xFFEC535C), fontSize: 21),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Itinerary Card ─────────────────────────────────────────────────────────────
// Itinerary Hub entry (spec 3.3-3.5), living in the existing "Itineraries"
// tab of Your Hub. Matches the visual language of `_SavedCard` above.

class _ItineraryCard extends StatelessWidget {
  final AppColors colors;
  final ItineraryModel itinerary;

  const _ItineraryCard({required this.colors, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final locations = ItineraryService.instance.resolveLocations(itinerary);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItineraryDetailScreen(itineraryId: itinerary.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined, color: colors.forest, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${locations.length} stop${locations.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: locations.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItineraryNavigationOverviewScreen(
                            itineraryName: itinerary.name,
                            stops: List<LocationModel>.of(locations),
                          ),
                        ),
                      );
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  color: locations.isEmpty ? colors.line : colors.forest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.navigation_rounded,
                      color: locations.isEmpty ? colors.muted : Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Navigate',
                      style: TextStyle(
                        color: locations.isEmpty ? colors.muted : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: colors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
