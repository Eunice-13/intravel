import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/profile_screen.dart';

/// Root shell with the persistent bottom nav bar. Matches the
/// Eunice-branch `#bottomNav` structure exactly: four destinations — Home,
/// Navigation, Plans, Profile (labelled "Settings" when active). "Your Hub"
/// (saved places) is intentionally NOT a tab here — in the branch it's
/// reached from Settings → Saved Places and hides the bottom bar, which is
/// what happens naturally when [FavoritesScreen] is pushed via Navigator.
class BottomNavScaffold extends StatefulWidget {
  final int initialIndex;

  const BottomNavScaffold({super.key, this.initialIndex = 0});

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screens = [
      HomeScreen(onOpenPlans: () => _goToTab(2)),
      const NavigationScreen(),
      const PlansScreen(),
      ProfileScreen(onOpenAccessibility: () => _goToTab(1)),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.paper,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
            child: Container(
              height: 76,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border.all(color: const Color(0xFFE3E5E3)),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      colors: colors,
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isActive: _currentIndex == 0,
                      onTap: () => _goToTab(0),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      colors: colors,
                      icon: Icons.explore_outlined,
                      label: 'Navigation',
                      isActive: _currentIndex == 1,
                      onTap: () => _goToTab(1),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      colors: colors,
                      icon: Icons.map_outlined,
                      label: 'Plans',
                      isActive: _currentIndex == 2,
                      onTap: () => _goToTab(2),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      colors: colors,
                      icon: Icons.person_outline_rounded,
                      label: 'Settings',
                      isActive: _currentIndex == 3,
                      onTap: () => _goToTab(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Button ─────────────────────────────────────────────────────────────────
// Mirrors `.nav-button` / `.nav-button.active`: inactive tabs show only the
// icon; the active tab expands into a forest-green pill with icon + label.

class _NavButton extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 15)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isActive ? colors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.center,
        // `mainAxisSize: min` alone isn't enough here: this Row sits inside
        // an `Expanded` slot with a *tight* width (one quarter of the bar),
        // so if the icon + label combo is wider than that slot — e.g. the
        // 10-character "Navigation" label — it used to overflow and throw a
        // RenderFlex exception that aborted the whole frame's paint (which
        // is why the entire nav bar, and whatever screen shared that frame,
        // appeared broken). Wrapping the label in `Flexible` + ellipsis lets
        // it shrink to fit instead of overflowing.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isActive ? Colors.white : const Color(0xFF667F75),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
