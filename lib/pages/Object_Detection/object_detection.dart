import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/utils/util.dart';

class ObjectDetectionScreen extends StatefulWidget {
  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  File? _capturedImage;
  List<dynamic>? _detections;
  final FlutterTts flutterTts = FlutterTts();
  static const platform = MethodChannel('onnx_channel');
  bool _isDetecting = false;

  // ⚡ your ESP32 CAM endpoint
  final String esp32Url = '$espBaseUrl/capture';

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    _fetchAndDetect();
  }

  Future<void> _fetchAndDetect() async {
    setState(() {
      _isDetecting = true;
    });

    try {
      // add timestamp param to force ESP32 refresh
      final String url =
          '$esp32Url?cb=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(url));
      print("📸 Fetching from $url");

      if (response.statusCode != 200) {
        throw Exception('Failed to load image from ESP32');
      }

      // save image with unique filename
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(response.bodyBytes);

      setState(() {
        _capturedImage = imageFile;
      });

      // 🚀 Run YOLO ONNX inference
      final List<dynamic> result =
          await platform.invokeMethod('runYOLO', {'path': imageFile.path});

      setState(() {
        _detections = result;
        _isDetecting = false;
      });

      // 🗣️ Speak results
      if (result.isNotEmpty) {
        String detectedObjects = result.join(", ");
        await flutterTts.speak("I see $detectedObjects");
      } else {
        await flutterTts.speak("No objects detected");
      }
    } catch (e) {
      print("❌ Error fetching/detecting: $e");
      setState(() => _isDetecting = false);
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isDetecting
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Capturing and detecting..."),
                  ],
                )
              : _capturedImage == null
                  ? Text("No image captured yet")
                  : Column(
                      children: [
                        FutureBuilder<Uint8List>(
                          future: _capturedImage?.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return CircularProgressIndicator();
                            return Image.memory(
                              snapshot.data!,
                              height: 250,
                              gaplessPlayback: true, // prevents old frame flash
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_detections != null)
                          Text(
                            "Detected Objects: ${_detections!.join(", ")}",
                            style: TextStyle(fontSize: 16),
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchAndDetect,
                          icon: Icon(Icons.refresh),
                          label: Text("Capture Again"),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}