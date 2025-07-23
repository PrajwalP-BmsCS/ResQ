import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:io';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isDetecting = false;
  static const platform = MethodChannel('onnx_channel');

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> detectObjects() async {
    if (_isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      // 📸 Take picture and save
      final XFile imageFile = await _controller.takePicture();
      final String imagePath = imageFile.path;

      // 🧠 Call native ONNX detection with image path
      final List<dynamic> result =
          await platform.invokeMethod('runYOLO', {'path': imagePath});

      print("✅ Detected Objects: $result");
    } catch (e) {
      print("❌ Error: $e");
    }

    setState(() {
      _isDetecting = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller)),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: detectObjects,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: _isDetecting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Detect Objects",
                        style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
