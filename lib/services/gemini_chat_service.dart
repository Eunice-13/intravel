import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import 'chat_memory_service.dart';
import 'chatbot_knowledge_base.dart';
import 'chatbot_system_instruction.dart';
import 'gemini_api_key_loader.dart';

// IntraBadi's persona/scope/grounding/action rules now live in
// `chatbot_system_instruction.dart` as a compiled-in Dart constant
// ([kChatbotSystemInstruction]) rather than being read from the bundled
// chatbot spec markdown at runtime. See that file's doc comment for why:
// the docs folder no longer ships inside the APK, and the system
// instruction can never fail to load and take chat down with it.

/// **Naming note:** this file/class kept its original `Gemini*` name
/// during the Gemini → Backboard.io chat-backend migration (see
/// `README.md`'s chat-assistant section) to minimize diff noise — the
/// public contract below (`GeminiChatService`, `GeminiChatResult`,
/// `GeminiFunctionCallRequest`, `GeminiChatException`) is what
/// `ChatbotChatSheet` and the existing test suite depend on, and none of
/// it is actually Gemini-specific in shape (text-or-function-calls in,
/// text-or-function-calls out) — only the backend behind it changed.
///
/// Function name for the `addToItinerary` tool (spec Section 4: adding a
/// location to the user's itinerary). State-changing, so the model
/// requesting this call is only ever a *request* — the actual mutation
/// still goes through the same mandatory chat confirmation flow
/// (`ChatbotPendingAction` / `ChatbotActionExecutor`) as the existing
/// regex-based intent path; this tool never bypasses that guardrail.
const String kAddToItineraryFunctionName = 'addToItinerary';

/// Function name for the `checkPrice` tool (spec Sections 2/3: entrance
/// fee / cost lookups grounded in the app's own dataset). Read-only, so
/// the result is simply handed back to the model as a tool result for
/// it to phrase a natural-language answer from — no confirmation needed
/// since nothing is mutated.
const String kCheckPriceFunctionName = 'checkPrice';

/// Function name for the `createItinerary` tool (spec Section 4:
/// creating a new itinerary, distinct from adding a location to an
/// existing one). State-changing, same as `addToItinerary` — the model
/// requesting this call is only ever a *request*; the actual creation
/// still goes through the mandatory chat confirmation flow.
const String kCreateItineraryFunctionName = 'createItinerary';

/// The tool declarations exposed to the model, in the OpenAI
/// function-calling JSON schema Backboard's `tools` request field
/// expects directly (chatbot spec Section 4: "The assistant can perform
/// actions on the user's behalf, not just answer questions"). Declaring
/// these lets the model itself decide, from natural conversational
/// phrasing, when a reply should be a tool call rather than plain text —
/// instead of relying solely on the offline regex [ChatbotIntentDetector]
/// to catch every phrasing.
///
/// The location-based tools take a single free-text `locationName` the
/// model extracts from the user's message (e.g. "Fort Santiago") —
/// resolving that name against the app's real dataset (fuzzy matching,
/// ids) is deliberately left to the caller
/// (`ChatbotKnowledgeService`/`ChatbotActionExecutor`) rather than asked
/// of the model, so results always stay grounded in the app's actual
/// data per spec Section 3.
final List<Map<String, Object?>> chatbotTools = [
  {
    'type': 'function',
    'function': {
      'name': kAddToItineraryFunctionName,
      'description':
          'Adds a specific Intramuros location to the user\'s itinerary. '
          'Call this whenever the user asks, in any phrasing, to add, '
          'save, include, or plan a stop/place/location into their '
          'itinerary or trip — this is a state-changing action, so it '
          'will always be confirmed with the user (Yes/No) before it '
          'actually takes effect.',
      'parameters': {
        'type': 'object',
        'properties': {
          'locationName': {
            'type': 'string',
            'description':
                'The name of the location to add, as the user referred '
                'to it (e.g. "Fort Santiago"). If the user used a vague '
                'reference like "that place" or "it", use the most '
                'recently discussed location name from the conversation '
                'history instead of leaving this empty.',
          },
        },
        'required': ['locationName'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': kCreateItineraryFunctionName,
      'description':
          'Creates a brand-new, empty itinerary for the user. Call this '
          'whenever the user asks, in any phrasing, to create, start, '
          'make, or plan a new itinerary/trip/plan — as distinct from '
          'adding a location to one that already exists. This is a '
          'state-changing action, so it will always be confirmed with '
          'the user (Yes/No) before it actually takes effect.',
      'parameters': {
        'type': 'object',
        'properties': {
          'itineraryName': {
            'type': 'string',
            'description':
                'The name for the new itinerary, if the user gave one '
                '(e.g. "Manila Trip", "Weekend Tour"). Leave this empty '
                'if the user did not specify a name — a sensible '
                'default will be used.',
          },
        },
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': kCheckPriceFunctionName,
      'description':
          'Looks up the real entrance fee / ticket price for a specific '
          'Intramuros location from the app\'s own dataset. Call this '
          'whenever the user asks about cost, price, fee, or "magkano" '
          'for a specific place, instead of guessing or estimating a '
          'price yourself.',
      'parameters': {
        'type': 'object',
        'properties': {
          'locationName': {
            'type': 'string',
            'description':
                'The name of the location to check the price for (e.g. '
                '"Fort Santiago"). If the user used a vague reference '
                'like "that place" or "it", use the most recently '
                'discussed location name from the conversation history '
                'instead of leaving this empty.',
          },
        },
        'required': ['locationName'],
      },
    },
  },
];

/// Thrown when the chat service can't produce a response — e.g. no API
/// key configured, or the network/model call itself failed. Callers (the
/// chat UI) should catch this and show a graceful in-chat error rather
/// than letting it crash the app.
class GeminiChatException implements Exception {
  final String message;
  final Object? cause;

  const GeminiChatException(this.message, {this.cause});

  @override
  String toString() => 'GeminiChatException: $message';
}

/// A single tool call the model wants performed, as parsed off a
/// Backboard `REQUIRES_ACTION` response — a thin, backend-agnostic
/// wrapper so callers (the chat UI) don't need to know the underlying
/// wire format just to read a call's name and arguments.
class GeminiFunctionCallRequest {
  final String name;
  final Map<String, Object?> args;

  /// Backboard's `tool_calls[].id`, tracked internally by
  /// [GeminiChatService] to match each [sendFunctionResults] entry back
  /// to the call that requested it (required when more than one tool
  /// call arrives in the same turn). Optional here and defaulted to an
  /// empty string so callers that construct this class directly (e.g.
  /// tests exercising only the chat UI's behavior, which predate the
  /// Backboard migration and have no id to supply) don't need to know
  /// this backend-specific detail exists.
  final String id;

  const GeminiFunctionCallRequest({
    required this.name,
    required this.args,
    this.id = '',
  });
}

/// The result of one [GeminiChatService.sendMessage] call: either plain
/// text to show directly, or one or more tool calls the caller must
/// resolve (by calling the real app service the tool bridges to) and
/// report back via [GeminiChatService.sendFunctionResults] before a
/// final text reply is available.
class GeminiChatResult {
  final String? text;
  final List<GeminiFunctionCallRequest> functionCalls;

  const GeminiChatResult({this.text, this.functionCalls = const []});

  bool get hasFunctionCalls => functionCalls.isNotEmpty;
}

/// Talks to the Backboard.io chat API (`POST /threads/messages` +
/// `POST /threads/tool-outputs`), seeded with the chatbot spec markdown
/// as its system prompt, and exposes the same `sendMessage`/
/// `sendFunctionResults` entry points the conversation UI layer already
/// depends on.
///
/// **Migration note (Gemini → Backboard):** this class previously wrapped
/// `google_generative_ai`'s `GenerativeModel`/`ChatSession`. It now makes
/// plain REST calls via `package:http` — mirroring
/// `OpenRouteServiceRouting`'s existing convention in
/// `routing_service.dart` — since Backboard has no official Dart/Flutter
/// SDK. The public contract (this class's method signatures,
/// [GeminiChatResult], [GeminiFunctionCallRequest], [GeminiChatException])
/// is unchanged, so `ChatbotChatSheet` required no changes at all.
///
/// Multi-turn history (chatbot spec Section 6) is maintained
/// *server-side* by Backboard once a `thread_id` exists — every call
/// after the first passes the same `thread_id` and Backboard supplies
/// the full conversation context itself; callers don't need to (and
/// shouldn't) replay past messages themselves for calls within one
/// [GeminiChatService] instance's lifetime.
///
/// **Cross-session history:** because the chat UI (`ChatbotChatSheet`)
/// is torn down and rebuilt every time the assistant's sheet is opened
/// (each open constructs a fresh [GeminiChatService]), a brand-new
/// Backboard thread would otherwise start with no history even though
/// [ChatMemoryService] already has prior turns persisted on disk —
/// meaning the model would have no idea what the user was just talking
/// about ("I want to add specific stops" right after asking about Fort
/// Santiago would look like a first, contextless message). To fix that,
/// the first request of a new thread is seeded with
/// [ChatMemoryService]'s already-persisted turns folded into the
/// system prompt (via [_seedHistoryPreamble]) — the same fix the prior
/// Gemini implementation made by replaying history into the SDK's
/// `ChatSession`, just expressed differently since Backboard's
/// thread-continuation model has no equivalent "seed history now" call.
///
/// The API key (via [GeminiApiKeyLoader]) is resolved lazily, on first
/// use, since it isn't available synchronously at construction time.
///
/// **Tool calling:** the model is also given [chatbotTools]
/// (`addToItinerary`, `createItinerary`, `checkPrice`) so it can trigger
/// those as real callbacks instead of only ever returning text. This
/// class itself never executes a tool — it only surfaces the model's
/// request via [GeminiChatResult.functionCalls] and later accepts the
/// caller's result via [sendFunctionResults] to continue the same turn.
/// The actual bridge to the app's real itinerary/pricing data lives in
/// the chat UI layer (`ChatbotChatSheet`), which already owns
/// `ChatbotKnowledgeService` and `ChatbotActionExecutor` for exactly
/// this purpose.
class GeminiChatService {
  GeminiChatService({
    GeminiApiKeyLoader? apiKeyLoader,
    ChatMemoryService? chatMemoryService,
    http.Client? httpClient,
  }) : _apiKeyLoader = apiKeyLoader ?? GeminiApiKeyLoader(),
       _chatMemoryService = chatMemoryService ?? ChatMemoryService.instance,
       _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://app.backboard.io/api';

  /// Explicit model/provider for this integration — **must** be passed
  /// on every `/threads/messages` call rather than omitted.
  ///
  /// **Live-checked against the real API (2026-08-15):** Backboard's own
  /// default provider/model (used whenever `llm_provider`/`model_name`
  /// are omitted — at the time of writing that default is `openai`/
  /// `gpt-4o`) was returning a hard `500 "Something went wrong. Please
  /// try again later."` for *every* request, on two separate accounts/
  /// API keys (including a brand-new account with fresh credit) — i.e.
  /// not a quota/billing/key problem, a break in Backboard's own default
  /// model path. The exact same endpoint immediately returned
  /// `200`/`COMPLETED` once a concrete `llm_provider`/`model_name` pair
  /// was specified, which is why this is a hard requirement here rather
  /// than a "nice to pin for stability" choice.
  ///
  /// Uses Backboard's `openrouter` routing rather than `anthropic`
  /// directly — `llm_provider: "anthropic"` with a bare model name like
  /// `"claude-haiku-4.5"` failed with `status: "FAILED"` / "Model ...
  /// is not supported" (this account's Backboard routing expects
  /// OpenRouter-style `provider/model` names). `openrouter` +
  /// `"anthropic/claude-haiku-4.5"` is the combination that actually
  /// live-checked as `200`/`COMPLETED`.
  ///
  /// Chosen over a free-tier model deliberately: this app previously
  /// hit Gemini's free-tier daily cap mid-testing (see the retry logic
  /// below), and a live demo cannot afford the assistant silently
  /// degrading to its offline engine because of a shared rate limit.
  static const String _llmProvider = 'openrouter';
  static const String _modelName = 'anthropic/claude-haiku-4.5';

  final GeminiApiKeyLoader _apiKeyLoader;
  final ChatMemoryService _chatMemoryService;

  /// Injectable for testing (so a fake `http.Client` can supply canned
  /// responses instead of making a real network call) — mirrors
  /// [OpenRouteServiceRouting]'s identical convention in
  /// `routing_service.dart`. Production call sites should omit this and
  /// let this class construct its own client.
  final http.Client _httpClient;

  /// The Backboard thread id for this service instance's conversation,
  /// once the first request has completed. `null` until then — the
  /// first request omits `thread_id` (Backboard auto-creates one) and
  /// every subsequent request reuses it, mirroring the previous
  /// `ChatSession`'s single-session-per-widget-instance lifetime.
  String? _threadId;

  /// Whether the very first request of this instance's lifetime has
  /// gone out yet — gates whether the seeded-history preamble (see
  /// [_seedHistoryPreamble]) needs to be included in the system prompt.
  /// Only the first request needs it: every later request already has
  /// `_threadId` set, so Backboard itself supplies that turn's history.
  bool _hasSentFirstMessage = false;

  String? _cachedApiKey;

  Future<String> _resolveApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey!;
    final apiKey = await _apiKeyLoader.resolveApiKey();
    if (apiKey.isEmpty) {
      throw const GeminiChatException(
        'No Backboard API key configured — set BACKBOARD_API_KEY via '
        '--dart-define or in env.json.',
      );
    }
    _cachedApiKey = apiKey;
    return apiKey;
  }

  /// Behavioral contract first (persona, scope, grounding, action
  /// guardrails), then the app knowledge base that grounds *what* the
  /// app actually contains. Order matters: the rules should frame how
  /// the knowledge is used, and the knowledge base itself defers to the
  /// live dataset/tools for any specific figure. Identical text to what
  /// the prior Gemini `systemInstruction` used.
  String _baseSystemPrompt() =>
      '$kChatbotSystemInstruction\n\n$kChatbotKnowledgeBase';

  /// Replays [ChatMemoryService]'s already-persisted turns (oldest
  /// first) as a plain-text transcript appended to the system prompt —
  /// see the class doc's "Cross-session history" note for why this is
  /// necessary: without it, a freshly-opened chat sheet would start the
  /// model off with no memory of anything the user already said earlier
  /// in the same persisted conversation (spec Section 6: multi-turn
  /// memory), even though it's still visibly on-screen as prior bubbles.
  ///
  /// Only used for the first request of a new thread (see
  /// [_hasSentFirstMessage]) — once `_threadId` is set, Backboard itself
  /// supplies every later turn's history.
  ///
  /// Only `user`/`assistant` turns carry real conversational content. A
  /// turn with empty text (shouldn't normally occur) is skipped rather
  /// than rendered as a blank line.
  String _seedHistoryPreamble() {
    final turns = <String>[];
    for (final message in _chatMemoryService.messages) {
      if (message.text.trim().isEmpty) continue;
      final speaker = message.role == ChatMessageRole.user ? 'User' : 'You';
      turns.add('$speaker: ${message.text}');
    }
    if (turns.isEmpty) return '';
    return '\n\nHere is the prior conversation history with this user, '
        'oldest first — you are already mid-conversation with them, so '
        'treat this as real context rather than a new introduction:\n'
        '${turns.join('\n')}';
  }

  /// Sends [message] to the model as the next turn in this thread and
  /// returns either its text response or the tool call(s) it wants
  /// performed (see [GeminiChatResult]). Throws [GeminiChatException] on
  /// any failure (missing key, or the underlying API call itself
  /// failing) — callers should catch this and show a graceful in-chat
  /// error.
  Future<GeminiChatResult> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      throw const GeminiChatException('Cannot send an empty message.');
    }

    return _send(() async {
      final apiKey = await _resolveApiKey();
      final systemPrompt = _hasSentFirstMessage
          ? null
          : _baseSystemPrompt() + _seedHistoryPreamble();

      final body = <String, Object?>{
        'content': message,
        if (_threadId case final id?) 'thread_id': id,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        'tools': chatbotTools,
        'llm_provider': _llmProvider,
        'model_name': _modelName,
        'stream': false,
      };

      return _post('/threads/messages', apiKey, body);
    });
  }

  /// Runs [operation] with retry-on-transient-failure, and converts the
  /// result (or final failure) for callers.
  ///
  /// Mirrors the prior Gemini implementation's retry behavior: hosted
  /// LLM APIs intermittently return capacity errors (503/`overloaded`/
  /// `high demand`) that resolve themselves within a couple of seconds.
  /// Retrying a couple of times with backoff recovers the overwhelming
  /// majority of these, so a purely temporary blip doesn't look like a
  /// broken integration.
  ///
  /// Non-transient failures (bad key, malformed request, rate limit/
  /// quota exhausted) are *not* retried — hammering them wastes the
  /// user's time and, for a rate limit, risks making it worse.
  Future<GeminiChatResult> _send(
    Future<Map<String, Object?>> Function() operation,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxSendAttempts; attempt++) {
      try {
        final result = _toResult(await operation());
        _hasSentFirstMessage = true;
        return result;
      } on GeminiChatException {
        rethrow;
      } catch (e) {
        lastError = e;
        final isLast = attempt == _maxSendAttempts - 1;
        if (isLast || !_isTransient(e)) break;
        final backoff = _retryBackoff[attempt];
        debugPrint(
          '[GeminiChatService] Transient API failure on attempt '
          '${attempt + 1}/$_maxSendAttempts — retrying in '
          '${backoff.inMilliseconds}ms. Cause: $e',
        );
        await Future<void>.delayed(backoff);
      }
    }

    // Carry the underlying cause into the message, not just the `cause`
    // field: the chat sheet logs this string when it falls back to the
    // offline engine, and a bare "Failed to get a response" gave no way
    // to tell a capacity blip apart from a rejected key.
    throw GeminiChatException(
      'Failed to get a response from the Backboard API: $lastError',
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
  /// retrying, as opposed to a request/credential/rate-limit problem
  /// that will fail identically every time.
  static bool _isTransient(Object error) {
    final text = error.toString().toLowerCase();

    // Rate-limit/quota exhaustion is explicitly NOT transient, even
    // though it may arrive alongside genuine capacity blips — retrying a
    // rate-limit failure cannot succeed within the same window and only
    // burns more of whatever quota remains.
    if (_isRateLimited(text)) return false;

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

  /// Whether [lowercaseText] is a rate-limit/quota exhaustion failure
  /// rather than a momentary server-side condition.
  static bool _isRateLimited(String lowercaseText) =>
      lowercaseText.contains('429') ||
      lowercaseText.contains('rate limit') ||
      lowercaseText.contains('too many requests') ||
      lowercaseText.contains('quota exceeded');

  /// Reports the results of one or more tool calls the model previously
  /// requested (via a prior [sendMessage] or [sendFunctionResults] call
  /// whose [GeminiChatResult.hasFunctionCalls] was true) back to the
  /// model as the next turn, and returns its follow-up response —
  /// typically a final natural-language reply grounded in the data the
  /// caller just supplied (e.g. "Fort Santiago costs ₱75 for adults."),
  /// though the model may also chain into another tool call.
  ///
  /// [results] maps each tool/function name to the data the caller's
  /// real bridge (e.g. [ChatbotKnowledgeService], [ChatbotActionExecutor])
  /// produced for it — e.g. `{'checkPrice': {'adultPrice': 75, ...}}` or
  /// `{'addToItinerary': {'status': 'pending_confirmation'}}`.
  ///
  /// Backboard identifies each tool result by the originating call's
  /// `tool_call_id`, not by function name — [_pendingToolCalls] (the
  /// calls surfaced by the most recent [GeminiChatResult]) supplies that
  /// mapping so callers can keep using the same by-name `results` shape
  /// the prior Gemini implementation exposed.
  Future<GeminiChatResult> sendFunctionResults(
    Map<String, Map<String, Object?>> results,
  ) async {
    if (results.isEmpty) {
      throw const GeminiChatException(
        'Cannot send an empty set of function results.',
      );
    }
    if (_threadId == null) {
      throw const GeminiChatException(
        'Cannot send function results before any message has been sent.',
      );
    }

    final toolOutputs = <Map<String, Object?>>[];
    for (final entry in results.entries) {
      final callId = _pendingToolCallIdsByName[entry.key];
      if (callId == null) {
        throw GeminiChatException(
          'No pending tool call named "${entry.key}" to report a result '
          'for.',
        );
      }
      toolOutputs.add({
        'tool_call_id': callId,
        'output': jsonEncode(entry.value),
      });
    }

    // Same retry/backoff treatment as [sendMessage]: a tool-call
    // follow-up is mid-conversation, so losing it to a capacity blip
    // would leave the user's confirmed action unacknowledged.
    return _send(() async {
      final apiKey = await _resolveApiKey();
      return _post('/threads/tool-outputs', apiKey, {
        'thread_id': _threadId,
        'tool_outputs': toolOutputs,
      });
    });
  }

  /// Maps each currently-pending tool call's function name to its
  /// `tool_call_id`, populated by [_toResult] whenever a response
  /// carries `tool_calls`, and consumed by [sendFunctionResults] so
  /// callers can keep reporting results by function name (matching the
  /// prior Gemini-backed contract) without needing to know Backboard's
  /// id-based matching requirement.
  final Map<String, String> _pendingToolCallIdsByName = {};

  Future<Map<String, Object?>> _post(
    String path,
    String apiKey,
    Map<String, Object?> body,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body) as Map<String, Object?>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'] ?? decoded['error'] ?? response.body;
      throw Exception(
        'Backboard API returned ${response.statusCode}: $detail',
      );
    }

    if (decoded['thread_id'] != null) {
      _threadId = decoded['thread_id'] as String;
    }

    return decoded;
  }

  GeminiChatResult _toResult(Map<String, Object?> response) {
    final status = response['status'] as String?;

    if (status == 'REQUIRES_ACTION') {
      final rawCalls = (response['tool_calls'] as List?) ?? const [];
      _pendingToolCallIdsByName.clear();
      final calls = <GeminiFunctionCallRequest>[];
      for (final raw in rawCalls) {
        final call = raw as Map<String, Object?>;
        final id = call['id'] as String;
        final function = call['function'] as Map<String, Object?>;
        final name = function['name'] as String;
        final rawArgs = function['arguments'] as String? ?? '{}';
        final args = jsonDecode(rawArgs) as Map<String, Object?>;
        _pendingToolCallIdsByName[name] = id;
        calls.add(GeminiFunctionCallRequest(name: name, args: args, id: id));
      }
      return GeminiChatResult(functionCalls: calls);
    }

    if (status == 'FAILED' || status == 'CANCELLED') {
      throw GeminiChatException(
        'The Backboard API reported status "$status" for this message.',
      );
    }

    final text = response['content'] as String?;
    if (text == null || text.isEmpty) {
      throw const GeminiChatException('The model returned an empty response.');
    }
    return GeminiChatResult(text: text);
  }

  /// The Backboard thread id backing this conversation, once known —
  /// exposed for callers that want to inspect/debug which thread this
  /// service instance is talking to. `null` until the first successful
  /// [sendMessage] call. Kept as a near drop-in analog of the prior
  /// `history` getter's debugging purpose, though the actual multi-turn
  /// transcript itself now lives server-side on Backboard rather than
  /// being locally inspectable.
  String? get threadId => _threadId;
}
