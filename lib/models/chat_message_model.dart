/// Who sent a given [ChatMessageModel] in the IntraBadi assistant's
/// conversation (chatbot spec Section 6: multi-turn memory within a
/// session).
enum ChatMessageRole { user, assistant }

/// Best-effort language guess for a single message (chatbot spec Section
/// 5: "auto-detect the language the user is typing in ... per-message
/// based on what the user actually typed"). Detection logic lives in
/// [ChatMemoryService]; this just names the possible results.
enum ChatMessageLanguage { english, filipino, taglish, unknown }

/// A single turn in the IntraBadi assistant's chat history. Mirrors the
/// app's existing model style (e.g. `ItineraryModel`): a plain data class
/// with `toJson`/`fromJson` for the SharedPreferences-backed persistence
/// in [ChatMemoryService].
///
/// [pageContext] optionally captures what page/location the user was
/// viewing when they sent the message (spec Section 6: "aware of what
/// page/location the user is currently viewing") — stored per-message so
/// a persisted history still reflects the context each turn was sent in.
/// This step only stores the value; resolving vague follow-ups against it
/// is conversation-engine logic for a later step.
class ChatMessageModel {
  final String id;
  final ChatMessageRole role;
  final String text;
  final ChatMessageLanguage language;
  final DateTime sentAt;
  final String? pageContext;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.text,
    required this.language,
    required this.sentAt,
    this.pageContext,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'language': language.name,
        'sentAt': sentAt.toIso8601String(),
        'pageContext': pageContext,
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      role: ChatMessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => ChatMessageRole.user,
      ),
      text: json['text'] as String? ?? '',
      language: ChatMessageLanguage.values.firstWhere(
        (l) => l.name == json['language'],
        orElse: () => ChatMessageLanguage.unknown,
      ),
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '') ??
          DateTime.now(),
      pageContext: json['pageContext'] as String?,
    );
  }
}
