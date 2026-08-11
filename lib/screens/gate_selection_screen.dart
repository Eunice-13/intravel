import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/gate_model.dart';
import '../services/gate_service.dart';
import '../services/gate_selection_service.dart';
import '../widgets/bottom_nav_scaffold.dart';

/// Entry-flow gate selection screen (spec Section 1). Shown once on first
/// launch — or reopened from Settings → "Starting Gate" to change the
/// choice later. Visual language (eyebrow + serif title, 2-column photo
/// grid cards with badge + name overlay) is reused from the existing Home
/// screen and location cards; no new design language is introduced.
class GateSelectionScreen extends StatelessWidget {
  /// When true, this is the first-launch onboarding flow: shows the "Skip"
  /// action and the nudge line, and proceeds straight into the app's main
  /// shell on either path. When false (revisit from Settings), it's a
  /// simple picker pushed on top of the existing navigation stack — no
  /// skip affordance needed since a choice already exists.
  final bool isOnboarding;

  const GateSelectionScreen({super.key, this.isOnboarding = true});

  void _selectGate(BuildContext context, GateModel gate) async {
    await GateSelectionService.instance.selectGate(gate.id);
    if (!context.mounted) return;
    if (isOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BottomNavScaffold()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip(BuildContext context) async {
    await GateSelectionService.instance.skip();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BottomNavScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final gates = GateService().getAllGates();

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: isOnboarding
          ? null
          : AppBar(
              backgroundColor: colors.paper,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.ink),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '— INTRAMUROS',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Where Are You\nEntering From?',
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 27,
                      color: colors.ink,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isOnboarding
                    ? 'Selecting your gate improves navigation accuracy — we\'ll use it to set your starting point on the map.'
                    : 'Pick the gate you are currently in. This sets your starting point on the navigation map.',
                style: TextStyle(
                  fontFamily: AppTheme.serifFont,
                  fontSize: 14,
                  color: colors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 158 / 204,
                ),
                itemBuilder: (context, index) {
                  final gate = gates[index];
                  return _GateCard(
                    gate: gate,
                    colors: colors,
                    onTap: () => _selectGate(context, gate),
                  );
                },
              ),

              if (isOnboarding) ...[
                const SizedBox(height: 28),
                Center(
                  child: GestureDetector(
                    onTap: () => _skip(context),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontFamily: AppTheme.serifFont,
                        fontSize: 15,
                        color: colors.muted,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gate Card ──────────────────────────────────────────────────────────────────
// Mirrors home_screen.dart's `_LocationCard`: rounded photo card with a
// white classification badge (top-right) and the gate name overlaid at the
// bottom on a dark gradient — same visual language, no new components.

class _GateCard extends StatelessWidget {
  final GateModel gate;
  final AppColors colors;
  final VoidCallback onTap;

  const _GateCard({
    required this.gate,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              gate.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4B6258), Color(0xFF1C4034)],
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  gate.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAB091C15)],
                  stops: [0.43, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  gate.kindLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF254438),
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 15,
              left: 15,
              right: 10,
              child: Text(
                gate.name,
                style: const TextStyle(
                  fontFamily: AppTheme.serifFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
