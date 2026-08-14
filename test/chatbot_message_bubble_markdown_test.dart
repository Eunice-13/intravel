import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/models/chat_message_model.dart';
import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/widgets/chatbot_chat_sheet.dart';

/// Verifies the chatbot's message bubble renders `**bold**` spans,
/// `*`/`-` bullet list lines, and `1.`/`2.` numbered list lines as real
/// rich text (bold [TextSpan]s, bullet glyphs, numbered list items)
/// instead of showing the literal markdown characters verbatim or an
/// unbroken run-on paragraph, per the reported bug: "the chat bubble
/// widget is just rendering it as raw plain text" / a numbered-list
/// reply rendering as one run-on "essay" instead of a real list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
  });

  Future<void> pumpSheetWithMessage(WidgetTester tester, String text) async {
    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.assistant,
      text: text,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatbotChatSheet())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    '**bold** markers are not shown literally, and the enclosed text is '
    'rendered with a bold font weight',
    (tester) async {
      await pumpSheetWithMessage(
        tester,
        'Fort Santiago costs **₱75** for adults.',
      );

      // The raw, unparsed markers must never appear on screen.
      expect(find.textContaining('**'), findsNothing);

      // Find the Text.rich widget and confirm one of its spans is bold
      // and contains exactly the previously-wrapped text.
      final richTextFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan != null &&
            widget.textSpan!.toPlainText().contains('₱75'),
      );
      expect(richTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(richTextFinder);
      final span = textWidget.textSpan!;
      bool foundBoldSpan = false;
      void visit(InlineSpan s) {
        if (s is TextSpan) {
          if (s.text == '₱75' && s.style?.fontWeight == FontWeight.w700) {
            foundBoldSpan = true;
          }
          s.children?.forEach(visit);
        }
      }

      visit(span);
      expect(foundBoldSpan, isTrue);
    },
  );

  testWidgets(
    'asterisk bullet list lines are rendered with a bullet glyph, not '
    'the literal "*" character',
    (tester) async {
      await pumpSheetWithMessage(
        tester,
        'Here are some fortifications:\n'
        '* Fort Santiago\n'
        '* Baluarte de San Diego',
      );

      // The literal bullet marker "* " must never appear verbatim.
      expect(find.textContaining('* Fort Santiago'), findsNothing);
      expect(find.textContaining('* Baluarte'), findsNothing);

      // The bullet glyph plus the item text should be present instead.
      expect(find.textContaining('•'), findsWidgets);
      expect(find.textContaining('Fort Santiago'), findsOneWidget);
      expect(find.textContaining('Baluarte de San Diego'), findsOneWidget);
    },
  );

  testWidgets(
    'numbered list lines ("1. ", "2. ") are rendered as a real list, not '
    'left as one unbroken run-on paragraph with the markers inline',
    (tester) async {
      await pumpSheetWithMessage(
        tester,
        'These have discounted student/PWD rates:\n'
        '1. Fort Santiago — 50% off for students.\n'
        '2. Manila Cathedral — free entry for PWDs.',
      );

      // Each numbered item's text should be its own visible line/item —
      // not merged into a single paragraph.
      expect(
        find.textContaining('Fort Santiago — 50% off for students.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Manila Cathedral — free entry for PWDs.'),
        findsOneWidget,
      );

      // The number itself should still be shown (as a proper list
      // marker), just not glued to the item text as raw "1." text.
      final richTextFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '1.  ',
      );
      expect(richTextFinder, findsOneWidget);
    },
  );

  testWidgets('plain text with no markdown renders unchanged', (tester) async {
    await pumpSheetWithMessage(tester, 'Hey! How can I help?');
    expect(find.text('Hey! How can I help?'), findsOneWidget);
  });
}
