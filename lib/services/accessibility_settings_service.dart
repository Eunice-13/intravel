import 'package:flutter/material.dart';

/// App-wide "Accessibility Support" on/off switch (addendum spec Section
/// 4.2), mirroring [ThemeController]'s in-memory `ChangeNotifier` pattern
/// (session-scoped, not persisted — same as Dark Mode).
///
/// When OFF, the Navigate flow's "Live Updates" / "Accessibility Modes"
/// panel is hidden entirely; when ON, it's shown (see
/// `NavigationScreen._buildAccessibilityPanel`).
class AccessibilitySettingsService extends ChangeNotifier {
  static final AccessibilitySettingsService instance =
      AccessibilitySettingsService._internal();
  AccessibilitySettingsService._internal();

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  void toggle([bool? value]) {
    _isEnabled = value ?? !_isEnabled;
    notifyListeners();
  }
}
