import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A min–max budget range, used by the Plans page to filter sites and
/// curated routes by estimated cost (addendum spec 3.1, 3.6). `null`
/// bounds mean "no lower/upper limit".
class PlanBudgetFilter {
  final double? min;
  final double? max;

  const PlanBudgetFilter({this.min, this.max});

  static const PlanBudgetFilter none = PlanBudgetFilter();

  bool get isActive => min != null || max != null;

  /// Whether an option with the given per-person price should be visible
  /// under this filter: included only if `price >= min` (when a min is
  /// set) AND `price <= max` (when a max is set). A `null` bound means "no
  /// lower/upper limit" and always passes that side of the check.
  bool allowsPrice(double price) {
    if (min != null && price < min!) return false;
    if (max != null && price > max!) return false;
    return true;
  }

  /// Whether a site/route with the given displayed price range (e.g. the
  /// "₱50–₱100" shown on its card) should be visible under this filter.
  /// The entire displayed range must fall within [min, max] — a site whose
  /// range only partially overlaps the filter (e.g. its max exceeds the
  /// filter's max) is excluded, since part of what's shown to the user
  /// would be outside the budget they asked for.
  bool allowsRange(double rangeMin, double rangeMax) {
    if (min != null && rangeMin < min!) return false;
    if (max != null && rangeMax > max!) return false;
    return true;
  }
}

/// Opens the detailed budget-range filter sheet (addendum spec 3.1): an
/// alternate, more precise entry point to the same budget-filter state the
/// bottom budget bar on the Plans page reads from and writes to. Returns
/// the new filter on Apply, or `null` if the sheet was dismissed/cancelled
/// without changes.
Future<PlanBudgetFilter?> showBudgetFilterSheet(
  BuildContext context,
  PlanBudgetFilter current,
) {
  final colors = AppColors.of(context);
  final minController = TextEditingController(
    text: current.min != null ? current.min!.round().toString() : '',
  );
  final maxController = TextEditingController(
    text: current.max != null ? current.max!.round().toString() : '',
  );

  return showModalBottomSheet<PlanBudgetFilter>(
    context: context,
    backgroundColor: colors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          String? errorText;

          void handleApply() {
            final min = double.tryParse(minController.text.trim());
            final max = double.tryParse(maxController.text.trim());
            // Validation (addendum spec 3.1): the max budget must be
            // greater than the min budget when both are set, otherwise the
            // range would be empty or inverted.
            if (min != null && max != null && max <= min) {
              setSheetState(() {
                errorText = 'Max budget must be greater than min budget.';
              });
              return;
            }
            Navigator.of(sheetContext).pop(
              PlanBudgetFilter(
                min: min != null && min >= 0 ? min : null,
                max: max != null && max >= 0 ? max : null,
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget filter',
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 22,
                          color: colors.ink,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          '×',
                          style: TextStyle(fontSize: 28, color: colors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set a min–max range to filter sites, itineraries, and '
                    'curated routes by estimated cost per person.',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _RangeField(
                          colors: colors,
                          label: 'MIN',
                          controller: minController,
                          hint: '₱0',
                          onChanged: (_) {
                            if (errorText != null) {
                              setSheetState(() => errorText = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RangeField(
                          colors: colors,
                          label: 'MAX',
                          controller: maxController,
                          hint: 'Any',
                          onChanged: (_) {
                            if (errorText != null) {
                              setSheetState(() => errorText = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Color(0xFFC0392B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(
                            sheetContext,
                          ).pop(PlanBudgetFilter.none),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.ink,
                            backgroundColor: colors.card,
                            side: BorderSide(color: colors.line),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: handleApply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.forest,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _RangeField extends StatelessWidget {
  final AppColors colors;
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _RangeField({
    required this.colors,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 16, color: colors.ink),
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: colors.muted, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
