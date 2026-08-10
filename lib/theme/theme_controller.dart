import 'package:flutter/material.dart';

/// App-wide dark mode switch, mirroring the Eunice-branch web dashboard's
/// `darkMode` boolean and `.dark` class toggle on the root `#app` element.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleDarkMode([bool? value]) {
    _isDarkMode = value ?? !_isDarkMode;
    notifyListeners();
  }
}
