import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads a result aloud using the phone's own text-to-speech engine.
/// Nothing is sent to any server.
class Speaker {
  Speaker._() {
    _tts.setStartHandler(() => speaking.value = true);
    _tts.setCompletionHandler(() => speaking.value = false);
    _tts.setCancelHandler(() => speaking.value = false);
    _tts.setErrorHandler((_) => speaking.value = false);
  }

  static final Speaker instance = Speaker._();

  final FlutterTts _tts = FlutterTts();

  /// True while audio is playing, so the button can switch to "Stop".
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text, {String lang = 'en-US'}) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.setLanguage(lang);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('tts failed: $e');
      speaking.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }
}
