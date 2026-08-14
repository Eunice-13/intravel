/// Why a message was judged in- or out-of-scope — mostly useful for
/// debugging/telemetry; the conversation engine only really needs
/// [ChatbotScopeResult.inScope].
enum ChatbotScopeReason {
  /// Mentions a known location, gate, or category from the app's dataset.
  knownEntity,

  /// Mentions itinerary/plans/settings/app-feature vocabulary.
  appFeature,

  /// General Intramuros visitor-info vocabulary (walkability, attire,
  /// etc. — spec Section 2) without a specific named entity.
  generalIntramurosTopic,

  /// Too short/ambiguous to confidently classify either way — treated as
  /// in-scope so the engine can ask a clarifying follow-up rather than
  /// bluntly declining a plausibly-relevant one-word message.
  ambiguousShort,

  /// Explicitly mentions somewhere in Manila/Metro Manila other than
  /// Intramuros itself (e.g. "airport", "Makati") — out of scope per the
  /// spec's confirmed decision to *not* extend to Manila-wide questions.
  outOfScopeManilaWide,

  /// No recognizable connection to the app, Intramuros, or the user's
  /// own data at all (general trivia, unrelated cities, personal advice,
  /// current events, etc.).
  outOfScopeUnrelated,
}

class ChatbotScopeResult {
  final bool inScope;
  final ChatbotScopeReason reason;

  const ChatbotScopeResult(this.inScope, this.reason);
}

/// Enforces the chatbot spec's Section 2 scoping guardrail: "the
/// assistant stays strictly scoped to Intramuros — it should decline
/// broader Manila/Metro Manila travel questions ... not just fully
/// unrelated topics. If a question isn't about Intramuros itself, the
/// app's features, or the user's own itinerary/saved data, it's out of
/// scope."
///
/// This is a lightweight, offline keyword/heuristic classifier — the
/// same tradeoff [ChatMemoryService.detectLanguage] makes — rather than
/// a full NLU model. It errs toward calling something in-scope when
/// ambiguous (a false "in scope" just gets a normal, possibly slightly
/// off-target answer; a false "out of scope" incorrectly and rudely
/// refuses a legitimate question, which is the worse failure mode for a
/// tour-guide persona).
class ChatbotScopeClassifier {
  const ChatbotScopeClassifier();

  static const List<String> _appFeatureTerms = [
    'itinerary', 'itineraries', 'plan', 'plans', 'planner', 'budget',
    'filter', 'accessibility', 'setting', 'settings', 'gate', 'save',
    'saved', 'favorite', 'favorites', 'navigate', 'navigation', 'route',
    'app', 'feature', 'wheelchair', 'audio guide', 'audio narration',
    'add to', 'starting gate',
    // Natural, conversational phrasings of the same itinerary/app-feature
    // intents above that don't happen to contain one of those exact
    // keywords — e.g. "I want to add specific stops" (itinerary-building)
    // or "can we include a few more places" (adding stops). Without
    // these, a message like that falls through every category below and
    // gets misclassified as unrelated, even though it's squarely an
    // itinerary-building request per Section 4 of the spec.
    'add', 'stop', 'stops', 'place to visit', 'places to visit',
    'include', 'visit more', 'more places', 'more stops', 'another place',
    'other places', 'change my', 'turn on', 'turn off', 'enable', 'disable',
  ];

  static const List<String> _generalIntramurosTerms = [
    'intramuros', 'walled city', 'walkable', 'walking tour', 'what to wear',
    'what should i wear', 'tranvia', 'kalesa', 'e-trike', 'etrike',
    'entrance fee', 'opening hours', 'best time to visit',
    // Cost/pricing vocabulary beyond "entrance fee" — the spec explicitly
    // lists "budget/cost" as an in-scope topic for any location (Section
    // 2), and a question about cost doesn't always name a location
    // ("what locations have discounted rates", "which places are
    // cheapest") — without these, such a question falls through every
    // category and gets misclassified as unrelated.
    'discount', 'discounted', 'cheap', 'cheapest', 'cost', 'price',
    'prices', 'fee', 'fees', 'ticket', 'tickets', 'magkano', 'bayad',
    'free entrance', 'free entry', 'senior discount', 'student discount',
  ];

  /// Place names/terms that signal a *broader Manila/Metro Manila*
  /// question rather than an Intramuros one — out of scope per the
  /// spec's confirmed decision, even though they're geographically close
  /// and travel-related.
  static const List<String> _manilaWideTerms = [
    'airport',
    'naia',
    'makati',
    'quezon city',
    'bgc',
    'taguig',
    'pasay',
    'ortigas',
    'manila bay',
    'divisoria',
    'binondo',
    'mall of asia',
    'ermita',
    'malate',
    'from the airport',
    'to the airport',
    'metro manila',
    'edsa',
    'lrt',
    'mrt',
    'jeepney fare',
  ];

  ChatbotScopeResult classify(
    String message, {
    required bool mentionsKnownLocation,
    required bool mentionsKnownGate,
    required bool mentionsKnownCategory,
  }) {
    final normalized = message.toLowerCase().trim();

    if (mentionsKnownLocation || mentionsKnownGate || mentionsKnownCategory) {
      return const ChatbotScopeResult(true, ChatbotScopeReason.knownEntity);
    }

    if (normalized.isEmpty) {
      return const ChatbotScopeResult(true, ChatbotScopeReason.ambiguousShort);
    }

    // App-feature vocabulary is checked BEFORE the Manila-wide terms.
    //
    // The Manila-wide list exists to decline questions about travelling
    // *to* Intramuros from elsewhere in the metro ("how do I get here
    // from the airport"), which the spec is explicit about. But because
    // it matched on bare substrings and ran first, it also swallowed
    // legitimate in-app questions that merely *reference* a metro
    // landmark — most visibly "which gate is closest to the LRT?", which
    // is squarely an Intramuros access question about the app's own gate
    // data, yet got hard-declined.
    //
    // Checking app-feature terms first means a message that's clearly
    // about an app feature (gates, itinerary, navigation, filters) stays
    // in scope even if it name-drops a metro landmark as a reference
    // point, while a message whose *only* signal is a metro landmark
    // still falls through to the decline below.
    for (final term in _appFeatureTerms) {
      if (normalized.contains(term)) {
        return const ChatbotScopeResult(true, ChatbotScopeReason.appFeature);
      }
    }

    for (final term in _manilaWideTerms) {
      if (normalized.contains(term)) {
        return const ChatbotScopeResult(
          false,
          ChatbotScopeReason.outOfScopeManilaWide,
        );
      }
    }

    for (final term in _generalIntramurosTerms) {
      if (normalized.contains(term)) {
        return const ChatbotScopeResult(
          true,
          ChatbotScopeReason.generalIntramurosTopic,
        );
      }
    }

    final wordCount = normalized.split(RegExp(r'\s+')).length;
    if (wordCount <= 2) {
      // Too short to confidently classify (e.g. "thanks", "ok", a
      // location fragment the caller's entity check already missed) —
      // let the engine treat it as in-scope/continuation rather than
      // refusing a two-word message outright.
      return const ChatbotScopeResult(true, ChatbotScopeReason.ambiguousShort);
    }

    // Nothing above matched: this offline keyword list will never be
    // exhaustive, and naturally-phrased in-scope requests routinely
    // don't contain any of these exact terms (e.g. "can you help me
    // build my trip," "I want to see more spots," "what can I visit
    // around here" — all clearly Intramuros/itinerary requests, none of
    // which hit an `_appFeatureTerms`/`_generalIntramurosTerms` keyword).
    // The two hard, spec-mandated decline signals (Manila-wide terms,
    // and genuinely unrelated topics below) are still enforced above/
    // below this point — this fallback only covers the *remainder*,
    // where hard-declining offline was causing exactly the rigidity
    // this classifier exists to avoid ("erring toward calling something
    // in-scope when ambiguous", per the class doc). Instead of a hard
    // decline, treat it as ambiguous and let it flow through to the
    // live Gemini call (which has the full conversation history and
    // explicit natural-language-flexibility guidance — see
    // `GeminiChatService._naturalLanguageGuidance`), which is far
    // better equipped than a keyword list to judge genuinely
    // unrelated-to-Intramuros content and decline it itself per the
    // chatbot spec's own system-instruction rules.
    if (_looksClearlyUnrelated(normalized)) {
      return const ChatbotScopeResult(
        false,
        ChatbotScopeReason.outOfScopeUnrelated,
      );
    }

    return const ChatbotScopeResult(true, ChatbotScopeReason.ambiguousShort);
  }

  /// A small, deliberately narrow set of signals for content that's
  /// unambiguously *not* about Intramuros, the app, or the user's own
  /// data — general trivia, other cities/countries, current events,
  /// personal advice unrelated to travel here, etc. (spec Section 2).
  /// Kept narrow on purpose: this is the only remaining hard offline
  /// decline path once a message clears every in-scope keyword bucket
  /// above, so it must not be so broad that it swallows legitimate,
  /// just-casually-phrased Intramuros/app requests back into a decline
  /// — that's the exact rigidity this whole classifier update is fixing.
  bool _looksClearlyUnrelated(String normalized) {
    const unrelatedMarkers = [
      'capital of',
      'president of',
      'weather in new york',
      'stock market',
      'football score',
      'basketball score',
      'world cup',
      'nba',
      'recipe for',
      'movie recommendation',
      'tv show',
      'celebrity',
      'politics',
      'election',
      'cryptocurrency',
      'bitcoin',
      'stock price',
      'solve this equation',
      'translate this to',
      'write me a poem',
      'write code',
      'programming language',
      'homework',
    ];
    return unrelatedMarkers.any(normalized.contains);
  }

  /// The spec's confirmed decline-and-redirect copy (Section 2), used
  /// verbatim by the conversation engine so refusals are consistent.
  static const String declineMessage =
      "I can only help with things related to Intramuros and this app — "
      "try asking about a location, your itinerary, or how a feature "
      "works.";
}
