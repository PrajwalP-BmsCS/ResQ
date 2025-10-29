import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _finalTranscript = "";

  Future<void> startListening(
      {String? pref_lang, required Function(String) onFinalResult}) async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("STATUS: $status"),
      onError: (error) => {
        print("ERROR: $error")
      },
    );

    print("PREFFERE $pref_lang");

    if (pref_lang == "ಕನ್ನಡ (Kannada)") {
      pref_lang = "kn-IN";
    } else {
      pref_lang = "en";
    }

    if (available) {
      _speech.listen(
        localeId: pref_lang,
        onResult: (result) {
          print("TRANSCRIPT: ${result.recognizedWords}");
          _finalTranscript = result.recognizedWords;
          if (result.finalResult) {
            onFinalResult(_finalTranscript);
          }
        },
      );
    } else {
      print("Speech recognition not available");
    }
  }

  void stopListening() {
    _speech.stop();
  }
}
