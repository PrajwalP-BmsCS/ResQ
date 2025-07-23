import 'dart:typed_data';
import 'package:flutter/services.dart';

class ONNXService {
  static const platform = MethodChannel('onnx_channel');

  Future<List<String>> runInference(Uint8List bytes) async {
    try {
      final List<dynamic> result = await platform.invokeMethod('runYOLOOnBytes', bytes);
      return result.cast<String>();
    } on PlatformException catch (e) {
      print('Error calling ONNX: $e');
      return [];
    }
  }
}
