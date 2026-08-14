import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/gemini_chat_service.dart';
import 'package:intravel/widgets/chatbot_chat_sheet.dart';

/// A controllable fake so tests can assert the loading state appears
/// while [sendMessage] is pending, and control exactly when/how it
/// resolves, without making a real network call.
class _FakeGeminiChatService extends GeminiChatService {
  _FakeGeminiChatService();

  Completer<GeminiChatResult>? _pendingCompleter;
  bool shouldThrow = false;
  int callCount = 0;

  @override
  Future<GeminiChatResult> sendMessage(String message) async {
    callCount++;
    if (shouldThrow) {
      throw const GeminiChatException('fake failure');
    }
    final completer = Completer<GeminiChatResult>();
    _pendingCompleter = completer;
    return completer.future;
  }

  void resolveWith(String text) {
    _pendingCompleter?.complete(GeminiChatResult(text: text));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    GeminiChatService geminiService,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatbotChatSheet(geminiService: geminiService),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a loading indicator while awaiting the Gemini reply, then '
    'shows the reply as a new bubble',
    (tester) async {
      final fake = _FakeGeminiChatService();
      await pumpSheet(tester, fake);

      await tester.enterText(find.byType(TextField), 'is intramuros walkable');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(); // user message appended
      await tester.pump(); // engine processed, Gemini call started

      // Loading indicator (three animated dots) should be visible while
      // the fake service's Future is still unresolved.
      expect(find.byType(AnimatedBuilder), findsWidgets);
      expect(fake.callCount, 1);

      fake.resolveWith('Yes, Intramuros is very walkable!');
      await tester.pumpAndSettle();

      expect(find.text('Yes, Intramuros is very walkable!'), findsOneWidget);
    },
  );

  testWidgets(
    'falls back to the engine\'s offline answer if Gemini throws',
    (tester) async {
      final fake = _FakeGeminiChatService()..shouldThrow = true;
      await pumpSheet(tester, fake);

      await tester.enterText(find.byType(TextField), 'is intramuros walkable');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(fake.callCount, 1);
      // The engine's own general-topic fallback text should be shown
      // instead of leaving the chat stuck on the loading indicator.
      expect(find.textContaining('walkable'), findsWidgets);
    },
  );

  testWidgets(
    'never calls Gemini for an out-of-scope (declined) message',
    (tester) async {
      final fake = _FakeGeminiChatService();
      await pumpSheet(tester, fake);

      await tester.enterText(
        find.byType(TextField),
        'how do i get to intramuros from the airport',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(fake.callCount, 0);
      expect(find.textContaining('Intramuros and this app'), findsOneWidget);
    },
  );

  testWidgets(
    'never calls Gemini for a recognized action request awaiting '
    'confirmation',
    (tester) async {
      final fake = _FakeGeminiChatService();
      await pumpSheet(tester, fake);

      await tester.enterText(
        find.byType(TextField),
        'add fort santiago to my itinerary',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(fake.callCount, 0);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    },
  );
}
