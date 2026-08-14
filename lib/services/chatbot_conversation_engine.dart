import '../models/chat_message_model.dart';
import '../models/location_model.dart';
import 'chat_memory_service.dart';
import 'chatbot_intent_service.dart';
import 'chatbot_knowledge_service.dart';
import 'chatbot_phrase_bank.dart';
import 'chatbot_scope_classifier.dart';

/// What kind of result the engine produced for a single message —
/// lets the UI layer decide how to handle each case distinctly (e.g.
/// only [answered] questions should additionally be routed to
/// [GeminiChatService] for a richer live answer; [declined] and
/// [actionPending] must always keep the engine's own text, since
/// scoping and action-confirmation are enforced in code, not by a
/// model prompt).
enum ChatbotEngineOutcome {
  /// The message was judged out of scope (chatbot spec Section 2) and
  /// [ChatbotEngineResult.replyText] is the standard decline message.
  declined,

  /// The message was a recognized, confirmed-pending action request
  /// (chatbot spec Section 4); [ChatbotEngineResult.pendingAction] is
  /// set and [ChatbotEngineResult.replyText] is the Yes/No confirmation
  /// prompt.
  actionPending,

  /// The message was an in-scope question the engine answered from the
  /// app's own dataset (chatbot spec Section 3).
  answered,

  /// The message looked like a state-changing action request, but the
  /// engine couldn't resolve what it referred to (e.g. an unrecognized
  /// location/gate name) — [ChatbotEngineResult.replyText] already
  /// carries specific, actionable guidance ("check the spelling"), so
  /// the UI layer should not additionally query Gemini for this case.
  actionUnresolved,
}

/// What the conversation engine decided to do with a single user
/// message, returned to the UI layer so it can render the assistant's
/// reply and, when [pendingAction] is set, surface a Yes/No confirmation
/// affordance (chatbot spec Section 4: "the assistant must confirm with
/// the user first in the chat before executing any state-changing
/// action").
///
/// Actually *executing* a confirmed action (mutating itinerary/settings/
/// navigation state) is a later step's job — this engine only ever
/// recognizes the request and prepares what a confirmation/execution
/// layer would need, per this step's NLU/scoping/context-only scope.
class ChatbotEngineResult {
  final String replyText;
  final ChatbotPendingAction? pendingAction;
  final ChatbotEngineOutcome outcome;

  const ChatbotEngineResult({
    required this.replyText,
    this.pendingAction,
    required this.outcome,
  });
}

/// A recognized, not-yet-confirmed action request (spec Section 4). Kept
/// deliberately data-only/serialization-free — a later "action
/// execution" step turns this into a real itinerary/settings/navigation
/// call once the user has confirmed.
class ChatbotPendingAction {
  final ChatbotActionType type;

  /// The resolved target, when applicable — e.g. a [LocationModel] id
  /// for addToItinerary/startNavigation, or a raw "feature|on/off" /
  /// "category|value" payload for changeSetting/applyFilter (mirroring
  /// [ChatbotIntent.targetText]'s encoding for those two types, since
  /// they don't resolve against the location/gate dataset).
  final String targetId;

  final String targetLabel;

  const ChatbotPendingAction({
    required this.type,
    required this.targetId,
    required this.targetLabel,
  });
}

/// The IntraBadi assistant's conversation engine (chatbot spec Sections
/// 2, 4, 5, 6): the "brain" that decides, for a single incoming user
/// message, what kind of request it is, whether it's in scope, what
/// language to answer in, and — using [ChatMemoryService]'s persisted
/// history plus the caller-supplied current-page context — resolves
/// vague follow-ups like "tell me more about this place" or "add that
/// to my itinerary".
///
/// This only produces the *text/decision* for a single turn; it does not
/// itself call any network/model backend (there is no such backend wired
/// up in this offline-first app) and does not mutate any app state
/// (itinerary, settings, navigation) — recognized actions are surfaced
/// as an unconfirmed [ChatbotPendingAction] for a later execution step to
/// pick up once the user says yes.
class ChatbotConversationEngine {
  ChatbotConversationEngine({
    ChatbotKnowledgeService? knowledgeService,
    ChatbotScopeClassifier? scopeClassifier,
    ChatbotIntentDetector? intentDetector,
    ChatbotPhraseBank? phraseBank,
  }) : _knowledge = knowledgeService ?? ChatbotKnowledgeService(),
       _scopeClassifier = scopeClassifier ?? const ChatbotScopeClassifier(),
       _intentDetector = intentDetector ?? const ChatbotIntentDetector(),
       _phraseBank = phraseBank ?? const ChatbotPhraseBank();

  final ChatbotKnowledgeService _knowledge;
  final ChatbotScopeClassifier _scopeClassifier;
  final ChatbotIntentDetector _intentDetector;
  final ChatbotPhraseBank _phraseBank;

  /// Processes one user message and returns the assistant's reply.
  ///
  /// [currentPageContext] is a caller-supplied label for what the user is
  /// currently looking at (spec Section 6 context awareness) — e.g. a
  /// location id/name when the chat is opened from a location details
  /// screen. It's used to resolve vague references ("this place", "how
  /// much does it cost") when the message itself doesn't name an entity.
  ChatbotEngineResult process(
    String userMessage, {
    String? currentPageContext,
  }) {
    final language = ChatMemoryService.instance.detectLanguage(userMessage);
    final normalized = userMessage.toLowerCase().trim();

    // ─── Resolve entities mentioned in this message ──────────────────────
    final mentionedLocation = _findMentionedLocation(normalized);
    final mentionedGate = _knowledge.findGateByName(normalized);
    final mentionedCategory = _resolveMentionedCategory(normalized);

    final scopeResult = _scopeClassifier.classify(
      normalized,
      mentionsKnownLocation: mentionedLocation != null,
      mentionsKnownGate: mentionedGate != null,
      mentionsKnownCategory: mentionedCategory != null,
    );

    if (!scopeResult.inScope) {
      return ChatbotEngineResult(
        replyText: _phraseBank.scopeDecline(language),
        outcome: ChatbotEngineOutcome.declined,
      );
    }

    final intent = _intentDetector.detect(normalized);

    if (intent.isAction) {
      return _handleAction(
        intent,
        language: language,
        currentPageContext: currentPageContext,
        mentionedLocation: mentionedLocation,
      );
    }

    return _handleQuestion(
      normalized,
      language: language,
      currentPageContext: currentPageContext,
      mentionedLocation: mentionedLocation,
      mentionedGate: mentionedGate,
      mentionedCategory: mentionedCategory,
    );
  }

  // ─── Question handling ──────────────────────────────────────────────────

  ChatbotEngineResult _handleQuestion(
    String normalized, {
    required ChatMessageLanguage language,
    required String? currentPageContext,
    required LocationModel? mentionedLocation,
    required dynamic mentionedGate,
    required String? mentionedCategory,
  }) {
    // Multi-turn memory (spec Section 6) should only kick in for an
    // actual vague follow-up to what was just discussed — e.g. "tell me
    // more", "how much does it cost", "is it open now" — where the user
    // is clearly still talking about the same thing and just isn't
    // repeating its name. A brand-new question that simply doesn't
    // happen to name a known location (e.g. "what locations have
    // discounted rates", "how do I add a stop to my itinerary") is NOT
    // that case, and must not be silently answered about whatever
    // location was last discussed — that's what previously made the
    // assistant seem "stuck" on one place (e.g. Fort Santiago) no matter
    // what was actually asked, once it had been mentioned once.
    //
    // A cost/hours question only counts as a *follow-up* (rather than a
    // general one, like "what locations have discounted rates") when it
    // also carries a pronoun-style reference ("it", "this place") or the
    // caller supplied a current-page context to anchor it to — a bare
    // cost/hours phrase with neither is a general question the dataset
    // itself (see the discount-list case below) or Gemini should answer,
    // not an implicit reference to session memory. A question that's
    // explicitly asking about multiple/unspecified locations (discount
    // listing) is never treated as a single-location follow-up, even if
    // a page context happens to be set, since it's asking about the
    // dataset broadly rather than "the place I'm currently looking at".
    final isGeneralDatasetQuery = _looksLikeDiscountQuestion(normalized);
    final hasAnchor =
        !isGeneralDatasetQuery &&
        currentPageContext != null &&
        currentPageContext.trim().isNotEmpty;
    final isFollowUp =
        !isGeneralDatasetQuery &&
        (_looksLikeVagueReference(normalized) || hasAnchor);

    final location =
        mentionedLocation ??
        (isFollowUp
            ? (_resolveFromPageContext(currentPageContext) ??
                  _mostRecentlyDiscussedLocation())
            : null);

    if (location != null && _looksLikeCostQuestion(normalized)) {
      return ChatbotEngineResult(
        replyText: _describeCost(location, language),
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    if (location != null && _looksLikeHoursQuestion(normalized)) {
      return ChatbotEngineResult(
        replyText: _describeHours(location, language),
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    if (location != null) {
      return ChatbotEngineResult(
        replyText: _describeLocation(location, language),
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    // A cost/discount question naming no specific location (e.g. "what
    // locations have discounted rates", "which places are cheapest") —
    // answer with a real, data-grounded, numbered list carrying the
    // actual adult/student/senior prices for each match, instead of a
    // flat comma-joined sentence that just names places and tells the
    // user to ask again for the actual numbers. The user already asked
    // for exactly this detail — making them ask a second time per place
    // is the rigidity this reply is meant to fix.
    // Structured/combined filters (budget range + category +
    // accessibility) — tried before the single-purpose fallbacks below so
    // a question like "cheap fortifications under 300 with ramps" is
    // answered as one grounded query rather than being reduced to
    // whichever single keyword happened to match first. This is also what
    // keeps the offline path useful when the live model is unavailable.
    final structured = _tryStructuredQuery(
      normalized,
      mentionedCategory: mentionedCategory,
    );
    if (structured != null) return structured;

    if (_looksLikeCostQuestion(normalized) ||
        _looksLikeDiscountQuestion(normalized)) {
      final discounted = _knowledge.allLocations
          .where((l) => l.ticketInfo.studentPrice < l.ticketInfo.adultPrice)
          .toList();
      if (discounted.isNotEmpty) {
        final lines = <String>[
          'Here are places with discounted student/senior rates:',
        ];
        final shortlist = discounted.take(6).toList();
        for (var i = 0; i < shortlist.length; i++) {
          final place = shortlist[i];
          final ticket = place.ticketInfo;
          final priceParts = <String>[
            '${ticket.formattedAdult} (adult)',
            '${ticket.formattedStudent} (student)',
          ];
          if (ticket.seniorPrice != null) {
            priceParts.add(
              '${ticket.currency}${ticket.seniorPrice!.toInt()} (senior/PWD)',
            );
          }
          lines.add('${i + 1}. **${place.name}** — ${priceParts.join(', ')}.');
        }
        return ChatbotEngineResult(
          replyText: lines.join('\n'),
          outcome: ChatbotEngineOutcome.answered,
        );
      }
    }

    if (mentionedGate != null) {
      return ChatbotEngineResult(
        replyText:
            "${mentionedGate.name} is one of Intramuros' ${mentionedGate.kindLabel.toLowerCase()}s — "
            "you can pick it as your starting gate from onboarding or "
            "settings.",
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    if (mentionedCategory != null) {
      final matches = _knowledge.locationsInCategory(mentionedCategory);
      if (matches.isEmpty) {
        return ChatbotEngineResult(
          replyText: _phraseBank.missingDetail(language),
          outcome: ChatbotEngineOutcome.answered,
        );
      }
      final shortlist = matches.take(6).toList();
      final lines = <String>['Here are some $mentionedCategory:'];
      for (var i = 0; i < shortlist.length; i++) {
        final place = shortlist[i];
        lines.add(
          '${i + 1}. **${place.name}** — ${place.ticketInfo.formattedAdult}, '
          '${place.ticketInfo.formattedStudent}.',
        );
      }
      return ChatbotEngineResult(
        replyText: lines.join('\n'),
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    // In-scope (per the classifier) but nothing specific enough to
    // ground an answer in the dataset — decline guessing rather than
    // inventing a fact, per spec Section 3. Still "answered" (not
    // "declined") from the outcome's perspective — the topic itself was
    // fine, so the UI layer is free to try a live Gemini answer instead
    // of this generic fallback.
    return ChatbotEngineResult(
      replyText: _phraseBank.missingDetail(language),
      outcome: ChatbotEngineOutcome.answered,
    );
  }

  /// Answers a question carrying one or more *structured* constraints —
  /// budget range, category, accessibility need, open-now — by composing
  /// them into a single [ChatbotKnowledgeService.queryLocations] call.
  ///
  /// Returns `null` when the message carries no structured constraint at
  /// all, so the caller falls through to its other handlers. Returns an
  /// honest "nothing matches" answer rather than silently relaxing a
  /// filter when the combination genuinely has no results.
  ChatbotEngineResult? _tryStructuredQuery(
    String normalized, {
    required String? mentionedCategory,
  }) {
    final budget = _parseBudget(normalized);
    final accessibility = _knowledge.resolveAccessibilityType(normalized);
    final wantsOpenNow =
        normalized.contains('open now') ||
        normalized.contains('open right now');

    // A bare category question is already handled well further down; only
    // take over when there's a real constraint beyond it.
    final hasConstraint =
        budget != null || accessibility != null || wantsOpenNow;
    if (!hasConstraint) return null;

    // A discount/pricing question has its own dedicated handler below that
    // reports real adult/student/senior figures per place. Only take it
    // over here when the user actually pinned a numeric budget, since
    // that's a genuine filter this composable query answers better.
    if (_looksLikeDiscountQuestion(normalized) && budget == null) {
      return null;
    }

    final matches = _knowledge.queryLocations(
      category: mentionedCategory,
      budgetMin: budget?.min,
      budgetMax: budget?.max,
      accessibility: accessibility,
      openNow: wantsOpenNow ? true : null,
    );

    final criteria = <String>[
      if (mentionedCategory != null) mentionedCategory.toLowerCase(),
      if (budget != null) _describeBudget(budget),
      if (accessibility != null) 'with ${_accessibilityLabel(accessibility)}',
      if (wantsOpenNow) 'open right now',
    ];
    final criteriaText = criteria.isEmpty ? '' : ' ${criteria.join(', ')}';

    if (matches.isEmpty) {
      return ChatbotEngineResult(
        replyText:
            "I couldn't find anything$criteriaText in the app's data. Try "
            'widening the budget or dropping one of the filters?',
        outcome: ChatbotEngineOutcome.answered,
      );
    }

    final shortlist = matches.take(6).toList();
    final lines = <String>['Here\'s what matches$criteriaText:'];
    for (var i = 0; i < shortlist.length; i++) {
      final place = shortlist[i];
      lines.add(
        '${i + 1}. **${place.name}** — ${place.category}, '
        '${place.budgetRange.formatted}.',
      );
    }
    if (matches.length > shortlist.length) {
      lines.add('…and ${matches.length - shortlist.length} more.');
    }
    return ChatbotEngineResult(
      replyText: lines.join('\n'),
      outcome: ChatbotEngineOutcome.answered,
    );
  }

  /// Extracts a peso budget constraint from free text, covering the
  /// phrasings the acceptance criteria call out ("₱200–₱500") plus the
  /// common one-sided forms.
  ({double? min, double? max})? _parseBudget(String text) {
    final t = text.replaceAll(',', '');

    final range = RegExp(
      r'(?:php|₱|p)?\s*(\d{2,6})\s*(?:-|–|—|to|and)\s*(?:php|₱|p)?\s*(\d{2,6})',
    ).firstMatch(t);
    if (range != null) {
      final a = double.tryParse(range.group(1)!);
      final b = double.tryParse(range.group(2)!);
      if (a != null && b != null) {
        return (min: a < b ? a : b, max: a < b ? b : a);
      }
    }

    final under = RegExp(
      r'(?:under|below|less than|at most|max|cheaper than|within|up to)\s*'
      r'(?:php|₱|p)?\s*(\d{2,6})',
    ).firstMatch(t);
    if (under != null) {
      final v = double.tryParse(under.group(1)!);
      if (v != null) return (min: null, max: v);
    }

    final over = RegExp(
      r'(?:above|over|more than|at least|minimum)\s*(?:php|₱|p)?\s*(\d{2,6})',
    ).firstMatch(t);
    if (over != null) {
      final v = double.tryParse(over.group(1)!);
      if (v != null) return (min: v, max: null);
    }

    return null;
  }

  String _describeBudget(({double? min, double? max}) budget) {
    final min = budget.min;
    final max = budget.max;
    if (min != null && max != null) {
      return 'between ₱${min.toInt()} and ₱${max.toInt()}';
    }
    if (max != null) return 'under ₱${max.toInt()}';
    if (min != null) return 'over ₱${min.toInt()}';
    return '';
  }

  String _accessibilityLabel(AccessibilityType type) {
    switch (type) {
      case AccessibilityType.ramps:
        return 'ramps / step-free access';
      case AccessibilityType.elevators:
        return 'elevators';
      case AccessibilityType.brailleVoice:
        return 'braille or voice guidance';
      case AccessibilityType.vegetarian:
        return 'vegetarian options';
      case AccessibilityType.restroom:
        return 'restrooms';
      case AccessibilityType.parking:
        return 'parking';
      case AccessibilityType.restAreas:
        return 'rest areas / seating';
      case AccessibilityType.pwdSeniorPriority:
        return 'PWD & senior priority assistance';
      case AccessibilityType.audioDescribedDirections:
        return 'audio-described directions';
      case AccessibilityType.cafe:
        return 'cafe amenities (WiFi & sockets)';
    }
  }

  bool _looksLikeCostQuestion(String text) =>
      text.contains('cost') ||
      text.contains('price') ||
      text.contains('magkano') ||
      text.contains('fee') ||
      text.contains('bayad');

  bool _looksLikeHoursQuestion(String text) =>
      text.contains('hour') ||
      text.contains('open') ||
      text.contains('close') ||
      text.contains('schedule');

  bool _looksLikeDiscountQuestion(String text) =>
      text.contains('discount') ||
      text.contains('discounted') ||
      text.contains('cheap') ||
      text.contains('cheapest') ||
      text.contains('free entrance') ||
      text.contains('free entry');

  /// Whether [text] reads like a pronoun-style follow-up about whatever
  /// was just discussed (spec Section 6: "tell me more about this
  /// place") rather than a self-contained new question — the only case
  /// where falling back to the current page context / most-recently-
  /// discussed location is appropriate. Deliberately narrow: a message
  /// that merely fails to name a known entity (e.g. "what locations have
  /// discounted rates", "how do I add a stop to my itinerary") should
  /// NOT match this, or every such question would silently get answered
  /// about whichever location happened to be discussed last.
  bool _looksLikeVagueReference(String text) {
    const vagueMarkers = [
      'tell me more',
      'more about',
      'more info',
      'this place',
      'that place',
      'is it',
      'does it',
      'it cost',
      'it open',
      'about it',
      'about this',
      'about that',
      'over there',
      'is there',
      'ganda',
      'maganda',
      'sulit ba',
    ];
    return vagueMarkers.any(text.contains);
  }

  String _describeCost(LocationModel location, ChatMessageLanguage language) {
    final ticket = location.ticketInfo;
    switch (language) {
      case ChatMessageLanguage.filipino:
        return '${location.name}: ${ticket.formattedAdult}, '
            '${ticket.formattedStudent}.';
      case ChatMessageLanguage.taglish:
        return 'For ${location.name}, it\'s ${ticket.formattedAdult} and '
            '${ticket.formattedStudent}.';
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return '${location.name} costs ${ticket.formattedAdult} and '
            '${ticket.formattedStudent}.';
    }
  }

  String _describeHours(LocationModel location, ChatMessageLanguage language) {
    final hours = location.operatingHours;
    return '${location.name} is open ${hours.formattedWeekday} on '
        'weekdays and ${hours.formattedWeekend} on weekends. Right now '
        'it\'s ${location.currentStatus.toLowerCase()}.';
  }

  String _describeLocation(
    LocationModel location,
    ChatMessageLanguage language,
  ) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return '${location.name} ay isang ${location.category.toLowerCase()} '
            '— ${location.subtitle}. ${location.description}';
      case ChatMessageLanguage.taglish:
        return '${location.name} is a ${location.category.toLowerCase()} — '
            '${location.subtitle}. ${location.description}';
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return '${location.name} is a ${location.category.toLowerCase()} — '
            '${location.subtitle}. ${location.description}';
    }
  }

  // ─── Action handling (recognition + confirmation prompt only) ─────────

  ChatbotEngineResult _handleAction(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
    required String? currentPageContext,
    required LocationModel? mentionedLocation,
  }) {
    switch (intent.actionType) {
      case ChatbotActionType.addToItinerary:
        return _handleAddToItinerary(
          intent,
          language: language,
          currentPageContext: currentPageContext,
          mentionedLocation: mentionedLocation,
        );
      case ChatbotActionType.startNavigation:
        return _handleStartNavigation(
          intent,
          language: language,
          currentPageContext: currentPageContext,
          mentionedLocation: mentionedLocation,
        );
      case ChatbotActionType.changeSetting:
        return _handleChangeSetting(intent, language: language);
      case ChatbotActionType.applyFilter:
        return _handleApplyFilter(intent, language: language);
      case ChatbotActionType.createItinerary:
        return _handleCreateItinerary(intent, language: language);
      case null:
        return ChatbotEngineResult(
          replyText: _phraseBank.missingDetail(language),
          outcome: ChatbotEngineOutcome.actionUnresolved,
        );
    }
  }

  ChatbotEngineResult _handleAddToItinerary(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
    required String? currentPageContext,
    required LocationModel? mentionedLocation,
  }) {
    final location =
        mentionedLocation ??
        _knowledge.findLocationByName(intent.targetText ?? '') ??
        _resolveFromPageContext(currentPageContext) ??
        _mostRecentlyDiscussedLocation();

    if (location == null) {
      return ChatbotEngineResult(
        replyText: _phraseBank.unknownLocation(
          language,
          intent.targetText ?? '',
        ),
        outcome: ChatbotEngineOutcome.actionUnresolved,
      );
    }

    return ChatbotEngineResult(
      replyText: _phraseBank.confirmAction(
        language,
        'Add ${location.name} to your itinerary?',
      ),
      pendingAction: ChatbotPendingAction(
        type: ChatbotActionType.addToItinerary,
        targetId: location.id,
        targetLabel: location.name,
      ),
      outcome: ChatbotEngineOutcome.actionPending,
    );
  }

  /// Handles a direct "create an itinerary" request (distinct from
  /// [_handleAddToItinerary]'s implicit auto-create-if-none-exists side
  /// effect) — the user explicitly asked to start a new itinerary,
  /// optionally naming it, rather than to add a specific place to one.
  /// [intent.targetText] carries the requested name, if any; falls back
  /// to a default name (mirroring [ChatbotActionExecutor]'s existing
  /// "My Itinerary" default) when the user didn't provide one.
  ChatbotEngineResult _handleCreateItinerary(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
  }) {
    final requestedName = (intent.targetText ?? '').trim();
    final name = requestedName.isEmpty ? 'My Itinerary' : requestedName;

    return ChatbotEngineResult(
      replyText: _phraseBank.confirmAction(
        language,
        'Create a new itinerary called "$name"?',
      ),
      pendingAction: ChatbotPendingAction(
        type: ChatbotActionType.createItinerary,
        // No existing entity id to resolve against (unlike a location/
        // gate) — the name itself is both the target and the label the
        // executor needs to actually create the itinerary.
        targetId: name,
        targetLabel: name,
      ),
      outcome: ChatbotEngineOutcome.actionPending,
    );
  }

  ChatbotEngineResult _handleStartNavigation(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
    required String? currentPageContext,
    required LocationModel? mentionedLocation,
  }) {
    final location =
        mentionedLocation ??
        _knowledge.findLocationByName(intent.targetText ?? '') ??
        _resolveFromPageContext(currentPageContext) ??
        _mostRecentlyDiscussedLocation();

    if (location == null) {
      return ChatbotEngineResult(
        replyText: _phraseBank.unknownLocation(
          language,
          intent.targetText ?? '',
        ),
        outcome: ChatbotEngineOutcome.actionUnresolved,
      );
    }

    return ChatbotEngineResult(
      replyText: _phraseBank.confirmAction(
        language,
        'Start navigation to ${location.name}?',
      ),
      pendingAction: ChatbotPendingAction(
        type: ChatbotActionType.startNavigation,
        targetId: location.id,
        targetLabel: location.name,
      ),
      outcome: ChatbotEngineOutcome.actionPending,
    );
  }

  ChatbotEngineResult _handleChangeSetting(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
  }) {
    final parts = (intent.targetText ?? '').split('|');
    final feature = parts.isNotEmpty ? parts[0].trim() : '';

    if (feature.toLowerCase().contains('starting gate') ||
        feature.toLowerCase() == 'gate') {
      final gateQuery = parts.length > 1 ? parts[1].trim() : '';
      final gate = _knowledge.findGateByName(gateQuery);
      if (gate == null) {
        return ChatbotEngineResult(
          replyText: _phraseBank.unknownLocation(language, gateQuery),
          outcome: ChatbotEngineOutcome.actionUnresolved,
        );
      }
      return ChatbotEngineResult(
        replyText: _phraseBank.confirmAction(
          language,
          'Change your starting gate to ${gate.name}?',
        ),
        pendingAction: ChatbotPendingAction(
          type: ChatbotActionType.changeSetting,
          targetId: 'starting_gate:${gate.id}',
          targetLabel: gate.name,
        ),
        outcome: ChatbotEngineOutcome.actionPending,
      );
    }

    final verb = parts.length > 1 ? parts[1].trim() : 'on';
    final label = feature.isEmpty ? 'that setting' : feature;
    return ChatbotEngineResult(
      replyText: _phraseBank.confirmAction(language, 'Turn $verb $label?'),
      pendingAction: ChatbotPendingAction(
        type: ChatbotActionType.changeSetting,
        targetId: 'toggle:$label:$verb',
        targetLabel: label,
      ),
      outcome: ChatbotEngineOutcome.actionPending,
    );
  }

  ChatbotEngineResult _handleApplyFilter(
    ChatbotIntent intent, {
    required ChatMessageLanguage language,
  }) {
    final raw = intent.targetText ?? '';
    if (raw.startsWith('budget|')) {
      final parts = raw.split('|');
      final direction = parts.length > 1 ? parts[1] : '';
      final amount = parts.length > 2 ? parts[2] : '';
      return ChatbotEngineResult(
        replyText: _phraseBank.confirmAction(
          language,
          'Filter by budget $direction ₱$amount?',
        ),
        pendingAction: ChatbotPendingAction(
          type: ChatbotActionType.applyFilter,
          targetId: 'budget:$direction:$amount',
          targetLabel: 'budget $direction ₱$amount',
        ),
        outcome: ChatbotEngineOutcome.actionPending,
      );
    }

    final category =
        _knowledge.resolveCategory(raw) ??
        (raw.toLowerCase() == 'only' ? null : raw);
    if (category == null || category.trim().isEmpty) {
      return ChatbotEngineResult(
        replyText: _phraseBank.missingDetail(language),
        outcome: ChatbotEngineOutcome.actionUnresolved,
      );
    }
    return ChatbotEngineResult(
      replyText: _phraseBank.confirmAction(language, 'Show only $category?'),
      pendingAction: ChatbotPendingAction(
        type: ChatbotActionType.applyFilter,
        targetId: 'category:$category',
        targetLabel: category,
      ),
      outcome: ChatbotEngineOutcome.actionPending,
    );
  }

  // ─── Context & memory resolution (spec Section 6) ──────────────────────

  LocationModel? _findMentionedLocation(String normalized) {
    // Try progressively shorter trailing windows of the message so a
    // phrase like "tell me about fort santiago" still resolves even
    // though the whole sentence isn't a location name.
    final directMatch = _knowledge.findLocationByName(normalized);
    if (directMatch != null) return directMatch;

    for (final location in _knowledge.allLocations) {
      final name = location.name.toLowerCase();
      if (normalized.contains(name)) return location;
    }
    return null;
  }

  String? _resolveMentionedCategory(String normalized) {
    for (final category in _knowledge.allCategories) {
      if (normalized.contains(category.toLowerCase()) ||
          normalized.contains(
            category.toLowerCase().replaceAll(RegExp(r's$'), ''),
          )) {
        return category;
      }
    }
    return null;
  }

  /// Resolves the caller-supplied current-page label (spec Section 6:
  /// "aware of what page/location the user is currently viewing") into a
  /// [LocationModel], when that label is itself a location id/name. The
  /// UI layer is expected to pass e.g. a location id when the chat is
  /// opened from that location's details screen; other page labels (like
  /// "home" or "plans") simply won't resolve to a location here.
  LocationModel? _resolveFromPageContext(String? pageContext) {
    if (pageContext == null || pageContext.trim().isEmpty) return null;
    return _knowledge.findLocationById(pageContext) ??
        _knowledge.findLocationByName(pageContext);
  }

  /// Multi-turn memory (spec Section 6): scans the persisted session
  /// history, most recent first, for the last location either the user
  /// or the assistant mentioned by name — so "add that to my itinerary"
  /// right after discussing a location resolves without the user
  /// restating its name.
  LocationModel? _mostRecentlyDiscussedLocation() {
    final history = ChatMemoryService.instance.messages;
    for (final message in history.reversed) {
      final normalized = message.text.toLowerCase();
      for (final location in _knowledge.allLocations) {
        if (normalized.contains(location.name.toLowerCase())) {
          return location;
        }
      }
    }
    return null;
  }
}
