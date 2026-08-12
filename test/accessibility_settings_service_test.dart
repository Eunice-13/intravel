import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/services/accessibility_settings_service.dart';

void main() {
  // Reset shared singleton state between tests, since
  // AccessibilitySettingsService.instance is a process-wide singleton.
  setUp(() {
    AccessibilitySettingsService.instance.toggle(true);
  });

  test('defaults to enabled', () {
    expect(AccessibilitySettingsService.instance.isEnabled, isTrue);
  });

  test('toggle() with no argument flips the current value', () {
    final service = AccessibilitySettingsService.instance;
    expect(service.isEnabled, isTrue);

    service.toggle();
    expect(service.isEnabled, isFalse);

    service.toggle();
    expect(service.isEnabled, isTrue);
  });

  test('toggle(value) sets the value explicitly', () {
    final service = AccessibilitySettingsService.instance;

    service.toggle(false);
    expect(service.isEnabled, isFalse);

    service.toggle(false);
    expect(service.isEnabled, isFalse);

    service.toggle(true);
    expect(service.isEnabled, isTrue);
  });

  test('notifies listeners on toggle', () {
    final service = AccessibilitySettingsService.instance;
    var notifyCount = 0;
    void listener() => notifyCount++;

    service.addListener(listener);
    service.toggle();
    service.toggle();
    service.removeListener(listener);

    expect(notifyCount, 2);
  });
}
