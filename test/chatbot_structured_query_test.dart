import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/models/location_model.dart';
import 'package:intravel/services/chatbot_knowledge_service.dart';
import 'package:intravel/services/chatbot_scope_classifier.dart';
import 'package:intravel/services/chatbot_system_instruction.dart';

void main() {
  final knowledge = ChatbotKnowledgeService();

  group('budget queries (acceptance criterion: "₱200–₱500")', () {
    test('locationsInBudgetRange returns only overlapping spend ranges', () {
      final results = knowledge.locationsInBudgetRange(min: 200, max: 500);
      expect(results, isNotEmpty);
      for (final loc in results) {
        expect(
          loc.budgetRange.min <= 500 && loc.budgetRange.max >= 200,
          isTrue,
          reason:
              '${loc.name} (${loc.budgetRange.min}-${loc.budgetRange.max}) '
              'does not overlap 200-500',
        );
      }
    });

    test('an impossible range yields nothing rather than falling back', () {
      final results = knowledge.locationsInBudgetRange(
        min: 900000,
        max: 1000000,
      );
      expect(results, isEmpty);
    });

    test('locationsWithAdmissionUnder respects the ticket price', () {
      final results = knowledge.locationsWithAdmissionUnder(50);
      for (final loc in results) {
        expect(loc.ticketInfo.adultPrice, lessThanOrEqualTo(50));
      }
    });
  });

  group('accessibility resolution', () {
    test('resolves common phrasings to real types', () {
      // Step-free vocabulary resolves to pwdSeniorPriority, not ramps —
      // improvement-batch spec Section 5 folded ramps/elevators into that
      // filter, so the chatbot must match the same set the UI toggle shows.
      expect(
        knowledge.resolveAccessibilityType('wheelchair'),
        AccessibilityType.pwdSeniorPriority,
      );
      expect(
        knowledge.resolveAccessibilityType('is there a ramp'),
        AccessibilityType.pwdSeniorPriority,
      );
      expect(
        knowledge.resolveAccessibilityType('elevator'),
        AccessibilityType.pwdSeniorPriority,
      );
      expect(
        knowledge.resolveAccessibilityType('bumpy road'),
        AccessibilityType.roughTerrain,
      );
      expect(
        knowledge.resolveAccessibilityType('braille'),
        AccessibilityType.brailleVoice,
      );
      expect(
        knowledge.resolveAccessibilityType('vegetarian food'),
        AccessibilityType.vegetarian,
      );
    });

    test('returns null for something unrelated instead of guessing', () {
      expect(knowledge.resolveAccessibilityType('history of the fort'), isNull);
      expect(knowledge.resolveAccessibilityType(''), isNull);
    });

    test(
      'bare "senior"/"pwd" do NOT resolve to an accessibility filter — those '
      'words belong to pricing questions ("discounted senior rates") and '
      'previously hijacked them away from the discount handler',
      () {
        expect(knowledge.resolveAccessibilityType('senior'), isNull);
        expect(knowledge.resolveAccessibilityType('pwd'), isNull);
        expect(
          knowledge.resolveAccessibilityType(
            'which places have discounted student senior rates',
          ),
          isNull,
        );
        // The genuine priority-assistance phrasing still resolves.
        expect(
          knowledge.resolveAccessibilityType('senior priority'),
          AccessibilityType.pwdSeniorPriority,
        );
      },
    );
  });

  group('combined filters (acceptance criterion: budget + category)', () {
    test('applies every constraint together, not just the first', () {
      final category = knowledge.allCategories.first;
      final results = knowledge.queryLocations(
        category: category,
        budgetMin: 0,
        budgetMax: 100000,
      );
      for (final loc in results) {
        expect(loc.category, category);
      }
    });

    test('an unknown category yields nothing rather than ignoring it', () {
      final results = knowledge.queryLocations(category: 'spaceports');
      expect(results, isEmpty);
    });

    test('omitted constraints do not filter', () {
      expect(knowledge.queryLocations().length, knowledge.allLocations.length);
    });

    test('discountedOnly narrows to genuine student discounts', () {
      final results = knowledge.queryLocations(discountedOnly: true);
      for (final loc in results) {
        expect(
          loc.ticketInfo.studentPrice,
          lessThan(loc.ticketInfo.adultPrice),
        );
      }
    });
  });

  group('scope classifier false-reject fix', () {
    const classifier = ChatbotScopeClassifier();

    ChatbotScopeResult classify(String message) => classifier.classify(
      message,
      mentionsKnownLocation: false,
      mentionsKnownGate: false,
      mentionsKnownCategory: false,
    );

    test('an app-feature question that name-drops a metro landmark stays in '
        'scope — "which gate is closest to the LRT?" is a gate question', () {
      expect(classify('which gate is closest to the lrt').inScope, isTrue);
    });

    test('the spec-mandated Manila-wide decline still holds when the metro '
        'landmark is the only signal', () {
      expect(
        classify('how do i get to intramuros from the airport').inScope,
        isFalse,
      );
      expect(classify('what is the best mall in makati').inScope, isFalse);
    });

    test('genuinely unrelated trivia is still declined', () {
      expect(classify('what is the capital of france').inScope, isFalse);
    });
  });

  group('system instruction is compiled in, not asset-loaded', () {
    test('is non-empty and carries the core guardrails', () {
      expect(kChatbotSystemInstruction, isNotEmpty);
      // Grounding rule — must never invent prices.
      expect(kChatbotSystemInstruction, contains('checkPrice'));
      // Scope rule — Manila-wide is out.
      expect(kChatbotSystemInstruction.toLowerCase(), contains('airport'));
      // Confirmation guardrail.
      expect(kChatbotSystemInstruction.toLowerCase(), contains('confirm'));
      // Language handling.
      expect(kChatbotSystemInstruction, contains('Taglish'));
    });
  });
}
