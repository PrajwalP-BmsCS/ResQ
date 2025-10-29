import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/utils/util.dart';

class OCRHomePage extends StatefulWidget {
  @override
  _OCRHomePageState createState() => _OCRHomePageState();
}

class _OCRHomePageState extends State<OCRHomePage> {
  String _extractedText = '';
  File? _selectedImage;
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isLoading = false;

  // 🔹 change this to your ESP32-CAM’s IP
  final String esp32Url = '$espBaseUrl/capture?_t=';

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    _fetchAndProcessImage(); // 👈 directly capture on startup
  }

  Future<void> _fetchAndProcessImage() async {
    setState(() {
      _isLoading = true;
      _extractedText = '';
      _selectedImage = null;
    });

    try {
      // add timestamp to bust caching
      final url = Uri.parse('$esp32Url${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/esp32_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);

        setState(() => _selectedImage = file);

        await _processImage(file);
      } else {
        throw Exception('ESP32 responded with ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching/detecting: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load image from ESP32')),
      // );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // final devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);

    String scannedText = '';
    String detectedLang = 'en-IN'; // default

    RecognizedText latin = await latinRecognizer.processImage(inputImage);
    // RecognizedText hindi = await devanagariRecognizer.processImage(inputImage);

    if (latin.text.trim().isNotEmpty) {
      scannedText = latin.text;

      // detect Kannada
      if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(scannedText)) {
        detectedLang = 'kn-IN';
      } else {
        detectedLang = 'en-IN';
      }
    }

    await latinRecognizer.close();
    // await devanagariRecognizer.close();

    setState(() => _extractedText = scannedText);

    _speakText(scannedText, detectedLang);
  }

  Future<void> _speakText(String text, String langCode) async {
    await flutterTts.setLanguage(langCode);
    await flutterTts.speak(text);
    setState(() => _isSpeaking = true);
  }

  Future<void> _pauseSpeech() async {
    await flutterTts.pause();
    setState(() => _isSpeaking = false);
  }

  Future<void> _resumeSpeech() async {
    await flutterTts.speak(_extractedText);
    setState(() => _isSpeaking = true);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR & TTS Smart Reader')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Capturing image from ESP32...'),
                  ],
                )
              else if (_selectedImage != null)
                Column(
                  children: [
                    Image.file(_selectedImage!, height: 250),
                    const SizedBox(height: 20),
                    Text(
                      _extractedText.isEmpty
                          ? 'Processing text...'
                          : _extractedText,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _fetchAndProcessImage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                        const SizedBox(width: 20),
                        if (_extractedText.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _isSpeaking ? _pauseSpeech : null,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                          ),
                        const SizedBox(width: 20),
                        if (_extractedText.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: !_isSpeaking ? _resumeSpeech : null,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                          ),
                      ],
                    ),
                  ],
                )
              else
                const Text('Waiting for image...'),
            ],
          ),
        ),
      ),
    );
  }
}