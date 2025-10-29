import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';

// Utility function
Map<String, dynamic> prefsMap = {};
late LocalStore store;
Future<bool> checkLanguageCondition() async {
  store = await LocalStore.getInstance();
  prefsMap = store.getGeneralPrefs();

  return prefsMap['lang'] == "English";
}

// Function 1: Check if device is connected to internet
Future<bool> isConnectedToInternet() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  // Check if connected to WiFi or Mobile data
  if (connectivityResult == ConnectivityResult.mobile ||
      connectivityResult == ConnectivityResult.wifi) {
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
  final res = await checkLanguageCondition();
  if (!await isConnectedToInternet() && !await isConnectedToWiFi()) {
    print("NOT CONNECTED");

    TTSManager().speak(res
        ? "No internet connection. Please connect to the internet and turn ON hotspot and try again."
        : "ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕವಿಲ್ಲ. ದಯವಿಟ್ಟು ಇಂಟರ್ನೆಟ್‌ಗೆ ಸಂಪರ್ಕಿಸಿ ಮತ್ತು ಹಾಟ್‌ಸ್ಪಾಟ್ ಆನ್ ಮಾಡಿ ಮತ್ತು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
    return false;
  }
  return true;
}
