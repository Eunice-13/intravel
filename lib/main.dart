import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/bottom_nav_scaffold.dart';
import 'screens/gate_selection_screen.dart';
import 'services/tts_service.dart';
import 'services/saved_places_service.dart';
import 'services/gate_selection_service.dart';
import 'services/itinerary_service.dart';
import 'services/review_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  TtsService().initialize();
  SavedPlacesService.instance.load();
  ItineraryService.instance.load();
  ReviewService.instance.load();

  runApp(const InTravelApp());
}

class InTravelApp extends StatelessWidget {
  const InTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'InTravel',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const _StartupGate(),
        );
      },
    );
  }
}

/// Decides whether to show the gate-selection onboarding screen (first
/// launch only, per spec Section 1.2) or go straight to the main app shell
/// once the stored onboarding state has loaded.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = GateSelectionService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(backgroundColor: AppTheme.paper);
        }
        return GateSelectionService.instance.onboardingComplete
            ? const BottomNavScaffold()
            : const GateSelectionScreen();
      },
    );
  }
}
