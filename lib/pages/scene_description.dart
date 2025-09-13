import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SceneDescriptionScreen extends StatefulWidget {
  @override
  _SceneDescriptionScreenState createState() => _SceneDescriptionScreenState();
}

class _SceneDescriptionScreenState extends State<SceneDescriptionScreen> {
  File? _selectedImage;
  String? _description;
  final FlutterTts flutterTts = FlutterTts();
  bool _isProcessing = false;

  // 🔌 Change this to your server’s IP / domain
  final String serverUrl = "http://192.168.31.45:8000/caption";

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    setState(() {
      _selectedImage = imageFile;
      _isProcessing = true;
      _description = null;
    });

    try {
      // 📤 Send image to server
      final request = http.MultipartRequest("POST", Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final result = data["caption"] ?? "No description found";

        setState(() {
          _description = result;
          _isProcessing = false;
        });

        // 🔊 Speak result
        if (result.isNotEmpty) {
          await flutterTts.speak("This looks like $result");
        } else {
          await flutterTts.speak("I could not describe the scene");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      print("❌ Error: $e");
      await flutterTts.speak("Error describing the scene");
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
      appBar: AppBar(title: Text("Scene Description")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Buttons to choose image
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera),
                  label: Text('Camera'),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Selected Image
            if (_selectedImage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(_selectedImage!, height: 250),
                  const SizedBox(height: 20),

                  // Description
                  if (_isProcessing)
                    Center(child: CircularProgressIndicator())
                  else if (_description != null)
                    Text(
                      "Scene: $_description",
                      style: TextStyle(fontSize: 16),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
