import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/services/chatbot_scope_classifier.dart';

/// Regression coverage for a reported rigidity bug: naturally-phrased,
/// clearly in-scope requests (itinerary-building, general Intramuros
/// visiting questions) that don't happen to contain one of the
/// classifier's exact keywords were being hard-declined offline with
/// the generic "I can only help with things related to Intramuros"
/// message, instead of flowing through to a richer, more flexible
/// Gemini answer. Fixed by narrowing the final offline hard-decline
/// path to only genuinely unrelated topics, so anything else ambiguous
/// is treated as in-scope and handed to Gemini (which has the full
/// conversation history and its own natural-language-flexibility
/// system-instruction guidance) instead.
void main() {
  const classifier = ChatbotScopeClassifier();

  ChatbotScopeResult classify(String message) => classifier.classify(
    message.toLowerCase(),
    mentionsKnownLocation: false,
    mentionsKnownGate: false,
    mentionsKnownCategory: false,
  );

  group('naturally-phrased in-scope requests are no longer hard-declined', () {
    const naturalPhrasings = [
      'I want to add specific stops',
      'can we plan a route with a few stops',
      "let's put together an itinerary",
      'I want more stops in my trip',
      "let's add a few places",
      'can you help me build my trip',
      'I want to customize my visit',
      'I want to see more spots',
      'help me plan my day',
      'what can I visit around here',
      'can I add more places to see',
    ];

    for (final phrase in naturalPhrasings) {
      test('"$phrase" is treated as in-scope', () {
        expect(classify(phrase).inScope, isTrue);
      });
    }
  });

  group('explicit out-of-scope guardrails (spec Section 2) still hold', () {
    test('Manila-wide questions are still declined', () {
      final result = classify('how do i get to intramuros from the airport');
      expect(result.inScope, isFalse);
      expect(result.reason, ChatbotScopeReason.outOfScopeManilaWide);
    });

    test('genuinely unrelated trivia is still declined', () {
      expect(
        classify('who is the president of the philippines').inScope,
        isFalse,
      );
      expect(classify('whats the latest nba score').inScope, isFalse);
      expect(classify('can you write me a poem about love').inScope, isFalse);
    });

    test('a known-entity mention is always in-scope regardless of wording', () {
      final result = classifier.classify(
        'random unrelated sentence',
        mentionsKnownLocation: true,
        mentionsKnownGate: false,
        mentionsKnownCategory: false,
      );
      expect(result.inScope, isTrue);
      expect(result.reason, ChatbotScopeReason.knownEntity);
    });
  });
}
