import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/gemini_chat_service.dart';
import 'package:intravel/services/itinerary_service.dart';
import 'package:intravel/widgets/chatbot_chat_sheet.dart';

/// A scripted fake that returns whatever [GeminiChatResult]s are queued
/// via [enqueue], in order, for each successive `sendMessage`/
/// `sendFunctionResults` call — lets tests drive a specific
/// function-call → function-result → final-text sequence without a real
/// network call.
class _ScriptedGeminiChatService extends GeminiChatService {
  final List<GeminiChatResult> _queue = [];
  final List<Map<String, Map<String, Object?>>> functionResultCalls = [];
  int sendMessageCallCount = 0;

  void enqueue(GeminiChatResult result) => _queue.add(result);

  GeminiChatResult _next() {
    if (_queue.isEmpty) {
      throw StateError('No more scripted GeminiChatResults queued.');
    }
    return _queue.removeAt(0);
  }

  @override
  Future<GeminiChatResult> sendMessage(String message) async {
    sendMessageCallCount++;
    return _next();
  }

  @override
  Future<GeminiChatResult> sendFunctionResults(
    Map<String, Map<String, Object?>> results,
  ) async {
    functionResultCalls.add(results);
    return _next();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
    await ItineraryService.instance.load();
    // ItineraryService is a process-wide singleton with no `clear()` of
    // its own (unlike ChatMemoryService) — reset its in-memory state
    // directly between tests so an itinerary created by one test doesn't
    // leak into the next one's "starts empty" assertions.
    for (final itinerary in List.of(ItineraryService.instance.itineraries)) {
      await ItineraryService.instance.deleteItinerary(itinerary.id);
    }
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
    'checkPrice function call: resolves the location, reports the real '
    'ticket data back to Gemini, and shows its final text reply',
    (tester) async {
      final fake = _ScriptedGeminiChatService();
      // First turn: the model decides to call checkPrice instead of
      // answering directly.
      fake.enqueue(
        const GeminiChatResult(
          functionCalls: [
            GeminiFunctionCallRequest(
              name: kCheckPriceFunctionName,
              args: {'locationName': 'Fort Santiago'},
            ),
          ],
        ),
      );
      // Second turn: after receiving the real price data, the model
      // produces its final natural-language answer.
      fake.enqueue(
        const GeminiChatResult(
          text: 'Fort Santiago costs ₱75 for adults and ₱50 for students.',
        ),
      );

      await pumpSheet(tester, fake);
      await tester.enterText(
        find.byType(TextField),
        'how much does fort santiago cost',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(fake.sendMessageCallCount, 1);
      expect(fake.functionResultCalls, hasLength(1));
      final reportedArgs =
          fake.functionResultCalls.first[kCheckPriceFunctionName];
      expect(reportedArgs, isNotNull);
      expect(reportedArgs!['found'], true);
      expect(reportedArgs['locationName'], 'Fort Santiago');

      expect(
        find.textContaining('Fort Santiago costs'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'addToItinerary function call: surfaces a Yes/No confirmation '
    'instead of mutating the itinerary immediately',
    (tester) async {
      final fake = _ScriptedGeminiChatService();
      fake.enqueue(
        const GeminiChatResult(
          functionCalls: [
            GeminiFunctionCallRequest(
              name: kAddToItineraryFunctionName,
              args: {'locationName': 'Fort Santiago'},
            ),
          ],
        ),
      );

      await pumpSheet(tester, fake);
      await tester.enterText(
        find.byType(TextField),
        'i want to add fort santiago as a stop',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // No itinerary mutation yet, and no function-result reported back
      // yet either — the model's tool call is left pending until the
      // user explicitly confirms, per the mandatory confirm-before-acting
      // guardrail (spec Section 4).
      expect(fake.functionResultCalls, isEmpty);
      expect(ItineraryService.instance.itineraries, isEmpty);
      expect(find.textContaining('Add Fort Santiago'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      // Confirming now should execute the real ItineraryService call and
      // report the outcome back to Gemini for its closing reply.
      fake.enqueue(
        const GeminiChatResult(
          text: 'Done — added Fort Santiago to your itinerary!',
        ),
      );
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(fake.functionResultCalls, hasLength(1));
      expect(
        fake.functionResultCalls.first[kAddToItineraryFunctionName]?['status'],
        'success',
      );
      expect(ItineraryService.instance.itineraries, hasLength(1));
      expect(
        find.textContaining('added Fort Santiago'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'createItinerary function call: surfaces a Yes/No confirmation and '
    'only creates the itinerary once the user confirms',
    (tester) async {
      final fake = _ScriptedGeminiChatService();
      fake.enqueue(
        const GeminiChatResult(
          functionCalls: [
            GeminiFunctionCallRequest(
              name: kCreateItineraryFunctionName,
              args: {'itineraryName': 'Manila Weekend'},
            ),
          ],
        ),
      );

      await pumpSheet(tester, fake);
      await tester.enterText(
        find.byType(TextField),
        "I'd like to begin planning a brand new trip called Manila Weekend",
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(fake.functionResultCalls, isEmpty);
      expect(ItineraryService.instance.itineraries, isEmpty);
      expect(
        find.textContaining('Create a new itinerary called "Manila Weekend"'),
        findsOneWidget,
      );
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      fake.enqueue(
        const GeminiChatResult(
          text: 'Done — created your Manila Weekend itinerary!',
        ),
      );
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(fake.functionResultCalls, hasLength(1));
      expect(
        fake.functionResultCalls.first[kCreateItineraryFunctionName]?['status'],
        'success',
      );
      expect(ItineraryService.instance.itineraries, hasLength(1));
      expect(
        ItineraryService.instance.itineraries.first.name,
        'Manila Weekend',
      );
      expect(
        find.textContaining('created your Manila Weekend'),
        findsOneWidget,
      );
    },
  );
}
