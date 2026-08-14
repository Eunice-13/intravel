import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the IntraBadi chatbot's toggleable side icon/handle is
/// currently shown or hidden (chatbot spec Section 1): "the side icon's
/// shown/hidden state should also persist as the user navigates between
/// pages, so it doesn't reset to visible (or hidden) every time they
/// switch tabs." Mirrors [SavedPlacesService]'s singleton +
/// SharedPreferences pattern so the value also survives app restarts.
///
/// This only tracks the *handle's* visibility (collapsed tab vs. expanded
/// button) — not whether the chat window itself is open, which is
/// transient per-open and lives in the widget's own state.
class ChatbotVisibilityService extends ChangeNotifier {
  static final ChatbotVisibilityService instance =
      ChatbotVisibilityService._internal();
  ChatbotVisibilityService._internal();

  static const String _storageKey = 'intravel.chatbot-handle-visible.v1';

  // Shown by default so first-time users discover the assistant; the user
  // can then hide it themselves per the spec.
  bool _isVisible = true;
  bool _isLoaded = false;

  bool get isVisible => _isVisible;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_storageKey);
      if (stored != null) {
        _isVisible = stored;
      }
    } catch (_) {
      // Keep the in-memory default if persistence is unavailable.
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setVisible(bool value) async {
    if (_isVisible == value) return;
    _isVisible = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => setVisible(!_isVisible);
}
