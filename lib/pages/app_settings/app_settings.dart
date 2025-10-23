import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';

// Function 1: Check if device is connected to internet
Future<bool> isConnectedToInternet() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  
  // Check if connected to WiFi or Mobile data
  if (connectivityResult == ConnectivityResult.wifi ||
      connectivityResult == ConnectivityResult.mobile) {
    return true;
  }
  return false;
}

// Function 2: Check if device is connected to WiFi (for hotspot sharing)
Future<bool> isConnectedToWiFi() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  
  // Check if connected to WiFi
  if (connectivityResult == ConnectivityResult.wifi) {
    return true;
  }
  return false;
}

// Usage example:
Future<bool> checkConnectivity() async {
  if (!await isConnectedToInternet()) {
    print("NOT CONNECTED");
    TTSManager().speak("No internet connection. Please connect to the internet and turn ON hotspot and try again.");
    return false;
  }

  if (!await isConnectedToWiFi()) {
    print("NOT ON WIFI");
    TTSManager().speak("You are not connected to WiFi. Please connect to WiFi and turn ON hotspot to share hotspot.");
    return false;
  }

  
  
  return true;
}