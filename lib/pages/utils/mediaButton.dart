// lib/services/media_button_service.dart

import 'package:flutter/services.dart';

class MediaButtonService {
  static final MediaButtonService _instance = MediaButtonService._internal();
  factory MediaButtonService() => _instance;
  MediaButtonService._internal();

  static const MethodChannel _channel = 
      MethodChannel("com.class_echo/media_button");
  
  Function(String)? _onSingleTap;
  Function(String)? _onLongPress;
  Function()? _onButtonDown;
  
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    
    _channel.setMethodCallHandler((call) async {
      print("📱 [MediaButtonService] Received: ${call.method}");
      
      switch (call.method) {
        case "button_down":
          print("🔽 Button down");
          _onButtonDown?.call();
          break;

        case "single_tap":
          print("👆 Single tap: ${call.arguments}");
          final duration = call.arguments?['duration']?.toString() ?? "0";
          _onSingleTap?.call(duration);
          break;

        case "long_press":
          print("👆 Long press: ${call.arguments}");
          final duration = call.arguments?['duration']?.toString() ?? "0";
          _onLongPress?.call(duration);
          break;

        default:
          print("❓ Unknown: ${call.method}");
      }
    });
    
    _isInitialized = true;
    print("✅ MediaButtonService initialized");
  }

  void setHandlers({
    Function(String)? onSingleTap,
    Function(String)? onLongPress,
    Function()? onButtonDown,
  }) {
    _onSingleTap = onSingleTap;
    _onLongPress = onLongPress;
    _onButtonDown = onButtonDown;
    print("✅ Handlers registered");
  }

  void clearHandlers() {
    _onSingleTap = null;
    _onLongPress = null;
    _onButtonDown = null;
    print("🧹 Handlers cleared");
  }
}