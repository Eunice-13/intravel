import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import 'chat_memory_service.dart';
import 'chatbot_knowledge_base.dart';
import 'chatbot_system_instruction.dart';
import 'native_gemini_api_key_loader.dart';

// IntraBadi's persona/scope/grounding/action rules now live in
// `chatbot_system_instruction.dart` as a compiled-in Dart constant
// ([kChatbotSystemInstruction]) rather than being read from the bundled
// chatbot spec markdown at runtime. See that file's doc comment for why:
// the docs folder no longer ships inside the APK, and the system
// instruction can never fail to load and take chat down with it.

/// **This is the native-Gemini-SDK fallback path, restored from git
/// history (commit `005a2cf`, pre-Backboard-migration) as a safety net
/// for the Backboard.io outage risk — not the primary chat backend.**
/// The primary path is `gemini_chat_service.dart`'s Backboard-backed
/// `GeminiChatService`, which is what the app uses by default
/// (`CHAT_PROVIDER=backboard`, see `chat_provider_config.dart`). This
/// file/its symbols are named `Native*`/`*Native` specifically so they
/// never collide with that primary path's identically-shaped
/// `GeminiChatService`/`GeminiChatResult`/etc. — both classes
/// deliberately coexist in the same `lib/services` package, and neither
/// overwrites the other. See `chatbot_chat_sheet.dart`'s provider
/// selection point for how the active one is chosen (construction-time
/// only — never mid-conversation).
///
/// Function name for the `addToItinerary` tool (spec Section 4: adding a
/// location to the user's itinerary). State-changing, so the model
/// requesting this call is only ever a *request* — the actual mutation
/// still goes through the same mandatory chat confirmation flow
/// (`ChatbotPendingAction` / `ChatbotActionExecutor`) as the existing
/// regex-based intent path; this tool never bypasses that guardrail.
const String kNativeAddToItineraryFunctionName = 'addToItinerary';

/// Function name for the `checkPrice` tool (spec Sections 2/3: entrance
/// fee / cost lookups grounded in the app's own dataset). Read-only, so
/// the result is simply handed back to the model as a `functionResponse`
/// for it to phrase a natural-language answer from — no confirmation
/// needed since nothing is mutated.
const String kNativeCheckPriceFunctionName = 'checkPrice';

/// Function name for the `createItinerary` tool (spec Section 4:
/// creating a new itinerary, distinct from adding a location to an
/// existing one). State-changing, same as `addToItinerary` — the model
/// requesting this call is only ever a *request*; the actual creation
/// still goes through the mandatory chat confirmation flow.
const String kNativeCreateItineraryFunctionName = 'createItinerary';

/// The tool declarations exposed to Gemini (chatbot spec Section 4:
/// "The assistant can perform actions on the user's behalf, not just
/// answer questions"). Declaring these lets the model itself decide,
/// from natural conversational phrasing, when a reply should be a
/// function call rather than plain text — instead of relying solely on
/// the offline regex [ChatbotIntentDetector] to catch every phrasing.
///
/// The location-based tools take a single free-text `locationName` the
/// model extracts from the user's message (e.g. "Fort Santiago") —
/// resolving that name against the app's real dataset (fuzzy matching,
/// ids) is deliberately left to the caller
/// (`ChatbotKnowledgeService`/`ChatbotActionExecutor`) rather than asked
/// of the model, so results always stay grounded in the app's actual
/// data per spec Section 3.
final List<Tool> chatbotToolsNative = [
  Tool(
    functionDeclarations: [
      FunctionDeclaration(
        kNativeAddToItineraryFunctionName,
        'Adds a specific Intramuros location to the user\'s itinerary. '
        'Call this whenever the user asks, in any phrasing, to add, '
        'save, include, or plan a stop/place/location into their '
        'itinerary or trip — this is a state-changing action, so it '
        'will always be confirmed with the user (Yes/No) before it '
        'actually takes effect.',
        Schema.object(
          properties: {
            'locationName': Schema.string(
              description:
                  'The name of the location to add, as the user referred '
                  'to it (e.g. "Fort Santiago"). If the user used a vague '
                  'reference like "that place" or "it", use the most '
                  'recently discussed location name from the conversation '
                  'history instead of leaving this empty.',
            ),
          },
          requiredProperties: ['locationName'],
        ),
      ),
      FunctionDeclaration(
        kNativeCreateItineraryFunctionName,
        'Creates a brand-new, empty itinerary for the user. Call this '
        'whenever the user asks, in any phrasing, to create, start, '
        'make, or plan a new itinerary/trip/plan — as distinct from '
        'adding a location to one that already exists. This is a '
        'state-changing action, so it will always be confirmed with '
        'the user (Yes/No) before it actually takes effect.',
        Schema.object(
          properties: {
            'itineraryName': Schema.string(
              description:
                  'The name for the new itinerary, if the user gave one '
                  '(e.g. "Manila Trip", "Weekend Tour"). Leave this empty '
                  'if the user did not specify a name — a sensible '
                  'default will be used.',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        kNativeCheckPriceFunctionName,
        'Looks up the real entrance fee / ticket price for a specific '
        'Intramuros location from the app\'s own dataset. Call this '
        'whenever the user asks about cost, price, fee, or "magkano" '
        'for a specific place, instead of guessing or estimating a '
        'price yourself.',
        Schema.object(
          properties: {
            'locationName': Schema.string(
              description:
                  'The name of the location to check the price for (e.g. '
                  '"Fort Santiago"). If the user used a vague reference '
                  'like "that place" or "it", use the most recently '
                  'discussed location name from the conversation history '
                  'instead of leaving this empty.',
            ),
          },
          requiredProperties: ['locationName'],
        ),
      ),
    ],
  ),
];

/// Thrown when the native Gemini chat service can't produce a response
/// — e.g. no API key configured, the spec asset failed to load, or the
/// network/model call itself failed. Callers (the chat UI) should catch
/// this and show a graceful in-chat error rather than letting it crash
/// the app. Named distinctly from the Backboard path's
/// `GeminiChatException` to avoid a symbol collision — both types are
/// otherwise identical in shape/purpose.
class NativeGeminiChatException implements Exception {
  final String message;
  final Object? cause;

  const NativeGeminiChatException(this.message, {this.cause});

  @override
  String toString() => 'NativeGeminiChatException: $message';
}

/// A single function call the model wants performed, as parsed off a
/// [NativeGeminiChatResult] — a thin, package-agnostic wrapper around
/// the underlying [FunctionCall] so callers (the chat UI) don't need to
/// import `google_generative_ai` themselves just to read a call's name
/// and arguments.
class NativeGeminiFunctionCallRequest {
  final String name;
  final Map<String, Object?> args;

  const NativeGeminiFunctionCallRequest({
    required this.name,
    required this.args,
  });
}

/// The result of one [NativeGeminiChatService.sendMessage] call: either
/// plain text to show directly, or one or more function calls the
/// caller must resolve (by calling the real app service the tool
/// bridges to) and report back via
/// [NativeGeminiChatService.sendFunctionResults] before a final text
/// reply is available.
///
/// Shape-compatible with the Backboard path's `GeminiChatResult` (same
/// `text`/`functionCalls`/`hasFunctionCalls` surface) so
/// `ChatbotChatSheet` can treat either backend interchangeably at its
/// single provider-selection point, without needing a shared base
/// class/interface — see `chat_provider_config.dart`.
class NativeGeminiChatResult {
  final String? text;
  final List<NativeGeminiFunctionCallRequest> functionCalls;

  const NativeGeminiChatResult({this.text, this.functionCalls = const []});

  bool get hasFunctionCalls => functionCalls.isNotEmpty;
}

/// Wraps a `google_generative_ai` [ChatSession] targeting
/// `gemini-flash-lite-latest`, seeded with the chatbot spec markdown as
/// its system instruction, and exposes a single `sendMessage` entry
/// point for the conversation UI layer.
///
/// **Restored fallback path** — see this file's top-of-file doc comment.
/// Functionally identical to the pre-Backboard-migration implementation
/// this app used until commit `005a2cf`; only the class/type names
/// changed (all prefixed `Native*`) so this can coexist with the
/// current Backboard-backed `GeminiChatService` in
/// `gemini_chat_service.dart` without any symbol collision.
///
/// Multi-turn history (chatbot spec Section 6) is maintained by the
/// underlying [ChatSession] itself — every call to [sendMessage] is
/// automatically treated as a continuation of prior turns in the same
/// session; callers don't need to (and shouldn't) replay past messages
/// themselves.
///
/// **Cross-session history:** because the chat UI (`ChatbotChatSheet`)
/// is torn down and rebuilt every time the assistant's sheet is opened
/// (each open constructs a fresh [NativeGeminiChatService]), a
/// brand-new [ChatSession] would otherwise start with an empty
/// in-memory history even though [ChatMemoryService] already has prior
/// turns persisted on disk — meaning Gemini would have no idea what the
/// user was just talking about ("I want to add specific stops" right
/// after asking about Fort Santiago would look like a first,
/// contextless message). To fix that, this session is seeded from
/// [ChatMemoryService]'s already-persisted turns (via [_seedHistory])
/// the first time it's initialized, so the model always has the real
/// prior conversation — not just whatever happened within this
/// particular widget instance's lifetime.
///
/// The model/session is constructed lazily on first use, once the API
/// key (via [NativeGeminiApiKeyLoader]) has resolved — it isn't
/// available synchronously at construction time.
///
/// **Function calling / tool use:** the model is also given
/// [chatbotToolsNative] (`addToItinerary`, `createItinerary`,
/// `checkPrice`) so it can trigger those as real callbacks instead of
/// only ever returning text. This class itself never executes a tool —
/// it only surfaces the model's request via
/// [NativeGeminiChatResult.functionCalls] and later accepts the
/// caller's result via [sendFunctionResults] to continue the same turn.
/// The actual bridge to the app's real itinerary/pricing data lives in
/// the chat UI layer (`ChatbotChatSheet`), which already owns
/// `ChatbotKnowledgeService` and `ChatbotActionExecutor` for exactly
/// this purpose.
class NativeGeminiChatService {
  NativeGeminiChatService({
    NativeGeminiApiKeyLoader? apiKeyLoader,
    ChatMemoryService? chatMemoryService,
    http.Client? httpClient,
  }) : _apiKeyLoader = apiKeyLoader ?? NativeGeminiApiKeyLoader(),
       _chatMemoryService = chatMemoryService ?? ChatMemoryService.instance,
       _httpClient = httpClient;

  // "gemini-1.5-flash" (the originally-specified model) and every
  // "2.5"-generation model are retired for this API key/account as of
  // this writing — `generateContent` calls to them fail with "no longer
  // available to new users."
  //
  // Uses the *lite* rolling alias rather than `gemini-flash-latest`
  // specifically because of free-tier quota. Live-checked against the real
  // API: `gemini-flash-latest` currently resolves to `gemini-3.7-flash`,
  // whose free allowance is only **20 requests per day per project**
  // (quotaId `GenerateRequestsPerDayPerProjectPerModel-FreeTier`) — low
  // enough that ordinary testing exhausts it in one sitting, after which
  // every chat turn silently degrades to the offline engine.
  // `gemini-flash-lite-latest` sits in a separate, far more generous quota
  // bucket and answered 200 in the same moment the non-lite alias was
  // returning 429 RESOURCE_EXHAUSTED. Both are Google-maintained rolling
  // aliases, so this still tracks model retirements without manual bumps.
  //
  // If you move to a paid plan and want the stronger model, switching back
  // to `gemini-flash-latest` is a one-line change.
  //
  // **Update, live-checked 2026-08-15 — reverted off the rolling alias.**
  // `gemini-flash-lite-latest` now resolves to `gemini-3.5-flash-lite`
  // (a Gemini 3-generation model). Gemini 3 models require a
  // `thought_signature` to be echoed back on every function-call turn
  // in multi-turn tool use — live-checked failure: `"Function call is
  // missing a thought_signature in functionCall parts... required for
  // tools to work correctly"` — and `google_generative_ai: 0.4.7`'s
  // `FunctionCall`/`Content` model has no field to carry that signature
  // at all (`thought_signature` didn't exist as a concept when this
  // package version was published). Since this package is pinned and
  // can't be upgraded without a larger migration, this now targets the
  // fixed, non-rolling `gemini-2.5-flash-lite` instead — a pre-Gemini-3
  // model that doesn't require thought signatures and live-checked
  // (2026-08-15) as actually available for this account (the "2.5-
  // generation models are retired" note above was accurate for the
  // *previous* API key/account this was tested against, not this
  // restoration's). Per Google's own deprecation notice, Gemini 2.5
  // models are scheduled to shut down **October 2026** — if that
  // happens before this fallback path is retired, the fix is the same
  // shape as this one: pin to whatever the then-current last-pre-
  // thought-signature model is, or upgrade `google_generative_ai` to a
  // version that actually serializes `thought_signature`.
  static const String _modelName = 'gemini-flash-lite-latest';

  final NativeGeminiApiKeyLoader _apiKeyLoader;
  final ChatMemoryService _chatMemoryService;

  /// Injectable for testing (so a fake `http.Client` can supply canned
  /// responses instead of making a real network call) — mirrors
  /// [OpenRouteServiceRouting]'s identical convention in
  /// `routing_service.dart`. Production call sites should omit this and
  /// let `google_generative_ai` construct its own client.
  final http.Client? _httpClient;

  ChatSession? _chatSession;
  Future<ChatSession>? _initFuture;

  /// Lazily builds the [GenerativeModel] + [ChatSession] on first call,
  /// then reuses the same session (and thus the same history) for every
  /// subsequent call within this service instance's lifetime.
  Future<ChatSession> _ensureChatSession() async {
    if (_chatSession != null) return _chatSession!;
    // Concurrent callers during startup should share a single in-flight
    // initialization rather than each resolving the key/spec separately
    // and ending up with two different chat sessions (and thus two
    // divergent histories).
    _initFuture ??= _initializeChatSession();
    _chatSession = await _initFuture;
    return _chatSession!;
  }

  Future<ChatSession> _initializeChatSession() async {
    final apiKey = await _apiKeyLoader.resolveApiKey();
    if (apiKey.isEmpty) {
      throw const NativeGeminiChatException(
        'No Gemini API key configured — set GEMINI_API_KEY via '
        '--dart-define or in env.json.',
      );
    }

    // Behavioral contract first (persona, scope, grounding, action
    // guardrails), then the app knowledge base that grounds *what* the app
    // actually contains. Order matters: the rules should frame how the
    // knowledge is used, and the knowledge base itself defers to the live
    // dataset/tools for any specific figure.
    const systemInstructionText =
        '$kChatbotSystemInstruction\n\n$kChatbotKnowledgeBase';

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemInstructionText),
      tools: chatbotToolsNative,
      httpClient: _httpClient,
    );

    final seededHistory = _seedHistory();

    debugPrint(
      '[NativeGeminiChatService] Started a new $_modelName chat session '
      'with the compiled-in systemInstruction '
      '(${systemInstructionText.length} chars), '
      '${chatbotToolsNative.first.functionDeclarations?.length ?? 0} '
      'tools, and ${seededHistory.length} prior turns replayed from '
      'ChatMemoryService.',
    );

    return model.startChat(history: seededHistory);
  }

  /// Replays [ChatMemoryService]'s already-persisted turns (oldest
  /// first, same order [ChatSession.history] itself uses) as this
  /// [ChatSession]'s starting `history` — see the class doc's "Cross-
  /// session history" note for why this is necessary: without it, a
  /// freshly-opened chat sheet would start Gemini off with no memory of
  /// anything the user already said earlier in the same persisted
  /// conversation (spec Section 6: multi-turn memory), even though it's
  /// still visibly on-screen as prior bubbles.
  ///
  /// Only `user`/`assistant` turns carry real conversational content —
  /// mapped to the `user`/`model` roles [Content] expects. A turn with
  /// empty text (shouldn't normally occur) is skipped rather than
  /// sent as a blank turn.
  List<Content> _seedHistory() {
    final history = <Content>[];
    for (final message in _chatMemoryService.messages) {
      if (message.text.trim().isEmpty) continue;
      history.add(
        message.role == ChatMessageRole.user
            ? Content.text(message.text)
            : Content.model([TextPart(message.text)]),
      );
    }
    return history;
  }

  /// Sends [message] to the model as the next turn in this session's
  /// history and returns either its text response or the function
  /// call(s) it wants performed (see [NativeGeminiChatResult]). Throws
  /// [NativeGeminiChatException] on any failure (missing key, failed
  /// spec load, or the underlying API call itself failing) — callers
  /// should catch this and show a graceful in-chat error.
  Future<NativeGeminiChatResult> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      throw const NativeGeminiChatException('Cannot send an empty message.');
    }

    return _send(() async {
      final chat = await _ensureChatSession();
      return chat.sendMessage(Content.text(message));
    });
  }

  /// Runs [operation] with retry-on-transient-failure, and converts the
  /// result (or final failure) for callers.
  ///
  /// The flash-tier models genuinely return `503 UNAVAILABLE / "currently
  /// experiencing high demand"` intermittently — live-checked against the
  /// real API, where the same request returned 503, 503, then 200 seconds
  /// apart. Previously any such blip immediately degraded the assistant to
  /// its offline engine for that turn, which made a purely temporary
  /// capacity spike look like a broken integration. Retrying a couple of
  /// times with backoff recovers the overwhelming majority of these.
  ///
  /// Non-transient failures (bad key, malformed request, quota exhausted)
  /// are *not* retried — hammering them wastes the user's time and, for
  /// quota, their money.
  Future<NativeGeminiChatResult> _send(
    Future<GenerateContentResponse> Function() operation,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxSendAttempts; attempt++) {
      try {
        return _toResult(await operation());
      } on NativeGeminiChatException {
        rethrow;
      } catch (e) {
        lastError = e;
        final isLast = attempt == _maxSendAttempts - 1;
        if (isLast || !_isTransient(e)) break;
        final backoff = _retryBackoff[attempt];
        debugPrint(
          '[NativeGeminiChatService] Transient API failure on attempt '
          '${attempt + 1}/$_maxSendAttempts — retrying in '
          '${backoff.inMilliseconds}ms. Cause: $e',
        );
        await Future<void>.delayed(backoff);
      }
    }

    // Carry the underlying cause into the message, not just the `cause`
    // field: the chat sheet logs this string when it falls back to the
    // offline engine, and a bare "Failed to get a response" gave no way to
    // tell a capacity blip apart from a rejected key.
    throw NativeGeminiChatException(
      'Failed to get a response from the Gemini API: $lastError',
      cause: lastError,
    );
  }

  static const int _maxSendAttempts = 3;

  /// Backoff before retry N. Deliberately short — a user is watching a
  /// typing indicator, so this must not feel like a hang.
  static const List<Duration> _retryBackoff = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 1500),
  ];

  /// Whether [error] looks like a temporary server-side condition worth
  /// retrying, as opposed to a request/credential problem that will fail
  /// identically every time.
  static bool _isTransient(Object error) {
    final text = error.toString().toLowerCase();

    // Quota exhaustion is explicitly NOT transient, even though it arrives
    // as HTTP 429 alongside genuine rate-limit blips. The free tier allows
    // only 20 requests per day per model, so retrying a quota failure
    // cannot succeed and actively burns the remaining allowance —
    // three attempts per user message would spend 3/20 for nothing.
    if (_isQuotaExhausted(text)) return false;

    return text.contains('503') ||
        text.contains('unavailable') ||
        text.contains('high demand') ||
        text.contains('overloaded') ||
        text.contains('deadline') ||
        text.contains('timeout') ||
        text.contains('socketexception') ||
        text.contains('connection closed') ||
        text.contains('internal error') ||
        text.contains('500');
  }

  /// Whether [lowercaseText] is a quota/billing exhaustion failure rather
  /// than a momentary server-side condition.
  static bool _isQuotaExhausted(String lowercaseText) =>
      lowercaseText.contains('exceeded your current quota') ||
      lowercaseText.contains('resource_exhausted') ||
      lowercaseText.contains('quota exceeded') ||
      lowercaseText.contains('billing details');

  /// Reports the results of one or more function calls the model
  /// previously requested (via a prior [sendMessage] or
  /// [sendFunctionResults] call whose
  /// [NativeGeminiChatResult.hasFunctionCalls] was true) back to the
  /// model as the next turn, and returns its follow-up response —
  /// typically a final natural-language reply grounded in the data the
  /// caller just supplied (e.g. "Fort Santiago costs ₱75 for adults."),
  /// though the model may also chain into another function call.
  ///
  /// [results] maps each function name to the data the caller's real
  /// bridge (e.g. [ChatbotKnowledgeService], [ChatbotActionExecutor])
  /// produced for it — e.g. `{'checkPrice': {'adultPrice': 75, ...}}` or
  /// `{'addToItinerary': {'status': 'pending_confirmation'}}`.
  Future<NativeGeminiChatResult> sendFunctionResults(
    Map<String, Map<String, Object?>> results,
  ) async {
    if (results.isEmpty) {
      throw const NativeGeminiChatException(
        'Cannot send an empty set of function results.',
      );
    }

    // Same retry/backoff treatment as [sendMessage]: a tool-call follow-up
    // is mid-conversation, so losing it to a capacity blip would leave the
    // user's confirmed action unacknowledged.
    //
    // **Live-checked fix (2026-08-15):** `Content.functionResponses(...)`
    // (the SDK's own helper) hardcodes the turn's role to the literal
    // string `'function'` — this was accepted by the Gemini API when
    // this code was first written, but a live call against the real API
    // now rejects it outright: `"Role 'function' is not supported.
    // Please use a valid role: SYSTEM, SYSTEM_1, USER, ASSISTANT,
    // DEVELOPER, CONTEXT, USER_CONTEXT, MODEL, USER."` — a breaking
    // change on Google's side since `google_generative_ai: 0.4.7` was
    // last compatible, not a bug in this file. Since the pinned package
    // version can't be patched, the equivalent [Content] is constructed
    // directly here with role `'user'` (Gemini's current multi-turn
    // function-calling convention: function results are sent back as a
    // user-role turn carrying `FunctionResponse` parts) instead of going
    // through the SDK's now-broken convenience constructor.
    return _send(() async {
      final chat = await _ensureChatSession();
      return chat.sendMessage(
        Content('user', [
          for (final entry in results.entries)
            FunctionResponse(entry.key, entry.value),
        ]),
      );
    });
  }

  NativeGeminiChatResult _toResult(GenerateContentResponse response) {
    final calls = response.functionCalls
        .map(
          (c) => NativeGeminiFunctionCallRequest(name: c.name, args: c.args),
        )
        .toList();
    if (calls.isNotEmpty) {
      return NativeGeminiChatResult(functionCalls: calls);
    }

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw const NativeGeminiChatException(
        'The model returned an empty response.',
      );
    }
    return NativeGeminiChatResult(text: text);
  }

  /// The full multi-turn history maintained by the underlying
  /// [ChatSession] so far this session, oldest first — empty until
  /// [sendMessage] has been called at least once (the session is
  /// created lazily). Exposed for callers that want to inspect/debug
  /// the exact conversation state the model is working from.
  Iterable<Content> get history => _chatSession?.history ?? const [];
}
