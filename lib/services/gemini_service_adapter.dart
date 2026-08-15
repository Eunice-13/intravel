import 'gemini_chat_service.dart';
import 'native_gemini_chat_service.dart';

/// Adapts [NativeGeminiChatService] (the restored native-Gemini-SDK
/// fallback path) to the exact public shape `ChatbotChatSheet` already
/// depends on — [GeminiChatService]'s `sendMessage`/
/// `sendFunctionResults` methods and its [GeminiChatResult]/
/// [GeminiFunctionCallRequest]/[GeminiChatException] types (all
/// Backboard-side names, despite this delegating to the native-Gemini
/// path).
///
/// **Why this exists:** `ChatbotChatSheet` was written once, against
/// the Backboard-backed [GeminiChatService]'s concrete type — its
/// `_geminiService` field, `_resolveGeminiResult`/
/// `_handleGeminiFunctionCalls`/`_reportActionOutcomeToGemini` methods,
/// and the tool-name switch inside them, are all written directly
/// against [GeminiChatResult]/[GeminiFunctionCallRequest]/
/// [GeminiChatException]. Duplicating that ~150 lines of function-call
/// bridging logic a second time for the native-Gemini path (with its
/// distinctly-named `NativeGeminiChatResult`/etc. types) would double
/// the code that has to stay in sync for both backends' tool-calling
/// behavior to actually match — exactly the kind of drift this restored
/// fallback needs to avoid, since it exists to be a reliable safety net,
/// not a second, half-matching implementation.
///
/// This class instead **extends [GeminiChatService]** (mirroring the
/// existing test suite's own technique — see e.g.
/// `_FakeGeminiChatService extends GeminiChatService` in
/// `chatbot_chat_sheet_gemini_wiring_test.dart`) and overrides just its
/// two network-calling methods to delegate to a real
/// [NativeGeminiChatService] instance, translating its
/// `NativeGeminiChatResult`/`NativeGeminiFunctionCallRequest`/
/// `NativeGeminiChatException` return/throw values into the equivalent
/// Backboard-side types `ChatbotChatSheet` already knows how to handle.
/// Every other method/field on [GeminiChatService] (there are none this
/// class needs) is inherited unchanged.
///
/// The tool/function *names* (`checkPrice`, `addToItinerary`,
/// `createItinerary`) are identical string literals in both
/// `gemini_chat_service.dart`'s `kCheckPriceFunctionName` etc. and
/// `native_gemini_chat_service.dart`'s `kNativeCheckPriceFunctionName`
/// etc. — only the Dart constant names differ, not their values — so
/// `ChatbotChatSheet`'s `switch (call.name)` continues to match
/// correctly regardless of which backend actually produced the call.
class GeminiServiceAdapter extends GeminiChatService {
  GeminiServiceAdapter({NativeGeminiChatService? nativeService})
    : _native = nativeService ?? NativeGeminiChatService();

  final NativeGeminiChatService _native;

  @override
  Future<GeminiChatResult> sendMessage(String message) async {
    try {
      return _toGeminiChatResult(await _native.sendMessage(message));
    } on NativeGeminiChatException catch (e) {
      throw GeminiChatException(e.message, cause: e.cause);
    }
  }

  @override
  Future<GeminiChatResult> sendFunctionResults(
    Map<String, Map<String, Object?>> results,
  ) async {
    try {
      return _toGeminiChatResult(await _native.sendFunctionResults(results));
    } on NativeGeminiChatException catch (e) {
      throw GeminiChatException(e.message, cause: e.cause);
    }
  }

  GeminiChatResult _toGeminiChatResult(NativeGeminiChatResult native) {
    if (!native.hasFunctionCalls) {
      return GeminiChatResult(text: native.text);
    }
    return GeminiChatResult(
      functionCalls: [
        for (final call in native.functionCalls)
          GeminiFunctionCallRequest(name: call.name, args: call.args),
      ],
    );
  }
}
