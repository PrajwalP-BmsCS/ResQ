import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:req_demo/pages/Flutter_STT/english_stt.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Navigation/navigation.dart';
import 'package:req_demo/pages/OCR/ocr_ml_kit.dart';
import 'package:req_demo/pages/Object_Detection/object_detection.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';
import 'package:req_demo/pages/home_page.dart';
import 'package:req_demo/pages/utils/mediaButton.dart';
import 'package:req_demo/pages/utils/onboard.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaButtonTestPage extends StatefulWidget {
  final String screen;
  const MediaButtonTestPage({Key? key, required this.screen}) : super(key: key);

  @override
  _MediaButtonTestPageState createState() => _MediaButtonTestPageState();
}

// Enum for mic status
enum MicStatus { idle, listening, processing, error }

class _MediaButtonTestPageState extends State<MediaButtonTestPage>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _mediaChannel =
      MethodChannel("com.class_echo/media_button");

  // Mic status tracking
  MicStatus _micStatus = MicStatus.idle;

  // Transcribed text
  String _transcribedText = '';
  String _finalTranscript = ''; // The complete transcript ready for API

  // Status message
  String _statusMessage = 'Press and hold the button to start listening...';

  final VoiceService voiceService = VoiceService();

  // Animation controller for mic pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    MediaButtonService().setHandlers(
    onSingleTap: (duration) => _onSingleTap(),
    onLongPress: (duration) => _onLongPress(),
  );

    // Show onboarding after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _checkAndShowOnboarding();
    });

    // Setup animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup voice service listener for transcription
    // _setupVoiceServiceListener();

    // Setup method call handler
    // _mediaChannel.setMethodCallHandler((call) async {
    //   switch (call.method) {
    //     case "button_down":
    //       print("Button pressed down");
    //       break;

    //     case "single_tap":
    //       print("Single tap: ${call.arguments}");
    //       final duration = call.arguments?['duration'] ?? 0;
    //       _onSingleTap();
    //       break;

    //     case "long_press":
    //       print("Long press: ${call.arguments}");
    //       final duration = call.arguments?['duration'] ?? 0;
    //       _onLongPress();
    //       break;

    //     default:
    //       print("Unknown method: ${call.method}");
    //   }
    // });
  }

  Future<void> _checkAndShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted && mounted) {
      // await showDialog(
      //   context: context,
      //   barrierDismissible: false,
      //   builder: (context) => OnboardingDialog(
      //     onPlayTTS: _playTTS,
      //     screen: "home",
      //     language: language_status ? "English" : "ಕನ್ನಡ (Kannada)",
      //     language_status: language_status,
      //     onToggleLanguage: _toggleLanguage, // ✅ callback from parent
      //   ),
      // );
    }
  }

  // TTS Function - Connect this to your TTSManager
  void _playTTS(String text) {
    // TODO: Connect to your TTS Manager
    // Example: TTSManager().speak(text);
    print("Playing TTS: $text");

    // For now, just print. Replace with actual TTS call:
    TTSManager().speak(text);
  }

  void _setupVoiceServiceListener() {
    // Listen to transcription updates from your VoiceService
    // Assuming VoiceService has a stream or callback for transcription
    // You'll need to adapt this based on your VoiceService implementation

    // Example implementation (adjust based on your VoiceService):
    /*
    voiceService.transcriptionStream?.listen((transcription) {
      setState(() {
        _transcribedText = transcription;
      });
    });
    */
  }

  void _onSingleTap() {
    print('onSingleTap() called — stopping mic if listening');

    if (_micStatus == MicStatus.listening) {
      // Stop listening
      _stopListening();
    } else {
      setState(() {
        _statusMessage = 'Mic is not active. Long press to start listening.';
      });
    }
  }

  void _onLongPress() {
    print('onLongPress() called — starting recording');
    _startListening();
  }

  String voiceText = "";
  void _startListening() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = 'Listening... Speak now';
      _transcribedText = '';
      _finalTranscript = '';
    });

    try {
      VoiceService().startListening(onFinalResult: (text) {
        print("Final recognized words: $text");
        voiceText = text;

        // Update the transcribed text
        if (voiceText.isNotEmpty) {
          setState(() {
            _transcribedText = voiceText;
          });
        }
      });
    } catch (e) {
      setState(() {
        _micStatus = MicStatus.error;
        _statusMessage = 'Error starting mic: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _micStatus = MicStatus.processing;
      _statusMessage = 'Processing...';
    });

    try {
      voiceService.stopListening();

      _finalTranscript = _transcribedText;

      await Future.delayed(const Duration(milliseconds: 500));
      print("Final Transcript_STOP: $_finalTranscript");
      if (_finalTranscript.isNotEmpty) {
        
        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = 'Tap and hold to start again.';
        });
      } else {
        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = 'No speech detected. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        _micStatus = MicStatus.error;
        _statusMessage = 'Error stopping mic: $e';
      });
    }
  }


  // Manual start button (for testing without headset)
  void _manualStart() {
    if (_micStatus == MicStatus.idle || _micStatus == MicStatus.error) {
      _startListening();
    } else if (_micStatus == MicStatus.listening) {
      _stopListening();
    }
  }

  // Get transcribed text for external use
  String getTranscribedText() {
    return _finalTranscript;
  }

  Color _getMicStatusColor() {
    switch (_micStatus) {
      case MicStatus.idle:
        return Colors.grey;
      case MicStatus.listening:
        return Colors.red;
      case MicStatus.processing:
        return Colors.orange;
      case MicStatus.error:
        return Colors.redAccent;
    }
  }

  IconData _getMicStatusIcon() {
    switch (_micStatus) {
      case MicStatus.idle:
        return Icons.mic_off;
      case MicStatus.listening:
        return Icons.mic;
      case MicStatus.processing:
        return Icons.sync;
      case MicStatus.error:
        return Icons.error_outline;
    }
  }

  String _getMicStatusText() {
    switch (_micStatus) {
      case MicStatus.idle:
        return 'IDLE';
      case MicStatus.listening:
        return 'LISTENING';
      case MicStatus.processing:
        return 'PROCESSING';
      case MicStatus.error:
        return 'ERROR';
    }
  }

  void resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
  }

  @override
  void dispose() {
    _mediaChannel.setMethodCallHandler(null);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("ResQ"),
        centerTitle: true,
        actions: [
          // Add replay onboarding button in settings
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () async {
              // Reset and show onboarding again
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_completed', false);
              // _checkAndShowOnboarding();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Tour
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        // await showDialog(
                        //   context: context,
                        //   barrierDismissible: false,
                        //   builder: (context) => OnboardingDialog(
                        //     onPlayTTS: _playTTS,
                        //     screen: "practice_area",
                        //     language: "English",
                        //   ),
                        // );
                      },
                      child: Text(
                        "Show Tutorial",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Mic Status Indicator
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _micStatus == MicStatus.listening
                              ? _pulseAnimation.value
                              : 1.0,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _getMicStatusColor(),
                              shape: BoxShape.circle,
                              boxShadow: _micStatus == MicStatus.listening
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _getMicStatusIcon(),
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getMicStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Transcription Display
              Container(
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.text_fields,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Transcription',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _transcribedText.isEmpty
                              ? 'Your transcribed text will appear here...'
                              : _transcribedText,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: _transcribedText.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    if (_transcribedText.isNotEmpty) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Words: ${_transcribedText.split(' ').where((w) => w.isNotEmpty).length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _transcribedText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Instructions
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'How to use',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Long press headset button to start listening\n'
                      '• Single tap headset button to stop and send\n'
                      '• Or use the button below for manual control',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 80), // Extra space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Space between buttons

          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.extended(
              heroTag: 'media_button_fab', // ✅ Add this line
              backgroundColor: _micStatus == MicStatus.listening
                  ? Colors.red
                  : Colors.deepPurple,
              icon: Icon(
                _micStatus == MicStatus.listening ? Icons.stop : Icons.mic,
                size: 24,
                color: Colors.white,
              ),
              label: Text(
                _micStatus == MicStatus.listening
                    ? 'Stop Listening'
                    : 'Start Listening',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: () async {
                // TODO: implement SOS
                _manualStart();
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Extension method to easily get the transcribed text from outside
extension TranscriptGetter on _MediaButtonTestPageState {
  String get currentTranscript => _finalTranscript;
}
