import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:image/image.dart' as img;

class OCRHomePage extends StatefulWidget {
  final String language;

  OCRHomePage({required this.language});
  @override
  _OCRHomePageState createState() => _OCRHomePageState();
}

class _OCRHomePageState extends State<OCRHomePage> {
  String _extractedText = '';
  File? _selectedImage;
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isLoading = false;
  String appTitle = "OCR & TTS Smart Reader";
  String captureTitle = "Capturing image from ESP32...";
  String processText = "'Processing text...'";
  String retake = "Retake";
  String pause = "Pause";
  String resume = "Resume";

  // 🔹 change this to your ESP32-CAM’s IP
  final String esp32Url = '$espBaseUrl/capture?_t=';

  @override
  void initState() {
    super.initState();

    _fetchAndProcessImage(); // 👈 directly capture on startup
  }

  Future<void> _fetchAndProcessImage() async {
    setState(() {
      _isLoading = true;
      _extractedText = '';
      _selectedImage = null;
      if (widget.language != "English") {
        appTitle = "OCR & TTS ಸ್ಮಾರ್ಟ್ ರೀಡರ್";
        captureTitle = "ESP32 ನಿಂದ ಚಿತ್ರವನ್ನು ಸೆರೆಹಿಡಿಯಲಾಗುತ್ತಿದೆ...";
        processText = 'ಪಠ್ಯವನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ...';
        retake = "ಮರುಪಡೆಯಿರಿ";
        pause = "ವಿರಾಮ";
        resume = "ಪುನರಾರಂಭಿಸಿ";
      } else {
        appTitle = "OCR & TTS Smart Reader";
        captureTitle = "Capturing image from ESP32...";
        processText = 'Processing text...';
        retake = "Retake";
        pause = "Pause";
        resume = "Resume";
      }
    });

    try {
      // add timestamp to bust caching
      final url =
          Uri.parse('$esp32Url${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg';

// ⬅️ Decode image bytes
      final original = img.decodeImage(response.bodyBytes);

// ⬅️ Rotate image 90 degrees
      final rotated = img.copyRotate(original!, angle: 90);

// ⬅️ Convert back to bytes
      final rotatedBytes = img.encodeJpg(rotated);

// write rotated image to file
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(rotatedBytes);

        setState(() => _selectedImage = imageFile);
        
        await _processImage(imageFile);
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

    TTSManager().speak(scannedText);
  }

  Future<void> _pauseSpeech() async {
    await TTSManager().pause();
    setState(() => _isSpeaking = false);
  }

  Future<void> _resumeSpeech() async {
    await TTSManager().speak(_extractedText);
    setState(() => _isSpeaking = true);
  }

  @override
  void dispose() {
    TTSManager().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(captureTitle),
                  ],
                )
              else if (_selectedImage != null)
                Column(
                  children: [
                    Image.file(_selectedImage!, height: 250),
                    const SizedBox(height: 20),
                    Text(
                      _extractedText.isEmpty ? processText : _extractedText,
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
                          label: Text(retake),
                        ),
                        const SizedBox(width: 20),
                        if (_extractedText.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _isSpeaking ? _pauseSpeech : null,
                            icon: const Icon(Icons.pause),
                            label: Text(pause),
                          ),
                        const SizedBox(width: 20),
                        if (_extractedText.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: !_isSpeaking ? _resumeSpeech : null,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(resume),
                          ),
                      ],
                    ),
                  ],
                )
              else
                Text(widget.language == "English"
                    ? 'Waiting for image...'
                    : 'ಚಿತ್ರಕ್ಕಾಗಿ ನಿರೀಕ್ಷಿಸಲಾಗುತ್ತಿದೆ...'),
            ],
          ),
        ),
      ),
    );
  }
}
