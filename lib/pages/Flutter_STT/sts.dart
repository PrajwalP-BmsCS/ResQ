import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _finalTranscript = "";

  Future<void> startListening({required Function(String) onFinalResult}) async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("STATUS: $status"),
      onError: (error) => print("ERROR: $error"),
    );

    if (available) {
      _speech.listen(
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