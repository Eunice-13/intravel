import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_memory_service.dart';
import '../services/chatbot_action_executor.dart';
import '../services/chatbot_conversation_engine.dart';
import '../services/chatbot_intent_service.dart' show ChatbotActionType;
import '../services/chatbot_knowledge_service.dart';
import '../services/gemini_chat_service.dart';
import '../theme/app_theme.dart';
import 'chatbot_avatar.dart';

/// The IntraBadi assistant's chat window (chatbot spec Section 1): opens
/// as an overlay/sheet on top of whatever page the user is on, without
/// navigating away, and closing it returns them to exactly where they
/// were. Matches the app's existing modal/sheet pattern (rounded top
/// corners, `colors.paper` background, drag handle) — see
/// `showBudgetFilterSheet` for the equivalent convention.
///
/// Messages are appended to [ChatMemoryService] (spec Section 6 —
/// persisted, multi-turn history) and each user turn is first run
/// through [ChatbotConversationEngine] (spec Sections 2/4/5/6 —
/// scoping, intent detection, language handling, and context/memory
/// resolution). What happens next depends on the engine's
/// [ChatbotEngineOutcome]:
/// - [ChatbotEngineOutcome.declined] / [ChatbotEngineOutcome.actionPending]
///   / [ChatbotEngineOutcome.actionUnresolved]: the engine's own text is
///   shown as-is. Scoping and the mandatory action-confirmation flow
///   (spec Section 4) are enforced here in code — never deferred to the
///   live model — so a recognized action always still requires an
///   explicit Yes/No before [ChatbotActionExecutor] runs.
/// - [ChatbotEngineOutcome.answered]: the message was an in-scope
///   question, so [GeminiChatService] is additionally asked for a
///   richer, more conversational answer (grounded by the chatbot spec
///   markdown as its system instruction) while a typing indicator shows
///   in place of a bubble; if that call fails for any reason (no
///   network, no API key, model error), the engine's own offline answer
///   is shown instead so the chat never dead-ends.
class ChatbotChatSheet extends StatefulWidget {
  final String? currentPageContext;

  /// Injectable for tests (so a fake can be substituted instead of
  /// making a real network call); production call sites should omit
  /// this and let the widget construct the real service.
  final GeminiChatService? geminiService;

  const ChatbotChatSheet({
    super.key,
    this.currentPageContext,
    this.geminiService,
  });

  @override
  State<ChatbotChatSheet> createState() => _ChatbotChatSheetState();
}

class _ChatbotChatSheetState extends State<ChatbotChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatbotConversationEngine _engine = ChatbotConversationEngine();
  final ChatbotActionExecutor _executor = ChatbotActionExecutor();
  final ChatbotKnowledgeService _knowledge = ChatbotKnowledgeService();
  late final GeminiChatService _geminiService;
  late final Future<void> _loadFuture;

  /// The action awaiting the user's explicit Yes/No, if any (spec
  /// Section 4). Cleared as soon as the user answers either way.
  ChatbotPendingAction? _pendingAction;
  bool _isExecutingAction = false;

  /// True when [_pendingAction] was raised by a Gemini
  /// `addToItinerary` tool call (see [_handleGeminiFunctionCalls])
  /// rather than the offline regex intent path — determines whether
  /// [_confirmPendingAction]/[_cancelPendingAction] need to report the
  /// outcome back to Gemini via [GeminiChatService.sendFunctionResults]
  /// so the model's own turn completes and it can phrase a natural
  /// closing reply, instead of leaving that tool call dangling.
  bool _pendingActionIsFromGemini = false;

  /// True while waiting on a live [GeminiChatService] reply for an
  /// in-scope question — drives the typing/loading indicator shown in
  /// place of the assistant's next bubble.
  bool _isWaitingForGeminiReply = false;

  /// Which expression the header avatar is showing. Driven contextually:
  /// waving on open, thinking while a reply is awaited, talking as a reply
  /// is delivered, smiling just after, then back to idle.
  ChatbotAvatarState _avatarState = ChatbotAvatarState.idle;

  /// Pending avatar timers, tracked so they can be cancelled if the user
  /// sends another message mid-animation (or the sheet closes) instead of
  /// firing against a disposed State.
  Timer? _avatarTimer;

  /// Moves the avatar to [state], optionally returning to another state
  /// after [holdFor]. Cancels any transition already queued.
  void _setAvatarState(
    ChatbotAvatarState state, {
    Duration? holdFor,
    ChatbotAvatarState then = ChatbotAvatarState.idle,
    ({Duration after, ChatbotAvatarState state})? andThen,
  }) {
    _avatarTimer?.cancel();
    if (!mounted) return;
    setState(() => _avatarState = state);
    if (holdFor == null) return;
    _avatarTimer = Timer(holdFor, () {
      if (!mounted) return;
      setState(() => _avatarState = then);
      if (andThen == null) return;
      _avatarTimer = Timer(andThen.after, () {
        if (!mounted) return;
        setState(() => _avatarState = andThen.state);
      });
    });
  }

  /// How long to play the talking animation for a given reply.
  ///
  /// Replies arrive all at once rather than streaming token-by-token, so
  /// there's no natural speech duration to follow. Scaling by word count
  /// (~40ms/word) makes the mouth movement feel tied to the amount actually
  /// being "said" — a fixed duration reads wrong for both "Yes." and a long
  /// multi-item list. Clamped at both ends so very short replies still
  /// register and very long ones don't chatter on for ages.
  Duration _talkingDurationFor(String reply) {
    final words = reply.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final ms = (words.length * 40).clamp(400, 4000);
    return Duration(milliseconds: ms);
  }

  /// True when the last turn was answered by the offline engine because
  /// the live model was unavailable (no/invalid key, no network, model
  /// error). Drives a small visible notice in the chat — the user-
  /// confirmed requirement that this degradation is never silent.
  bool _isDegradedToOffline = false;

  @override
  void initState() {
    super.initState();
    _geminiService = widget.geminiService ?? GeminiChatService();
    _loadFuture = ChatMemoryService.instance.load();
    ChatMemoryService.instance.addListener(_onHistoryChanged);
    // Greet on open, then settle into idle (spec Section 7's friendly
    // tour-guide persona, expressed in the avatar rather than only in copy).
    _setAvatarState(
      ChatbotAvatarState.waving,
      holdFor: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _avatarTimer?.cancel();
    ChatMemoryService.instance.removeListener(_onHistoryChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Keep the latest turn (or the typing indicator) in view as new
    // messages are appended or the loading state changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.user,
      text: text,
      pageContext: widget.currentPageContext,
    );

    // A pending confirmation takes priority over normal message
    // processing: if the assistant just asked "Add Fort Santiago to
    // your itinerary? (Yes/No)", the next thing the user types is their
    // answer to *that*, not a brand-new request — so a typed "yes"/"no"
    // reply is honored the same as tapping the Yes/No buttons, without
    // re-running it through the intent detector (or Gemini).
    if (_pendingAction != null) {
      final normalized = text.toLowerCase().trim();
      final isYes = _affirmativeReplies.contains(normalized);
      final isNo = _negativeReplies.contains(normalized);
      if (isYes) {
        await _confirmPendingAction();
        return;
      }
      if (isNo) {
        await _cancelPendingAction();
        return;
      }
      // Anything else while a confirmation is outstanding: remind the
      // user we're still waiting on an explicit yes/no rather than
      // silently dropping their new message or guessing at intent.
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.assistant,
        text:
            'Sorry, just need a Yes or No for that first — want me to '
            'go ahead?',
        pageContext: widget.currentPageContext,
      );
      return;
    }

    final result = _engine.process(
      text,
      currentPageContext: widget.currentPageContext,
    );

    if (result.pendingAction != null) {
      setState(() => _pendingAction = result.pendingAction);
    }

    // Which outcomes stay purely offline, and which fall through to the
    // model, is deliberate:
    //
    //  * `declined` — the spec's scope guardrail (Section 2). Enforced in
    //    code so an out-of-scope message is never sent to the model at
    //    all, rather than trusting it to refuse.
    //  * `actionPending` — a recognized state-changing request already
    //    awaiting an explicit Yes/No (Section 4). Handing this to the
    //    model would risk a second, conflicting interpretation while a
    //    confirmation is outstanding.
    //
    // Everything else falls through. `actionUnresolved` and the engine's
    // generic "I don't have that detail" answer used to be terminal, and
    // that was the single biggest cause of the assistant looking
    // keyword-bound: a question the regex layer simply failed to parse
    // got a dead-end reply even though the data to answer it existed.
    // Those are exactly the cases a model with the full dataset and
    // conversation history should get a shot at.
    final staysOffline =
        result.outcome == ChatbotEngineOutcome.declined ||
        result.outcome == ChatbotEngineOutcome.actionPending;

    if (staysOffline) {
      await ChatMemoryService.instance.addMessage(
        role: ChatMessageRole.assistant,
        text: result.replyText,
        pageContext: widget.currentPageContext,
      );
      return;
    }

    // In-scope question (or an action the offline layer couldn't resolve):
    // show the typing indicator and ask Gemini, falling back to the
    // engine's own offline answer (already computed above, in
    // result.replyText) if that fails.
    setState(() => _isWaitingForGeminiReply = true);
    _setAvatarState(ChatbotAvatarState.thinking);
    _scrollToBottom();

    String? replyText;
    var usedOfflineFallback = false;
    String? fallbackReason;
    try {
      final geminiResult = await _geminiService.sendMessage(text);
      replyText = await _resolveGeminiResult(geminiResult);
    } on GeminiChatException catch (e) {
      replyText = result.replyText;
      usedOfflineFallback = true;
      fallbackReason = e.message;
    } catch (e) {
      replyText = result.replyText;
      usedOfflineFallback = true;
      fallbackReason = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _isWaitingForGeminiReply = false;
      // Per the user-confirmed decision: the assistant runs on the model
      // when a key is present and degrades to the offline engine when
      // it isn't — but that degradation must be *visible*, not silent.
      // Previously this fallback was swallowed entirely, so a
      // misconfigured key or dead network produced a plausible-looking
      // keyword reply with no indication the smarter path never ran.
      _isDegradedToOffline = usedOfflineFallback;
    });
    if (usedOfflineFallback) {
      debugPrint(
        '[ChatbotChatSheet] Gemini unavailable — answered from the offline '
        'engine instead. Reason: $fallbackReason',
      );
    }

    // A null replyText means a function call was handled by putting up
    // a pending confirmation instead of a text reply (see
    // `_handleGeminiFunctionCalls`) — that confirmation message was
    // already appended there, so there's nothing further to add here.
    if (replyText == null) {
      _setAvatarState(ChatbotAvatarState.idle);
      return;
    }

    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.assistant,
      text: replyText,
      pageContext: widget.currentPageContext,
    );

    // "Speak" the reply for a duration proportional to its length, then a
    // brief pleased beat, then back to resting.
    _setAvatarState(
      ChatbotAvatarState.talking,
      holdFor: _talkingDurationFor(replyText),
      then: ChatbotAvatarState.smiling,
      andThen: const (
        after: Duration(milliseconds: 1400),
        state: ChatbotAvatarState.idle,
      ),
    );
  }

  /// Unwraps a [GeminiChatResult]: plain text is returned as-is; one or
  /// more function calls are dispatched to the real app bridge
  /// (`ChatbotKnowledgeService` for `checkPrice`, the existing
  /// confirmation flow + `ChatbotActionExecutor` for `addToItinerary`),
  /// per the chatbot's tool-use wiring (spec Section 4). May recurse
  /// once, since reporting a `checkPrice` result back to Gemini can
  /// itself produce either final text or another function call.
  Future<String?> _resolveGeminiResult(GeminiChatResult geminiResult) async {
    if (!geminiResult.hasFunctionCalls) {
      return geminiResult.text;
    }
    return _handleGeminiFunctionCalls(geminiResult.functionCalls);
  }

  Future<String?> _handleGeminiFunctionCalls(
    List<GeminiFunctionCallRequest> calls,
  ) async {
    final functionResults = <String, Map<String, Object?>>{};

    for (final call in calls) {
      final locationName = (call.args['locationName'] as String?) ?? '';
      final location = _knowledge.findLocationByName(locationName);

      switch (call.name) {
        case kCheckPriceFunctionName:
          // Read-only lookup — no confirmation needed. Grounded in the
          // exact same `ChatbotKnowledgeService`/dataset the rest of the
          // app reads ticket prices from (spec Section 3).
          if (location == null) {
            functionResults[kCheckPriceFunctionName] = {
              'found': false,
              'error': 'No location matching "$locationName" was found.',
            };
          } else {
            final ticket = location.ticketInfo;
            functionResults[kCheckPriceFunctionName] = {
              'found': true,
              'locationName': location.name,
              'adultPrice': ticket.adultPrice,
              'studentPrice': ticket.studentPrice,
              if (ticket.childPrice != null) 'childPrice': ticket.childPrice,
              if (ticket.seniorPrice != null) 'seniorPrice': ticket.seniorPrice,
              'currency': ticket.currency,
              if (ticket.notes != null) 'notes': ticket.notes,
            };
          }
          break;

        case kAddToItineraryFunctionName:
          // State-changing — never executed directly from a model tool
          // call. Surfaced as the same `ChatbotPendingAction` +
          // Yes/No confirmation UI the offline regex intent path already
          // uses, so the mandatory confirm-before-acting guardrail
          // (spec Section 4) applies identically regardless of which
          // path recognized the request.
          if (location == null) {
            functionResults[kAddToItineraryFunctionName] = {
              'status': 'not_found',
              'error': 'No location matching "$locationName" was found.',
            };
            break;
          }
          setState(() {
            _pendingAction = ChatbotPendingAction(
              type: ChatbotActionType.addToItinerary,
              targetId: location.id,
              targetLabel: location.name,
            );
            _pendingActionIsFromGemini = true;
          });
          await ChatMemoryService.instance.addMessage(
            role: ChatMessageRole.assistant,
            text: 'Add ${location.name} to your itinerary?',
            pageContext: widget.currentPageContext,
          );
          // A confirmation message was already appended above — return
          // null so the caller doesn't also append the (nonexistent)
          // text reply for this turn.
          return null;

        case kCreateItineraryFunctionName:
          // State-changing, same guardrail as addToItinerary above:
          // never created directly from a model tool call — surfaced as
          // a pending Yes/No confirmation, and only actually created via
          // `ChatbotActionExecutor` (→ `ItineraryService.createItinerary`)
          // once the user explicitly confirms.
          final requestedName =
              (call.args['itineraryName'] as String?)?.trim() ?? '';
          final name = requestedName.isEmpty ? 'My Itinerary' : requestedName;
          setState(() {
            _pendingAction = ChatbotPendingAction(
              type: ChatbotActionType.createItinerary,
              targetId: name,
              targetLabel: name,
            );
            _pendingActionIsFromGemini = true;
          });
          await ChatMemoryService.instance.addMessage(
            role: ChatMessageRole.assistant,
            text: 'Create a new itinerary called "$name"?',
            pageContext: widget.currentPageContext,
          );
          return null;
      }
    }

    if (functionResults.isEmpty) {
      return null;
    }

    // Hand the resolved data back to Gemini so it phrases the actual
    // reply (e.g. "Fort Santiago costs ₱75 for adults and ₱50 for
    // students.") from real app data, rather than this bridge code
    // templating the sentence itself.
    final followUp = await _geminiService.sendFunctionResults(functionResults);
    return _resolveGeminiResult(followUp);
  }

  static const Set<String> _affirmativeReplies = {
    'yes',
    'y',
    'yeah',
    'yep',
    'sure',
    'ok',
    'okay',
    'oo',
    'opo',
    'sige',
  };
  static const Set<String> _negativeReplies = {
    'no',
    'n',
    'nope',
    'cancel',
    'huwag',
    'hindi',
    'ayaw',
  };

  /// Calls [ChatbotActionExecutor] — the only place in this widget that
  /// does — strictly after the user has explicitly confirmed (spec
  /// Section 4). Never invoked automatically.
  Future<void> _confirmPendingAction() async {
    final action = _pendingAction;
    if (action == null) return;
    final wasFromGemini = _pendingActionIsFromGemini;
    setState(() {
      _isExecutingAction = true;
    });

    final result = await _executor.execute(action, context);

    if (!mounted) return;
    setState(() {
      _pendingAction = null;
      _pendingActionIsFromGemini = false;
      _isExecutingAction = false;
    });

    if (wasFromGemini) {
      // Completes the model's `addToItinerary` tool call with the real
      // outcome, so Gemini's own next reply (rather than a hardcoded
      // string here) can acknowledge it in its usual conversational
      // voice, and so the tool call doesn't dangle unresolved in the
      // session's history for the *next* turn.
      await _reportActionOutcomeToGemini(action, result);
      return;
    }

    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.assistant,
      text: result.message,
      pageContext: widget.currentPageContext,
    );
  }

  /// Shows a confirmation dialog (Proceed/Cancel, styled to match the
  /// app's existing delete-confirmation convention — see
  /// `itinerary_detail_screen.dart`'s `_deleteItinerary`) before wiping
  /// the chat session. Clearing chat history is a destructive,
  /// irreversible action (spec Section 6: history persists across app
  /// restarts), so it must never fire directly off a single tap without
  /// an explicit second confirmation — the same guardrail the app
  /// already applies to deleting an itinerary.
  Future<void> _confirmClearHistory() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Clear chat history?', style: TextStyle(color: colors.ink)),
        content: Text(
          'This will permanently delete this entire conversation with '
          'IntraBadi. This cannot be undone.',
          style: TextStyle(color: colors.ink.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Proceed',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );

    // Cancel (or dismissing the dialog any other way, e.g. tapping
    // outside it) must do nothing — only an explicit "Proceed" clears
    // anything.
    if (confirmed != true) return;

    setState(() {
      _pendingAction = null;
      _pendingActionIsFromGemini = false;
      _isWaitingForGeminiReply = false;
    });
    await ChatMemoryService.instance.clear();
  }

  Future<void> _cancelPendingAction() async {
    final wasFromGemini = _pendingActionIsFromGemini;
    final action = _pendingAction;
    setState(() {
      _pendingAction = null;
      _pendingActionIsFromGemini = false;
    });

    if (wasFromGemini && action != null) {
      await _reportActionOutcomeToGemini(
        action,
        const ChatbotActionExecutionResult(
          outcome: ChatbotActionOutcome.failed,
          message: 'The user declined this action.',
        ),
        userDeclined: true,
      );
      return;
    }

    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.assistant,
      text: 'Okay, cancelled. Anything else I can help with?',
      pageContext: widget.currentPageContext,
    );
  }

  /// Reports a Gemini-originated [ChatbotPendingAction]'s real execution
  /// outcome back to the model via [GeminiChatService.sendFunctionResults]
  /// and shows whatever it replies with — falling back to
  /// [result]/[ChatbotActionExecutionResult.message] directly if that
  /// follow-up call fails, so the user still gets a clear answer either
  /// way.
  Future<void> _reportActionOutcomeToGemini(
    ChatbotPendingAction action,
    ChatbotActionExecutionResult result, {
    bool userDeclined = false,
  }) async {
    // Report under whichever tool name actually raised this pending
    // action, so Gemini's own function-call/response pairing stays
    // consistent regardless of which state-changing action was
    // confirmed — hardcoding one name here would mislabel every other
    // action type's outcome when reported back.
    final functionName = switch (action.type) {
      ChatbotActionType.createItinerary => kCreateItineraryFunctionName,
      _ => kAddToItineraryFunctionName,
    };

    String? replyText;
    try {
      final followUp = await _geminiService.sendFunctionResults({
        functionName: {
          'status': userDeclined ? 'declined' : result.outcome.name,
          'locationName': action.targetLabel,
          'message': result.message,
        },
      });
      replyText = await _resolveGeminiResult(followUp);
    } catch (_) {
      replyText = null;
    }

    if (!mounted) return;
    await ChatMemoryService.instance.addMessage(
      role: ChatMessageRole.assistant,
      text: replyText ?? result.message,
      pageContext: widget.currentPageContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // ~80% of the screen height, matching the proportions other full
    // sheets in the app use (e.g. review/plan forms) rather than a short
    // partial sheet, since a chat thread needs vertical room to breathe.
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    // The keyboard (soft input) overlays the bottom of the screen when
    // the text field is focused; `viewInsets.bottom` is how tall it is.
    // Without accounting for it, this sheet's fixed height stays anchored
    // to the bottom of the *screen*, so the keyboard simply covers the
    // input bar and the tail of the conversation. Padding the sheet by
    // that same amount pushes it up above the keyboard instead.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      // Matches the keyboard's own show/hide easing/duration so the
      // sheet rides up and down in sync with it rather than snapping.
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SafeArea(
        top: false,
        // The keyboard already provides the bottom inset once it's up,
        // so avoid SafeArea double-padding the bottom in that case.
        bottom: keyboardInset == 0,
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: colors.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _ChatHeader(
                colors: colors,
                onClearHistory: _confirmClearHistory,
                avatarState: _avatarState,
              ),
              Divider(height: 1, color: colors.line),
              // Visible degraded-mode notice (see [_isDegradedToOffline]) —
              // the assistant must never quietly answer from the weaker
              // offline path while appearing to be fully working.
              if (_isDegradedToOffline) _OfflineModeNotice(colors: colors),
              Expanded(
                child: FutureBuilder<void>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final messages = ChatMemoryService.instance.messages;
                    if (messages.isEmpty && !_isWaitingForGeminiReply) {
                      return _MessageArea(colors: colors);
                    }
                    // +1 slot for the typing indicator, appended after the
                    // last real message while a Gemini reply is pending.
                    final itemCount =
                        messages.length + (_isWaitingForGeminiReply ? 1 : 0);
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index >= messages.length) {
                          return _TypingIndicator(colors: colors);
                        }
                        final message = messages[index];
                        final isLast = index == messages.length - 1;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MessageBubble(colors: colors, message: message),
                            if (isLast &&
                                _pendingAction != null &&
                                !_isWaitingForGeminiReply)
                              _ConfirmationControls(
                                colors: colors,
                                isBusy: _isExecutingAction,
                                onYes: _confirmPendingAction,
                                onNo: _cancelPendingAction,
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _ChatInputBar(
                colors: colors,
                controller: _inputController,
                onSend: _handleSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [ChatbotChatSheet] as a modal bottom sheet. Kept as a free
/// function (mirroring `showBudgetFilterSheet`) so the side handle widget
/// doesn't need to know sheet-construction details. [currentPageContext]
/// is forwarded to [ChatbotChatSheet] — see its doc comment.
Future<void> showChatbotChatSheet(
  BuildContext context, {
  String? currentPageContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        ChatbotChatSheet(currentPageContext: currentPageContext),
  );
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onClearHistory;

  /// Current expression for the header avatar, driven by the sheet's
  /// conversation state (see [_ChatbotAvatarState] triggers).
  final ChatbotAvatarState avatarState;

  const _ChatHeader({
    required this.colors,
    required this.onClearHistory,
    required this.avatarState,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
      child: Row(
        children: [
          // Character only — no CircleAvatar/backing shape behind it, per
          // the confirmed "transparent background, character only"
          // requirement. Sized to the footprint the old circle occupied so
          // the header layout is unchanged.
          ChatbotAvatar(state: avatarState, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IntraBadi',
                  style: TextStyle(
                    fontFamily: AppTheme.serifFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                Text(
                  'Your Intramuros guide',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClearHistory,
            icon: Icon(Icons.delete_outline_rounded, color: colors.muted),
            tooltip: 'Clear chat history',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: colors.muted),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

/// Explicit Yes/No confirmation control shown under the assistant's
/// action-confirmation message (spec Section 4: "Start navigation to
/// Fort Santiago? Yes/No"). Tapping Yes is the *only* path that leads to
/// [ChatbotActionExecutor.execute] being called for this pending action —
/// there is no automatic/implicit confirmation.
class _ConfirmationControls extends StatelessWidget {
  final AppColors colors;
  final bool isBusy;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ConfirmationControls({
    required this.colors,
    required this.isBusy,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
      child: Row(
        children: [
          _ConfirmationButton(
            colors: colors,
            label: 'Yes',
            isPrimary: true,
            isBusy: isBusy,
            onTap: isBusy ? null : onYes,
          ),
          const SizedBox(width: 8),
          _ConfirmationButton(
            colors: colors,
            label: 'No',
            isPrimary: false,
            isBusy: isBusy,
            onTap: isBusy ? null : onNo,
          ),
        ],
      ),
    );
  }
}

class _ConfirmationButton extends StatelessWidget {
  final AppColors colors;
  final String label;
  final bool isPrimary;
  final bool isBusy;
  final VoidCallback? onTap;

  const _ConfirmationButton({
    required this.colors,
    required this.label,
    required this.isPrimary,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? colors.forest : colors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isPrimary ? null : Border.all(color: colors.line),
          ),
          child: isBusy && isPrimary
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : colors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Empty-state placeholder shown before any turns exist in the session.
class _MessageArea extends StatelessWidget {
  final AppColors colors;

  const _MessageArea({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: colors.muted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me about places, gates, your itinerary, or how a '
              'feature works.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin banner shown when the last reply came from the offline engine
/// because the live model couldn't be reached (no/invalid `GEMINI_API_KEY`,
/// no network, or a model error).
///
/// Exists because the fallback used to be completely silent: chat would
/// answer from keyword matching and look identical to a full model reply,
/// so a misconfigured key was invisible during testing. Styled with the
/// app's existing warning treatment (same amber as the map-unavailable
/// notice in `osm_poi_map_screen.dart`) rather than a new visual language.
class _OfflineModeNotice extends StatelessWidget {
  final AppColors colors;

  const _OfflineModeNotice({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Icon(Icons.cloud_off_rounded, size: 15, color: Color(0xFFB25E00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline mode — answering from app data only. Check your '
              'connection or GEMINI_API_KEY for smarter replies.',
              style: TextStyle(fontSize: 11, color: Color(0xFF7A4200)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator shown as an assistant-side bubble while waiting on
/// a live [GeminiChatService] reply — same left-aligned, neutral-card
/// shape as a real assistant [_MessageBubble] so it reads as "IntraBadi
/// is typing" rather than a generic spinner disconnected from the
/// conversation.
class _TypingIndicator extends StatelessWidget {
  final AppColors colors;

  const _TypingIndicator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.line),
        ),
        child: SizedBox(
          width: 32,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (i) => _TypingDot(colors: colors, delay: i * 200),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single pulsing dot in the [_TypingIndicator], staggered by [delay]
/// milliseconds so the three dots animate in sequence rather than in
/// lockstep.
class _TypingDot extends StatefulWidget {
  final AppColors colors;
  final int delay;

  const _TypingDot({required this.colors, required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.3 + 0.7 * (0.5 - (_controller.value - 0.5).abs()) * 2;
        return Opacity(
          opacity: opacity.clamp(0.3, 1.0),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.colors.muted,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// A single chat bubble for one persisted turn. User turns align right
/// in the app's forest-green; assistant turns align left in a neutral
/// card surface — the same left/right + accent-color convention used for
/// other "yours vs. the app's" contrasts elsewhere in the UI (e.g. active
/// vs. inactive nav tabs).
class _MessageBubble extends StatelessWidget {
  final AppColors colors;
  final ChatMessageModel message;

  const _MessageBubble({required this.colors, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final textColor = isUser ? Colors.white : colors.ink;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? colors.forest : colors.card,
          borderRadius: BorderRadius.circular(18),
          border: isUser ? null : Border.all(color: colors.line),
        ),
        child: _MessageBubbleMarkdown(
          text: message.text,
          baseStyle: TextStyle(fontSize: 14, height: 1.4, color: textColor),
        ),
      ),
    );
  }
}

/// Renders a small subset of markdown that [GeminiChatService] /
/// [ChatbotConversationEngine] replies commonly contain — `**bold**`
/// spans, `*`/`-` bullet list lines, and `1.`/`2.` numbered list lines —
/// as real rich text instead of showing the raw markdown characters (or
/// an unbroken run-on paragraph with the list markers left inline)
/// verbatim. Deliberately scoped to just this bubble widget rather than
/// pulling in a full markdown package or a generic parser used
/// elsewhere, since chat replies only ever need this small subset.
class _MessageBubbleMarkdown extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const _MessageBubbleMarkdown({required this.text, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: baseStyle.fontSize! * 0.35),
          _buildLine(lines[i], baseStyle, boldStyle),
        ],
      ],
    );
  }

  Widget _buildLine(String line, TextStyle baseStyle, TextStyle boldStyle) {
    // A leading "* " or "- " (with optional indentation) marks a bullet
    // list item — render as a bullet glyph + the parsed remainder,
    // rather than leaving the literal marker character in the text.
    final bulletMatch = RegExp(r'^(\s*)[*-]\s+(.*)$').firstMatch(line);
    if (bulletMatch != null) {
      final content = bulletMatch.group(2) ?? '';
      return Padding(
        padding: const EdgeInsets.only(left: 4, top: 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('•  ', style: baseStyle),
            Expanded(child: _richLine(content, baseStyle, boldStyle)),
          ],
        ),
      );
    }

    // A leading "1. ", "2. ", etc. (with optional indentation) marks a
    // numbered list item — e.g. Gemini's replies to "what places have
    // discounted rates" commonly come back as a numbered list rather
    // than asterisk bullets. Rendered the same way bullets are (glyph/
    // number column + parsed remainder) instead of leaving it as an
    // unbroken paragraph with the literal "1." left inline, which is
    // what made such replies read as one run-on "essay" instead of a
    // real list.
    final numberedMatch = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
    if (numberedMatch != null) {
      final number = numberedMatch.group(2) ?? '';
      final content = numberedMatch.group(3) ?? '';
      return Padding(
        padding: const EdgeInsets.only(left: 4, top: 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$number.  ', style: boldStyle),
            Expanded(child: _richLine(content, baseStyle, boldStyle)),
          ],
        ),
      );
    }

    if (line.isEmpty) {
      return SizedBox(height: baseStyle.fontSize ?? 14);
    }

    return _richLine(line, baseStyle, boldStyle);
  }

  /// Renders one line of (possibly `**bold**`-containing) text. Uses a
  /// plain [Text] when there's no bold span to parse — so
  /// `find.text`/`find.textContaining` in widget tests, and any other
  /// code that expects a single [Text] widget with the full string in
  /// `data`, keep working for the common case of an unformatted reply —
  /// and falls back to [Text.rich] (still a [Text] widget under the
  /// hood, unlike a bare [RichText]) only when there's an actual `**`
  /// span to bold.
  Widget _richLine(String line, TextStyle baseStyle, TextStyle boldStyle) {
    if (!line.contains('**')) {
      return Text(line, style: baseStyle);
    }
    return Text.rich(_parseInline(line, baseStyle, boldStyle));
  }

  /// Splits a single line on `**bold**` markers and returns a [TextSpan]
  /// tree alternating between [baseStyle] and [boldStyle] runs. Any
  /// unmatched/stray `**` (e.g. an odd count) is left as literal text
  /// rather than dropped, so malformed markdown never eats characters.
  TextSpan _parseInline(String line, TextStyle baseStyle, TextStyle boldStyle) {
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: line.substring(cursor, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

/// Input bar (text field + send button), wired to append a user message
/// to [ChatMemoryService] and trigger the conversation engine on send.
class _ChatInputBar extends StatelessWidget {
  final AppColors colors;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.colors,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.line),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Message IntraBadi…',
                  hintStyle: TextStyle(color: colors.muted, fontSize: 14),
                ),
                style: TextStyle(color: colors.ink, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: colors.forest,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSend,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
