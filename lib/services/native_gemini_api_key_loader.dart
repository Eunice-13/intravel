import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// Resolves the Gemini API key for the IntraBadi assistant's **native
/// Gemini fallback path** (see `native_gemini_chat_service.dart`'s doc
/// comment) — restored from the pre-Backboard-migration implementation
/// (git history, commit `005a2cf`) as a deliberate safety net alongside
/// the primary Backboard-backed `gemini_chat_service.dart`, not a
/// replacement for it. Named `Native*` (rather than reusing
/// `GeminiApiKeyLoader`) purely to avoid a top-level symbol collision —
/// both classes live in the same `lib/services` package.
///
/// Mirrors [OpenRouteServiceRouting]'s exact key-loading convention (see
/// `routing_service.dart`) so this app has one consistent pattern for
/// every keyed API rather than a bespoke approach per service.
///
/// Resolution order:
/// 1. A compile-time `--dart-define=GEMINI_API_KEY=...` value, when
///    provided and non-empty.
/// 2. Otherwise, the `GEMINI_API_KEY` entry in the bundled, gitignored
///    `env.json` asset, read once at runtime and cached.
///
/// The key value itself is never logged — only whether one was found and
/// its length, for diagnosing "why isn't this configured" without ever
/// printing the secret. `env.json` is never committed (see .gitignore);
/// only its path is declared as a bundled asset in pubspec.yaml so this
/// runtime fallback works no matter how the app is launched (IDE Run
/// button, hot restart, a plain `flutter run` with no flags).
///
/// This class only loads the key — it does not itself call the Gemini
/// API or construct a `GenerativeModel`; that's for the chat-logic layer
/// that consumes the resolved key.
class NativeGeminiApiKeyLoader {
  NativeGeminiApiKeyLoader({
    this._compileTimeApiKey = const String.fromEnvironment(
      'GEMINI_API_KEY',
    ),
  }) {
    debugPrint(
      _compileTimeApiKey.isEmpty
          ? '[NativeGeminiApiKeyLoader] No GEMINI_API_KEY compiled in via '
                '--dart-define — will attempt to load it from the bundled '
                'env.json asset on first use instead.'
          : '[NativeGeminiApiKeyLoader] GEMINI_API_KEY compiled in via '
                '--dart-define (${_compileTimeApiKey.length} chars). Key '
                'value itself is never logged.',
    );
  }

  final String _compileTimeApiKey;

  /// Resolved lazily on first use and cached, same as
  /// [OpenRouteServiceRouting._resolveApiKey] — the asset is only
  /// read/parsed once per app run, not on every call.
  String? _resolvedApiKey;
  Future<String>? _resolveKeyFuture;

  /// Resolves the API key to use: the compile-time define if one was
  /// provided, otherwise the value loaded from the bundled `env.json`
  /// asset. Returns an empty string if neither source has a usable key
  /// — callers should treat that as "not configured" and fail
  /// gracefully rather than sending an empty key to the API.
  Future<String> resolveApiKey() async {
    if (_compileTimeApiKey.isNotEmpty) return _compileTimeApiKey;
    if (_resolvedApiKey != null) return _resolvedApiKey!;
    // Multiple concurrent callers during startup should share a single
    // in-flight asset load rather than each parsing env.json separately.
    _resolveKeyFuture ??= _loadKeyFromAssetFallback();
    _resolvedApiKey = await _resolveKeyFuture;
    return _resolvedApiKey!;
  }

  /// Whether a usable key is available from either source, without
  /// triggering the asset load itself — useful for a quick compile-time
  /// check before deciding whether to attempt the (async) full
  /// resolution at all.
  bool get hasCompileTimeKey => _compileTimeApiKey.isNotEmpty;

  /// Reads and parses the bundled `env.json` asset for `GEMINI_API_KEY`,
  /// used only when no compile-time define was supplied.
  Future<String> _loadKeyFromAssetFallback() async {
    try {
      final raw = await rootBundle.loadString('env.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final key = decoded['GEMINI_API_KEY'] as String? ?? '';
      debugPrint(
        key.isEmpty
            ? '[NativeGeminiApiKeyLoader] env.json asset loaded but '
                  'GEMINI_API_KEY is empty/missing in it.'
            : '[NativeGeminiApiKeyLoader] GEMINI_API_KEY loaded from the '
                  'bundled env.json asset (${key.length} chars). Key value '
                  'itself is never logged.',
      );
      return key;
    } catch (e) {
      debugPrint(
        '[NativeGeminiApiKeyLoader] Could not load the env.json asset '
        'fallback (missing file, invalid JSON, or not declared as a '
        'bundled asset in pubspec.yaml): $e',
      );
      return '';
    }
  }
}
