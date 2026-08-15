import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// Resolves the `CHAT_PROVIDER` config flag that selects which chat
/// backend `ChatbotChatSheet` talks to — `"backboard"` (default) or
/// `"gemini"` (the restored native-Gemini-SDK fallback, see
/// `native_gemini_chat_service.dart` and `gemini_service_adapter.dart`).
///
/// This exists purely as a safety net against a Backboard.io outage
/// before submission — Backboard is the primary, confirmed-working
/// end-to-end backend and stays the default. Switching to `"gemini"` is
/// a config-only change (`--dart-define=CHAT_PROVIDER=gemini` or the
/// same key in `env.json`), never a code change.
///
/// **Resolved once, at process/app startup — not re-checked mid-session.**
/// [ChatbotChatSheet] reads this exactly once per widget construction
/// (i.e. once per chat-sheet open), which in practice means once per
/// app run for all intents and purposes, since nothing in this app
/// mutates `env.json` or restarts the process on its own. This is
/// deliberate: Backboard's server-side thread history and Gemini's
/// local-transcript-replay history are not compatible with each other,
/// so switching backends mid-conversation would silently drop context
/// either way. A provider change only ever takes effect on a fresh
/// app restart, matching how the underlying API keys already work.
///
/// Resolution order, mirroring [GeminiApiKeyLoader]/
/// [NativeGeminiApiKeyLoader]'s existing convention:
/// 1. A compile-time `--dart-define=CHAT_PROVIDER=...` value, when
///    provided and non-empty.
/// 2. Otherwise, the `CHAT_PROVIDER` entry in the bundled, gitignored
///    `env.json` asset.
/// 3. Otherwise, `"backboard"`.
enum ChatProvider {
  backboard,
  gemini;

  static ChatProvider fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'gemini':
        return ChatProvider.gemini;
      case 'backboard':
      case '':
        return ChatProvider.backboard;
      default:
        debugPrint(
          '[ChatProvider] Unrecognized CHAT_PROVIDER value "$raw" — '
          'defaulting to backboard.',
        );
        return ChatProvider.backboard;
    }
  }
}

/// Loads the `CHAT_PROVIDER` flag, same two-source resolution order and
/// asset-fallback mechanics as [GeminiApiKeyLoader]/
/// [NativeGeminiApiKeyLoader]/[OpenRouteServiceRouting]'s key-loading
/// convention, so this fits the app's one existing pattern for runtime
/// config rather than introducing a new one.
class ChatProviderConfig {
  ChatProviderConfig({
    this.compileTimeValue = const String.fromEnvironment('CHAT_PROVIDER'),
  }) {
    debugPrint(
      compileTimeValue.isEmpty
          ? '[ChatProviderConfig] No CHAT_PROVIDER compiled in via '
                '--dart-define — will attempt to load it from the bundled '
                'env.json asset on first use instead (defaulting to '
                'backboard if that is also absent).'
          : '[ChatProviderConfig] CHAT_PROVIDER compiled in via '
                '--dart-define: "$compileTimeValue".',
    );
  }

  final String compileTimeValue;

  /// Resolves the active [ChatProvider]: the compile-time define if one
  /// was provided, otherwise the `CHAT_PROVIDER` entry from the bundled
  /// `env.json` asset, defaulting to [ChatProvider.backboard] if neither
  /// has a usable value. Synchronous once [compileTimeValue] is set (the
  /// common case for a real build/run using the VS Code launch configs
  /// or an explicit `--dart-define`); only falls through to the async
  /// asset read when no compile-time value was supplied.
  Future<ChatProvider> resolve() async {
    if (compileTimeValue.isNotEmpty) {
      return ChatProvider.fromString(compileTimeValue);
    }
    final envValue = await _loadFromEnvJson();
    return ChatProvider.fromString(envValue);
  }

  Future<String?> _loadFromEnvJson() async {
    try {
      // Bounded, rather than an unbounded await: in a handful of
      // observed cases (multiple widget tests constructing
      // `ChatbotChatSheet` back-to-back in the same test process without
      // each one evicting `rootBundle`'s per-key asset cache — the
      // pattern other Gemini/Backboard-key-loading tests in this repo
      // explicitly do via `rootBundle.evict('env.json')` in `setUp`,
      // which this call site can't control since it's triggered
      // indirectly from inside `ChatbotChatSheet`) this future can sit
      // unresolved indefinitely rather than either succeeding or
      // throwing. A provider-resolution stall must never be able to
      // freeze the whole chat sheet's `_initialize()` future — falling
      // through to the `"backboard"` default after a short timeout is
      // strictly safer than hanging.
      final raw = await rootBundle
          .loadString('env.json')
          .timeout(const Duration(seconds: 2));
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded['CHAT_PROVIDER'] as String?;
    } catch (e) {
      debugPrint(
        '[ChatProviderConfig] Could not load the env.json asset fallback '
        '(missing file, invalid JSON, timed out, or not declared as a '
        'bundled asset in pubspec.yaml): $e — defaulting to backboard.',
      );
      return null;
    }
  }
}
