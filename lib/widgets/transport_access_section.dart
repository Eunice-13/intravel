import 'package:flutter/material.dart';

import '../models/gate_model.dart';
import '../models/nav_target.dart';
import '../models/route_model.dart';
import '../services/gate_selection_service.dart';
import '../services/gate_service.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import 'location_photo.dart';
import 'nav_flow_launcher.dart';
import 'receipt_dividers.dart';

/// Home page "getting around" module: two tappable cards side by side —
/// **Transport & Access** and **Starting Gates** — each opening a small
/// receipt-styled popup.
///
/// Relocated to Home from Settings per `intramuros-app-spec-updates-2.md`
/// Section 2 and the improvement-batch spec Section 3. The two-column
/// layout applies to these two *section* cards; the individual transport
/// options and gates live inside their respective popups rather than being
/// flattened into the grid, which keeps the Home feed short and lets each
/// popup carry the full detail a half-width tile couldn't hold.
///
/// The two popups deliberately differ:
///  * Transport & Access is a **priced** receipt — fares, discount/legal
///    notes, and a verified pickup location per option, each row tapping
///    through to the app's own shared Navigate flow ([NavFlowLauncher])
///    rather than an external Maps handoff.
///  * Starting Gates is an **unpriced** receipt — gates carry no cost, so
///    it shows an instruction to pick where you're arriving instead, and
///    writes the choice straight to [GateSelectionService] (the same store
///    the Settings picker and first-launch onboarding use, so there's one
///    source of truth and no state divergence).
///
/// The collapse chevron confirmed in updates-2 Section 2 is preserved.
class TransportAccessSection extends StatefulWidget {
  const TransportAccessSection({super.key});

  @override
  State<TransportAccessSection> createState() => _TransportAccessSectionState();
}

class _TransportAccessSectionState extends State<TransportAccessSection> {
  /// Starts expanded, matching the Settings version's default (and the
  /// Navigate flow's Live Updates panel).
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                'GETTING AROUND',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
              const Spacer(),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: colors.muted,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              // IntrinsicHeight so the two cards match height even when
              // their captions differ in length. It also supplies the
              // bounded height that CrossAxisAlignment.stretch needs —
              // without it the Row sits under a sliver's unbounded
              // height constraint and trips a `hasSize` assertion.
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _SectionTile(
                          colors: colors,
                          emoji: '🚋',
                          label: 'Transport\n& Access',
                          caption: 'Fares & pickup points',
                          onTap: () =>
                              _showTransportReceipt(context, colors: colors),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: GateSelectionService.instance,
                          builder: (context, _) {
                            final selectedId =
                                GateSelectionService.instance.selectedGateId;
                            final gate = selectedId == null
                                ? null
                                : GateService().getGateById(selectedId);
                            return _SectionTile(
                              colors: colors,
                              emoji: '🚪',
                              label: 'Starting\nGates',
                              caption: gate?.name ?? 'Not set',
                              onTap: () => _showStartingGatesReceipt(
                                context,
                                colors: colors,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// One of the two half-width section cards. Carries only an icon, a title
/// and a short caption — the detail lives in the receipt popup it opens.
class _SectionTile extends StatelessWidget {
  final AppColors colors;
  final String emoji;
  final String label;
  final String caption;
  final VoidCallback onTap;

  const _SectionTile({
    required this.colors,
    required this.emoji,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.muted.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              caption,
              style: TextStyle(fontSize: 10.5, color: colors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared receipt popup shell ──────────────────────────────────────────────
// Both popups reuse the Plans page's itinerary-receipt treatment (cream
// paper, monospace type, dashed rules, closing double rule) via
// `receipt_dividers.dart`. Those colors are intentionally fixed "printed
// receipt" values rather than theme tokens — same as the original — so the
// treatment reads identically in dark mode.

Future<void> _showReceiptDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFFFFFDF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // Tighter than the default 40px inset so the gate photos get as much
      // width as possible on a phone.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: DottedDivider(),
              ),
              ...children,
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: DoubleDivider(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Transport & Access receipt (priced) ─────────────────────────────────────

void _showTransportReceipt(BuildContext context, {required AppColors colors}) {
  final options = RouteService().getTransportOptions();

  _showReceiptDialog(
    context,
    title: 'TRANSPORT & ACCESS',
    subtitle: 'Tap an option to navigate to its pickup point',
    children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: DottedDivider(),
          ),
        _TransportReceiptRow(
          option: options[i],
          colors: colors,
          // Closes over the *page* context rather than the row's own
          // context, which is inside the dialog and becomes defunct the
          // moment it's popped.
          onNavigate: options[i].coordinates == null
              ? null
              : () {
                  final option = options[i];
                  Navigator.of(context).pop();
                  NavFlowLauncher.startWithTarget(
                    context,
                    target: NavTarget(
                      name: option.name,
                      coordinates: option.coordinates!,
                    ),
                  );
                },
        ),
      ],
    ],
  );
}

class _TransportReceiptRow extends StatelessWidget {
  final TransportOption option;
  final AppColors colors;
  final VoidCallback? onNavigate;

  const _TransportReceiptRow({
    required this.option,
    required this.colors,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final canNavigate = onNavigate != null;

    return GestureDetector(
      onTap: onNavigate,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canNavigate)
                Icon(Icons.navigation_outlined, size: 15, color: colors.forest),
            ],
          ),
          const SizedBox(height: 4),
          // The fare is the receipt's "cost" line for this option.
          Text(
            option.pricing,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
          ),
          if (option.discountNote != null) ...[
            const SizedBox(height: 2),
            Text(
              option.discountNote!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.grey,
              ),
            ),
          ],
          if (option.legalNote != null) ...[
            const SizedBox(height: 2),
            Text(
              option.legalNote!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.grey,
              ),
            ),
          ],
          if (option.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 11, color: colors.accent),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    option.locationLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Starting Gates receipt (unpriced) ───────────────────────────────────────

void _showStartingGatesReceipt(
  BuildContext context, {
  required AppColors colors,
}) {
  final gates = GateService().getAllGates();

  _showReceiptDialog(
    context,
    title: 'STARTING GATES',
    // Gates carry no cost, so this receipt gives an instruction in place
    // of a fare column.
    subtitle: 'Choose the gate you\'re arriving at',
    children: [
      AnimatedBuilder(
        animation: GateSelectionService.instance,
        builder: (context, _) {
          final selectedId = GateSelectionService.instance.selectedGateId;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < gates.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: DottedDivider(),
                  ),
                _GateReceiptRow(
                  gate: gates[i],
                  colors: colors,
                  isSelected: gates[i].id == selectedId,
                ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _GateReceiptRow extends StatelessWidget {
  final GateModel gate;
  final AppColors colors;
  final bool isSelected;

  const _GateReceiptRow({
    required this.gate,
    required this.colors,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Writes to the same store the Settings picker and first-launch
      // onboarding use, so all three stay in sync.
      onTap: () => GateSelectionService.instance.selectGate(gate.id),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large photo of the gate — the point of this popup is letting
          // the user recognise the entrance they're physically standing
          // at, which a small thumbnail was too cramped to do. Reuses
          // [LocationPhoto], which resolves network vs. asset paths and
          // degrades to a plain colored box if an image fails to load.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: double.infinity,
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocationPhoto(
                    imagePath: gate.imageUrl,
                    fallbackColor: colors.forest.withValues(alpha: 0.5),
                  ),
                  // Selected gate gets a green outline over the photo so
                  // the current choice is obvious at a glance.
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.forest, width: 3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  gate.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected) ...[
                Icon(Icons.check_rounded, size: 15, color: colors.forest),
                const SizedBox(width: 3),
                Text(
                  'SET',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.forest,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            gate.kindLabel,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
