import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/services/gate_selection_service.dart';
import 'package:intravel/services/gate_service.dart';
import 'package:intravel/services/live_tracking_activation_service.dart';

/// Builds a [Position] at the given point. Only lat/lng matter here.
Position _positionAt(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Both are process-wide singletons with intentionally sticky session
    // state, so each case must start from a clean slate — otherwise an
    // earlier test activating tracking would silently satisfy a later one.
    GateSelectionService.instance.resetForTesting();
    LiveTrackingActivationService.instance.resetForTesting();
  });

  group('starting gate is only the start, not a position override', () {
    test('live tracking stays inactive while the user is still far from their '
        'selected gate, so the gate remains the effective start', () async {
      await GateSelectionService.instance.selectGate('puerta-real');

      // Somewhere else in Metro Manila — Quezon City, ~12km away.
      LiveTrackingActivationService.instance.evaluate(
        _positionAt(14.6760, 121.0437),
      );

      expect(
        LiveTrackingActivationService.instance.isActive,
        isFalse,
        reason:
            'a distant GPS fix must not activate live tracking; the gate '
            'is still the source of truth for the start position',
      );
    });

    test('arriving within ~50m of the selected gate activates live tracking, '
        'handing position back to real GPS', () async {
      await GateSelectionService.instance.selectGate('puerta-real');
      final gate = GateService().getGateById('puerta-real')!;

      expect(LiveTrackingActivationService.instance.isActive, isFalse);

      // Essentially standing at the gate.
      LiveTrackingActivationService.instance.evaluate(
        _positionAt(gate.coordinates.latitude, gate.coordinates.longitude),
      );

      expect(
        LiveTrackingActivationService.instance.isActive,
        isTrue,
        reason: 'the user has arrived, so their real position takes over',
      );
    });

    test(
      'once activated, walking well away from the gate does NOT revert to '
      'gate-anchored positioning — the gate was only the starting point',
      () async {
        await GateSelectionService.instance.selectGate('puerta-real');
        final gate = GateService().getGateById('puerta-real')!;

        LiveTrackingActivationService.instance.evaluate(
          _positionAt(gate.coordinates.latitude, gate.coordinates.longitude),
        );
        expect(LiveTrackingActivationService.instance.isActive, isTrue);

        // Now deep inside Intramuros, far past the 50m activation radius.
        LiveTrackingActivationService.instance.evaluate(
          _positionAt(14.5906, 120.9750),
        );

        expect(
          LiveTrackingActivationService.instance.isActive,
          isTrue,
          reason:
              'tracking must stay live for the rest of the session so the '
              'app keeps following the user\'s actual whereabouts',
        );
      },
    );

    test('skipping gate selection leaves live tracking active from the start, '
        'so raw GPS drives position with no gate to wait on', () async {
      await GateSelectionService.instance.skip();

      expect(
        GateSelectionService.instance.selectedGateId,
        isNull,
        reason: 'skip records no gate',
      );
      expect(
        LiveTrackingActivationService.instance.isActive,
        isTrue,
        reason: 'with no gate selected there is nothing to anchor to',
      );
    });
  });

  group('gate selection propagates', () {
    test(
      'selecting a gate notifies listeners so every surface can rebuild',
      () async {
        var notifications = 0;
        void listener() => notifications++;
        GateSelectionService.instance.addListener(listener);
        addTearDown(
          () => GateSelectionService.instance.removeListener(listener),
        );

        await GateSelectionService.instance.selectGate('victoria-street');
        await GateSelectionService.instance.selectGate('aduana-magallanes');

        expect(
          notifications,
          greaterThanOrEqualTo(2),
          reason:
              'screens listen to this service to reflect the change in their '
              'markers, route start, and camera',
        );
        expect(
          GateSelectionService.instance.selectedGateId,
          'aduana-magallanes',
        );
      },
    );

    test('every catalogued gate resolves to real coordinates', () {
      final gates = GateService().getAllGates();
      expect(gates, isNotEmpty);
      for (final gate in gates) {
        expect(
          GateService().getGateById(gate.id),
          isNotNull,
          reason: '${gate.id} must be resolvable by id',
        );
        // Inside the greater Manila area — guards against a gate pin
        // drifting somewhere nonsensical.
        expect(gate.coordinates.latitude, closeTo(14.59, 0.05));
        expect(gate.coordinates.longitude, closeTo(120.975, 0.05));
      }
    });

    test('every gate photo points at an image file, not a webpage', () {
      for (final gate in GateService().getAllGates()) {
        expect(
          gate.imageUrl,
          startsWith('https://'),
          reason: '${gate.id} should load its photo over https',
        );
        expect(
          RegExp(
            r'\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ).hasMatch(Uri.parse(gate.imageUrl).path),
          isTrue,
          reason:
              '${gate.id} imageUrl must be a direct image file — a page URL '
              'renders as a blank fallback box',
        );
      }
    });
  });
}
