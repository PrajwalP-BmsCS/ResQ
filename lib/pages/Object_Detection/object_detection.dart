import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/Flutter_STT/language_translation.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:image/image.dart' as img;

class ObjectDetectionScreen extends StatefulWidget {
  final String language;
  ObjectDetectionScreen({required this.language});

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  File? _capturedImage;
  List<dynamic>? _detections;
  static const platform = MethodChannel('onnx_channel');
  bool _isDetecting = false;
  String appTitle = "";
  String imageNote = "";
  String finalResult = "";

  // ⚡ your ESP32 CAM endpoint
  final String esp32Url = '$espBaseUrl/capture';

  @override
  void initState() {
    super.initState();

    _fetchAndDetect();
  }

  Future<void> _fetchAndDetect() async {
    if (widget.language != "English") {
      print("LANG ${widget.language}");
      setState(() {
        // _isDetecting = true;
        appTitle = "ವಸ್ತು ಪತ್ತೆ";
        imageNote = "ಇನ್ನೂ ಯಾವುದೇ ಚಿತ್ರವನ್ನು ಸೆರೆಹಿಡಿಯಲಾಗಿಲ್ಲ";
      });
    } else {
      setState(() {
        _isDetecting = true;
        appTitle = "Object Detection";
      });
    }

    try {
      // add timestamp param to force ESP32 refresh
      final String url = '$esp32Url';
      final response = await http.get(Uri.parse(url));
      print("📸 Fetching from $url");

      if (response.statusCode != 200) {
        throw Exception('Failed to load image from ESP32');
      }

      // save image with unique filename
      // final Directory tempDir = await getTemporaryDirectory();
      // final String filePath =
      //     '${tempDir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // final File imageFile = File(filePath);
      // await imageFile.writeAsBytes(response.bodyBytes);

      // save image with unique filename
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

      setState(() {
        _capturedImage = imageFile;
      });

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
        detectedObjects = "I am seeing " + detectedObjects + " in front of me";

        if (widget.language != "English") {
          detectedObjects = (await TranslationService.translateWithMyMemory(
              detectedObjects, "en|kn"))!;
        }
        await TTSManager().speak("$detectedObjects");

        setState(() {
          finalResult = detectedObjects;
        });
      } else {
        await TTSManager().speak(widget.language == "English"
            ? "No objects detected"
            : "ಯಾವುದೇ ವಸ್ತುಗಳು ಪತ್ತೆಯಾಗಿಲ್ಲ");
      }
    } catch (e) {
      print("❌ Error fetching/detecting: $e");
      setState(() => _isDetecting = false);
      await TTSManager().speak(widget.language == "English"
          ? "No objects detected"
          : "ಯಾವುದೇ ವಸ್ತುಗಳು ಪತ್ತೆಯಾಗಿಲ್ಲ");
    }
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isDetecting
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      widget.language == "English"
                          ? "Capturing and detecting..."
                          : "ಸೆರೆಹಿಡಿಯುವುದು ಮತ್ತು ಪತ್ತೆಹಚ್ಚುವುದು...",
                    ),
                  ],
                )
              : _capturedImage == null
                  ? Text(imageNote)
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
                        if (finalResult != null)
                          Text(
                            widget.language == "English"
                                ? "Detected Objects: ${finalResult}"
                                : "ಪತ್ತೆಯಾದ ವಸ್ತುಗಳು: ${finalResult}",
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
