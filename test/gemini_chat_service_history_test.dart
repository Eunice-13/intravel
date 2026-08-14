import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/models/chat_message_model.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/gemini_api_key_loader.dart';
import 'package:intravel/services/gemini_chat_service.dart';

/// Fake [http.Client] that records the JSON body of every request it
/// receives and returns a fixed, minimal-but-valid `generateContent`
/// response shape, so [GeminiChatService] can be driven through a real
/// `sendMessage` call — and thus really construct its `ChatSession` and
/// send a real (locally captured) request — without any actual network
/// access.
class _RecordingFakeClient extends http.BaseClient {
  final List<Map<String, Object?>> capturedRequestBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      capturedRequestBodies.add(
        jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, Object?>,
      );
    }
    const responseJson = {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'A reply grounded in the seeded history.'},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    };
    final bytes = utf8.encode(jsonEncode(responseJson));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Verifies the fix for "the bot doesn't understand context from
/// earlier turns because a fresh chat sheet starts Gemini off with no
/// memory of what was already said" — [GeminiChatService] must seed its
/// underlying `ChatSession` from whatever [ChatMemoryService] already
/// has persisted (spec Section 6: multi-turn memory), not start empty
/// every time a new instance is constructed, which happens every time
/// the chat sheet widget is reopened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
    rootBundle.evict('docs/intramuros-app-spec-chatbot.md');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'docs/intramuros-app-spec-chatbot.md') {
        final bytes = utf8.encode('# Test spec\nJust a stub for tests.');
        return ByteData.view(Uint8List.fromList(bytes).buffer);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test(
    'sends prior ChatMemoryService turns as part of the very first '
    'request, instead of starting the session with no memory of them',
    () async {
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.user,
        text: 'Tell me about Fort Santiago',
      );
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.assistant,
        text: 'Fort Santiago is a historic fortification in Intramuros.',
      );

      final fakeClient = _RecordingFakeClient();
      final service = GeminiChatService(
        apiKeyLoader: GeminiApiKeyLoader(compileTimeApiKey: 'test-key-123'),
        chatMemoryService: ChatMemoryService.instance,
        httpClient: fakeClient,
      );

      await service.sendMessage('I want to add specific stops');

      expect(fakeClient.capturedRequestBodies, hasLength(1));
      final contents =
          fakeClient.capturedRequestBodies.first['contents'] as List;

      // 2 seeded history turns + the new message just sent = 3.
      expect(contents, hasLength(3));
      expect(contents[0], {
        'role': 'user',
        'parts': [
          {'text': 'Tell me about Fort Santiago'},
        ],
      });
      expect(contents[1], {
        'role': 'model',
        'parts': [
          {'text': 'Fort Santiago is a historic fortification in Intramuros.'},
        ],
      });
      expect(contents[2], {
        'role': 'user',
        'parts': [
          {'text': 'I want to add specific stops'},
        ],
      });
    },
  );

  test(
    'starts with an empty history when ChatMemoryService has no prior '
    'turns, sending only the new message',
    () async {
      final fakeClient = _RecordingFakeClient();
      final service = GeminiChatService(
        apiKeyLoader: GeminiApiKeyLoader(compileTimeApiKey: 'test-key-123'),
        chatMemoryService: ChatMemoryService.instance,
        httpClient: fakeClient,
      );

      await service.sendMessage('Is Intramuros walkable?');

      final contents =
          fakeClient.capturedRequestBodies.first['contents'] as List;
      expect(contents, hasLength(1));
      expect(contents[0], {
        'role': 'user',
        'parts': [
          {'text': 'Is Intramuros walkable?'},
        ],
      });
    },
  );
}
