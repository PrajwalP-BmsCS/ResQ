import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:req_demo/pages/home_page.dart';


void main() {
  // Ensures Flutter engine and bindings are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP32 CAM Snapshot',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(cameras: []),
    );
  }
}

// class CameraPage extends StatefulWidget {
//   @override
//   _CameraPageState createState() => _CameraPageState();
// }

// class _CameraPageState extends State<CameraPage> {
//   Uint8List? imageBytes;

//   Future<void> captureImage() async {
//     // Change this IP to match your ESP32-CAM’s local or static IP
//     final url = Uri.parse('http://10.195.49.101/capture');
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         setState(() {
//           imageBytes = response.bodyBytes;
//         });
//       } else {
//         print('Failed to capture image: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('ESP32 CAM Snapshot')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // if (imageBytes != null)
//             //   Image.memory(imageBytes!)
//             // else
//             //   const Text('Press the button to capture an image'),
//             // const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: captureImage,
//               child: const Text('Capture Image'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
