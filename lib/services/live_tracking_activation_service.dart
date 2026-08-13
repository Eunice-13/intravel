import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'gate_selection_service.dart';
import 'gate_service.dart';

/// Tracks whether live GPS tracking has "activated" for the current app
/// session (addendum spec Section 2.3).
///
/// When the user has a selected starting gate, the app uses that gate's
/// fixed coordinates as the effective starting position — for both the
/// user's marker and route calculations — until the user's real GPS is
/// detected within ~50 meters of it. Once that threshold is crossed, live
/// GPS tracking takes over for the rest of the session. If the user
/// skipped gate selection entirely, live GPS is used from app start with
/// no fixed starting point to wait on.
///
/// Session state lives only in memory (same pattern as
/// [AccessibilitySettingsService]) — it resets on app restart, matching
/// the spec's own example scenario of opening the app while still far from
/// Intramuros, then approaching on a fresh launch.
class LiveTrackingActivationService extends ChangeNotifier {
  static final LiveTrackingActivationService instance =
      LiveTrackingActivationService._internal();
  LiveTrackingActivationService._internal();

  static const double _activationThresholdMeters = 50;

  bool _activated = false;

  /// True once live GPS should be used to position the user's marker and
  /// drive route calculations: immediately if no gate was ever selected,
  /// or once the user has come within [_activationThresholdMeters] of
  /// their selected gate.
  bool get isActive =>
      _activated || GateSelectionService.instance.selectedGateId == null;

  /// Call on every fresh GPS reading. No-ops once already activated, or if
  /// there's no selected gate to check proximity against (in which case
  /// [isActive] is already true unconditionally).
  void evaluate(Position position) {
    if (_activated) return;
    final gateId = GateSelectionService.instance.selectedGateId;
    if (gateId == null) return;
    final gate = GateService().getGateById(gateId);
    if (gate == null) return;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      gate.coordinates.latitude,
      gate.coordinates.longitude,
    );
    if (distance <= _activationThresholdMeters) {
      _activated = true;
      notifyListeners();
    }
  }
}
