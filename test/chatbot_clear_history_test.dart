import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/models/chat_message_model.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/widgets/chatbot_chat_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatbotChatSheet()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping the clear-history icon shows a confirmation dialog with '
    'Proceed and Cancel, and Cancel leaves the history untouched',
    (tester) async {
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.user,
        text: 'hello there',
      );

      await pumpSheet(tester);
      expect(find.text('hello there'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Clear chat history?'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, message still there — Cancel did nothing.
      expect(find.text('Clear chat history?'), findsNothing);
      expect(ChatMemoryService.instance.messages, hasLength(1));
      expect(find.text('hello there'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Proceed in the confirmation dialog clears the chat history',
    (tester) async {
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.user,
        text: 'hello there',
      );

      await pumpSheet(tester);
      expect(find.text('hello there'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(ChatMemoryService.instance.messages, isEmpty);
      expect(find.text('hello there'), findsNothing);
    },
  );
}
