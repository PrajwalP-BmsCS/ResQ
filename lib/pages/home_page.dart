import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:req_demo/pages/Flutter_STT/sts.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Navigation/nav_utility_functions.dart';
import 'package:req_demo/pages/Navigation/navigation.dart';
import 'package:req_demo/pages/OCR/ocr_ml_kit.dart';
import 'package:req_demo/pages/Object_Detection/object_detection.dart';
import 'package:req_demo/pages/Scene%20Description/scene_description.dart';
import 'package:req_demo/pages/Settings/practice.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';
import 'package:req_demo/pages/app_settings/app_settings.dart';
import 'package:req_demo/pages/home_page.dart';
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

  @override
  void initState() {
    super.initState();

    // To reset ONBOARDING
    resetOnboarding();

    initAll();

    // Show onboarding after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });

    // Setup animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup voice service listener for transcription
    // _setupVoiceServiceListener();

    // Setup method call handler
    _mediaChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "button_down":
          print("Button pressed down");
          break;

        case "single_tap":
          print("Single tap: ${call.arguments}");
          final duration = call.arguments?['duration'] ?? 0;
          _onSingleTap();
          break;

        case "long_press":
          print("Long press: ${call.arguments}");
          final duration = call.arguments?['duration'] ?? 0;
          _onLongPress();
          break;

        default:
          print("Unknown method: ${call.method}");
      }
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => OnboardingDialog(
          onPlayTTS: _playTTS,
          screen: "home",
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
        _statusMessage = 'Mic is not active. Long press to start listening.';
      });
    }
  }

  void _onLongPress() {
    print('onLongPress() called — starting recording');
    _startListening();
  }

  String voiceText = "";
  void _startListening() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = 'Listening... Speak now';
      _transcribedText = '';
      _finalTranscript = '';
    });

    try {
      VoiceService().startListening(onFinalResult: (text) {
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
        _statusMessage = 'Error starting mic: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _micStatus = MicStatus.processing;
      _statusMessage = 'Processing...';
    });

    try {
      voiceService.stopListening();

      _finalTranscript = _transcribedText;

      await Future.delayed(const Duration(milliseconds: 500));
      print("Final Transcript_STOP: $_finalTranscript");
      if (_finalTranscript.isNotEmpty) {
        // Await the intent result
        try {
          final intent_result = await get_user_intent(voiceText);
          print("Received intent result from API");
          print(intent_result);

          // if (intent_result.containsKey('intent')) {
          //   if (intent_result['contact_option'] == null) {
          //     intent_result['contact_option'] = 0;
          //   }

          //   navigateToNextScreen(
          //     intent_result['intent'],
          //     intent_result['listen_back'] ?? false, // 👈 safe default
          //     intent_result['contact_option'] ?? 0,
          //     intent_result['want_to_call'] ?? false, // 👈 safe default
          //   );
          // }

          // Start
          handleIntentResult(intent_result);

          print("Intent Result: $intent_result");
        } catch (e) {
          print("Intent API error: $e");
        }

        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = 'Tap and hold to start again.';
        });
      } else {
        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = 'No speech detected. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        _micStatus = MicStatus.error;
        _statusMessage = 'Error stopping mic: $e';
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
        contactManager.contacts = rawList
            .map((e) => EmergencyContact.fromJson(jsonDecode(e)))
            .toList();
      });
      print("Contacts loaded: ${contactManager.contacts.length}");
    }
  }

/*
  /// Main navigation function
  void navigateToNextScreen(
    String intent,
    bool listen_status,
    int contact_option,
    bool want_to_call,
    String? yesNoResponse,
  ) async {
    try {
      print(
          "🎯 Intent: $intent | Listen: $listen_status | Want Call: $want_to_call | Response: $yesNoResponse");

      // Handle Yes/No responses
      if (intent == "yes_no_response") {
        _handleYesNoResponse(yesNoResponse);
        return;
      }

      // Handle other intents only if not waiting for confirmation
      if (_waitingForCallConfirmation) {
        print(
            "⚠️ Currently waiting for call confirmation, ignoring other intents");
        return;
      }

      switch (intent) {
        case "connect_glasses":
          bool res = await checkConnectivity();
          if (res) {
            TTSManager().speak("Connecting to your glasses");
            // Add your connection logic here
          }
          break;

        case "scene_description":
          TTSManager().speak("Navigating to scene description screen");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => SceneDescriptionScreen()));
          break;

        case "object_detection":
          TTSManager().speak("Navigating to object detection screen");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => ObjectDetectionScreen()));
          break;

        case "ocr":
          TTSManager().speak("Starting text recognition");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => OCRHomePage()));
          break;

        case "navigation":
          TTSManager().speak("Navigating to navigation screen");
          // Navigator.push(context, MaterialPageRoute(builder: (_) => WalkingRouteMapPage()));
          break;

        case "list_contacts":
          _handleListContacts();
          break;

        case "call_contact":
          _handleCallContact(listen_status, contact_option, want_to_call);
          break;

        default:
          TTSManager().speak("Intent not recognized. Please try again.");
      }
    } catch (e) {
      print("❌ Error in navigateToNextScreen: $e");
      TTSManager().speak("An error occurred. Please try again.");
    }
  }

  /// Handle Yes/No responses
  void _handleYesNoResponse(String? response) async {
    if (_waitingForCallConfirmation) {
      if (response == "yes") {
        print("✅ User confirmed: Calling option $_pendingContactOption");
        TTSManager().speak("Calling $_pendingContactName now");

        await Future.delayed(Duration(seconds: 7), () {
          _makePhoneCall(_pendingContactOption!);
        });

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      } else if (response == "no") {
        print("❌ User declined call");
        TTSManager().speak("Call cancelled. How can I help you?");

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      }
    } else {
      // Handle generic yes/no without context
      if (response == "yes") {
        TTSManager().speak("Okay");
      } else if (response == "no") {
        TTSManager().speak("Understood");
      }
    }
  }

  /// Handle List Contacts intent
  void _handleListContacts() async {
    await initAll();

    final contacts = contactManager.contacts;

    print(contactManager.contacts);
    print("IN HANDLES");

    if (contacts.isEmpty) {
      TTSManager().speak("You have no contacts saved.");
      return;
    }

    StringBuffer contactList = StringBuffer();
    contactList.write("Your contacts are: ");

    for (int i = 0; i < contacts.length; i++) {
      contactList.write("Option ${i + 1}: ${contacts[i].name}. ");
    }

    contactList.write("Please say the option number you want to call.");
    TTSManager().speak(contactList.toString());
  }

  /// Handle Call Contact intent
  void _handleCallContact(
      bool listen_status, int contact_option, bool want_to_call) async {
    await initAll();

    print(
        "Handling call contact123: Option $contact_option | Want Call: $want_to_call | Listen: $listen_status");
    if (contact_option == 0) {
      print("⚠️ No contact option provided");
      TTSManager().speak("Please specify which contact to call.");
      return;
    }

    // Validate contact option
    if (contact_option < 1 || contact_option > contactManager.contacts.length) {
      print("❌ Invalid contact option: $contact_option");
      TTSManager().speak("Invalid contact option. Please try again.");
      return;
    }

    final contact = contactManager.contacts[contact_option - 1];

    if (want_to_call) {
      // User explicitly wants to call
      print("🔴 Direct call to option $contact_option: ${contact.name}");
      TTSManager().speak("Calling ${contact.name} now");

      await Future.delayed(Duration(seconds: 1), () {
        _makePhoneCall(contact_option);
      });
    } else if (listen_status) {
      // Ask for confirmation
      print("❓ Asking for confirmation before calling option $contact_option");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;
      _pendingContactName = contact.name;

      TTSManager().speak(
        "Do you want to call ${contact.name} at ${contact.phone}? Please say yes or no.",
      );
    } else {
      // Default: ask for confirmation
      print("❓ Default: Asking for confirmation");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;

      _pendingContactName = contact.name;

      TTSManager().speak(
        "Do you want to call ${contact.name}? Please say yes or no.",
      );
    }
  }

  /// Make the actual phone call
  // Future<void> _makePhoneCall(int contactOption) async {
  //   try {
  //     if (contactOption < 1 || contactOption > contactManager.contacts.length) {
  //       TTSManager().speak("Invalid contact option.");
  //       return;
  //     }

  //     final contact = contactManager.contacts[contactOption - 1];
  //     final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

  //     print("Making call to ${phoneNumber.length} via SOS method");

  //     if (phoneNumber.isEmpty) {
  //       TTSManager().speak("Phone number not available for this contact.");
  //       return;
  //     }
  //     // try {
  //     //   if (contactOption < 1 || contactOption > contactManager.contacts.length) {
  //     //     TTSManager().speak("Invalid contact option.");
  //     //     return;
  //     //   }

  //     //   final contact = contactManager.contacts[contactOption - 1];
  //     //   final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

  //     //   if (phoneNumber.isEmpty) {
  //     //     TTSManager().speak("Phone number not available for this contact.");
  //     //     return;
  //     //   }

  //     final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

  //     if (await canLaunchUrl(launchUri)) {
  //       await launchUrl(launchUri);
  //       print("✅ Call initiated to ${contact.name}");
  //     } else {
  //       TTSManager().speak("Could not make the call. Please try again.");
  //     }
  //   } catch (e) {
  //     print("❌ Error making call: $e");
  //     TTSManager().speak("An error occurred while making the call.");
  //   }
  // }


*/
  Future<void> _makePhoneCall(int contactOption, bool sos) async {
    try {
      if (contactOption < 1 || contactOption > contactManager.contacts.length) {
        TTSManager().speak("Invalid contact option.");
        return;
      }

      final contact = contactManager.contacts[contactOption - 1];
      final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (sos) {
        await TTSManager().speak("Calling ${contact.name}");
      }

      if (phoneNumber.isEmpty) {
        TTSManager().speak("Phone number not available for this contact.");
        return;
      }

      // ✅ Request runtime permission
      if (await Permission.phone.request().isDenied) {
        TTSManager().speak("Please enable phone permission to make a call.");
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

      print("✅ Native call requested to ${contact.name} ($phoneNumber)");
    } catch (e) {
      print("❌ Error making call: $e");
      TTSManager().speak("An error occurred while making the call.");
    }
  }

// Add these state variables
  bool _emergencyInProgress = false;
  bool _cancelEmergency = false;
  Timer? _emergencyListeningTimer;

  /// Emergency countdown with continuous cancel listening
  Future<bool> setCounter() async {
    _cancelEmergency = false;
    _emergencyInProgress = true;

    // Speak initial message
    await TTSManager().speak(
        "Emergency feature has been enabled. It will trigger in 10 seconds. Say cancel to stop.");

    // Wait for TTS to finish before starting listening
    await Future.delayed(const Duration(milliseconds: 500));

    // Start continuous listening for cancel command
    _startContinuousEmergencyListener();

    // Countdown loop
    for (int i = 10; i > 0; i--) {
      if (_cancelEmergency) {
        await _stopEmergencyListener();
        await TTSManager().speak("Emergency has been cancelled.");
        debugPrint("❌ Emergency cancelled by user.");
        _emergencyInProgress = false;

        setState(() {
          _micStatus = MicStatus.idle;
          _statusMessage = 'Emergency cancelled. Press to start listening.';
        });
        return false;
      }

      await TTSManager().speak("$i");
      debugPrint("⏳ Countdown: $i");

      // Give time for user to say "cancel" during countdown
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Final check before triggering
    if (_cancelEmergency) {
      await _stopEmergencyListener();
      await TTSManager().speak("Emergency has been cancelled.");
      _emergencyInProgress = false;

      setState(() {
        _micStatus = MicStatus.idle;
        _statusMessage = 'Emergency cancelled.';
      });
      return false;
    }

    await _stopEmergencyListener();
    await TTSManager().speak("Triggering emergency action now.");
    await _triggerSOS();

    _emergencyInProgress = false;

    setState(() {
      _micStatus = MicStatus.idle;
      _statusMessage = 'Emergency action completed.';
    });

    return true;
  }

  /// Start continuous listening that restarts automatically
  void _startContinuousEmergencyListener() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = 'Say "CANCEL" to stop emergency';
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
              _statusMessage = 'Cancelling emergency...';
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
        _statusMessage = 'Press and hold to start listening...';
      });
    } catch (e) {
      debugPrint("❌ Error stopping emergency listener: $e");
    }
  }

  /// Alternative: Use a periodic timer to keep checking
  void _startContinuousEmergencyListenerWithTimer() {
    setState(() {
      _micStatus = MicStatus.listening;
      _statusMessage = 'Say "CANCEL" to stop emergency';
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
              _statusMessage = 'Cancelling emergency...';
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
    );
  }

  void navigateToNextScreen(
    String intent,
    bool listen_status,
    int contact_option,
    bool want_to_call,
    bool want_to_share,
    String? yesNoResponse,
  ) async {
    try {
      print(
          "🎯 Intent: $intent | Listen: $listen_status | Want Call: $want_to_call | Want Share: $want_to_share | Response: $yesNoResponse");

      // Handle Yes/No responses
      if (intent == "yes_no_response") {
        _handleYesNoResponse(yesNoResponse);
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
        TTSManager().speak(
            "Currently waiting for your confirmation, for earlier $s request. Please tell No if you want to cancel the request.");
        return;
      }

      switch (intent) {
        case "connect_glasses":
          bool res = await checkConnectivity();
          if (res) {
            TTSManager().speak("Connecting to your glasses");
            await Future.delayed(Duration(seconds: 2), () {
              TTSManager()
                  .speak("Your glasses has been successfully connected");
            });
          }
          break;

        case "scene_description":
          TTSManager().speak("Navigating to scene description screen");
          break;

        case "object_detection":
          TTSManager().speak("Navigating to object detection screen");
          break;

        case "ocr":
          TTSManager().speak("Starting text recognition");
          break;

        case "navigation":
          TTSManager().speak("Navigating to navigation screen");
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => WalkingRouteMapPage()));
          break;

        case "list_contacts":
          _handleListContacts();
          break;

        case "call_contact":
          _handleCallContact(listen_status, contact_option, want_to_call);
          break;

        case "list_share_contacts":
          _handleListShareContacts();
          break;

        case "share_location":
          _handleShareLocation(listen_status, contact_option, want_to_share);
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
            TTSManager().speak("Emergency already in progress.");
          }

          break;

        default:
          TTSManager().speak("Intent not recognized. Please try again.");
      }
    } catch (e) {
      print("❌ Error in navigateToNextScreen: $e");
      TTSManager().speak("An error occurred. Please try again.");
    }
  }

  /// Handle Yes/No responses for both call and share
  void _handleYesNoResponse(String? response) async {
    if (_waitingForCallConfirmation) {
      if (response == "yes") {
        print("✅ User confirmed: Calling option $_pendingContactOption");
        TTSManager().speak("Calling $_pendingContactName now");

        await Future.delayed(Duration(seconds: 1), () {
          _makePhoneCall(_pendingContactOption!, false);
        });

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      } else if (response == "no") {
        print("❌ User declined call");
        TTSManager().speak("Call cancelled. How can I help you?");

        // Reset state
        _waitingForCallConfirmation = false;
        _pendingContactOption = null;
        _pendingContactName = null;
      }
    } else if (_waitingForShareConfirmation) {
      if (response == "yes") {
        print(
            "✅ User confirmed: Sharing location with option $_pendingShareContactOption");
        TTSManager()
            .speak("Sharing your location with $_pendingShareContactName now");

        await Future.delayed(Duration(seconds: 1), () {
          _shareLocationWithContact(_pendingShareContactOption!);
        });

        // Reset state
        _waitingForShareConfirmation = false;
        _pendingShareContactOption = null;
        _pendingShareContactName = null;
      } else if (response == "no") {
        print("❌ User declined share");
        TTSManager().speak("Location sharing cancelled. How can I help you?");

        // Reset state
        _waitingForShareConfirmation = false;
        _pendingShareContactOption = null;
        _pendingShareContactName = null;
      }
    } else {
      // Handle generic yes/no without context
      if (response == "yes") {
        TTSManager().speak("Okay");
      } else if (response == "no") {
        TTSManager().speak("Understood");
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
      TTSManager().speak("You have no contacts saved.");
      return;
    }

    StringBuffer contactList = StringBuffer();
    contactList.write("Your contacts are: ");

    for (int i = 0; i < callContacts.length; i++) {
      contactList.write("Option ${i + 1}: ${callContacts[i].name}. ");
    }

    contactList.write("Please say the option number you want to call.");
    TTSManager().speak(contactList.toString());
  }

  /// Handle Call Contact intent
  void _handleCallContact(
      bool listen_status, int contact_option, bool want_to_call) async {
    await initAll();

    final contacts = contactManager.contacts;
    final locationContacts =
        contacts.where((c) => c.allowCall == true).toList();

    print(
        "Handling call contact: Option $contact_option | Want Call: $want_to_call | Listen: $listen_status");

    if (contact_option == 0) {
      print("⚠️ No contact option provided");
      TTSManager().speak("Please specify which contact to call.");
      return;
    }

    // Validate contact option
    if (contact_option < 1 || contact_option > contactManager.contacts.length) {
      print("❌ Invalid contact option: $contact_option");
      TTSManager().speak("Invalid contact option. Please try again.");
      return;
    }

    final contact = locationContacts[contact_option - 1];

    if (want_to_call) {
      print("🔴 Direct call to option $contact_option: ${contact.name}");
      TTSManager().speak("Calling ${contact.name} now");

      await Future.delayed(Duration(seconds: 2), () {
        _makePhoneCall(contact_option, false);
      });
    } else if (listen_status) {
      print("❓ Asking for confirmation before calling option $contact_option");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;
      _pendingContactName = contact.name;

      TTSManager().speak(
        "Do you want to call ${contact.name} at ${contact.phone}? Please say yes or no.",
      );
    } else {
      print("❓ Default: Asking for confirmation");
      _waitingForCallConfirmation = true;
      _pendingContactOption = contact_option;
      _pendingContactName = contact.name;

      TTSManager().speak(
        "Do you want to call ${contact.name}? Please say yes or no.",
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
      TTSManager().speak("You have no contacts saved.");
      return;
    }

    StringBuffer contactList = StringBuffer();
    contactList.write("Your contacts are: ");

    for (int i = 0; i < locationContacts.length; i++) {
      contactList.write("Option ${i + 1}: ${locationContacts[i].name}. ");
    }

    contactList.write("Please say the option number.");
    TTSManager().speak(contactList.toString());
  }

  /// Handle Share Location intent
  void _handleShareLocation(
      bool listen_status, int contact_option, bool want_to_share) async {
    await initAll();

    final contacts = contactManager.contacts;
    final locationContacts = contacts.where((c) => c.location == true).toList();

    print(
        "Handling share location: Option $contact_option | Want Share: $want_to_share | Listen: $listen_status");

    // Handle share with all contacts
    // if (contact_option == -1) {
    //   if (want_to_share) {
    //     print("🌍 Sharing location with all contacts");
    //     TTSManager().speak("Sharing your location with all contacts now");

    //     await Future.delayed(Duration(seconds: 1), () {
    //       _shareLocationWithAll();
    //     });
    //   } else {
    //     print("❓ Asking for confirmation before sharing with all");
    //     _waitingForShareConfirmation = true;
    //     _pendingShareContactOption = -1;
    //     _pendingShareContactName = "all contacts";

    //     TTSManager().speak(
    //       "Do you want to share your location with all contacts? Please say yes or no.",
    //     );
    //   }
    //   return;
    // }

    if (contact_option == 0) {
      print("⚠️ No contact option provided");
      TTSManager()
          .speak("Please specify which contact to share your location with.");
      return;
    }

    // Validate contact option
    if (contact_option < 1 || contact_option > contactManager.contacts.length) {
      print("❌ Invalid contact option: $contact_option");
      TTSManager().speak("Invalid contact option. Please try again.");
      return;
    }

    final contact = locationContacts[contact_option - 1];

    if (want_to_share) {
      print("🌍 Direct share to option $contact_option: ${contact.name}");
      TTSManager().speak("Sharing your location with ${contact.name} now");

      await Future.delayed(Duration(seconds: 1), () {
        _shareLocationWithContact(contact_option);
      });
    } else if (listen_status) {
      print(
          "❓ Asking for confirmation before sharing with option $contact_option");
      _waitingForShareConfirmation = true;
      _pendingShareContactOption = contact_option;
      _pendingShareContactName = contact.name;

      TTSManager().speak(
        "Do you want to share your location with ${contact.name}? Please say yes or no.",
      );
    } else {
      print("❓ Default: Asking for confirmation");
      _waitingForShareConfirmation = true;
      _pendingShareContactOption = contact_option;
      _pendingShareContactName = contact.name;

      TTSManager().speak(
        "Do you want to share your location with ${contact.name}? Please say yes or no.",
      );
    }
  }

  // /// Make the actual phone call
  // Future<void> _makePhoneCall(int contactOption) async {
  //   try {
  //     if (contactOption < 1 || contactOption > contactManager.contacts.length) {
  //       TTSManager().speak("Invalid contact option.");
  //       return;
  //     }

  //     final contact = contactManager.contacts[contactOption - 1];
  //     final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

  //     if (phoneNumber.isEmpty) {
  //       TTSManager().speak("Phone number not available for this contact.");
  //       return;
  //     }

  //     final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

  //     if (await canLaunchUrl(launchUri)) {
  //       await launchUrl(launchUri);
  //       print("✅ Call initiated to ${contact.name}");
  //     } else {
  //       TTSManager().speak("Could not make the call. Please try again.");
  //     }
  //   } catch (e) {
  //     print("❌ Error making call: $e");
  //     TTSManager().speak("An error occurred while making the call.");
  //   }
  // }

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
        return "https://www.google.com/maps?q=${locData.latitude},${locData.longitude}";
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }

  /// Share location with specific contact
  Future<void> _shareLocationWithContact(int contactOption) async {
    try {
      // if (contactOption == -1) {
      //   _shareLocationWithAll();
      //   return;
      // }

      if (contactOption < 1 || contactOption > contactManager.contacts.length) {
        TTSManager().speak("Invalid contact option.");
        return;
      }

      final contacts = contactManager.contacts;
      final locationContacts =
          contacts.where((c) => c.location == true).toList();

      final contact = locationContacts[contactOption - 1];

      // Share via SMS or WhatsApp
      final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (phoneNumber.isNotEmpty) {
        // You can use url_launcher to open WhatsApp, SMS, or other apps
        // Example: WhatsApp
        final shareMessage = await _getLocationLink();
        if (shareMessage != null) {
          final Uri whatsappUri = Uri.parse(
              "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareMessage)}");

          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri);
            print("✅ Location shared with ${contact.name} via WhatsApp");
            TTSManager().speak("Location shared with ${contact.name}");
          } else {
            // Fallback: SMS
            final Uri smsUri = Uri.parse(
                "sms:$phoneNumber?body=${Uri.encodeComponent(shareMessage)}");
            if (await canLaunchUrl(smsUri)) {
              await launchUrl(smsUri);
              print("✅ Location shared with ${contact.name} via SMS");
              TTSManager().speak("Location shared with ${contact.name}");
            }
          }
        }
      } else {
        TTSManager().speak("Phone number not available for this contact.");
      }
    } catch (e) {
      print("❌ Error sharing location: $e");
      TTSManager().speak("An error occurred while sharing your location.");
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
    store = await LocalStore.getInstance();
    print("LocalStore initialized: $store");

    prefsMap = store.getGeneralPrefs();

    if (prefsMap == {}) {
      prefsMap['defaultAction'] = "call";
    }

    print("✅ Loaded prefsMap: $prefsMap");

    final action = prefsMap['defaultAction'];

    if (action == "Call") {
      _makePhoneCall(1, true);
    } else if (action == "Share Location") {
      _shareLocationWithContact(1);
    }
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
        return 'IDLE';
      case MicStatus.listening:
        return 'LISTENING';
      case MicStatus.processing:
        return 'PROCESSING';
      case MicStatus.error:
        return 'ERROR';
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
    _mediaChannel.setMethodCallHandler(null);
    _pulseController.dispose();
    _emergencyListeningTimer?.cancel();
    _stopEmergencyListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        "title": "Object Detection",
        "icon": Icons.camera_alt,
        "page": ObjectDetectionScreen()
      },
      {"title": "OCR", "icon": Icons.text_fields, "page": OCRHomePage()},
      {
        "title": "Navigation",
        "icon": Icons.navigation,
        "page": WalkingRouteMapPage()
      },
      {
        "title": "Scene Description",
        "icon": Icons.image_search,
        "page": SceneDescriptionScreen()
      },
      {
        "title": "Practice Area",
        "icon": Icons.image_search,
        "page": MediaButtonTestPage(
          screen: "home",
        )
      },
    ];
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("ResQ"),
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
        child: SingleChildScrollView(
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Connecting to glasses...")),
                    );
                  },
                  icon:
                      Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                  label: Text(
                    "Connect Glasses",
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
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.extended(
              heroTag: 'sos_fab', // ✅ Add this line
              backgroundColor: Colors.red,
              icon: Icon(Icons.emergency, color: Colors.white),
              label: Text("SOS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () async {
                _triggerSOS();
              },
            ),
          ),
          SizedBox(width: 20), // Space between buttons

          Padding(
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
                    ? 'Stop Listening'
                    : 'Start Listening',
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
