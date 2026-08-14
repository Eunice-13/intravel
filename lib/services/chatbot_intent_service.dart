/// The broad shape of what the user is asking for.
enum ChatbotIntentKind {
  /// A question/informational request ("how much does it cost", "tell
  /// me about Fort Santiago").
  question,

  /// A request to perform a state-changing action on the user's behalf
  /// (chatbot spec Section 4).
  action,

  /// Doesn't clearly fit either — treated like a question by the engine
  /// (safe default: it will never fire an action without a recognized
  /// action intent, per the confirmation guardrail in Section 4).
  unknown,
}

/// Which specific action the user is asking for, when [ChatbotIntentKind]
/// is [ChatbotIntentKind.action]. Matches the four confirmed action
/// capabilities in chatbot spec Section 4.
enum ChatbotActionType {
  addToItinerary,
  startNavigation,
  applyFilter,
  changeSetting,
  createItinerary,
}

/// The result of intent detection on a single user message: what kind of
/// request it is, which action (if any), and the raw text span the
/// action seems to refer to (e.g. a location name for "add X to my
/// itinerary") for the caller to resolve against [ChatbotKnowledgeService].
class ChatbotIntent {
  final ChatbotIntentKind kind;
  final ChatbotActionType? actionType;

  /// The free-text fragment the action appears to target — e.g. "fort
  /// santiago" from "add fort santiago to my itinerary", or "puerta
  /// real" from "change my starting gate to puerta real". Not resolved
  /// against the dataset here; that's [ChatbotKnowledgeService]'s job.
  final String? targetText;

  const ChatbotIntent({
    required this.kind,
    this.actionType,
    this.targetText,
  });

  bool get isAction => kind == ChatbotIntentKind.action;
}

/// Detects whether a message is a general question or a request to
/// perform an action (chatbot spec Section 4: "The assistant can perform
/// actions on the user's behalf, not just answer questions"), and which
/// of the four confirmed action types it maps to.
///
/// Like [ChatbotScopeClassifier], this is a lightweight offline
/// keyword/pattern matcher rather than a full NLU model — appropriate
/// given nothing here needs to be perfectly precise; the mandatory
/// confirm-before-acting step (Section 4) is the real safety net against
/// a misclassified action firing unintentionally, not this detector.
class ChatbotIntentDetector {
  const ChatbotIntentDetector();

  static const List<String> _questionStarters = [
    'what', 'where', 'when', 'why', 'how', 'is', 'are', 'does', 'do',
    'can you tell', 'tell me', 'who',
  ];

  ChatbotIntent detect(String message) {
    final normalized = message.toLowerCase().trim();
    if (normalized.isEmpty) {
      return const ChatbotIntent(kind: ChatbotIntentKind.unknown);
    }

    final createMatch = _matchCreateItinerary(normalized);
    if (createMatch != null) return createMatch;

    final addMatch = _matchAddToItinerary(normalized);
    if (addMatch != null) return addMatch;

    final navMatch = _matchStartNavigation(normalized);
    if (navMatch != null) return navMatch;

    final settingMatch = _matchChangeSetting(normalized);
    if (settingMatch != null) return settingMatch;

    final filterMatch = _matchApplyFilter(normalized);
    if (filterMatch != null) return filterMatch;

    if (normalized.endsWith('?') ||
        _questionStarters.any((s) => normalized.startsWith(s))) {
      return const ChatbotIntent(kind: ChatbotIntentKind.question);
    }

    return const ChatbotIntent(kind: ChatbotIntentKind.unknown);
  }

  /// "create an itinerary", "create a new itinerary called Manila Trip",
  /// "make a new plan named Weekend Tour", "start a new trip". The name
  /// group is optional — plenty of natural requests don't name the
  /// itinerary at all, in which case [ChatbotIntent.targetText] comes
  /// back empty and the engine falls back to a default name.
  ChatbotIntent? _matchCreateItinerary(String text) {
    final patterns = [
      RegExp(
        r'^(create|make|start) (a |an )?(new )?(itinerary|plan|trip)'
        r'( (called|named) (.+))?$',
      ),
      RegExp(
        r'^(create|make|start) (.+?) (itinerary|plan|trip)$',
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        // First pattern carries the name (if any) in its last group;
        // the second pattern's middle group is a name-like prefix (e.g.
        // "create Manila Trip itinerary") rather than a trailing
        // "called X" clause.
        final name = (match.groupCount >= 7 ? match.group(7) : null) ??
            (match.groupCount == 3 ? match.group(2) : null) ??
            '';
        return ChatbotIntent(
          kind: ChatbotIntentKind.action,
          actionType: ChatbotActionType.createItinerary,
          targetText: name.trim(),
        );
      }
    }
    return null;
  }

  /// "add fort santiago to my itinerary", "add fort santiago", "put fort
  /// santiago on my plans".
  ChatbotIntent? _matchAddToItinerary(String text) {
    final patterns = [
      RegExp(r'^add (.+?) to (my )?(itinerary|plans?|trip)'),
      RegExp(r'^(add|save) (.+?)$'),
      RegExp(r'^put (.+?) (on|in) (my )?(itinerary|plans?)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        // Group 1 for the first/third pattern, group 2 for the "add|save"
        // shorthand pattern — pick whichever matched non-null group holds
        // the target text.
        final target = (match.groupCount >= 1 ? match.group(1) : null) ??
            '';
        final resolvedTarget =
            target.isNotEmpty ? target : (match.groupCount >= 2 ? match.group(2) : '') ?? '';
        return ChatbotIntent(
          kind: ChatbotIntentKind.action,
          actionType: ChatbotActionType.addToItinerary,
          targetText: resolvedTarget.trim(),
        );
      }
    }
    return null;
  }

  /// "navigate me to plaza roma", "navigate to fort santiago", "take me
  /// to plaza roma", "start navigation to fort santiago", "how do i
  /// navigate to fort santiago", "can you navigate me to fort santiago",
  /// "how can i get to plaza roma" — deliberately not anchored to the
  /// very start of the message for the "navigate"/"get to" wording,
  /// since a natural request routinely wraps the actual navigation verb
  /// in a question phrasing ("how do I ...", "can you ...") rather than
  /// leading with it. Anchoring only at the start (as this used to do)
  /// meant "how do I navigate to Fort Santiago" fell through to a plain
  /// question and got answered with the location's definition/history
  /// instead of ever being recognized as a navigation request.
  ChatbotIntent? _matchStartNavigation(String text) {
    final patterns = [
      RegExp(r'^navigate( me)? to (.+)$'),
      RegExp(r'^(start )?navigation to (.+)$'),
      RegExp(r'^take me to (.+)$'),
      RegExp(r'^guide me to (.+)$'),
      RegExp(r'^how do i get to (.+)$'),
      // Broader, not-start-anchored variants: "navigate" or "get to"
      // appearing anywhere in the message, with the destination being
      // whatever follows "to". Checked after the exact-anchored patterns
      // above so those still take priority when they match.
      RegExp(r'navigate(?: me)? to (.+)$'),
      RegExp(r'how (?:do|can|would) i (?:get|go) to (.+)$'),
      RegExp(r'^(?:go|head|walk) to (.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var target = match.group(match.groupCount)?.trim() ?? '';
        // A destination clause can trail off into a second, unrelated
        // request in the same message (e.g. "navigate to fort santiago
        // to one of the cafes", "navigate to fort santiago then show me
        // the cafes") — keep only the first destination-like clause so
        // the resolved target stays a single place name rather than the
        // entire rest of the sentence. Split on a second "to "/"then "
        // that starts a new clause, and on trailing punctuation.
        final secondClauseMatch = RegExp(
          r'^(.*?)\s+(?:to|then|and then|and)\s+(?:one of|the|a|another)\b',
        ).firstMatch(target);
        if (secondClauseMatch != null) {
          target = secondClauseMatch.group(1)?.trim() ?? target;
        }
        target = target.replaceAll(RegExp(r'[?.!]+$'), '').trim();
        return ChatbotIntent(
          kind: ChatbotIntentKind.action,
          actionType: ChatbotActionType.startNavigation,
          targetText: target,
        );
      }
    }
    return null;
  }

  /// "turn on accessibility mode", "turn off accessibility support",
  /// "change my starting gate to puerta real", "enable dark mode".
  ChatbotIntent? _matchChangeSetting(String text) {
    final togglePattern = RegExp(
      r'^(turn (on|off)|enable|disable) (.+)$',
    );
    final toggleMatch = togglePattern.firstMatch(text);
    if (toggleMatch != null) {
      final onOff = toggleMatch.group(2);
      final feature = toggleMatch.group(3) ?? toggleMatch.group(1) ?? '';
      final verb = onOff ?? (toggleMatch.group(1) == 'enable' ? 'on' : 'off');
      return ChatbotIntent(
        kind: ChatbotIntentKind.action,
        actionType: ChatbotActionType.changeSetting,
        targetText: '$feature|$verb',
      );
    }

    final gatePattern = RegExp(
      r'^change (my )?(starting )?gate to (.+)$',
    );
    final gateMatch = gatePattern.firstMatch(text);
    if (gateMatch != null) {
      final gate = gateMatch.group(3) ?? '';
      return ChatbotIntent(
        kind: ChatbotIntentKind.action,
        actionType: ChatbotActionType.changeSetting,
        targetText: 'starting gate|$gate',
      );
    }

    return null;
  }

  /// "show me only fortifications", "filter by budget under 200", "show
  /// only museums".
  ChatbotIntent? _matchApplyFilter(String text) {
    final categoryPattern = RegExp(
      r'^show( me)? (only )?(.+)$',
    );
    final categoryMatch = categoryPattern.firstMatch(text);
    if (categoryMatch != null) {
      final target = categoryMatch.group(3) ?? '';
      return ChatbotIntent(
        kind: ChatbotIntentKind.action,
        actionType: ChatbotActionType.applyFilter,
        targetText: target.trim(),
      );
    }

    final budgetPattern = RegExp(
      r'^filter (by )?budget (under|below|less than|above|over|more than) '
      r'.*?(\d+)',
    );
    final budgetMatch = budgetPattern.firstMatch(text);
    if (budgetMatch != null) {
      final direction = budgetMatch.group(2) ?? '';
      final amount = budgetMatch.group(3) ?? '';
      return ChatbotIntent(
        kind: ChatbotIntentKind.action,
        actionType: ChatbotActionType.applyFilter,
        targetText: 'budget|$direction|$amount',
      );
    }

    return null;
  }
}
