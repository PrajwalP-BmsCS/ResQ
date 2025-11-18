import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:req_demo/pages/Flutter_STT/english_stt.dart';
import 'package:req_demo/pages/Flutter_STT/kannada_stt.dart';
import 'package:req_demo/pages/Flutter_STT/language_translation.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Navigation/nav_utility_functions.dart';
import 'package:req_demo/pages/Navigation/navigation.dart';
import 'package:req_demo/pages/OCR/ocr_ml_kit.dart';
import 'package:req_demo/pages/Object_Detection/object_detection.dart';
import 'package:req_demo/pages/Scene%20Description/scene_description.dart';
import 'package:req_demo/pages/Settings/practice.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';
import 'package:req_demo/pages/Settings/app_settings.dart';
import 'package:req_demo/pages/home_page.dart';
import 'package:req_demo/pages/utils/mediaButton.dart';
import 'package:req_demo/pages/utils/onboard.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as ld;

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  HomePage({required this.cameras});

  @override
  HomePageState createState() => HomePageState();
}

// Enum for mic status
enum MicStatus { idle, listening, processing, error }

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _mediaChannel =
      MethodChannel("com.class_echo/media_button");

  // Mic status tracking
  MicStatus _micStatus = MicStatus.idle;

  // Transcribed text
  String _transcribedText = '';
  String _finalTranscript = ''; // The complete transcript ready for API

  // Status message
  String _statusMessage = 'Press and hold the button to start listening...';

  final VoiceService voiceService = VoiceService();

  // Animation controller for mic pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // @override
  // void initState() {
  //   super.initState();

  //   // To reset ONBOARDING
  //   // resetOnboarding();

  //   // Initialize service once
  //   MediaButtonService().initialize();

  //   // Set handlers for this page
  //   MediaButtonService().setHandlers(
  //     onSingleTap: (duration) => _onSingleTap(),
  //     onLongPress: (duration) => _onLongPress(),
  //     onButtonDown: () => print("Button down on HomePage"),
  //   );

  //   initAll();

  //   // Show onboarding after the first frame is built
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _checkAndShowOnboarding();
  //   });

  //   // Setup animation
  //   _pulseController = AnimationController(
  //     duration: const Duration(milliseconds: 1000),
  //     vsync: this,
  //   )..repeat(reverse: true);

  //   _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
  //     CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  //   );

  //   // Setup voice service listener for transcription
  //   // _setupVoiceServiceListener();

  //   // Setup method call handler
  //   // _mediaChannel.setMethodCallHandler((call) async {
  //   //   switch (call.method) {
  //   //     case "button_down":
  //   //       print("Button pressed down");
  //   //       break;

  //   //     case "single_tap":
  //   //       print("Single tap: ${call.arguments}");
  //   //       final duration = call.arguments?['duration'] ?? 0;
  //   //       _onSingleTap();
  //   //       break;

  //   //     case "long_press":
  //   //       print("Long press: ${call.arguments}");
  //   //       final duration = call.arguments?['duration'] ?? 0;
  //   //       _onLongPress();
  //   //       break;

  //   //     default:
  //   //       print("Unknown method: ${call.method}");
  //   //   }
  //   // });
  // }

  late String preffered_lang = "";
  @override
  void initState() {
    super.initState();

    // ✅ 1. Setup media channel IMMEDIATELY
    _setupMediaChannel();

    // ✅ 2. Setup animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ 3. Initialize services
    initAll();

    // ✅ 4. Show onboarding LAST
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  void _setupMediaChannel() {
    _mediaChannel.setMethodCallHandler((call) async {
      print("📱 [HomePage] Media event: ${call.method}");

      switch (call.method) {
        case "button_down":
          print("🔽 Button down");
          break;

        case "single_tap":
          print("👆 Single tap: ${call.arguments}");
          _onSingleTap();
          break;

        case "long_press":
          print("👆 Long press: ${call.arguments}");
          _onLongPress();
          break;

        default:
          print("❓ Unknown: ${call.method}");
      }
    });

    print("✅ Media channel handler registered for HomePage");
  }

  bool language_status = true;

  void _toggleLanguage() {
    setState(() {
      language_status = !language_status;
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    store = await LocalStore.getInstance();
    prefsMap = store.getGeneralPrefs();
    final bool onboardingCompleted = prefsMap['onboarding_completed'] ?? false;
    print("ONB $onboardingCompleted");

    if (!onboardingCompleted && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => OnboardingDialog(
          onPlayTTS: _playTTS,
          screen: "home",
          language: language_status ? "English" : "ಕನ್ನಡ (Kannada)",
          language_status: language_status,
          onToggleLanguage: _toggleLanguage, // ✅ callback from parent
        ),
      );
    }
  }

  // TTS Function - Connect this to your TTSManager
  void _playTTS(String text) {
    // TODO: Connect to your TTS Manager
    // Example: TTSManager().speak(text);
    print("Playing TTS: $text");

    // For now, just print. Replace with actual TTS call:
    TTSManager().speak(text);
  }

  void _setupVoiceServiceListener() {
    // Listen to transcription updates from your VoiceService
    // Assuming VoiceService has a stream or callback for transcription
    // You'll need to adapt this based on your VoiceService implementation

    // Example implementation (adjust based on your VoiceService):
    /*
    voiceService.transcriptionStream?.listen((transcription) {
      setState(() {
        _transcribedText = transcription;
      });
    });
    */
  }

  void _onSingleTap() {
    print('onSingleTap() called — stopping mic if listening');

    if (_micStatus == MicStatus.listening) {
      // Stop listening
      _stopListening();
    } else {
      setState(() {
        _statusMessage = checkLanguageCondition()
            ? 'Mic is not active. Long press to start listening.'
            : "ಮೈಕ್ ಸಕ್ರಿಯವಾಗಿಲ್ಲ. ಕೇಳಲು ಪ್ರಾರಂಭಿಸಲು ದೀರ್ಘವಾಗಿ ಒತ್ತಿರಿ.";
      });
    }
  }

  void _onLongPress() {
    print('onLongPress() called — starting recording');
    _startListening();
  }

  String voiceText = "";
  void _startListening() async {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = checkLanguageCondition()
          ? 'Listening... Speak now'
          : "ಕೇಳುತ್ತಿದ್ದೇನೆ... ಈಗಲೇ ಮಾತನಾಡಿ";
      _transcribedText = '';
      _finalTranscript = '';
    });

    try {
      store = await LocalStore.getInstance();

      prefsMap = store.getGeneralPrefs();

      preffered_lang = prefsMap['lang'];

      print("PREFE $preffered_lang");
      VoiceService().startListening(
          pref_lang: preffered_lang,
          onFinalResult: (text) {
            print("Final recognized words: $text");
            voiceText = text;

            // Update the transcribed text
            if (voiceText.isNotEmpty) {
              setState(() {
                _transcribedText = voiceText;
              });
            }
          });
    } catch (e) {
      setState(() {
        _micStatus = MicStatus.error;
        _statusMessage = checkLanguageCondition()
            ? 'Error starting mic: $e'
            : "ಮೈಕ್ ಪ್ರಾರಂಭಿಸುವಲ್ಲಿ ದೋಷ: $e";
      });
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _micStatus = MicStatus.processing;
      _statusMessage = checkLanguageCondition()
          ? 'Processing...'
          : 'ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ...';
    });

    try {
      voiceService.stopListening();

      _finalTranscript = _transcribedText;

      await Future.delayed(const Duration(milliseconds: 500));

      if (_finalTranscript.isNotEmpty) {
        // Await the intent result

        print("Final Transcript_STOP: $_finalTranscript");

        String? translated_text;
        if (preffered_lang == "ಕನ್ನಡ (Kannada)") {
          translated_text = await TranslationService.translateWithMyMemory(
              _finalTranscript, "kn|en");
          print("TRANSLATED TEXT $translated_text");
        }

        try {
          final intent_result = (preffered_lang == "ಕನ್ನಡ (Kannada)")
              ? await get_user_intent(translated_text!)
              : await get_user_intent(_finalTranscript);
          print("Received intent result from API");
          print(intent_result);

          // Start
          handleIntentResult(intent_result);

          print("Intent Result: $intent_result");
        } catch (e) {
          print("Intent API error: $e");
          await TTSManager().speak(checkLanguageCondition()
              ? "Sorry for the inconvenience, Please Try Again!!"
              : "ಅನಾನುಕೂಲತೆಗೆ ಕ್ಷಮಿಸಿ, ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ!!");
        }

        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = checkLanguageCondition()
              ? 'Tap and hold to start again.'
              : 'ಮತ್ತೆ ಪ್ರಾರಂಭಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ ಮತ್ತು ಹಿಡಿದುಕೊಳ್ಳಿ.';
        });
      } else {
        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = checkLanguageCondition()
              ? 'No speech detected. Try again.'
              : 'ಯಾವುದೇ ಮಾತು ಪತ್ತೆಯಾಗಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';
        });
      }
    } catch (e) {
      setState(() {
        _micStatus = MicStatus.error;
        _statusMessage = checkLanguageCondition()
            ? 'Error stopping mic: $e'
            : 'ಮೈಕ್ ನಿಲ್ಲಿಸುವಲ್ಲಿ ದೋಷ: $e';
      });
    }
  }

  // void navigateToNextScreen(String intent, bool listen_status,
  //     int contact_option, bool want_to_call) async {
  //   // Implement navigation logic here

  //   if (intent == "connect_glasses") {
  //     bool res = await checkConnectivity();
  //     if (res) {
  //       // connection logic
  //     }
  //   } else if (intent == "scene_description") {
  //     TTSManager().speak("Navigating to scene description screen");
  //     // Navigator.push(
  //     //   context,
  //     //   MaterialPageRoute(
  //     //       builder: (_) => SceneDescriptionScreen()),
  //     // );
  //   } else if (intent == "object_detection") {
  //     // Navigator.push(
  //     //   context,
  //     //   MaterialPageRoute(
  //     //       builder: (_) => ObjectDetectionScreen()),
  //     // );
  //     TTSManager().speak("Navigate to object detection screen");
  //   } else if (intent == "ocr") {
  //     print("OCR");
  //     // Navigator.push(
  //     //   context,
  //     //   MaterialPageRoute(
  //     //       builder: (_) => OCRHomePage()),
  //     // );
  //   } else if (intent == "navigation") {
  //     // Navigator.push(
  //     //   context,
  //     //   MaterialPageRoute(
  //     //       builder: (_) => WalkingRouteMapPage()),
  //     // );
  //     TTSManager().speak("Navigate to navigation screen");
  //   } else if (intent == "try_again") {
  //     TTSManager().speak("Could not understand. Please try again.");
  //     setState(() {
  //       _statusMessage = 'Could not understand. Please try again.';
  //     });
  //   }
  //   // List of supported contacts
  //   else if (intent == "list_contacts") {
  //     TTSManager().speak("Listing contacts");
  //   } else if (intent == "call_contact") {
  //     String option = contact_option.toString();

  //     if (want_to_call == false) {
  //       TTSManager().speak(
  //         "Do you want to call Option ${option}? Please say yes or no.",
  //       );
  //     } else {
  //       TTSManager().speak(
  //         "Calling Option ${option} now.",
  //       );
  //     }
  //   }
  // }

  // FOR CALLING AND SHARING
  bool _waitingForCallConfirmation = false;
  int? _pendingContactOption;
  String? _pendingContactName;

  bool _waitingForShareConfirmation = false;
  int? _pendingShareContactOption;
  String? _pendingShareContactName;

  late ContactManager contactManager;
  Map<String, dynamic> prefsMap = {};
  late LocalStore store;

  // for Emergency contant
  bool _waitingForCancel = true;

  Future<void> initAll() async {
    store = await LocalStore.getInstance();
    contactManager = ContactManager();

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('emergency_contacts');

    prefsMap = store.getGeneralPrefs();
    print("✅ Loaded prefsMap: $prefsMap");

    if (rawList != null) {
      setState(() {
        preffered_lang = prefsMap['lang'] ?? "English";

        if (preffered_lang != "English") {
          _statusMessage = "ಕೇಳಲು ಪ್ರಾರಂಭಿಸಲು ಬಟನ್ ಒತ್ತಿ ಹಿಡಿದುಕೊಳ್ಳಿ...";
        } else {
          _statusMessage = 'Press and hold the button to start listening...';
        }
        contactManager.contacts = rawList
            .map((e) => EmergencyContact.fromJson(jsonDecode(e)))
            .toList();
      });
      print("Contacts loaded: ${contactManager.contacts.length}");
    }
  }

  bool checkLanguageCondition() {
    return prefsMap['lang'] == "English";
  }

  Future<void> _makePhoneCall(
      int contactOption, bool sos, String contactName, final contact) async {
    print(
        "CALLOP $contactOption | sos: $sos | conname $contactName | finalcon:$contact");
    try {
      final contacts = contactManager.contacts;
      final locationContacts =
          contacts.where((c) => c.allowCall == true).toList();

      final phoneNumber, final_contact;
      if (contact is EmergencyContact) {
        print("Name based contact");
        phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
        final_contact = contact;
      } else {
        print("EMERGENCY / option based contact");
        phoneNumber = locationContacts[contactOption - 1].phone;
        final_contact = locationContacts[contactOption - 1];
      }

      if (sos) {
        String s = "Calling";
        if (!checkLanguageCondition()) {
          s = "ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ";
          await TTSManager().speak("${final_contact.name} ಇಗೆ ${s}");
        } else {
          await TTSManager().speak("Calling ${final_contact.name}");
        }
      }

      if (phoneNumber.isEmpty) {
        TTSManager().speak(checkLanguageCondition()
            ? "Phone number not available for this contact."
            : "ಈ ಸಂಪರ್ಕಕ್ಕೆ ಫೋನ್ ಸಂಖ್ಯೆ ಲಭ್ಯವಿಲ್ಲ.");
        return;
      }

      // ✅ Request runtime permission
      if (await Permission.phone.request().isDenied) {
        TTSManager().speak(checkLanguageCondition()
            ? "Please enable phone permission to make a call."
            : "ಕರೆ ಮಾಡಲು ದಯವಿಟ್ಟು ಫೋನ್ ಅನುಮತಿಯನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿ.");
        return;
      }

      // ✅ Small delay to avoid thread race
      await Future.delayed(const Duration(milliseconds: 400));

      // ✅ Invoke Kotlin native handler
      const platform = MethodChannel('onnx_channel');
      await platform.invokeMethod('callWithSim', {
        'phone': phoneNumber,
        'simSlot': 0, // or 1 for SIM2
      });

      print("✅ Native call requested to ${final_contact.name} ($phoneNumber)");
    } catch (e) {
      print("❌ Error making call: $e");
      TTSManager().speak(checkLanguageCondition()
          ? "An error occurred while making the call."
          : "ಕರೆ ಮಾಡುವಾಗ ದೋಷ ಸಂಭವಿಸಿದೆ.");
    }
  }

// Add these state variables
  bool _emergencyInProgress = false;
  bool _cancelEmergency = false;
  Timer? _emergencyListeningTimer;
  Map numbersMap = {
    10: "ಹತ್ತು",
    9: "ಒಂಬತ್ತು",
    8: "ಎಂಟು",
    7: "ಏಳು",
    6: "ಆರು",
    5: "ಐದು",
    4: "ನಾಲ್ಕು",
    3: "ಮೂರು",
    2: "ಎರಡು",
    1: "ಒಂದು"
  };

  /// Emergency countdown with continuous cancel listening
  Future<bool> setCounter() async {
    _cancelEmergency = false;
    _emergencyInProgress = true;
    final seconds = 6;

    // Speak initial message
    await TTSManager().speak(checkLanguageCondition()
        ? "Emergency feature has been enabled. It will start in $seconds seconds. Say cancel to stop."
        : "ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ. ಇದು $seconds ಸೆಕೆಂಡುಗಳಲ್ಲಿ ಆರಂಭವಾಗುತ್ತದೆ. ನಿಲ್ಲಿಸಲು Cancel ಎಂದು ಹೇಳಿ.");

    // Wait for TTS to finish before starting listening
    await Future.delayed(const Duration(milliseconds: 500));

    // Start continuous listening for cancel command
    _startContinuousEmergencyListener();

    // Countdown loop
    for (int i = seconds; i > 0; i--) {
      if (_cancelEmergency) {
        await _stopEmergencyListener();
        await TTSManager().speak(checkLanguageCondition()
            ? "Emergency feature has been cancelled."
            : "ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.");
        debugPrint("❌ Emergency cancelled by user.");
        _emergencyInProgress = false;

        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = checkLanguageCondition()
              ? 'Emergency cancelled. Press to start listening.'
              : 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ ರದ್ದುಗೊಂಡಿದೆ. ಕೇಳಲು ಪ್ರಾರಂಭಿಸಲು ಒತ್ತಿರಿ.';
        });
        return false;
      }
      if (checkLanguageCondition()) {
        await TTSManager().speak("$i");
      } else {
        await TTSManager().speak("${numbersMap[i]}");
      }

      debugPrint("⏳ Countdown: $i");

      // Give time for user to say "cancel" during countdown
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Final check before triggering
    if (_cancelEmergency) {
      await _stopEmergencyListener();
      await TTSManager().speak(checkLanguageCondition()
          ? "Emergency feature has been cancelled."
          : "ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.");
      _emergencyInProgress = false;

      setState(() {
        _micStatus = MicStatus.idle;
        _statusMessage = checkLanguageCondition()
            ? 'Emergency feature cancelled.'
            : 'ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.';
      });
      return false;
    }

    await _stopEmergencyListener();
    await TTSManager().speak(checkLanguageCondition()
        ? "Starting emergency action now."
        : "ಈಗ ತುರ್ತು ಕ್ರಮ ಕೈಗೊಳ್ಳಲಾಗುತ್ತಿದೆ.");
    await _triggerSOS();

    _emergencyInProgress = false;

    setState(() {
      _micStatus = MicStatus.idle;
      _statusMessage = checkLanguageCondition()
          ? 'Emergency action completed.'
          : 'ತುರ್ತು ಕ್ರಮ ಪೂರ್ಣಗೊಂಡಿದೆ.';
    });

    return true;
  }

  /// Start continuous listening that restarts automatically
  void _startContinuousEmergencyListener() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = checkLanguageCondition()
          ? 'Say "CANCEL" to stop emergency'
          : 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ ನಿಲ್ಲಿಸಲು "CANCEL" ಎಂದು ಹೇಳಿ';
    });

    _restartEmergencyListener();
  }

  /// Restart listener continuously until emergency is done
  void _restartEmergencyListener() {
    if (!_emergencyInProgress || _cancelEmergency) {
      return;
    }

    try {
      VoiceService().startListening(
        onFinalResult: (text) {
          print("🎤 Emergency listener heard: $text");

          // Check if user said "cancel" or similar words
          final lowerText = text.toLowerCase();
          if (lowerText.contains("cancel") ||
              lowerText.contains("stop") ||
              lowerText.contains("no") ||
              lowerText.contains("abort") ||
              lowerText.contains("don't") ||
              lowerText.contains("wait")) {
            print("🛑 Cancel command detected: $text");
            _cancelEmergency = true;

            setState(() {
              _micStatus = MicStatus.processing;
              _statusMessage = checkLanguageCondition()
                  ? 'Cancelling emergency...'
                  : 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ ರದ್ದು...';
            });
            return;
          }

          // If no cancel detected, restart listening after a short delay
          if (_emergencyInProgress && !_cancelEmergency) {
            debugPrint("🔄 Restarting emergency listener...");
            Future.delayed(const Duration(milliseconds: 300), () {
              _restartEmergencyListener();
            });
          }
        },
      );
    } catch (e) {
      debugPrint("❌ Error in emergency listener: $e");

      // Try to restart even if there was an error
      if (_emergencyInProgress && !_cancelEmergency) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _restartEmergencyListener();
        });
      }
    }
  }

  /// Stop the emergency listener
  Future<void> _stopEmergencyListener() async {
    try {
      _emergencyInProgress = false; // Stop the restart loop
      voiceService.stopListening();
      _emergencyListeningTimer?.cancel();
      _emergencyListeningTimer = null;
      debugPrint("✅ Emergency listener stopped");

      setState(() {
        _micStatus = MicStatus.idle;
        _statusMessage = checkLanguageCondition()
            ? 'Press and hold to start listening...'
            : 'ಕೇಳಲು ಪ್ರಾರಂಭಿಸಲು ಒತ್ತಿ ಹಿಡಿದುಕೊಳ್ಳಿ...';
      });
    } catch (e) {
      debugPrint("❌ Error stopping emergency listener: $e");
    }
  }

  /// Alternative: Use a periodic timer to keep checking
  void _startContinuousEmergencyListenerWithTimer() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = checkLanguageCondition()
          ? 'Say "CANCEL" to stop emergency'
          : 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ ನಿಲ್ಲಿಸಲು "CANCEL" ಎಂದು ಹೇಳಿ';
    });

    // Start initial listener
    _startSingleEmergencyListener();

    // Set up a timer to restart listening every 2 seconds
    _emergencyListeningTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (!_emergencyInProgress || _cancelEmergency) {
          timer.cancel();
          return;
        }

        debugPrint("🔄 Restarting emergency listener (timer)...");
        voiceService.stopListening();

        Future.delayed(const Duration(milliseconds: 200), () {
          if (_emergencyInProgress && !_cancelEmergency) {
            _startSingleEmergencyListener();
          }
        });
      },
    );
  }

  void _startSingleEmergencyListener() {
    try {
      VoiceService().startListening(
        onFinalResult: (text) {
          print("🎤 Emergency listener heard: $text");

          final lowerText = text.toLowerCase();
          if (lowerText.contains("cancel") ||
              lowerText.contains("stop") ||
              lowerText.contains("no") ||
              lowerText.contains("abort")) {
            print("🛑 Cancel command detected: $text");
            _cancelEmergency = true;

            setState(() {
              _micStatus = MicStatus.processing;
              _statusMessage = checkLanguageCondition()
                  ? 'Cancelling emergency...'
                  : 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ ರದ್ದು...';
            });
          }
        },
      );
    } catch (e) {
      debugPrint("❌ Error starting emergency listener: $e");
    }
  }

  /// Updated call from intent detection
  void handleIntentResult(Map<String, dynamic> intent_result) {
    navigateToNextScreen(
      intent_result['intent'],
      intent_result['listen_back'] ?? false,
      intent_result['contact_option'] ?? 0,
      intent_result['want_to_call'] ?? false,
      intent_result['want_to_share'] ?? false,
      intent_result['response'],
      intent_result['contact_name'] ?? '',
    );
  }

  void navigateToNextScreen(
    String intent,
    bool listen_status,
    int contact_option,
    bool want_to_call,
    bool want_to_share,
    String? yesNoResponse,
    String contactName,
  ) async {
    try {
      print(
          "🎯 Intent: $intent | Listen: $listen_status | Want Call: $want_to_call | Want Share: $want_to_share | Response: $yesNoResponse | Contact Name: $contactName");

      // Handle Yes/No responses
      if (intent == "yes_no_response") {
        _handleYesNoResponse(yesNoResponse, contactName);
        return;
      }

      // Handle other intents only if not waiting for confirmation
      if (_waitingForCallConfirmation || _waitingForShareConfirmation) {
        print("⚠️ Currently waiting for confirmation, ignoring other intents");

        String s = "";
        if (_waitingForCallConfirmation) {
          s = "call";
        } else if (_waitingForShareConfirmation) {
          s = "share location";
        }
        TTSManager().speak(checkLanguageCondition()
            ? "Currently waiting for your confirmation, for earlier $s request. Please tell No if you want to cancel the request."
            : "ನಿಮ್ಮ ದೃಢೀಕರಣಕ್ಕಾಗಿ ಕಾಯುತ್ತಿದ್ದೇನೆ, ಹಿಂದಿನ $s ವಿನಂತಿಗಾಗಿ. ನೀವು ವಿನಂತಿಯನ್ನು ರದ್ದುಗೊಳಿಸಲು ಬಯಸಿದರೆ ದಯವಿಟ್ಟು ಇಲ್ಲ ಎಂದು ಹೇಳಿ.");
        return;
      }

      bool res = await checkConnectivity();

      switch (intent) {
        case "connect_glasses":
          if (res) {
            TTSManager().speak(checkLanguageCondition()
                ? "Connecting to your glasse \n\nYour glasses has been successfully connected."
                : "ಕನ್ನಡಕಗಳಿಗೆ ಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ. \n\n\n\n ನಿಮ್ಮ ಕನ್ನಡಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಜೋಡಿಸಲಾಗಿದೆ");
          }
          break;

        case "scene_description":
          if (res) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SceneDescriptionScreen(
                          language: preffered_lang ?? "English",
                        )));
            await TTSManager().speak(checkLanguageCondition()
                ? "Starting to scene description now.."
                : "ಈಗ ದೃಶ್ಯ ವಿವರಣೆಯನ್ನು ಪ್ರಾರಂಭಿಸುತ್ತಿದ್ದೇನೆ..");
          }
          break;

        case "object_detection":
          // if (res) {
          // Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //         builder: (context) => ObjectDetectionScreen(language: preffered_lang ?? "English",)));
          await TTSManager().speak(checkLanguageCondition()
              ? "Detecting objects"
              : "ವಸ್ತುಗಳನ್ನು ಪತ್ತೆಹಚ್ಚುವುದು");
          // }

          break;

        case "ocr":
          // if (res) {
          // Navigator.push(context,
          //     MaterialPageRoute(builder: (context) => OCRHomePage(language: preffered_lang ?? "English",)));
          await TTSManager().speak(checkLanguageCondition()
              ? "Starting text recognition"
              : "ಪಠ್ಯ ಗುರುತಿಸುವಿಕೆಯನ್ನು ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ");
          // }
          break;

        case "navigation":
          if (res) {
            await TTSManager().speak(checkLanguageCondition()
                ? "Navigating to navigation screen"
                : "ನ್ಯಾವಿಗೇಷನ್ ಸ್ಕ್ರೀನ್‌ಗೆ ನ್ಯಾವಿಗೇಟ್ ಮಾಡಲಾಗುತ್ತಿದೆ");
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => WalkingRouteMapPage(
                        language: preffered_lang ?? "English")));
          }
          break;

        case "list_contacts":
          _handleListContacts();
          break;

        case "call_contact":
          _handleCallContact(
              listen_status, contact_option, want_to_call, contactName);
          break;

        case "list_share_contacts":
          _handleListShareContacts();
          break;

        case "share_location":
          _handleShareLocation(
              listen_status, contact_option, want_to_share, contactName);
          break;

        case "emergency":
          if (!_emergencyInProgress) {
            bool wasTriggered = await setCounter();
            if (wasTriggered) {
              debugPrint("✅ Emergency SOS triggered");
            } else {
              debugPrint("❌ Emergency was cancelled");
            }
          } else {
            TTSManager().speak(checkLanguageCondition()
                ? "Emergency feature already in progress."
                : "ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವು ಈಗಾಗಲೇ ಪ್ರಗತಿಯಲ್ಲಿದೆ.");
          }

          break;

        default:
          TTSManager().speak(checkLanguageCondition()
              ? "Intent not recognized. Please try again."
              : "ಉದ್ದೇಶವನ್ನು ಗುರುತಿಸಲಾಗಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
      }
    } catch (e) {
      print("❌ Error in navigateToNextScreen: $e");
      TTSManager().speak(checkLanguageCondition()
          ? "An error occurred. Please try again."
          : "ದೋಷ ಸಂಭವಿಸಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
    }
  }

  /// Handle Yes/No responses for both call and share
  void _handleYesNoResponse(String? response, String contactName) async {
    if (_waitingForCallConfirmation) {
      if (response == "yes") {
        print("✅ User confirmed: Calling option $_pendingContactOption");
        await TTSManager().speak(checkLanguageCondition()
            ? "Calling $_pendingContactName now"
            : "ಈಗ $_pendingContactName ಗೆ ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ");

        await Future.delayed(Duration(seconds: 1), () {
          _makePhoneCall(_pendingContactOption!, false, contactName, {});
        });

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      } else if (response == "no") {
        print("❌ User declined call");
        TTSManager().speak(checkLanguageCondition()
            ? "Call cancelled. How can I help you?"
            : "ಕರೆ ರದ್ದುಗೊಂಡಿದೆ. ನಾನು ನಿಮಗೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ?");

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      }
    } else if (_waitingForShareConfirmation) {
      if (response == "yes") {
        print(
            "✅ User confirmed: Sharing location with option $_pendingShareContactOption");
        TTSManager().speak(checkLanguageCondition()
            ? "Sharing your location with $_pendingShareContactName now"
            : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು $_pendingShareContactName ರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ.");

        await Future.delayed(Duration(seconds: 1), () {
          _shareLocationWithContact(_pendingShareContactOption!, false, "", {});
        });

        // Reset state
        _waitingForShareConfirmation = false;
        _pendingShareContactOption = null;
        _pendingShareContactName = null;
      } else if (response == "no") {
        print("❌ User declined share");
        TTSManager().speak(checkLanguageCondition()
            ? "Location sharing cancelled. How can I help you?"
            : "ಸ್ಥಳ ಹಂಚಿಕೆ ರದ್ದುಗೊಂಡಿದೆ. ನಾನು ನಿಮಗೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಬಹುದು?");

        // Reset state
        _waitingForShareConfirmation = false;
        _pendingShareContactOption = null;
        _pendingShareContactName = null;
      }
    } else {
      // Handle generic yes/no without context
      if (response == "yes") {
        TTSManager().speak(checkLanguageCondition() ? "Okay" : "ಸರಿ");
      } else if (response == "no") {
        TTSManager()
            .speak(checkLanguageCondition() ? "Understood" : "ಅರ್ಥವಾಯಿತು");
      }
    }
  }

  /// Handle List Contacts intent
  void _handleListContacts() async {
    await initAll();

    final contacts = contactManager.contacts;
    final callContacts = contacts.where((c) => c.allowCall == true).toList();

    print(contactManager.contacts);
    print("IN HANDLES");

    if (callContacts.isEmpty) {
      TTSManager().speak(checkLanguageCondition()
          ? "You have no contacts saved."
          : "ನೀವು ಯಾವುದೇ ಸಂಪರ್ಕಗಳನ್ನು ಉಳಿಸಿಕೊಂಡಿಲ್ಲ.");
      return;
    }

    StringBuffer contactList = StringBuffer();
    contactList.write(
        checkLanguageCondition() ? "Your contacts are: " : "ನಿಮ್ಮ ಸಂಪರ್ಕಗಳು: ");

    for (int i = 0; i < callContacts.length; i++) {
      contactList.write(checkLanguageCondition()
          ? "Option ${i + 1}: ${callContacts[i].name}. "
          : "ಆಯ್ಕೆ ${i + 1}: ${callContacts[i].name}. ");
    }

    contactList.write(checkLanguageCondition()
        ? "Please say the option number you want to call."
        : "ದಯವಿಟ್ಟು ನೀವು ಕರೆ ಮಾಡಲು ಬಯಸುವ ಆಯ್ಕೆ ಸಂಖ್ಯೆಯನ್ನು ಹೇಳಿ.");
    TTSManager().speak(contactList.toString());
  }

  /// Handle Call Contact intent
  void _handleCallContact(bool listen_status, int contact_option,
      bool want_to_call, String contactName) async {
    await initAll();

    final contacts = contactManager.contacts;
    final locationContacts =
        contacts.where((c) => c.allowCall == true).toList();

    print(
        "Handling call contact: Option $contact_option | Want Call: $want_to_call | Listen: $listen_status | ContcNmae: $contactName");

    if (contact_option == 0 && contactName.isEmpty) {
      print("⚠️ No contact option provided");
      TTSManager().speak(checkLanguageCondition()
          ? "Please specify which contact to call."
          : "ದಯವಿಟ್ಟು ಯಾವ ಸಂಪರ್ಕಕ್ಕೆ ಕರೆ ಮಾಡಬೇಕೆಂದು ನಿರ್ದಿಷ್ಟಪಡಿಸಿ.");
      return;
    }

    // Validate contact option
    if ((contact_option < 1 ||
            contact_option > contactManager.contacts.length) &&
        contactName.isEmpty) {
      print("❌ Invalid contact option: $contact_option");
      TTSManager().speak(checkLanguageCondition()
          ? "Invalid contact option. Please try again."
          : "ಸಂಪರ್ಕ ಆಯ್ಕೆ ಅಮಾನ್ಯವಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
      return;
    }

    // for (var i in contacts) {
    //   print("${i.name.toLowerCase().trim().length}");
    // }
    // print("COPT ${contactName.toLowerCase().length}");
    final contact;
    if (contactName.isNotEmpty) {
      contact_option = locationContacts.indexWhere((contact) =>
          contact.name.toLowerCase().trim() == contactName.toLowerCase());
      print("COPT $contact_option");

      if (contact_option == -1) {
        await TTSManager().speak(checkLanguageCondition()
            ? "The contact you told is not available, please say again"
            : "ನೀವು ಹೇಳಿದ ಸಂಪರ್ಕ ಲಭ್ಯವಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಮ್ಮೆ ಹೇಳಿ.");
        return;
      }
      contact = locationContacts[contact_option];
    } else {
      contact = locationContacts[contact_option - 1];
    }

    if (want_to_call) {
      print("🔴 Direct call to option $contact_option: ${contact.name}");
      TTSManager().speak(checkLanguageCondition()
          ? "Calling ${contact.name} now"
          : "ಈಗ ${contact.name} ಗೆ ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ");

      await Future.delayed(Duration(seconds: 2), () {
        _makePhoneCall(contact_option, false, contactName, contact);
      });
    } else if (listen_status) {
      print("❓ Asking for confirmation before calling option $contact_option");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;
      _pendingContactName = contact.name;

      TTSManager().speak(
        checkLanguageCondition()
            ? "Do you want to call ${contact.name} at ${contact.phone}? Please say yes or no."
            : "ನೀವು ${contact.name} ಕರೆ ಮಾಡಲು ಬಯಸುವಿರಾ? \n ದಯವಿಟ್ಟು ಹೇಳಿ yes ಅಥವಾ no.",
      );
    } else {
      print("❓ Default: Asking for confirmation");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;
      _pendingContactName = contact.name;

      TTSManager().speak(
        checkLanguageCondition()
            ? "Do you want to call ${contact.name}? Please say yes or no."
            : "ನೀವು ${contact.name} ಕರೆ ಮಾಡಲು ಬಯಸುವಿರಾ? \n ದಯವಿಟ್ಟು ಹೇಳಿ yes ಅಥವಾ no.",
      );
    }
  }

  /// Handle List Share Contacts intent
  void _handleListShareContacts() async {
    await initAll();

    final contacts = contactManager.contacts;
    final locationContacts = contacts.where((c) => c.location == true).toList();

    print("Listing contacts for sharing");

    if (locationContacts.isEmpty) {
      TTSManager().speak(checkLanguageCondition()
          ? "You have no contacts saved."
          : "ನೀವು ಯಾವುದೇ ಸಂಪರ್ಕಗಳನ್ನು ಉಳಿಸಿಕೊಂಡಿಲ್ಲ.");
      return;
    }

    StringBuffer contactList = StringBuffer();
    contactList.write(
        checkLanguageCondition() ? "Your contacts are: " : "ನಿಮ್ಮ ಸಂಪರ್ಕಗಳು: ");

    for (int i = 0; i < locationContacts.length; i++) {
      contactList.write(checkLanguageCondition()
          ? "Option ${i + 1}: ${locationContacts[i].name}. "
          : "ಆಯ್ಕೆ ${i + 1}: ${locationContacts[i].name}. ");
    }

    contactList.write(checkLanguageCondition()
        ? "Please say the option number you want to share."
        : "ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳಲು ಬಯಸುವ ಆಯ್ಕೆಯನ್ನು ಹೇಳಿ");

    TTSManager().speak(contactList.toString());
  }

  /// Handle Share Location intent
  void _handleShareLocation(bool listen_status, int contact_option,
      bool want_to_share, String contactName) async {
    await initAll();

    final contacts = contactManager.contacts;
    final locationContacts = contacts.where((c) => c.location == true).toList();

    print(
        "Handling share location: Option $contact_option | Want Share: $want_to_share | Listen: $listen_status");

    if (contact_option == 0 && contactName.isEmpty) {
      print("⚠️ No contact option provided");
      TTSManager().speak(checkLanguageCondition()
          ? "Please specify which contact to share your location with."
          : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ಯಾವ ಸಂಪರ್ಕದೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಬೇಕೆಂದು ದಯವಿಟ್ಟು ನಿರ್ದಿಷ್ಟಪಡಿಸಿ.");
      return;
    }

    // Validate contact option
    if ((contact_option < 1 ||
            contact_option > contactManager.contacts.length) &&
        contactName.isEmpty) {
      print("❌ Invalid contact option: $contact_option");
      TTSManager().speak(checkLanguageCondition()
          ? "Invalid contact option. Please try again."
          : "ಸಂಪರ್ಕ ಆಯ್ಕೆ ಅಮಾನ್ಯವಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
      return;
    }

    final contact;
    if (contactName.isNotEmpty) {
      contact_option = locationContacts.indexWhere((contact) =>
          contact.name.toLowerCase().trim() == contactName.toLowerCase());
      print("COPT $contact_option");
      if (contact_option == -1) {
        await TTSManager().speak(checkLanguageCondition()
            ? "The contact you told is not available, please say again"
            : "ನೀವು ಹೇಳಿದ ಸಂಪರ್ಕ ಲಭ್ಯವಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಮ್ಮೆ ಹೇಳಿ.");
        return;
      }
      contact = locationContacts[contact_option];
    } else {
      contact = locationContacts[contact_option - 1];
    }

    if (want_to_share) {
      print("🌍 Direct share to option $contact_option: ${contact.name}");
      TTSManager().speak(checkLanguageCondition()
          ? "Sharing your location with ${contact.name} now"
          : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ");

      await Future.delayed(Duration(seconds: 1), () {
        _shareLocationWithContact(contact_option, false, contactName, contact);
      });
    } else if (listen_status) {
      print(
          "❓ Asking for confirmation before sharing with option $contact_option");
      _waitingForShareConfirmation = true;
      _pendingShareContactOption = contact_option;
      _pendingShareContactName = contact.name;

      TTSManager().speak(
        checkLanguageCondition()
            ? "Do you want to share your location with ${contact.name}? Please say yes or no."
            : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ನೀವು ${contact.name}? ರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲು ಬಯಸುತ್ತೀರ? \n ದಯವಿಟ್ಟು ಹೇಳಿ yes ಅಥವಾ no.",
      );
    } else {
      print("❓ Default: Asking for confirmation");
      _waitingForShareConfirmation = true;
      _pendingShareContactOption = contact_option;
      _pendingShareContactName = contact.name;

      TTSManager().speak(
        checkLanguageCondition()
            ? "Do you want to share your location with ${contact.name}? Please say yes or no."
            : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ನೀವು ${contact.name}? ರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲು ಬಯಸುತ್ತೀರ? \n ದಯವಿಟ್ಟು ಹೇಳಿ yes ಅಥವಾ no.",
      );
    }
  }

  Future<String?> _getLocationLink() async {
    try {
      ld.Location location = ld.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return null;
      }

      ld.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return null;
      }

      ld.LocationData locData = await location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        if (checkLanguageCondition()) {
          return "🚨I'm in an emergency!🚨 Please help me. I'm currently at this location:\n https://www.google.com/maps?q=${locData.latitude},${locData.longitude} \nPlease try to call as soon as you see this message. Also arrive to the above location as soon as possible.";
        } else {
          return "🚨ನಾನು ತುರ್ತು ಪರಿಸ್ಥಿತಿಯಲ್ಲಿ ಇದ್ದೇನೆ!🚨ದಯವಿಟ್ಟು ಸಹಾಯ ಮಾಡಿ. ನಾನು ಪ್ರಸ್ತುತ ಈ ಸ್ಥಳದಲ್ಲಿದ್ದೇನೆ:\n https://www.google.com/maps?q=${locData.latitude},${locData.longitude} \nದಯವಿಟ್ಟು ಈ ಕಳಿಸಿರುವ ಸ್ಥಳಕ್ಕೆ ಬೇಗ ಬನ್ನಿ ಹಾಗೂ ಈ ಸಂದೇಶವನ್ನು ನೋಡಿದ ಕೂಡಲೇ ನನಗೆ ಒಂದು ಕರೆ ಮಾಡಿ.";
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }

  /// Share location with specific contact
  Future<void> _shareLocationWithContact(int contactOption, bool emergency,
      String contactName, final contact) async {
    try {
      // Share via SMS or WhatsApp

      final contacts = contactManager.contacts;
      final locationContacts =
          contacts.where((c) => c.allowLocation == true).toList();

      final phoneNumber, final_contact;
      if (contact is EmergencyContact) {
        print("Name based contact");
        phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
        final_contact = contact;
      } else {
        print("EMERGENCY / option based contact");
        phoneNumber = locationContacts[contactOption - 1].phone;
        final_contact = locationContacts[contactOption - 1];
      }

      if (phoneNumber.isNotEmpty) {
        // You can use url_launcher to open WhatsApp, SMS, or other apps
        // Example: WhatsApp
        final shareMessage = await _getLocationLink();

        final seconds = 10;
        final callSeconds = 6;
        if (shareMessage != null) {
          final Uri whatsappUri = Uri.parse(
              "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareMessage)}");

          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri);
            print("✅ Location shared with ${final_contact.name} via WhatsApp");

            if (emergency) {
              await TTSManager().speak(checkLanguageCondition()
                  ? "Location shared with ${final_contact.name}. \n Also in next $callSeconds seconds a phone call will be initiated, please stay in the APP. "
                  : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${final_contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ. \n ಮುಂದಿನ ${numbersMap[callSeconds]} ಸೆಕೆಂಡುಗಳಲ್ಲಿ ಫೋನ್ ಕರೆ ಪ್ರಾರಂಭವಾಗುತ್ತದೆ, ದಯವಿಟ್ಟು APP ನಲ್ಲಿ ಇರಿ.");

              for (int second = callSeconds; second > 0; second--) {
                if (checkLanguageCondition()) {
                  if (second == callSeconds || second == 1) {
                  await TTSManager().speak("Calling in $second seconds");
                }
                else{
                  await TTSManager().speak("$second");
                }
                } else {
                  if (second == callSeconds || second == 1) {
                    await TTSManager().speak(
                        "ಇನ್ನು ${numbersMap[second]} ಸೆಕೆಂಡುಗಳು ರಲ್ಲಿ ಕರೆ ಮಾಡಲಾಗುತ್ತದೆ");
                  } else {
                    await TTSManager().speak("${numbersMap[second]}");
                  }
                }
                await Future.delayed(const Duration(milliseconds: 1000));
              }
              _makePhoneCall(1, true, '', {});
              // await Future.delayed(Duration(seconds: 10), () {

              // });
            } else {
              await TTSManager().speak(checkLanguageCondition()
                  ? "Location shared with ${final_contact.name}."
                  : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${final_contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ.");
            }
          } else {
            // Fallback: SMS
            final Uri smsUri = Uri.parse(
                "sms:$phoneNumber?body=${Uri.encodeComponent(shareMessage)}");
            if (await canLaunchUrl(smsUri)) {
              await launchUrl(smsUri);
              print("✅ Location shared with ${final_contact.name} via SMS");
              await TTSManager().speak(checkLanguageCondition()
                  ? "Location shared with ${final_contact.name}"
                  : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${final_contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ.");
            }
          }
        }
      } else {
        TTSManager().speak(checkLanguageCondition()
            ? "Phone number not available for this contact."
            : "ಈ ಸಂಪರ್ಕಕ್ಕೆ ಫೋನ್ ಸಂಖ್ಯೆ ಲಭ್ಯವಿಲ್ಲ.");
      }
    } catch (e) {
      print("❌ Error sharing location: $e");
      TTSManager().speak(checkLanguageCondition()
          ? "An error occurred while sharing your location."
          : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳುವಾಗ ದೋಷ ಸಂಭವಿಸಿದೆ.");
    }
  }

  /// Share location with all contacts
  Future<void> _shareLocationWithAll() async {
    try {
      await initAll();

      final contacts = contactManager.contacts;

      if (contacts.isEmpty) {
        TTSManager().speak("You have no contacts to share with.");
        return;
      }

      // Get current location
      ld.Location location = ld.Location();
      ld.LocationData currentLocation = await location.getLocation();
      final currentLat = currentLocation.latitude;
      final currentLon = currentLocation.longitude;

      // Create share message
      final String shareMessage =
          "My current location: Latitude: $currentLat, Longitude: $currentLon";

      int successCount = 0;

      for (var contact in contacts) {
        try {
          final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

          if (phoneNumber.isNotEmpty) {
            final Uri whatsappUri = Uri.parse(
                "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareMessage)}");

            if (await canLaunchUrl(whatsappUri)) {
              await launchUrl(whatsappUri);
              successCount++;
              print("✅ Location shared with ${contact.name}");
            }
          }
        } catch (e) {
          print("⚠️ Error sharing with ${contact.name}: $e");
        }

        // Small delay between shares
        await Future.delayed(Duration(milliseconds: 500));
      }

      TTSManager().speak("Location shared with $successCount contact(s)");
      print("✅ Location shared with $successCount contacts");
    } catch (e) {
      print("❌ Error sharing location with all: $e");
      TTSManager().speak("An error occurred while sharing your location.");
    }
  }

  // Trigger SOS
  Future<void> _triggerSOS() async {
    // store = await LocalStore.getInstance();
    // print("LocalStore initialized: $store");

    // prefsMap = store.getGeneralPrefs();

    // if (prefsMap == {}) {
    //   prefsMap['defaultAction'] = "call";
    // }

    // print("✅ Loaded prefsMap: $prefsMap");

    // final action = prefsMap['defaultAction'];

    _shareLocationWithContact(1, true, "", {});
    // if (action == "Call") {

    // } else if (action == "Share Location") {

    // }
  }

  Future<Map<String, dynamic>> get_user_intent(String transcript) async {
    final url = Uri.parse("$baseUrl/get_user_intent");
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'audioText': transcript,
      }),
    );

    print("Response status: ${response.body}");
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user intent');
    }
  }

  // Manual start button (for testing without headset)
  void _manualStart() {
    if (_micStatus == MicStatus.idle || _micStatus == MicStatus.error) {
      _startListening();
    } else if (_micStatus == MicStatus.listening) {
      _stopListening();
    }
  }

  // Get transcribed text for external use
  String getTranscribedText() {
    return _finalTranscript;
  }

  Color _getMicStatusColor() {
    switch (_micStatus) {
      case MicStatus.idle:
        return Colors.grey;
      case MicStatus.listening:
        return Colors.red;
      case MicStatus.processing:
        return Colors.orange;
      case MicStatus.error:
        return Colors.redAccent;
    }
  }

  IconData _getMicStatusIcon() {
    switch (_micStatus) {
      case MicStatus.idle:
        return Icons.mic_off;
      case MicStatus.listening:
        return Icons.mic;
      case MicStatus.processing:
        return Icons.sync;
      case MicStatus.error:
        return Icons.error_outline;
    }
  }

  String _getMicStatusText() {
    switch (_micStatus) {
      case MicStatus.idle:
        return checkLanguageCondition() ? 'IDLE' : 'ಐಡಲ್';
      case MicStatus.listening:
        return checkLanguageCondition() ? 'LISTENING' : 'ಆಲಿಸುವುದು';
      case MicStatus.processing:
        return checkLanguageCondition()
            ? 'PROCESSING'
            : 'ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ';
      case MicStatus.error:
        return checkLanguageCondition() ? 'ERROR' : 'ದೋಷ';
    }
  }

  void resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
  }

  @override
  void dispose() {
    _mediaChannel.setMethodCallHandler(null);
    _pulseController.dispose();
    _emergencyListeningTimer?.cancel();
    _stopEmergencyListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      // {
      //   "title": "Practice STT",
      //   "icon": Icons.image_search,
      //   "page": MediaButtonTestPage(
      //     screen: '',
      //   ),
      // },
      // {
      //   "title": "Kannada STT",
      //   "icon": Icons.image_search,
      //   "page": KannadaSpeechToTextPage(),
      // },
      {
        "title": checkLanguageCondition() ? "Object Detection" : "ವಸ್ತು ಪತ್ತೆ",
        "icon": Icons.camera_alt,
        "page": ObjectDetectionScreen(
          language: preffered_lang ?? "English",
        )
      },
      {
        "title": checkLanguageCondition() ? "OCR" : "ಒ.ಸಿ.ಆರ್",
        "icon": Icons.text_fields,
        "page": OCRHomePage(
          language: preffered_lang ?? "English",
        )
      },
      {
        "title": checkLanguageCondition() ? "Navigation" : "ನ್ಯಾವಿಗೇಷನ್",
        "icon": Icons.navigation,
        "page": WalkingRouteMapPage(
          language: preffered_lang ?? "English",
        )
      },
      {
        "title":
            checkLanguageCondition() ? "Scene Description" : "ದೃಶ್ಯ ವಿವರಣೆ",
        "icon": Icons.image_search,
        "page": SceneDescriptionScreen(
          language: preffered_lang ?? "English",
        )
      },
    ];
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(checkLanguageCondition() ? "ResQ" : "ರೆಸ್ಕ್ಯೂ"),
        centerTitle: true,
        actions: [
          // Add replay onboarding button in settings
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () async {
              // Reset and show onboarding again

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_completed', false);
              _checkAndShowOnboarding();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await initAll();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Status Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Mic Status Indicator
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _micStatus == MicStatus.listening
                                ? _pulseAnimation.value
                                : 1.0,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _getMicStatusColor(),
                                shape: BoxShape.circle,
                                boxShadow: _micStatus == MicStatus.listening
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _getMicStatusIcon(),
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getMicStatusText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Connect Glasses Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: Size(double.infinity, 80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      showStatusSnackBar(
                          context,
                          checkLanguageCondition()
                              ? "Connecting to the Glasses"
                              : "ಕನ್ನಡಕಗಳಿಗೆ ಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ",
                          "warning");
                      bool res = await checkConnectivity();
                      if (res) {
                        await TTSManager().speak(checkLanguageCondition()
                            ? "Connecting to your glasses \n\n Your glasses has been successfully connected"
                            : "ಕನ್ನಡಕಗಳಿಗೆ ಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ. \n\n ನಿಮ್ಮ ಕನ್ನಡಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಜೋಡಿಸಲಾಗಿದೆ");
                        // await Future.delayed(Duration(seconds: 4), () {
                        //   TTSManager().speak(checkLanguageCondition()
                        //       ? "Your glasses has been successfully connected"
                        //       : "ನಿಮ್ಮ ಕನ್ನಡಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಜೋಡಿಸಲಾಗಿದೆ");
                        // });
                        showStatusSnackBar(
                            context,
                            checkLanguageCondition()
                                ? "Glasses has been connected!"
                                : "ನಿಮ್ಮ ಕನ್ನಡಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಜೋಡಿಸಲಾಗಿದೆ",
                            "success");
                      }
                    },
                    icon: Icon(Icons.wifi_tethering,
                        color: Colors.white, size: 28),
                    label: Text(
                      checkLanguageCondition()
                          ? "Connect Glasses"
                          : "ಕನೆಕ್ಟ್ ಗ್ಲಾಸ್‌ಗಳು",
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Grid of 4 feature squares
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: features.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final feature = features[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => feature["page"]),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(feature["icon"],
                                  size: 50, color: Colors.white),
                              SizedBox(height: 10),
                              Text(
                                feature["title"],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 80), // Extra space for FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: 'sos_fab', // ✅ Add this line
                backgroundColor: Colors.red,
                icon: Icon(Icons.emergency, color: Colors.white),
                label: Text(
                    checkLanguageCondition() ? "SOS" : "ತುರ್ತು \nಪರಿಸ್ಥಿತಿ",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.visible)),
                onPressed: () async {
                  if (!_emergencyInProgress) {
                    // _triggerSOS();
                    bool wasTriggered = await setCounter();
                    if (wasTriggered) {
                      debugPrint("✅ Emergency SOS triggered");
                    } else {
                      debugPrint("❌ Emergency was cancelled");
                    }
                  } else {
                    TTSManager().speak(checkLanguageCondition()
                        ? "Emergency feature already in progress."
                        : "ತುರ್ತು ವೈಶಿಷ್ಟ್ಯವು ಈಗಾಗಲೇ ಪ್ರಗತಿಯಲ್ಲಿದೆ.");
                  }
                },
              ),
            ),
          ),
          SizedBox(width: 20), // Space between buttons

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: 'media_button_fab', // ✅ Add this line
                backgroundColor: _micStatus == MicStatus.listening
                    ? Colors.red
                    : Colors.deepPurple,

                icon: Icon(
                  _micStatus == MicStatus.listening ? Icons.stop : Icons.mic,
                  size: 24,
                  color: Colors.white,
                ),
                label: Text(
                  _micStatus == MicStatus.listening
                      ? checkLanguageCondition()
                          ? 'Stop Listening'
                          : 'ಕೇಳುವುದನ್ನು \nನಿಲ್ಲಿಸಿ'
                      : checkLanguageCondition()
                          ? 'Start Listening'
                          : 'ಕೇಳುವುದನ್ನು \nಪ್ರಾರಂಭಿಸಿ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () async {
                  // TODO: implement SOS
                  _manualStart();
                  // _handleListContacts();
                },
              ),
            ),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text("$title Module Coming Soon!")),
    );
  }
}
