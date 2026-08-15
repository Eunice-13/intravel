import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/itinerary_service.dart';
import '../models/location_model.dart';

/// Custom itinerary creation flow (spec Section 3.3): name the itinerary,
/// multi-select locations from the app's own listings, then save. Once
/// saved, the itinerary appears in the Itinerary Hub (Your Hub → Itineraries
/// tab, reached from Settings → Saved Places).
class ItineraryCreateScreen extends StatefulWidget {
  /// Optional location to open the builder with already included as a stop
  /// (improvement-batch spec Section 7): the Location Details "Directions"
  /// button routes here rather than launching inline turn-by-turn, and the
  /// originating location arrives pre-selected.
  ///
  /// Deliberately just a seed for the normal selection state rather than a
  /// separate "locked" stop — Section 7.4 requires the pre-included stop to
  /// behave exactly like a manually added one (editable, removable, and
  /// reorderable once saved), which falls out for free if it's an ordinary
  /// member of [_selectedLocationIds].
  final LocationModel? seedLocation;

  const ItineraryCreateScreen({super.key, this.seedLocation});

  @override
  State<ItineraryCreateScreen> createState() => _ItineraryCreateScreenState();
}

class _ItineraryCreateScreenState extends State<ItineraryCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedLocationIds = {};
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    final seed = widget.seedLocation;
    if (seed == null) return;
    _selectedLocationIds.add(seed.id);
    // Pre-filled so arriving from "Directions" isn't an immediate dead end
    // at the "Give your itinerary a name first" guard in [_save]. Still a
    // normal editable field — the user can rename it before saving.
    _nameController.text = 'Trip to ${seed.name}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<LocationModel> get _filteredSites {
    final all = LocationService().getAllLocations();
    final term = _searchTerm.trim().toLowerCase();
    final matches = term.isEmpty
        ? List<LocationModel>.of(all)
        : all.where((s) => s.name.toLowerCase().contains(term)).toList();

    // Float the seeded stop to the top of the list. Without this the one
    // location the user just came from could sit dozens of rows down, so
    // "it's already added" would be invisible — the selection count would
    // read 1 with nothing on screen to explain why.
    final seedId = widget.seedLocation?.id;
    if (seedId != null) {
      final index = matches.indexWhere((s) => s.id == seedId);
      if (index > 0) matches.insert(0, matches.removeAt(index));
    }
    return matches;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your itinerary a name first')),
      );
      return;
    }
    if (_selectedLocationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one location')),
      );
      return;
    }
    await ItineraryService.instance.createItinerary(
      name: name,
      locationIds: _selectedLocationIds.toList(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sites = _filteredSites;

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
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'NEW ITINERARY —',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Build Your Trip',
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

                  // ─── Itinerary Name ────────────────────────────────
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: colors.line),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 14, color: colors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Name your itinerary (e.g. "My Day 1")',
                        hintStyle: TextStyle(fontSize: 14, color: colors.muted),
                        contentPadding: const EdgeInsets.only(top: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── Search to narrow the list ─────────────────────
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: colors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: colors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchTerm = v),
                            style: TextStyle(fontSize: 13, color: colors.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search locations to add...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT LOCATIONS',
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${_selectedLocationIds.length} selected',
                        style: TextStyle(
                          color: colors.forest,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 12),
                itemCount: sites.length,
                itemBuilder: (context, index) {
                  final site = sites[index];
                  final isSelected = _selectedLocationIds.contains(site.id);
                  return _SelectableSiteCard(
                    colors: colors,
                    site: site,
                    isSelected: isSelected,
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedLocationIds.remove(site.id);
                      } else {
                        _selectedLocationIds.add(site.id);
                      }
                    }),
                  );
                },
              ),
            ),

            // ─── Save Button ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 20),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Itinerary',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Selectable Site Card ───────────────────────────────────────────────────────
// Matches the visual language of Plans' `_SiteListCard` (image + type +
// name + note), plus a selection checkmark indicator for multi-select.

class _SelectableSiteCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel site;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableSiteCard({
    required this.colors,
    required this.site,
    required this.isSelected,
    required this.onTap,
  });

  ImageProvider _resolveImage() {
    return site.imageUrl.startsWith('http')
        ? NetworkImage(site.imageUrl)
        : AssetImage(site.imageUrl) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(minHeight: 90),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? colors.forest : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 90,
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
                  padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
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
                      const SizedBox(height: 5),
                      Text(
                        site.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        site.note,
                        style: const TextStyle(
                          color: Color(0xFF65746C),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? colors.forest : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? colors.forest : colors.muted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
