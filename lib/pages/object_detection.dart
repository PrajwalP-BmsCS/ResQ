import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

class ObjectDetectionScreen extends StatefulWidget {
  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  File? _selectedImage;
  List<dynamic>? _detections;
  final FlutterTts flutterTts = FlutterTts();
  static const platform = MethodChannel('onnx_channel');
  bool _isDetecting = false;

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
      _isDetecting = true;
    });

    try {
      // Run YOLO ONNX inference
      final List<dynamic> result =
          await platform.invokeMethod('runYOLO', {'path': imageFile.path});

      setState(() {
        _detections = result;
        _isDetecting = false;
      });

      // Speak results
      if (result.isNotEmpty) {
        String detectedObjects = result.join(", ");
        await flutterTts.speak("I see $detectedObjects");
      } else {
        await flutterTts.speak("No objects detected");
      }
    } catch (e) {
      setState(() => _isDetecting = false);
      print("❌ Error: $e");
      await flutterTts.speak("Error detecting objects");
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
      appBar: AppBar(title: Text("Object Detection")),
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

                  // Detection results
                  if (_isDetecting)
                    Center(child: CircularProgressIndicator())
                  else if (_detections != null)
                    Text(
                      "Detected Objects: ${_detections!.join(", ")}",
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
