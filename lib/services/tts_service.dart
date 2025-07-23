import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  Future speak(String text) async {
    await _tts.speak(text);
  }
}
