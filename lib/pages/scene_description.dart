import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SceneDescriptionScreen extends StatefulWidget {
  @override
  _SceneDescriptionScreenState createState() => _SceneDescriptionScreenState();
}

class _SceneDescriptionScreenState extends State<SceneDescriptionScreen> {
  File? _capturedImage;
  String? _description;
  bool _isProcessing = false;
  final FlutterTts flutterTts = FlutterTts();

  // ⚙️ Change to your ESP32 and server URLs
  final String esp32Url = "http://192.168.31.203/capture"; // ESP32 camera endpoint
  final String serverUrl = "http://192.168.31.45:8000/caption"; // your AI caption server

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
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
      final uri = Uri.parse("$esp32Url?_t=${DateTime.now().millisecondsSinceEpoch}");
      final response = await http.get(uri);

      if (response.statusCode != 200) throw Exception("Failed to load image");

      // 📂 Save image locally
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/scene_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final imageFile = File(filePath);
      await imageFile.writeAsBytes(bytes);

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
      request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final caption = data["caption"] ?? "No description found";

        setState(() {
          _description = caption;
          _isProcessing = false;
        });

        // 🔊 Speak the description
        await flutterTts.speak("This looks like $caption");
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
      appBar: AppBar(title: const Text("Scene Description")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text("Processing, please wait..."),
            ] else if (_capturedImage != null) ...[
              Image.file(_capturedImage!, height: 250),
              const SizedBox(height: 20),
              if (_description != null)
                Text(
                  "Scene: $_description",
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _captureFromESP32,
                icon: const Icon(Icons.refresh),
                label: const Text("Retake"),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _captureFromESP32,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Capture Scene"),
              ),
          ],
        ),
      ),
    );
  }
}
