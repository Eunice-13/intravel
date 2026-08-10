import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen starting gate (spec Section 1), plus whether
/// the first-launch onboarding prompt has already been shown so it's never
/// re-shown automatically after the user picks a gate or skips it.
class GateSelectionService extends ChangeNotifier {
  static final GateSelectionService instance =
      GateSelectionService._internal();
  GateSelectionService._internal();

  static const String _onboardingCompleteKey =
      'intravel.gate-onboarding-complete.v1';
  static const String _selectedGateIdKey = 'intravel.selected-gate-id.v1';

  bool _onboardingComplete = false;
  String? _selectedGateId;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get onboardingComplete => _onboardingComplete;
  String? get selectedGateId => _selectedGateId;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;
      _selectedGateId = prefs.getString(_selectedGateIdKey);
    } catch (_) {
      // Fall back to "not onboarded yet" if persistence is unavailable.
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Records the user's chosen gate and marks onboarding as complete.
  Future<void> selectGate(String gateId) async {
    _selectedGateId = gateId;
    _onboardingComplete = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedGateIdKey, gateId);
      await prefs.setBool(_onboardingCompleteKey, true);
    } catch (_) {}
  }

  /// Marks onboarding as complete without recording a gate (Skip).
  Future<void> skip() async {
    _onboardingComplete = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompleteKey, true);
    } catch (_) {}
  }
}
