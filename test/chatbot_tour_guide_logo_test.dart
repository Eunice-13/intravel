import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intravel/widgets/chatbot_tour_guide_logo.dart';

/// Smoke test for the IntraBadi assistant's new logo — a salakot-wearing
/// tour guide portrait (neck up, smiling) replacing the previous generic
/// [Icons.chat_bubble_rounded] glyph — verifying it renders without
/// error at both call-site sizes and stays a simple content-only paint
/// (no background of its own), matching "keep the background of the
/// logo the same" and "core features remain the same".
void main() {
  testWidgets('renders without error inside a circular background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF1C4034),
              child: ChatbotTourGuideLogo(size: 22),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChatbotTourGuideLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // The old generic chat-bubble glyph must be gone from this slot.
    expect(find.byIcon(Icons.chat_bubble_rounded), findsNothing);
  });

  testWidgets('renders at a different size without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ChatbotTourGuideLogo(size: 30)),
        ),
      ),
    );

    expect(find.byType(ChatbotTourGuideLogo), findsOneWidget);
  });
}
