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

