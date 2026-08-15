import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/gemini_api_key_loader.dart';
import 'package:intravel/services/gemini_chat_service.dart';

/// Fake client that replays a scripted sequence of HTTP statuses, so the
/// service's retry behavior can be driven deterministically without network
/// access.
class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.statuses);

  /// One entry per expected request, consumed in order. The last entry
  /// repeats if more requests arrive than were scripted.
  final List<int> statuses;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final status = statuses[requestCount.clamp(0, statuses.length - 1)];
    requestCount++;

    final body = status == 200
        ? jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'pong'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          })
        : jsonEncode({
            'error': {
              'code': status,
              'message': status == 503
                  ? 'This model is currently experiencing high demand.'
                  : 'API key not valid. Please pass a valid API key.',
              'status': status == 503 ? 'UNAVAILABLE' : 'INVALID_ARGUMENT',
            },
          });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Locks in the transient-failure handling added after observing the real
/// API return `503 UNAVAILABLE / "high demand"` intermittently on
/// `gemini-flash-latest` — the same request returned 503, 503, then 200
/// seconds apart. Before this, any such blip dropped the assistant to its
/// offline engine for that turn, making a temporary capacity spike look
/// like a broken integration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
    rootBundle.evict('env.json');
    // No env.json in tests — the key is injected via the loader instead.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'env.json') {
            final bytes = utf8.encode('{"GEMINI_API_KEY": ""}');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  GeminiChatService serviceWith(_ScriptedClient client) => GeminiChatService(
    apiKeyLoader: GeminiApiKeyLoader(compileTimeApiKey: 'test-key'),
    httpClient: client,
  );

  test('recovers from a transient 503 by retrying, instead of degrading to the '
      'offline engine on the first blip', () async {
    final client = _ScriptedClient([503, 503, 200]);
    final result = await serviceWith(client).sendMessage('ping');

    expect(result.text, 'pong');
    expect(
      client.requestCount,
      3,
      reason: 'should have retried twice before succeeding',
    );
  });

  test(
    'succeeds on the first attempt without any retry when healthy',
    () async {
      final client = _ScriptedClient([200]);
      final result = await serviceWith(client).sendMessage('ping');

      expect(result.text, 'pong');
      expect(client.requestCount, 1, reason: 'no retry should be needed');
    },
  );

  test('does NOT retry a non-transient failure — a rejected key fails the same '
      'way every time, so retrying only wastes the user\'s time', () async {
    final client = _ScriptedClient([400]);

    await expectLater(
      serviceWith(client).sendMessage('ping'),
      throwsA(isA<GeminiChatException>()),
    );
    expect(
      client.requestCount,
      1,
      reason: '400 is a request/credential problem, not worth retrying',
    );
  });

  test(
    'gives up after a bounded number of attempts when 503 persists, and '
    'surfaces the underlying cause rather than a bare generic message',
    () async {
      final client = _ScriptedClient([503]);

      try {
        await serviceWith(client).sendMessage('ping');
        fail('expected a GeminiChatException');
      } on GeminiChatException catch (e) {
        // The chat sheet logs this string when it falls back offline; a bare
        // "Failed to get a response" gave no way to tell a capacity blip
        // apart from a rejected key.
        expect(e.message, contains('Failed to get a response'));
        expect(
          e.message.toLowerCase(),
          anyOf(contains('503'), contains('unavailable'), contains('demand')),
          reason: 'the real cause must be visible in the message',
        );
        expect(e.cause, isNotNull);
      }

      expect(
        client.requestCount,
        3,
        reason: 'bounded retry: must not loop indefinitely',
      );
    },
  );

  test('an empty message is rejected before any request is made', () async {
    final client = _ScriptedClient([200]);

    await expectLater(
      serviceWith(client).sendMessage('   '),
      throwsA(isA<GeminiChatException>()),
    );
    expect(client.requestCount, 0);
  });
}
