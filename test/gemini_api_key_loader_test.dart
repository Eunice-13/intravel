import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/services/gemini_api_key_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // rootBundle caches loaded assets by key internally; without
    // clearing it between tests, a later test's mock handler for
    // 'env.json' would never actually be hit — the cached bytes from an
    // earlier test's mock response would be served instead.
    rootBundle.evict('env.json');
  });

  test('prefers the compile-time define over the asset fallback', () async {
    final loader = GeminiApiKeyLoader(compileTimeApiKey: 'compile-time-key');
    final key = await loader.resolveApiKey();
    expect(key, 'compile-time-key');
    expect(loader.hasCompileTimeKey, isTrue);
  });

  test('falls back to loading GEMINI_API_KEY from the env.json asset '
      'when no compile-time key is set', () async {
    // Simulate the bundled env.json asset without touching the real
    // gitignored file on disk.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'env.json') {
            final bytes = utf8.encode('{"GEMINI_API_KEY": "asset-key-123"}');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          return null;
        });

    final loader = GeminiApiKeyLoader(compileTimeApiKey: '');
    final key = await loader.resolveApiKey();
    expect(key, 'asset-key-123');
    expect(loader.hasCompileTimeKey, isFalse);

    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('returns empty string when neither source has a key', () async {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => null);

    final loader = GeminiApiKeyLoader(compileTimeApiKey: '');
    final key = await loader.resolveApiKey();
    expect(key, '');

    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}
