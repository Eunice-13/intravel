import 'package:flutter/material.dart';
import '../models/itinerary_model.dart';
import '../widgets/nav_flow_launcher.dart';
import 'accessibility_settings_service.dart';
import 'chatbot_conversation_engine.dart';
import 'chatbot_intent_service.dart';
import 'chatbot_knowledge_service.dart';
import 'gate_selection_service.dart';
import 'itinerary_service.dart';

/// What happened when a confirmed [ChatbotPendingAction] was executed —
/// used by the chat UI to phrase the follow-up message (spec Section 4).
enum ChatbotActionOutcome {
  success,

  /// The action type is recognized and confirmed, but there's no
  /// existing public API to actually perform it against (see
  /// [ChatbotActionExecutor]'s doc comment on budget filtering) — the
  /// assistant should say so honestly rather than pretending it worked.
  unsupported,

  /// Something about the confirmed target no longer resolves (e.g. a
  /// gate id that isn't in the catalogue) — shouldn't normally happen
  /// since the engine already resolved it once before asking to
  /// confirm, but guarded against regardless.
  failed,
}

class ChatbotActionExecutionResult {
  final ChatbotActionOutcome outcome;
  final String message;

  const ChatbotActionExecutionResult({
    required this.outcome,
    required this.message,
  });
}

/// Executes a [ChatbotPendingAction] once — and only once — the user has
/// explicitly confirmed it in chat with "Yes" (chatbot spec Section 4:
/// "the assistant must confirm with the user first in the chat before
/// executing any state-changing action"). The chat UI is responsible for
/// gating the call to [execute] behind that confirmation; this class
/// itself does not re-check confirmation state, it just performs the
/// already-confirmed action.
///
/// Every action here goes through the app's *existing* public
/// service/navigation entry points — [ItineraryService], the shared
/// [NavFlowLauncher] flow (same "Navigate" button every other screen
/// uses, including its view-mode picker), [AccessibilitySettingsService],
/// and [GateSelectionService] — rather than any new/shortcut
/// implementation, per spec Section 4's requirement that e.g. starting
/// navigation from chat "trigger the same navigation flow described in
/// the base spec (view-mode choice, etc.), not a shortcut that skips
/// it."
///
/// **Known gap — budget filter is not wired to a real action.** The
/// Plans page's budget filter (`PlanBudgetFilter`) is held as private
/// `State` inside `PlansScreen` (`_budgetFilter`), not in any shared
/// service with a public setter the chatbot (which lives outside that
/// screen's widget tree, at the app root) can call. Making "apply a
/// filter" actually take effect would require adding a public,
/// settable, shared home for that state — which is a change to
/// `plans_screen.dart`/a new service, and this step's guardrail is to
/// call *existing* public methods only, not refactor/introduce new
/// service-level state ownership. So [ChatbotActionType.applyFilter]
/// intentionally returns [ChatbotActionOutcome.unsupported] with an
/// honest message instead of silently no-op'ing or faking success —
/// wiring it for real is flagged as follow-up work, not implemented here.
class ChatbotActionExecutor {
  ChatbotActionExecutor({
    ChatbotKnowledgeService? knowledgeService,
    ItineraryService? itineraryService,
    AccessibilitySettingsService? accessibilitySettingsService,
    GateSelectionService? gateSelectionService,
  }) : _knowledge = knowledgeService ?? ChatbotKnowledgeService(),
       _itineraryService = itineraryService ?? ItineraryService.instance,
       _accessibilityService =
           accessibilitySettingsService ??
           AccessibilitySettingsService.instance,
       _gateSelectionService =
           gateSelectionService ?? GateSelectionService.instance;

  final ChatbotKnowledgeService _knowledge;
  final ItineraryService _itineraryService;
  final AccessibilitySettingsService _accessibilityService;
  final GateSelectionService _gateSelectionService;

  /// [context] is only required for [ChatbotActionType.startNavigation],
  /// which must push through [NavFlowLauncher.start] — the same shared
  /// entry point every "Navigate" button in the app uses — and is
  /// otherwise unused. Callers should check `context.mounted` before
  /// calling this after any prior `await` (e.g. a confirmation dialog),
  /// same as any other Navigator use.
  Future<ChatbotActionExecutionResult> execute(
    ChatbotPendingAction action,
    BuildContext context,
  ) async {
    switch (action.type) {
      case ChatbotActionType.addToItinerary:
        return _executeAddToItinerary(action);
      case ChatbotActionType.createItinerary:
        return _executeCreateItinerary(action);
      case ChatbotActionType.startNavigation:
        return _executeStartNavigation(action, context);
      case ChatbotActionType.changeSetting:
        return _executeChangeSetting(action, context);
      case ChatbotActionType.applyFilter:
        return const ChatbotActionExecutionResult(
          outcome: ChatbotActionOutcome.unsupported,
          message:
              "I can't apply that filter myself yet — head to the Plans "
              "page and use the budget filter there for now.",
        );
    }
  }

  /// Executes a direct "create an itinerary" request via the same
  /// public [ItineraryService.createItinerary] entry point
  /// [_executeAddToItinerary] uses for its auto-create fallback — this
  /// is just the explicit, user-requested version of that same call,
  /// always creating a new itinerary regardless of how many already
  /// exist (the user asked for a *new* one, so no disambiguation
  /// against existing itineraries applies here).
  Future<ChatbotActionExecutionResult> _executeCreateItinerary(
    ChatbotPendingAction action,
  ) async {
    final name = action.targetLabel.trim().isEmpty
        ? 'My Itinerary'
        : action.targetLabel.trim();

    final itinerary = await _itineraryService.createItinerary(
      name: name,
      locationIds: const [],
    );

    return ChatbotActionExecutionResult(
      outcome: ChatbotActionOutcome.success,
      message: 'Created a new itinerary called "${itinerary.name}".',
    );
  }

  Future<ChatbotActionExecutionResult> _executeAddToItinerary(
    ChatbotPendingAction action,
  ) async {
    final location = _knowledge.findLocationById(action.targetId);
    if (location == null) {
      return ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.failed,
        message:
            "Something went wrong finding \"${action.targetLabel}\" — "
            "could you try again?",
      );
    }

    // No chat-level concept of "which itinerary" — use the existing
    // single itinerary if there's exactly one, create one via the
    // existing `createItinerary` entry point if the user has none yet
    // (mirrors what a first-time user does from the Plans page), or ask
    // for disambiguation if there's more than one rather than guessing
    // which itinerary the user meant.
    final itineraries = _itineraryService.itineraries;
    ItineraryModel targetItinerary;
    if (itineraries.isEmpty) {
      targetItinerary = await _itineraryService.createItinerary(
        name: 'My Itinerary',
        locationIds: const [],
      );
    } else if (itineraries.length == 1) {
      targetItinerary = itineraries.first;
    } else {
      return ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.unsupported,
        message:
            "You have a few itineraries saved — head to the Plans page "
            "to add ${location.name} to the one you want.",
      );
    }

    await _itineraryService.addLocation(targetItinerary.id, location.id);

    return ChatbotActionExecutionResult(
      outcome: ChatbotActionOutcome.success,
      message: 'Added ${location.name} to "${targetItinerary.name}".',
    );
  }

  Future<ChatbotActionExecutionResult> _executeStartNavigation(
    ChatbotPendingAction action,
    BuildContext context,
  ) async {
    final location = _knowledge.findLocationById(action.targetId);
    if (location == null) {
      return ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.failed,
        message:
            "Something went wrong finding \"${action.targetLabel}\" — "
            "could you try again?",
      );
    }

    if (!context.mounted) {
      return const ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.failed,
        message: 'Could not start navigation — please try again.',
      );
    }

    // Same shared entry point every "Navigate"/"Navigate Now" button in
    // the app uses (Home, Location Details) — shows the view-mode
    // picker exactly as it would from those screens, per spec Section 4.
    await NavFlowLauncher.start(context, location: location);

    return ChatbotActionExecutionResult(
      outcome: ChatbotActionOutcome.success,
      message: 'Starting navigation to ${location.name}.',
    );
  }

  Future<ChatbotActionExecutionResult> _executeChangeSetting(
    ChatbotPendingAction action,
    BuildContext context,
  ) async {
    if (action.targetId.startsWith('starting_gate:')) {
      final gateId = action.targetId.substring('starting_gate:'.length);
      final gate = _knowledge.findGateById(gateId);
      if (gate == null) {
        return ChatbotActionExecutionResult(
          outcome: ChatbotActionOutcome.failed,
          message:
              "Something went wrong finding \"${action.targetLabel}\" — "
              "could you try again?",
        );
      }
      await _gateSelectionService.selectGate(gate.id);
      return ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.success,
        message: 'Your starting gate is now ${gate.name}.',
      );
    }

    if (action.targetId.startsWith('toggle:')) {
      final parts = action.targetId.split(':');
      final label = parts.length > 1 ? parts[1] : action.targetLabel;
      final verb = parts.length > 2 ? parts[2] : 'on';

      // Only "accessibility" maps to a real existing toggle
      // (`AccessibilitySettingsService`, spec addendum Section 4.2).
      // Other free-text settings mentions (e.g. "dark mode", which is
      // `ThemeController` — a different existing service) aren't wired
      // here since this step's guardrail is calling existing methods
      // for the four confirmed action types as scoped, and dark mode
      // isn't one of chat's listed example settings in spec Section 4 —
      // flagged as a natural follow-up rather than guessed at.
      if (label.toLowerCase().contains('accessibility')) {
        final turnOn = verb.toLowerCase() != 'off';
        _accessibilityService.toggle(turnOn);
        return ChatbotActionExecutionResult(
          outcome: ChatbotActionOutcome.success,
          message:
              'Accessibility Support is now turned ${turnOn ? 'on' : 'off'}.',
        );
      }

      return ChatbotActionExecutionResult(
        outcome: ChatbotActionOutcome.unsupported,
        message:
            "I can't change \"$label\" myself yet — you can find it in "
            "Settings.",
      );
    }

    return const ChatbotActionExecutionResult(
      outcome: ChatbotActionOutcome.unsupported,
      message: "I can't change that setting myself yet.",
    );
  }
}
