import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../models/location_model.dart';
import '../services/itinerary_service.dart';

/// System-generated plan options for a tapped Curated Route (addendum spec
/// 3.4): the user reviews 1-4 candidate itineraries built from sites
/// matching the route's theme, picks one, and saves it. Saving calls the
/// same [ItineraryService.createItinerary] used by manually-built
/// itineraries, so the result gets full feature parity (Navigate, Edit,
/// Reorder, Delete) via the existing Itinerary Hub screens for free.
class RoutePlanOptionsScreen extends StatefulWidget {
  final CuratedRoute route;

  const RoutePlanOptionsScreen({super.key, required this.route});

  @override
  State<RoutePlanOptionsScreen> createState() =>
      _RoutePlanOptionsScreenState();
}

class _RoutePlanOptionsScreenState extends State<RoutePlanOptionsScreen> {
  late final List<PlanOption> _options;
  int _selectedIndex = -1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _options = ItineraryService.instance.buildPlanOptions(widget.route);
  }

  Future<void> _save() async {
    if (_selectedIndex < 0 || _isSaving) return;
    setState(() => _isSaving = true);
    final option = _options[_selectedIndex];
    await ItineraryService.instance.createItinerary(
      name: widget.route.name,
      locationIds: option.stops.map((s) => s.id).toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.route.name} saved to Itinerary Hub')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 20),
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
                          '— ROUTE OPTIONS',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.route.name,
                          style: TextStyle(
                            fontFamily: AppTheme.serifFont,
                            fontSize: 24,
                            color: colors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_options.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_options.length} option${_options.length == 1 ? '' : 's'} · ~${widget.route.hours} hrs',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _options.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            'No qualifying sites are available for this route yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: colors.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _options.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) => _PlanOptionCard(
                          colors: colors,
                          option: _options[index],
                          groupSize: 'All group sizes',
                          isSelected: index == _selectedIndex,
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedIndex < 0 || _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.forest,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.line,
                  minimumSize: const Size.fromHeight(53),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isSaving ? 'Saving…' : 'Save to Itinerary Hub',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

// ─── Plan Option Card ───────────────────────────────────────────────────────────

class _PlanOptionCard extends StatelessWidget {
  final AppColors colors;
  final PlanOption option;
  final String groupSize;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.colors,
    required this.option,
    required this.groupSize,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final min = option.stops.fold<double>(
      0,
      (sum, site) => sum + site.budgetRange.min,
    );
    final max = option.stops.fold<double>(
      0,
      (sum, site) => sum + site.budgetRange.max,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: isSelected ? colors.forest : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                Text(
                  min == max
                      ? '₱${min.round()}'
                      : '₱${min.round()}–₱${max.round()}',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${option.stops.length} stops · ~${option.hours} hrs · $groupSize',
              style: TextStyle(color: colors.muted, fontSize: 11),
            ),
            const SizedBox(height: 11),
            ...option.stops.map(
              (LocationModel site) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: colors.accent, fontSize: 14),
                    ),
                    Expanded(
                      child: Text(
                        site.name,
                        style: TextStyle(fontSize: 12, color: colors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
