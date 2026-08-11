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
  const ItineraryCreateScreen({super.key});

  @override
  State<ItineraryCreateScreen> createState() => _ItineraryCreateScreenState();
}

class _ItineraryCreateScreenState extends State<ItineraryCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedLocationIds = {};
  String _searchTerm = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<LocationModel> get _filteredSites {
    final all = LocationService().getAllLocations();
    if (_searchTerm.trim().isEmpty) return all;
    final term = _searchTerm.trim().toLowerCase();
    return all.where((s) => s.name.toLowerCase().contains(term)).toList();
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
<<<<<<< HEAD
                      const SizedBox(width: 20),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 90,
                        ), // Adjust this value to push text right
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
=======
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '— NEW ITINERARY',
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
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
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
<<<<<<< HEAD
                        contentPadding: const EdgeInsets.only(top: 15),
=======
>>>>>>> 72e57dbb2a595f88aa9dbad25294aa3937569f77
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
