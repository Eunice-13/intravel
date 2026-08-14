import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/bottom_nav_scaffold.dart';
import 'widgets/chatbot_side_handle.dart';
import 'screens/gate_selection_screen.dart';
import 'services/tts_service.dart';
import 'services/saved_places_service.dart';
import 'services/gate_selection_service.dart';
import 'services/itinerary_service.dart';
import 'services/review_service.dart';
import 'services/chatbot_visibility_service.dart';

/// App-wide [Navigator] key so widgets mounted outside the Navigator's
/// subtree (e.g. [ChatbotSideHandle], via [MaterialApp.builder]) can still
/// reach a [BuildContext] that sits inside it — needed to open dialogs/
/// modal sheets (like the chatbot's chat window) from there.
final GlobalKey<NavigatorState> chatbotNavigatorKey =
    GlobalKey<NavigatorState>();

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
  ChatbotVisibilityService.instance.load();

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
          navigatorKey: chatbotNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'InTravel',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const _StartupGate(),
          builder: (context, child) {
            // Mounts the chatbot's toggleable side handle above/outside
            // the Navigator's own subtree (see chatbot_side_handle.dart)
            // so it persists, unchanged, across every page's push/pop
            // instead of being torn down and rebuilt per-screen.
            return Stack(
              children: [
                ?child,
                const ChatbotSideHandle(),
              ],
            );
          },
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
