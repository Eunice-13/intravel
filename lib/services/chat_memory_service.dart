import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message_model.dart';

/// Manages the IntraBadi assistant's multi-turn chat session state
/// (chatbot spec Section 6) and persists it across app restarts ("chat
/// history persists across app restarts — it should be saved (per
/// user/device) rather than reset each session, so a user can close the
/// app and later reopen the chat with prior conversation still
/// visible").
///
/// Mirrors [ReviewService]/[ItineraryService]'s singleton + ChangeNotifier
/// + SharedPreferences (JSON-encoded list) persistence pattern used
/// elsewhere in this app, so this fits the same conventions rather than
/// introducing a new storage approach.
///
/// This service only owns *state* — appending messages, detecting
/// language, and persisting/loading history. Actually calling an
/// AI/backend to generate assistant replies, intent detection, and
/// in/out-of-scope classification are conversation-engine concerns for a
/// later step; nothing here talks to a network or model.
class ChatMemoryService extends ChangeNotifier {
  static final ChatMemoryService instance = ChatMemoryService._internal();
  ChatMemoryService._internal();

  static const String _storageKey = 'intravel.chatbot_history.v1';

  List<ChatMessageModel> _messages = [];
  bool _isLoaded = false;

  /// All turns in the current session, oldest first.
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final decoded = jsonDecode(stored) as List;
        _messages = decoded
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Keep an empty history if persistence is unavailable or corrupted.
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  /// Appends a new message to the session, detecting its language (for
  /// user messages) and persisting the updated history. [pageContext] is
  /// an optional caller-supplied label for what page/location was active
  /// when the message was sent (spec Section 6 context awareness) — the
  /// UI layer is responsible for resolving that to a human-readable
  /// value; this service just stores whatever it's given.
  Future<ChatMessageModel> addMessage({
    required ChatMessageRole role,
    required String text,
    String? pageContext,
  }) async {
    final message = ChatMessageModel(
      id: 'chat-msg-${DateTime.now().microsecondsSinceEpoch}',
      role: role,
      text: text,
      language: detectLanguage(text),
      sentAt: DateTime.now(),
      pageContext: pageContext,
    );
    _messages = [..._messages, message];
    notifyListeners();
    await _persist();
    return message;
  }

  /// Clears the session's chat history (e.g. a future "clear chat"
  /// affordance) and persists the empty state.
  Future<void> clear() async {
    _messages = [];
    notifyListeners();
    await _persist();
  }

  // ─── Language detection ───────────────────────────────────────────────
  //
  // Basic, offline, keyword/heuristic detector (spec Section 5:
  // "auto-detect the language the user is typing in ... English,
  // Filipino, or Taglish"). This is intentionally simple — a lightweight
  // signal for the conversation engine to use later, not a full NLU
  // language classifier. It looks at common Filipino function
  // words/markers vs. English ones and classifies mixed usage as
  // Taglish.

  static const List<String> _filipinoMarkers = [
    'ang', 'mga', 'ng', 'nang', 'sa', 'na', 'ko', 'mo', 'niya', 'nila',
    'natin', 'namin', 'ito', 'iyan', 'iyon', 'dito', 'diyan', 'doon',
    'kung', 'kasi', 'pero', 'saan', 'paano', 'bakit', 'ano', 'sino',
    'magkano', 'pupunta', 'punta', 'gusto', 'ayaw', 'salamat', 'po',
    'opo', 'hindi', 'oo', 'may', 'meron', 'wala', 'yung', 'yun', 'ba',
  ];

  static const List<String> _englishMarkers = [
    'the', 'is', 'are', 'to', 'how', 'what', 'where', 'why', 'when',
    'can', 'could', 'would', 'please', 'thanks', 'thank', 'you', 'and',
    'add', 'my', 'itinerary', 'navigate', 'show', 'filter',
  ];

  /// Classifies [text] as English, Filipino, Taglish (a mix of both), or
  /// unknown (e.g. empty input, or no recognizable markers of either).
  /// Public since [ChatbotConversationEngine] (Step 3) calls this
  /// directly to decide which language to reply in, not just tests.
  ChatMessageLanguage detectLanguage(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return ChatMessageLanguage.unknown;

    final words = normalized
        .split(RegExp(r'[^a-zà-ÿ]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    if (words.isEmpty) return ChatMessageLanguage.unknown;

    final hasFilipino = words.any(_filipinoMarkers.contains);
    final hasEnglish = words.any(_englishMarkers.contains);

    if (hasFilipino && hasEnglish) return ChatMessageLanguage.taglish;
    if (hasFilipino) return ChatMessageLanguage.filipino;
    if (hasEnglish) return ChatMessageLanguage.english;
    // No recognized markers either way (e.g. a single proper noun like a
    // location name) — default to English since that's the app's base
    // language, rather than leaving it unknown for common short queries.
    return ChatMessageLanguage.english;
  }
}
