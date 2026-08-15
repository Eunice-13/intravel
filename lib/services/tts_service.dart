import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _currentLanguage = 'en-US';

  /// Optional callback invoked when speech finishes naturally (not paused/stopped).
  VoidCallback? onComplete;

  bool get isSpeaking => _isSpeaking;
  String get currentLanguage => _currentLanguage;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await initialize();
    if (_isSpeaking) {
      await stop();
    }
    _isSpeaking = true;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    _isSpeaking = false;
    await _flutterTts.pause();
  }

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _flutterTts.setLanguage(language);
  }

  Future<void> speakDirections(String direction) async {
    await speak(direction);
  }

  Future<void> speakLocationInfo(String name, String description) async {
    final text = '$name. $description';
    await speak(text);
  }

  void dispose() {
    _flutterTts.stop();
  }
}
