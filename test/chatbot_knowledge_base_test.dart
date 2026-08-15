import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/models/location_model.dart';
import 'package:intravel/services/chatbot_knowledge_base.dart';
import 'package:intravel/services/chatbot_knowledge_service.dart';
import 'package:intravel/services/chatbot_system_instruction.dart';
import 'package:intravel/services/gate_service.dart';

/// Guards the grounding context fed to IntraBadi as `systemInstruction`.
///
/// Two classes of risk are covered:
///  1. Drift — the knowledge base naming categories/gates/features that no
///     longer match the real dataset.
///  2. Untruth — the knowledge base asserting behavior the app doesn't
///     actually have, which would make the model confidently wrong while
///     simultaneously being told never to invent facts.
void main() {
  /// The knowledge base lowercased with every run of whitespace collapsed to
  /// a single space. The document is hard-wrapped prose, so a phrase like
  /// "walking path" can legitimately span a line break — matching against
  /// the raw string would fail for formatting reasons rather than content.
  final kb = kChatbotKnowledgeBase.toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );

  group('knowledge base content', () {
    test('is non-empty and substantive', () {
      expect(kChatbotKnowledgeBase.trim(), isNotEmpty);
      expect(kChatbotKnowledgeBase.length, greaterThan(2000));
    });

    test('covers each of the four real filter categories', () {
      for (final category in [
        'Fortifications',
        'Landmarks',
        'Parks',
        'Schools',
      ]) {
        expect(
          kChatbotKnowledgeBase,
          contains(category),
          reason: '$category missing from grounding context',
        );
      }
    });

    test('states that museums live under Landmarks on the map, and is honest '
        'that the Plans page additionally breaks them out', () {
      expect(kb, contains('museums'));
      expect(kb, contains('no separate museums filter'));
      // The Plans page really does have its own Museums and Churches chips;
      // claiming otherwise would send users hunting for a chip that is there.
      expect(kb, contains('plans page'));
    });

    test('names every real entry gate from GateService', () {
      for (final gate in GateService().getAllGates()) {
        // Match on a distinctive fragment so punctuation/format differences
        // between the doc and the dataset don't cause false failures.
        final key = gate.name.split(RegExp(r'[ /]')).first;
        expect(
          kChatbotKnowledgeBase,
          contains(key),
          reason: 'gate "${gate.name}" missing from grounding context',
        );
      }
    });

    test(
      'describes the gate-then-live-GPS handoff, including the 50m rule',
      () {
        expect(kb, contains('50'));
        expect(kb, contains('live gps'));
      },
    );

    test('tells the model to prefer tools over this document for figures', () {
      expect(kb, contains('call your tools'));
      expect(kb, contains('authoritative'));
    });

    test('preserves the Intramuros-only scope boundary', () {
      expect(kb, contains('within'));
      expect(kb, contains('metro manila'));
    });
  });

  group('accuracy: no claims the app cannot back up', () {
    test('does NOT claim Parking routes over real drivable roads — no vehicle '
        'road dataset exists, so that would be a fabricated capability', () {
      expect(
        kb.contains('drivable road') &&
            !kb.contains('no drivable-road dataset'),
        isFalse,
        reason:
            'Parking must not be described as using real road routing '
            'until a vehicle road graph actually ships',
      );
      // It should instead be explicit about the current limitation.
      expect(kb, contains('pedestrian path graph'));
    });

    test('describes the Location Details "Directions" button as opening the '
        'itinerary builder, and no longer as a no-op (improvement-batch spec '
        'Section 7)', () {
      expect(
        kb.contains('not yet functional') || kb.contains('no-op'),
        isFalse,
        reason:
            'the button works now; calling it broken would send users to '
            'Navigate for something Directions actually does',
      );
      expect(kb, contains('itinerary builder'));
      // The two buttons must stay distinguishable, or the model will
      // describe Directions as a second turn-by-turn entry point.
      expect(kb, contains('navigate starts turn-by-turn'));
    });

    test('the accessibility modes it lists all exist in AccessibilityType', () {
      final knowledge = ChatbotKnowledgeService();
      // Every mode the document names must resolve to a real enum value.
      for (final phrase in [
        'ramps',
        'elevators',
        'braille',
        'vegetarian',
        'restrooms',
        'parking',
        'rest areas',
        'priority assistance',
        'pwd & senior access',
        'rough / bumpy road',
        'cafe',
      ]) {
        expect(
          kb,
          contains(phrase),
          reason: '$phrase should be listed as an available mode',
        );
      }
      // And the mode set really does back them — with step-free vocabulary
      // resolving to the consolidated PWD & Senior filter, per the fold.
      expect(
        knowledge.resolveAccessibilityType('ramps'),
        AccessibilityType.pwdSeniorPriority,
      );
      expect(
        knowledge.resolveAccessibilityType('rest areas'),
        AccessibilityType.restAreas,
      );
    });

    test(
      'DOES offer the terrain filter now that it is implemented, and explains '
      'where Ramps/Elevators went (improvement-batch spec Section 5)',
      () {
        expect(kb, contains('rough / bumpy road'));
        expect(kb, contains('pwd & senior access'));
        expect(kb, contains('step-free'));
        expect(
          ChatbotKnowledgeService().resolveAccessibilityType('bumpy road'),
          AccessibilityType.roughTerrain,
        );
      },
    );

    test('no longer offers audio-described directions, which was removed', () {
      expect(
        kb.contains('audio-described') || kb.contains('audio described'),
        isFalse,
        reason:
            'that mode was replaced by the terrain filter; offering it '
            'would point users at a toggle that no longer exists',
      );
    });

    test('is honest that all transport modes draw a walking path', () {
      expect(
        kb,
        contains('walking path'),
        reason:
            'Tranvia/Kalesa/Pedicab reuse the walking route; the model '
            'should not imply mode-specific routing',
      );
    });
  });

  group('composition with the behavioral contract', () {
    test('the two constants are distinct and do not contradict on scope', () {
      expect(kChatbotSystemInstruction, isNot(equals(kChatbotKnowledgeBase)));
      // Both must reinforce the same scope rule.
      expect(kChatbotSystemInstruction.toLowerCase(), contains('airport'));
      expect(kb, contains('metro manila'));
    });

    test('combined instruction stays a reasonable prompt size', () {
      final combined = '$kChatbotSystemInstruction\n\n$kChatbotKnowledgeBase';
      // Sanity bound: large enough to be useful, small enough that it isn't
      // silently ballooning per-request token cost.
      expect(combined.length, greaterThan(4000));
      expect(
        combined.length,
        lessThan(20000),
        reason: 'the system instruction ships on every request — keep it lean',
      );
    });
  });
}
