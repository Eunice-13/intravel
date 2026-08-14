import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/chatbot_conversation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
  });

  test(
    'does not keep answering about a previously-discussed location once '
    'a new, unrelated question is asked (regression: bot fixating on '
    'Fort Santiago for every later question)',
    () {
      final engine = ChatbotConversationEngine();

      // First: a genuine, specific question about Fort Santiago —
      // establishes it as the "most recently discussed" location.
      final first = engine.process('tell me about fort santiago');
      expect(first.outcome, ChatbotEngineOutcome.answered);
      expect(first.replyText, contains('Fort Santiago'));

      // Next: a completely different, dataset-wide question that names
      // no location at all. Must NOT describe Fort Santiago.
      final discountResult = engine.process(
        'what locations have discounted rates',
      );
      expect(discountResult.outcome, ChatbotEngineOutcome.answered);
      expect(discountResult.replyText, isNot(contains('seat of Spanish')));
      expect(
        discountResult.replyText.toLowerCase(),
        contains('discount'),
      );

      // Then: an itinerary how-to question, also naming no location.
      // Must not describe Fort Santiago either.
      final howToResult = engine.process(
        'how do I add a stop to my itinerary?',
      );
      expect(howToResult.replyText, isNot(contains('seat of Spanish')));
    },
  );

  test(
    'a genuine vague follow-up ("how much does it cost") still resolves '
    'against the most recently discussed location',
    () {
      final engine = ChatbotConversationEngine();

      engine.process('tell me about fort santiago');
      final followUp = engine.process('how much does it cost');

      expect(followUp.outcome, ChatbotEngineOutcome.answered);
      expect(followUp.replyText, contains('Fort Santiago'));
    },
  );

  test(
    'a discount question naming no location lists real discounted '
    'places from the dataset',
    () {
      final engine = ChatbotConversationEngine();
      final result = engine.process('which places are cheapest');

      expect(result.outcome, ChatbotEngineOutcome.answered);
      expect(result.replyText.toLowerCase(), contains('discount'));
    },
  );

  test(
    'a direct "create an itinerary" request surfaces a pending '
    'confirmation with a default name when none is given',
    () {
      final engine = ChatbotConversationEngine();
      final result = engine.process('create an itinerary');

      expect(result.outcome, ChatbotEngineOutcome.actionPending);
      expect(result.pendingAction, isNotNull);
      expect(result.pendingAction!.targetLabel, 'My Itinerary');
      expect(result.replyText, contains('My Itinerary'));
    },
  );

  test(
    'a "create an itinerary called X" request uses the given name',
    () {
      final engine = ChatbotConversationEngine();
      final result = engine.process(
        'create a new itinerary called Manila Weekend',
      );

      expect(result.outcome, ChatbotEngineOutcome.actionPending);
      expect(result.pendingAction!.targetLabel, 'manila weekend');
    },
  );

  group('navigation requests wrapped in a question phrasing are still '
      'recognized as navigation, not answered with a definition '
      '(regression: "how do I navigate to Fort Santiago" incorrectly '
      'returned Fort Santiago\'s history instead of asking to navigate)', () {
    final phrasings = [
      'how do i navigate to fort santiago',
      'how to navigate to fort santiago',
      'can you navigate me to fort santiago',
      'how can i get to fort santiago',
      'how do i navigate to fort santiago to one of the cafes',
    ];

    for (final phrase in phrasings) {
      test('"$phrase"', () {
        final engine = ChatbotConversationEngine();
        final result = engine.process(phrase);

        expect(result.outcome, ChatbotEngineOutcome.actionPending);
        expect(result.pendingAction, isNotNull);
        expect(result.pendingAction!.targetLabel, 'Fort Santiago');
        // Must be a navigation confirmation, not the location's
        // history/definition.
        expect(result.replyText, contains('Start navigation'));
        expect(result.replyText, isNot(contains('seat of Spanish')));
      });
    }
  });

  test(
    'a discount question naming no location returns a numbered list with '
    'real per-place prices, not a flat comma-joined sentence with no '
    'details (regression: reply used to say "ask me about a specific '
    'one for the exact prices" instead of just giving them)',
    () {
      final engine = ChatbotConversationEngine();
      final result = engine.process(
        'what are the places that have discounted rates for students '
        'and pwds',
      );

      expect(result.outcome, ChatbotEngineOutcome.answered);
      // Numbered list markers must be present.
      expect(result.replyText, contains('1. '));
      expect(result.replyText, contains('2. '));
      // Real prices must be included inline, not deferred to a
      // follow-up question.
      expect(result.replyText, contains('₱'));
      expect(result.replyText, contains('adult'));
      expect(result.replyText, contains('student'));
      expect(
        result.replyText.toLowerCase(),
        isNot(contains('ask me about a specific one')),
      );
    },
  );

  test(
    'a category question (e.g. "show me museums") returns a numbered '
    'list with per-place prices, not just a comma-joined name list',
    () {
      final engine = ChatbotConversationEngine();
      final result = engine.process('what museums are there');

      expect(result.outcome, ChatbotEngineOutcome.answered);
      expect(result.replyText, contains('1. '));
      expect(result.replyText, contains('₱'));
    },
  );
}
