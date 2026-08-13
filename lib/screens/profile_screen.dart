import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../models/nav_target.dart';
import '../models/route_model.dart';
import '../services/gate_selection_service.dart';
import '../services/gate_service.dart';
import '../services/accessibility_settings_service.dart';
import '../services/route_service.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';
import '../widgets/nav_flow_launcher.dart';
import 'favorites_screen.dart';
import 'gate_selection_screen.dart';
import 'reviewable_locations_screen.dart';

/// Settings screen, ported from the Eunice-branch `#screen-profile` markup:
/// guest sign-in card, weather card, Dark Mode toggle (wired to the app-wide
/// [ThemeController] so it actually re-themes every screen), Map style
/// toggle, and navigation rows into Saved Places / Accessibility Support.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _mapStyle = 'Standard';

  /// Whether the Transport & Access section is expanded (addendum spec
  /// Section 4.3's "minimize/collapse control"). Starts expanded, same
  /// default as the Navigate flow's Live Updates panel.
  bool _isTransportSectionExpanded = true;

  // Intramuros, Manila — same default center used by the app's map screens.
  static const double _weatherLat = 14.5906;
  static const double _weatherLon = 120.9750;

  WeatherSnapshot? _weather;
  bool _isWeatherLoading = true;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isWeatherLoading = true;
      _weatherError = null;
    });
    try {
      final snapshot = await WeatherService().fetchCurrent(
        latitude: _weatherLat,
        longitude: _weatherLon,
      );
      if (!mounted) return;
      setState(() {
        _weather = snapshot;
        _isWeatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = e is WeatherException
            ? e.message
            : 'Could not load weather.';
        _isWeatherLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;
        return Scaffold(
          backgroundColor: colors.paper,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '— PROFILE',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 27,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 21),

                  // ─── Guest Card ────────────────────────────────────────
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign-in will be available soon'),
                        duration: Duration(seconds: 1),
                      ),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 106),
                      padding: const EdgeInsets.all(19),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.muted.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD8D8D8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  'Click to sign in',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '›',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 42),

                  // ─── Weather Card ──────────────────────────────────────
                  GestureDetector(
                    onTap: _weatherError != null ? _loadWeather : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 106),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF343434) : AppTheme.warm,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 61,
                            height: 61,
                            decoration: BoxDecoration(
                              color: colors.card,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: _isWeatherLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: const Color(0xFFA68752),
                                    ),
                                  )
                                : Text(
                                    _weatherError != null
                                        ? '⚠'
                                        : _weather!.condition.glyph,
                                    style: TextStyle(
                                      fontSize: 25,
                                      color: const Color(0xFFA68752),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INTRAMUROS · TODAY',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isWeatherLoading
                                      ? 'Loading weather…'
                                      : _weatherError != null
                                      ? 'Weather unavailable — tap to retry'
                                      : '${_weather!.temperatureLabel} ${_weather!.condition.label}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),

                  // ─── Appearance ────────────────────────────────────────
                  Text(
                    'APPEARANCE',
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _SettingRow(
                    colors: colors,
                    label: 'Dark Mode',
                    trailing: _SwitchPill(isOn: isDark, colors: colors),
                    onTap: () => ThemeController.instance.toggleDarkMode(),
                  ),

                  const SizedBox(height: 17),
                  Text(
                    'MAP',
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minHeight: 67),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.muted.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MapToggleButton(
                            colors: colors,
                            label: 'Standard',
                            isActive: _mapStyle == 'Standard',
                            onTap: () => setState(() => _mapStyle = 'Standard'),
                          ),
                        ),
                        Expanded(
                          child: _MapToggleButton(
                            colors: colors,
                            label: 'Satellite',
                            isActive: _mapStyle == 'Satellite',
                            onTap: () =>
                                setState(() => _mapStyle = 'Satellite'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  _SettingRow(
                    colors: colors,
                    label: 'Saved Places',
                    trailing: Text(
                      '›',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: colors.muted,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  _SettingRow(
                    colors: colors,
                    label: 'Reviews',
                    trailing: Text(
                      '›',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: colors.muted,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReviewableLocationsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  AnimatedBuilder(
                    animation: AccessibilitySettingsService.instance,
                    builder: (context, _) {
                      final isEnabled =
                          AccessibilitySettingsService.instance.isEnabled;
                      return _SettingRow(
                        colors: colors,
                        label: 'Accessibility Support',
                        trailing: _SwitchPill(isOn: isEnabled, colors: colors),
                        onTap: () =>
                            AccessibilitySettingsService.instance.toggle(),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  AnimatedBuilder(
                    animation: GateSelectionService.instance,
                    builder: (context, _) {
                      final selectedGate =
                          GateSelectionService.instance.selectedGateId;
                      final gateName = selectedGate != null
                          ? GateService().getGateById(selectedGate)?.name
                          : null;
                      return _SettingRow(
                        colors: colors,
                        label: 'Starting Gate',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gateName ?? 'Not set',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '›',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GateSelectionScreen(
                                isOnboarding: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 17),
                  _buildTransportAccessSection(colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Transport & Access (addendum spec Section 4.3) ────────────────────

  Widget _buildTransportAccessSection(AppColors colors) {
    final options = RouteService().getTransportOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(
            () => _isTransportSectionExpanded = !_isTransportSectionExpanded,
          ),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                'TRANSPORT & ACCESS',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
              const Spacer(),
              Icon(
                _isTransportSectionExpanded
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
          child: _isTransportSectionExpanded
              ? Column(
                  children: options
                      .map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransportOptionCard(
                            colors: colors,
                            option: option,
                            onTap: option.coordinates == null
                                ? null
                                : () => NavFlowLauncher.startWithTarget(
                                    context,
                                    target: NavTarget(
                                      name: option.name,
                                      coordinates: option.coordinates!,
                                    ),
                                  ),
                          ),
                        ),
                      )
                      .toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Transport Option Card ───────────────────────────────────────────────────
// Addendum spec Section 4.3: tapping a transport option navigates to its
// real-world location (verified via web search — see RouteService), using
// the shared Navigate flow like every other destination in the app.
// [onTap] is null for options with no single fixed real-world point,
// which disables the row's navigate affordance while still showing
// pricing/notes.

class _TransportOptionCard extends StatelessWidget {
  final AppColors colors;
  final TransportOption option;
  final VoidCallback? onTap;

  const _TransportOptionCard({
    required this.colors,
    required this.option,
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
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(option.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.pricing,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                  if (option.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: colors.accent,
                        ),
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
            ),
            if (onTap != null)
              Icon(Icons.navigation_outlined, color: colors.forest, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Setting Row ────────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final AppColors colors;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.colors,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 67),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.muted.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.ink.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Switch Pill ─────────────────────────────────────────────────────────────────

class _SwitchPill extends StatelessWidget {
  final bool isOn;
  final AppColors colors;

  const _SwitchPill({required this.isOn, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 45,
      height: 25,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isOn ? colors.forest : const Color(0xFFDEDEDE),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Map Toggle Button ───────────────────────────────────────────────────────────

class _MapToggleButton extends StatelessWidget {
  final AppColors colors;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MapToggleButton({
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
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? colors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : colors.ink,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
