import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const InTravelApp());
}

class InTravelApp extends StatelessWidget {
  const InTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InTravel',
      home: InTravelDashboard(),
    );
  }
}

class InTravelDashboard extends StatefulWidget {
  const InTravelDashboard({super.key});

  @override
  State<InTravelDashboard> createState() => _InTravelDashboardState();
}

class _InTravelDashboardState extends State<InTravelDashboard> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _loadError;
  String? _savedNavigationState;
  bool _pageFinished = false;
  bool _stateRestoredForPage = false;

  @override
  void initState() {
    super.initState();
    _loadSavedNavigationState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'InTravelState',
        onMessageReceived: (message) {
          _saveNavigationState(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _pageFinished = false;
            _stateRestoredForPage = false;
            if (mounted) {
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
            }
          },
          onPageFinished: (_) {
            _pageFinished = true;
            _restoreSavedNavigationState();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? false) && mounted) {
              setState(() {
                _isLoading = false;
                _loadError = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            // The dashboard is a bundled, local-first experience. Blocking
            // arbitrary top-level navigation keeps untrusted pages from
            // replacing the app inside the WebView.
            final isBundledAsset = request.url.startsWith('file:');
            final isBlankPage = request.url == 'about:blank';
            return isBundledAsset || isBlankPage
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset('assets/intravel/index.html');
  }

  Future<void> _loadSavedNavigationState() async {
    final preferences = await SharedPreferences.getInstance();
    _savedNavigationState = preferences.getString('intravel.navigation.v1');
    _restoreSavedNavigationState();
  }

  Future<void> _saveNavigationState(String state) async {
    _savedNavigationState = state;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('intravel.navigation.v1', state);
  }

  Future<bool> _goBackInWebView() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'Boolean(window.InTravelApp && window.InTravelApp.goBack && window.InTravelApp.goBack())',
      );
      return result == true || result.toString() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _restoreSavedNavigationState() async {
    if (!_pageFinished || _stateRestoredForPage) return;
    _stateRestoredForPage = true;
    final state = _savedNavigationState;
    final serializedState =
        state == null || state.isEmpty ? 'null' : jsonEncode(state);
    await _controller.runJavaScript(
      'window.InTravelApp && window.InTravelApp.restoreState($serializedState)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handled = await _goBackInWebView();
        if (!handled) {
          await SystemNavigator.pop();
        }
      },
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
          SafeArea(
            top: false,
            bottom: false,
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const ColoredBox(
              color: Color(0xFF0D1713),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFDF9A43)),
              ),
            ),
          if (_loadError != null)
            ColoredBox(
              color: const Color(0xFF0D1713),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'InTravel could not load.',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFCBD5D0)),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _loadError = null;
                          });
                          _controller.reload();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
