import 'package:flutter/material.dart';
import 'object_detection.dart';
import 'dummy_screen.dart';
import 'package:camera/camera.dart';

class HomePage extends StatelessWidget {
  final List<CameraDescription> cameras;
  HomePage({required this.cameras});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {'title': 'Object Detection', 'route': ObjectDetectionScreen(cameras: cameras)},
      {'title': 'OCR', 'route': DummyScreen(title: 'OCR')},
      {'title': 'Navigation', 'route': DummyScreen(title: 'Navigation')},
      {'title': 'Scene Description', 'route': DummyScreen(title: 'Scene Description')},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Glasses"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: features.map((feature) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => feature['route']),
                );
              },
              child: Center(
                child: Text(
                  feature['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
