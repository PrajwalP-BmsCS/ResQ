import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class KannadaSpeechToTextPage extends StatefulWidget {
  const KannadaSpeechToTextPage({Key? key}) : super(key: key);

  @override
  State<KannadaSpeechToTextPage> createState() => _KannadaSpeechToTextPageState();
}

class _KannadaSpeechToTextPageState extends State<KannadaSpeechToTextPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  String _currentLocale = 'kn-IN'; // Kannada locale
  double _confidence = 0.0;
  List<stt.LocaleName> _availableLocales = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  /// Step 1: Initialize Speech Recognition and get available languages
  Future<void> _initializeSpeech() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status.isDenied) {
        _showSnackBar('Microphone permission is required for speech recognition');
        return;
      }

      // Initialize speech recognition
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech Status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          print('Speech Error: $error');
          setState(() {
            _isListening = false;
          });
          _showSnackBar('Error: ${error.errorMsg}');
        },
      );

      if (available) {
        // Get available locales
        _availableLocales = await _speech.locales();
        
        print('✅ Speech recognition initialized');
        print('Available locales: ${_availableLocales.length}');
        
        // Check if Kannada is available
        bool kannadaAvailable = _availableLocales.any(
          (locale) => locale.localeId.startsWith('kn')
        );
        
        if (kannadaAvailable) {
          print('✅ Kannada language is available');
        } else {
          print('⚠️ Kannada language not found. Available locales:');
          for (var locale in _availableLocales) {
            print('  - ${locale.localeId}: ${locale.name}');
          }
          _showSnackBar('Kannada may not be available. Check Gboard settings.');
        }
      } else {
        _showSnackBar('Speech recognition not available on this device');
      }
    } catch (e) {
      print('Error initializing speech: $e');
      _showSnackBar('Failed to initialize speech recognition');
    }
  }

  /// Step 2: Start listening for Kannada speech
  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      setState(() {
        _recognizedText = '';
        _confidence = 0.0;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            _confidence = result.confidence;
          });
          print('Recognized: ${result.recognizedWords}');
          print('Confidence: ${result.confidence}');
        },
        localeId: _currentLocale, // Use Kannada locale
        // listenMode: stt.ListenMode.confirmation, // Wait for user to finish
        // cancelOnError: true,
        // partialResults: true, // Show results as user speaks
        onSoundLevelChange: (level) {
          // Optional: Visual feedback for sound level
          // print('Sound level: $level');
        },
      );

      setState(() {
        _isListening = true;
      });

      print('🎤 Started listening in Kannada');
    } catch (e) {
      print('Error starting listening: $e');
      _showSnackBar('Failed to start listening');
      setState(() {
        _isListening = false;
      });
    }
  }

  /// Step 3: Stop listening
  Future<void> _stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      print('🛑 Stopped listening');
    } catch (e) {
      print('Error stopping listening: $e');
    }
  }

  /// Toggle listening state
  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  /// Clear recognized text
  void _clearText() {
    setState(() {
      _recognizedText = '';
      _confidence = 0.0;
    });
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Change language
  void _changeLanguage(String localeId) {
    setState(() {
      _currentLocale = localeId;
    });
    _showSnackBar('Language changed to: $localeId');
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kannada Speech-to-Text'),
        actions: [
          // Language selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: _changeLanguage,
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  value: 'kn-IN',
                  child: Text('ಕನ್ನಡ (Kannada)'),
                ),
                const PopupMenuItem(
                  value: 'en-IN',
                  child: Text('English (India)'),
                ),
                const PopupMenuItem(
                  value: 'hi-IN',
                  child: Text('हिन्दी (Hindi)'),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Card
              Card(
                color: _isListening ? Colors.red[50] : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_off,
                        size: 48,
                        color: _isListening ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? 'ಕೇಳುತ್ತಿದೆ... (Listening...)' : 'ಮೈಕ್ ಆಫ್ (Mic Off)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.red : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Language: ${_currentLocale == 'kn-IN' ? 'ಕನ್ನಡ' : _currentLocale}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Recognized Text Display
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ಗುರುತಿಸಲಾದ ಪಠ್ಯ (Recognized Text):',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        Text(
                          _recognizedText.isEmpty
                              ? 'ಮಾತನಾಡಲು ಪ್ರಾರಂಭಿಸಿ... (Start speaking...)'
                              : _recognizedText,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.5,
                            color: _recognizedText.isEmpty
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        if (_confidence > 0) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Control Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                        _isListening ? 'ನಿಲ್ಲಿಸಿ (Stop)' : 'ಪ್ರಾರಂಭಿಸಿ (Start)',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _recognizedText.isEmpty ? null : _clearText,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Available Locales Info
              if (_availableLocales.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Available Languages'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableLocales.length,
                            itemBuilder: (context, index) {
                              final locale = _availableLocales[index];
                              return ListTile(
                                title: Text(locale.name),
                                subtitle: Text(locale.localeId),
                                onTap: () {
                                  _changeLanguage(locale.localeId);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: Text('${_availableLocales.length} languages available'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}