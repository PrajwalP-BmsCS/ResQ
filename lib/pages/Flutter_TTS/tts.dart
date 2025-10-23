import 'dart:ui';

import 'package:flutter_tts/flutter_tts.dart';

/// Singleton class to manage Text-to-Speech functionality
/// Configure all TTS settings in one place
class TTSManager {
  // Singleton instance
  static final TTSManager _instance = TTSManager._internal();
  factory TTSManager() => _instance;
  TTSManager._internal();

  // FlutterTts instance
  final FlutterTts _flutterTts = FlutterTts();
  
  // Configuration variables - Change these as needed
  static const String _language = "en-US"; // Language code
  static const double _speechRate = 0.5; // 0.0 (slow) to 1.0 (fast)
  static const double _volume = 1.0; // 0.0 to 1.0
  static const double _pitch = 1.0; // 0.5 to 2.0 (1.0 is normal)
  
  // Initialization flag
  bool _isInitialized = false;

  /// Initialize TTS with default settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set language
      await _flutterTts.setLanguage(_language);
      
      // Set speech rate
      await _flutterTts.setSpeechRate(_speechRate);
      
      // Set volume
      await _flutterTts.setVolume(_volume);
      
      // Set pitch
      await _flutterTts.setPitch(_pitch);

      // Set iOS specific settings (if needed)
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      // Set up handlers (optional)
      _flutterTts.setStartHandler(() {
        print("TTS: Speech started");
      });

      _flutterTts.setCompletionHandler(() {
        print("TTS: Speech completed");
      });

      _flutterTts.setErrorHandler((msg) {
        print("TTS Error: $msg");
      });

      _isInitialized = true;
      print("TTS: Initialized successfully");
    } catch (e) {
      print("TTS Initialization Error: $e");
    }
  }

  /// Main method to speak text
  /// [message] - The text to be spoken
  /// Returns Future<void>
// In TTSManager class
Future<void> speak(String message, {VoidCallback? onComplete}) async {
  if (!_isInitialized) {
    await initialize();
  }

  if (message.isEmpty) {
    return;
  }

  try {
    await _flutterTts.speak(message);
    await _flutterTts.awaitSpeakCompletion(true);
    onComplete?.call(); // Call completion callback
  } catch (e) {
    print("TTS Speak Error: $e");
  }
}

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print("TTS Stop Error: $e");
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      print("TTS Pause Error: $e");
    }
  }

  /// Check if TTS is currently speaking
  Future<bool> isSpeaking() async {
    try {
      return await _flutterTts.awaitSpeakCompletion(false);
    } catch (e) {
      print("TTS isSpeaking Error: $e");
      return false;
    }
  }

  /// Get available languages
  Future<List<dynamic>> getLanguages() async {
    try {
      return await _flutterTts.getLanguages;
    } catch (e) {
      print("TTS getLanguages Error: $e");
      return [];
    }
  }

  /// Get available voices for current language
  Future<List<dynamic>> getVoices() async {
    try {
      return await _flutterTts.getVoices;
    } catch (e) {
      print("TTS getVoices Error: $e");
      return [];
    }
  }

  /// Change speech rate dynamically
  Future<void> setSpeechRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      print("TTS setSpeechRate Error: $e");
    }
  }

  /// Change volume dynamically
  Future<void> setVolume(double volume) async {
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      print("TTS setVolume Error: $e");
    }
  }

  /// Change pitch dynamically
  Future<void> setPitch(double pitch) async {
    try {
      await _flutterTts.setPitch(pitch);
    } catch (e) {
      print("TTS setPitch Error: $e");
    }
  }

  /// Change language dynamically
  Future<void> setLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      print("TTS setLanguage Error: $e");
    }
  }
}


