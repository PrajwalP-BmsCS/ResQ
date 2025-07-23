import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/onnx_service.dart';
import '../services/tts_service.dart';
import '../services/camera_service.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  CameraController? _controller;
  late final TTSService _ttsService;
  late final ONNXService _onnxService;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _ttsService = TTSService();
    _onnxService = ONNXService();
  }

  Future<void> _initCamera() async {
    final cameras = await CameraService.getAvailableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    _controller = CameraController(frontCamera, ResolutionPreset.medium);
    await _controller!.initialize();
    _controller!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _runDetection(image);
      }
    });
    setState(() {});
  }

  Future<void> _runDetection(CameraImage image) async {
    try {
      final bytes = image.planes[0].bytes; // Simplification, real app needs to convert properly.
      final detections = await _onnxService.runInference(Uint8List.fromList(bytes));
      if (detections.contains('person')) {
        await _ttsService.speak('Person ahead');
      }
      if (detections.contains('chair')) {
        await _ttsService.speak('Obstacle ahead');
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Object Detection')),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : CameraPreview(_controller!),
    );
  }
}
