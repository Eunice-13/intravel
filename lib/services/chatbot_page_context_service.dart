import 'package:flutter/foundation.dart';

/// Tracks which location (if any) the user is currently looking at, so the
/// assistant can resolve vague references like "tell me more about this
/// place" or "how much does it cost" without the user naming it (chatbot
/// spec Section 6: "aware of what page/location the user is currently
/// viewing").
///
/// This exists because [ChatbotSideHandle] is deliberately mounted in
/// `MaterialApp.builder`, *outside* the Navigator subtree, so it persists
/// across page pushes — which also means it has no way to inspect the
/// current route or the screen beneath it. Screens that represent a
/// specific location publish themselves here instead.
///
/// The plumbing for this already existed end-to-end
/// ([ChatbotChatSheet.currentPageContext] → the conversation engine's
/// `_resolveFromPageContext`), but nothing ever supplied a value, so
/// page-aware follow-ups silently never worked. This is the missing
/// producer.
///
/// Session-only in-memory state (no persistence): "what am I looking at
/// right now" is meaningless across restarts.
class ChatbotPageContextService extends ChangeNotifier {
  static final ChatbotPageContextService instance =
      ChatbotPageContextService._internal();
  ChatbotPageContextService._internal();

  String? _currentLocationId;

  /// The id of the location currently on screen, or `null` when the user
  /// isn't on a location-specific page. Passed through to the chat sheet
  /// as its `currentPageContext`.
  String? get currentLocationId => _currentLocationId;

  /// Called by a location-specific screen when it becomes visible.
  void setCurrentLocation(String locationId) {
    if (_currentLocationId == locationId) return;
    _currentLocationId = locationId;
    notifyListeners();
  }

  /// Called when a location-specific screen goes away. Guarded by
  /// [locationId] so a screen being disposed *after* a newer one already
  /// registered doesn't clear the newer screen's context — push/pop
  /// ordering makes that interleaving normal.
  void clearCurrentLocation(String locationId) {
    if (_currentLocationId != locationId) return;
    _currentLocationId = null;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _currentLocationId = null;
  }
}
