import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLOv5n ONNX Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  String _detectionResult = "No detections yet";
  static const platform = MethodChannel('onnx_channel');

  /// Run inference on the selected image by calling Kotlin
  Future<void> _runONNXInference(String imagePath) async {
    try {
      print("Running ONNX inference on image: $imagePath");

      final resultPath =
          await platform.invokeMethod<String>('runYOLO', {'path': imagePath});
      print("Inference completed, annotated image path: $resultPath");

      if (resultPath != null && File(resultPath).existsSync()) {
        setState(() {
          // Add a cache-busting query to force reload
          final cacheBustedPath = '$resultPath?v=${DateTime.now().millisecondsSinceEpoch}';
          _image = File(resultPath);
          _detectionResult = "Objects detected and annotated!";
        });
      } else {
        setState(() {
          _detectionResult = resultPath ?? "No detection output from model";
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _detectionResult = "ONNX Runtime error: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _detectionResult = "Unexpected error: $e";
      });
    }
  }

  /// Pick image from gallery and run detection
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path); // Temporarily show original
          _detectionResult = "Running YOLOv5 inference...";
          print("Picked image: ${pickedFile.path}");
        });
        await _runONNXInference(pickedFile.path);
      } else {
        setState(() {
          _detectionResult = "No image selected.";
        });
      }
    } catch (e) {
      setState(() {
        _detectionResult = "Image picker error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOLOv5n Object Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_image != null)
              // Unique key ensures Flutter doesn't reuse old image widget
              Image.file(
                _image!,
                key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                height: 300,
                fit: BoxFit.contain,
              )
            else
              const Text('Pick an image to detect objects'),
            const SizedBox(height: 20),
            Text(
              _detectionResult,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        tooltip: 'Pick Image',
        child: const Icon(Icons.image),
      ),
    );
  }
}
