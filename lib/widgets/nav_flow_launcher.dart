import 'package:flutter/material.dart';
import '../models/location_model.dart';
import '../models/nav_target.dart';
import '../screens/navigation_screen.dart';
import '../theme/app_theme.dart';

/// Single shared entry point into the Navigate flow (addendum spec
/// Section 1): every "Navigate Now" / "Navigate" action in the app —
/// Home, Location Details, and each itinerary leg — calls one of these
/// functions instead of independently pushing [NavigationScreen], so the
/// view-mode choice (and, for itineraries, the transport-mode choice) is
/// identical everywhere by construction rather than by convention.
class NavFlowLauncher {
  const NavFlowLauncher._();

  /// Home page / Location Details entry point (addendum spec Section 1):
  /// no transport-mode choice, straight to the view-mode picker.
  static Future<void> start(
    BuildContext context, {
    required LocationModel location,
  }) {
    return _startWithTarget(context, target: NavTarget.fromLocation(location));
  }

  /// Settings > Transport & Access entry point (addendum spec Section
  /// 4.3): navigates to a transport service's real-world pickup point,
  /// which has no catalogued [LocationModel] of its own. No
  /// transport-mode choice here (that selector is for choosing how to
  /// travel *within* an itinerary, not for reaching a transport service
  /// itself) — straight to the shared view-mode picker.
  static Future<void> startWithTarget(
    BuildContext context, {
    required NavTarget target,
  }) {
    return _startWithTarget(context, target: target);
  }

  /// Itinerary-leg entry point (addendum spec Section 6): shows the
  /// transport-mode selector first, then proceeds into the same
  /// view-mode picker used everywhere else.
  static Future<void> startFromItinerary(
    BuildContext context, {
    required LocationModel location,
  }) async {
    final mode = await showTransportModeSheet(context);
    if (mode == null || !context.mounted) return;
    await _startWithTarget(
      context,
      target: NavTarget.fromLocation(location),
      transportMode: mode,
    );
  }

  static Future<void> _startWithTarget(
    BuildContext context, {
    required NavTarget target,
    TransportModeOption transportMode = TransportModeOption.walk,
  }) async {
    final viewMode = await showNavViewModeSheet(context);
    if (viewMode == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          navTarget: target,
          viewMode: viewMode,
          transportMode: transportMode,
        ),
      ),
    );
  }
}

/// View-mode picker (addendum spec Section 1): Bird's-eye vs Turn-by-turn.
/// Returns `null` if the user dismisses the sheet without choosing.
Future<NavViewMode?> showNavViewModeSheet(BuildContext context) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<NavViewMode>(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a view',
              style: TextStyle(
                fontFamily: AppTheme.serifFont,
                fontSize: 20,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How would you like to navigate?',
              style: TextStyle(fontSize: 13, color: colors.muted),
            ),
            const SizedBox(height: 18),
            _NavModeOptionCard(
              colors: colors,
              icon: Icons.map_outlined,
              title: "Bird's-eye view",
              subtitle: 'Overview map with the full route line — no panel.',
              onTap: () => Navigator.of(sheetContext).pop(NavViewMode.birdsEye),
            ),
            const SizedBox(height: 12),
            _NavModeOptionCard(
              colors: colors,
              icon: Icons.navigation_outlined,
              title: 'Turn-by-turn view',
              subtitle:
                  'Step-by-step directions with a live heading and distance to the next turn.',
              onTap: () =>
                  Navigator.of(sheetContext).pop(NavViewMode.turnByTurn),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Transport-mode picker (addendum spec Section 6), shown before the
/// view-mode picker only for itinerary navigation. Returns `null` if the
/// user dismisses the sheet without choosing.
Future<TransportModeOption?> showTransportModeSheet(BuildContext context) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<TransportModeOption>(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how you\'ll travel',
              style: TextStyle(
                fontFamily: AppTheme.serifFont,
                fontSize: 20,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This leg will use the same walking-path route, shown in your chosen mode\'s color.',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: TransportModeOption.values
                  .map(
                    (mode) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _TransportModeButton(
                          colors: colors,
                          mode: mode,
                          onTap: () => Navigator.of(sheetContext).pop(mode),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavModeOptionCard extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavModeOptionCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.forest, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

class _TransportModeButton extends StatelessWidget {
  final AppColors colors;
  final TransportModeOption mode;
  final VoidCallback onTap;

  const _TransportModeButton({
    required this.colors,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mode.routeColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
