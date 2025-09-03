import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

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
    initCamera();
  }

  Future<void> initCamera() async {
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();
    await _controller.setFlashMode(FlashMode.off);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> detectObjects() async {
    if (_isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      final XFile imageFile = await _controller.takePicture();
      final String imagePath = imageFile.path;

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
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.previewSize!.height,
                height: _controller.value.previewSize!.width,
                child: CameraPreview(_controller),
              ),
            ),
          ),
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
