import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/itinerary_model.dart';
import '../models/location_model.dart';
import '../services/itinerary_service.dart';
import '../services/location_service.dart';
import 'itinerary_navigation_overview_screen.dart';
import 'location_details_screen.dart';

/// Itinerary detail / edit screen (spec Section 3.4-3.5): shows the saved
/// itinerary's stops, offers the auto-suggested nearest-neighbor visiting
/// order (computed from the user's current GPS position), lets the user
/// switch to and manually drag-reorder their own stop sequence, and
/// supports adding/removing locations, renaming, and deleting the whole
/// itinerary.
class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;

  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  bool _useSuggestedOrder = false;
  List<LocationModel>? _suggestedOrder;
  bool _isSequencing = false;
  String? _sequencingError;

  Future<void> _computeSuggestedOrder(ItineraryModel itinerary) async {
    setState(() {
      _isSequencing = true;
      _sequencingError = null;
    });
    final position = await ItineraryService.instance.resolveCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _isSequencing = false;
        _sequencingError =
            'Could not read your current location. Enable location services and try again.';
      });
      return;
    }
    final ordered = ItineraryService.instance.sequenceByNearestNeighbor(
      itinerary,
      position,
    );
    setState(() {
      _suggestedOrder = ordered;
      _isSequencing = false;
      _useSuggestedOrder = true;
    });
  }

  void _useManualOrder() {
    setState(() => _useSuggestedOrder = false);
  }

  Future<void> _renameItinerary(ItineraryModel itinerary) async {
    final controller = TextEditingController(text: itinerary.name);
    final colors = AppColors.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Rename Itinerary', style: TextStyle(color: colors.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.ink),
          decoration: const InputDecoration(hintText: 'Itinerary name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('Save', style: TextStyle(color: colors.forest)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ItineraryService.instance.renameItinerary(itinerary.id, newName);
    }
  }

  Future<void> _deleteItinerary(ItineraryModel itinerary) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Delete Itinerary?', style: TextStyle(color: colors.ink)),
        content: Text(
          'This will permanently delete "${itinerary.name}". This cannot be undone.',
          style: TextStyle(color: colors.ink.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ItineraryService.instance.deleteItinerary(itinerary.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addLocation(ItineraryModel itinerary) async {
    final colors = AppColors.of(context);
    final allSites = LocationService().getAllLocations();
    final available = allSites
        .where((s) => !itinerary.locationIds.contains(s.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All locations are already in this itinerary'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<LocationModel>(
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
                  'Add a location',
                  style: TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 20,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final site = available[index];
                      return ListTile(
                        title: Text(
                          site.name,
                          style: TextStyle(color: colors.ink),
                        ),
                        subtitle: Text(
                          site.category,
                          style: TextStyle(color: colors.muted),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(site),
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
    if (selected != null) {
      await ItineraryService.instance.addLocation(itinerary.id, selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: ItineraryService.instance,
      builder: (context, _) {
        final itinerary = ItineraryService.instance.getById(widget.itineraryId);
        if (itinerary == null) {
          return Scaffold(
            backgroundColor: colors.paper,
            body: Center(
              child: Text(
                'Itinerary not found',
                style: TextStyle(color: colors.muted),
              ),
            ),
          );
        }

        final manualOrder = ItineraryService.instance.resolveLocations(
          itinerary,
        );
        final displayedOrder = _useSuggestedOrder && _suggestedOrder != null
            ? _suggestedOrder!
            : manualOrder;

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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '— ITINERARY',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 12,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  itinerary.name,
                                  style: TextStyle(
                                    fontFamily: AppTheme.serifFont,
                                    fontSize: 20,
                                    color: colors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            color: colors.card,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: colors.ink,
                            ),
                            onSelected: (value) {
                              if (value == 'rename') {
                                _renameItinerary(itinerary);
                              }
                              if (value == 'delete') {
                                _deleteItinerary(itinerary);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(
                                  'Rename',
                                  style: TextStyle(color: colors.ink),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete Itinerary',
                                  style: TextStyle(color: colors.ink),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ─── Order Toggle ───────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _OrderToggleButton(
                              colors: colors,
                              label: 'My Order',
                              isActive: !_useSuggestedOrder,
                              onTap: _useManualOrder,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _OrderToggleButton(
                              colors: colors,
                              label: _isSequencing
                                  ? 'Finding route…'
                                  : 'Suggested Route',
                              isActive: _useSuggestedOrder,
                              onTap: _isSequencing
                                  ? null
                                  : () => _computeSuggestedOrder(itinerary),
                            ),
                          ),
                        ],
                      ),
                      if (_sequencingError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _sequencingError!,
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (_useSuggestedOrder && _suggestedOrder != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Ordered nearest-to-farthest from your current location. Reordering is disabled while viewing the suggested route — switch to "My Order" to drag and rearrange.',
                            style: TextStyle(color: colors.muted, fontSize: 11),
                          ),
                        ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${displayedOrder.length} stops',
                            style: TextStyle(color: colors.muted, fontSize: 12),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: displayedOrder.isEmpty
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ItineraryNavigationOverviewScreen(
                                                  itineraryName: itinerary.name,
                                                  stops: List<LocationModel>.of(
                                                    displayedOrder,
                                                  ),
                                                ),
                                          ),
                                        );
                                      },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.navigation_rounded,
                                      size: 16,
                                      color: displayedOrder.isEmpty
                                          ? colors.muted
                                          : colors.forest,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Navigate',
                                      style: TextStyle(
                                        color: displayedOrder.isEmpty
                                            ? colors.muted
                                            : colors.forest,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => _addLocation(itinerary),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: colors.forest,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add stop',
                                      style: TextStyle(
                                        color: colors.forest,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),

                Expanded(
                  child: displayedOrder.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'No stops yet. Tap "Add stop" to start building this itinerary.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : (_useSuggestedOrder
                            ? ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  25,
                                  0,
                                  25,
                                  20,
                                ),
                                itemCount: displayedOrder.length,
                                itemBuilder: (context, index) => _StopCard(
                                  colors: colors,
                                  index: index,
                                  site: displayedOrder[index],
                                  showDragHandle: false,
                                  onRemove: () =>
                                      ItineraryService.instance.removeLocation(
                                        itinerary.id,
                                        displayedOrder[index].id,
                                      ),
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  25,
                                  0,
                                  25,
                                  20,
                                ),
                                itemCount: displayedOrder.length,
                                onReorder: (oldIndex, newIndex) {
                                  var adjustedNewIndex = newIndex;
                                  if (oldIndex < newIndex) {
                                    adjustedNewIndex -= 1;
                                  }
                                  ItineraryService.instance.reorderLocation(
                                    itinerary.id,
                                    oldIndex,
                                    adjustedNewIndex,
                                  );
                                },
                                itemBuilder: (context, index) => _StopCard(
                                  key: ValueKey(displayedOrder[index].id),
                                  colors: colors,
                                  index: index,
                                  site: displayedOrder[index],
                                  showDragHandle: true,
                                  onRemove: () =>
                                      ItineraryService.instance.removeLocation(
                                        itinerary.id,
                                        displayedOrder[index].id,
                                      ),
                                ),
                              )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Order Toggle Button ────────────────────────────────────────────────────────

class _OrderToggleButton extends StatelessWidget {
  final AppColors colors;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _OrderToggleButton({
    required this.colors,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? colors.forest : colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isActive ? colors.forest : colors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : colors.ink,
          ),
        ),
      ),
    );
  }
}

// ─── Stop Card ──────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final AppColors colors;
  final int index;
  final LocationModel site;
  final bool showDragHandle;
  final VoidCallback onRemove;

  const _StopCard({
    super.key,
    required this.colors,
    required this.index,
    required this.site,
    required this.showDragHandle,
    required this.onRemove,
  });

  ImageProvider _resolveImage() {
    return site.imageUrl.startsWith('http')
        ? NetworkImage(site.imageUrl)
        : AssetImage(site.imageUrl) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 32,
              alignment: Alignment.center,
              color: colors.forest,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(
              width: 74,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocationDetailsScreen(location: site),
                    ),
                  );
                },
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
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      site.type.toUpperCase(),
                      style: TextStyle(
                        color: colors.forest,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close_rounded, size: 18, color: colors.muted),
              ),
            ),
            if (showDragHandle)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 20,
                    color: colors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
