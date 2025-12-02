import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/Flutter_STT/language_translation.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Settings/app_settings.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:image/image.dart' as img;

class SceneDescriptionScreen extends StatefulWidget {
  final String language;

  SceneDescriptionScreen({required this.language});

  @override
  _SceneDescriptionScreenState createState() => _SceneDescriptionScreenState();
}

class _SceneDescriptionScreenState extends State<SceneDescriptionScreen> {
  File? _capturedImage;
  String? _description;
  bool _isProcessing = false;
  final FlutterTts flutterTts = FlutterTts();

  // ⚙️ Change to your ESP32 and server URLs
  final String esp32Url = "$espBaseUrl/capture"; // ESP32 camera endpoint
  final String serverUrl = "$baseUrl/caption"; // your AI caption server

  @override
  void initState() {
    super.initState();

    _captureFromESP32(); // Automatically capture when screen opens
  }

  Future<void> _captureFromESP32() async {
    
    setState(() {
      _isProcessing = true;
      _description = null;
      _capturedImage = null;
    });

    try {
      // 🧠 Cache-busting parameter so it always fetches a fresh image
      final uri =
          Uri.parse("$esp32Url?_t=${DateTime.now().millisecondsSinceEpoch}");
      final response = await http.get(uri);

      if (response.statusCode != 200) throw Exception("Failed to load image");

      // 📂 Save image locally
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

      setState(() => _capturedImage = imageFile);

      // 🧠 Send image to captioning server
      await _sendToServer(imageFile);
    } catch (e) {
      print("❌ Error fetching image: $e");
      await flutterTts.speak("Error fetching image from camera");
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendToServer(File imageFile) async {
    try {
      final request = http.MultipartRequest("POST", Uri.parse(serverUrl));
      request.files
          .add(await http.MultipartFile.fromPath("file", imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        String? translated_text =
            "This looks like " + data["caption"] ?? "No description found";

        if (widget.language == "ಕನ್ನಡ (Kannada)" && translated_text != null) {
          translated_text = await TranslationService.translateWithMyMemory(
              translated_text!, "en|kn");
        }

        setState(() {
          _description = translated_text;
          _isProcessing = false;
        });

        // 🔊 Speak the description
        await TTSManager().speak(translated_text!);
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error sending to server: $e");
      await flutterTts.speak("Error describing the scene");
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.language == "English"
              ? "Scene Description"
              : "ದೃಶ್ಯ ವಿವರಣೆ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(widget.language == "English"
                  ? "Processing, please wait..."
                  : "ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ, ದಯವಿಟ್ಟು ನಿರೀಕ್ಷಿಸಿ..."),
            ] else if (_capturedImage != null) ...[
              Image.file(_capturedImage!, height: 250),
              const SizedBox(height: 20),
              if (_description != null)
                Text(
                  widget.language == "English"
                      ? "Scene: $_description"
                      : "ದೃಶ್ಯ: $_description",
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _captureFromESP32,
                icon: const Icon(Icons.refresh),
                label: Text(
                    widget.language == "English" ? "Retake" : "ಮರುಪಡೆಯಿರಿ"),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _captureFromESP32,
                icon: const Icon(Icons.camera_alt),
                label: Text(widget.language == "English"
                    ? "Capture Scene"
                    : "ದೃಶ್ಯ ಸೆರೆಹಿಡಿಯುವಿಕೆ"),
              ),
          ],
        ),
      ),
    );
  }
}
