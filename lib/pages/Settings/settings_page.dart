import 'dart:async';
import 'dart:convert';
import 'dart:io'; // <-- add this at the top of your Dart file
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:req_demo/pages/Settings/debug_data.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Navigation/set_current_location.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

// ------------------------- Models -------------------------
class EmergencyContact {
  String id;
  String name;
  String phone;
  String address;
  bool location;
  bool allowCall;
  bool allowLocation;
  String? latitude; // <-- new
  String? longitude; // <-- new

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
    this.allowCall = false,
    this.allowLocation = false,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'location': location,
        'allowCall': allowCall,
        'allowLocation': allowLocation,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] ?? UniqueKey().toString(),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        location: j['location'] ?? '',
        allowCall: j['allowCall'] ?? false,
        allowLocation: j['allowLocation'] ?? false,
        latitude: j['latitude'] ?? '',
        longitude: j['longitude'] ?? '',
      );
}

class MedicalInfo {
  String bloodGroup;
  String allergies;
  String medications;
  String doctorName;
  String doctorPhone;

  MedicalInfo({
    this.bloodGroup = '',
    this.allergies = '',
    this.medications = '',
    this.doctorName = '',
    this.doctorPhone = '',
  });

  bool isEmpty() {
    return bloodGroup.isEmpty &&
        allergies.isEmpty &&
        medications.isEmpty &&
        doctorName.isEmpty &&
        doctorPhone.isEmpty;
  }

  Map<String, dynamic> toJson() => {
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'medications': medications,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
      };

  factory MedicalInfo.fromJson(Map<String, dynamic> j) => MedicalInfo(
        bloodGroup: j['bloodGroup'] ?? '',
        allergies: j['allergies'] ?? '',
        medications: j['medications'] ?? '',
        doctorName: j['doctorName'] ?? '',
        doctorPhone: j['doctorPhone'] ?? '',
      );
}

class SOSLog {
  String id;
  DateTime time;
  List<String> contacted; // list of contact ids
  String location;
  SOSLog(
      {required this.id,
      required this.time,
      required this.contacted,
      required this.location});

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'contacted': contacted,
        'location': location,
      };

  factory SOSLog.fromJson(Map<String, dynamic> j) => SOSLog(
        id: j['id'] ?? UniqueKey().toString(),
        time: DateTime.parse(j['time']),
        contacted: List<String>.from(j['contacted'] ?? []),
        location: j['location'] ?? '',
      );
}

Future<void> callNumber(String number) async {
  await FlutterPhoneDirectCaller.callNumber(number);
}

/// Navigate using Google Maps
// Future<void> _navigateToLocation(EmergencyContact c) async {
//   final url = Uri.parse(
//       "https://www.google.com/maps/dir/?api=1&destination=${c.latitude},${c.longitude}");
//   if (await canLaunchUrl(url)) {
//     await launchUrl(url);
//   } else {
//     debugPrint("Could not launch Maps for ${c.name}");
//   }
// }

// ------------------------- Storage Helpers -------------------------
class LocalStore {
  static const _contactsKey = 'emergency_contacts';
  static const _medicalKey = 'medical_v1';
  static const _prefsKey = 'prefs_v1';
  static const _sosLogsKey = 'soslogs_v1';

  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  LocalStore._(this.prefs);

  static Future<LocalStore> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  // ---------------- Contacts ----------------
  List<EmergencyContact> getContacts() {
    final raw = prefs.getStringList(_contactsKey) ?? [];
    return raw.map((e) => EmergencyContact.fromJson(jsonDecode(e))).toList();
  }

  Future<void> setContacts(List<EmergencyContact> list) async {
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_contactsKey, raw);
  }

  // ---------------- Medical Info ----------------
  MedicalInfo getMedical() {
    final raw = prefs.getString(_medicalKey);
    if (raw == null) return MedicalInfo();
    return MedicalInfo.fromJson(jsonDecode(raw));
  }

  Future<void> setMedical(MedicalInfo m) async {
    await prefs.setString(_medicalKey, jsonEncode(m.toJson()));
  }

  // ---------------- General Preferences ----------------
  Map<String, dynamic> getGeneralPrefs() {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return {}; // return empty only if nothing stored
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> setGeneralPrefs(Map<String, dynamic> p) async {
    await prefs.setString(_prefsKey, jsonEncode(p));
  }

  Future<void> clearGeneralPrefs() async {
    await prefs.remove(_prefsKey);
  }

  // ---------------- SOS Logs ----------------
  List<SOSLog> getSosLogs() {
    final raw = prefs.getStringList(_sosLogsKey) ?? [];
    return raw.map((e) => SOSLog.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addSosLog(SOSLog log) async {
    final list = getSosLogs();
    list.insert(0, log); // newest first
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_sosLogsKey, raw);
  }

  // ---------------- Secure PIN ----------------
  Future<void> setPin(String pin) async {
    await secureStorage.write(key: 'user_pin', value: pin);
  }

  Future<String?> getPin() async {
    return await secureStorage.read(key: 'user_pin');
  }

  Future<void> deletePin() async {
    await secureStorage.delete(key: 'user_pin');
  }
}

Future<void> getLocationAndShare() async {
  Location location = Location();

  bool serviceEnabled;
  PermissionStatus permissionGranted;

  serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) return;
  }

  permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) return;
  }

  LocationData locData = await location.getLocation();

  double? lat = locData.latitude;
  double? lon = locData.longitude;

  if (lat != null && lon != null) {
    String googleMapsUrl = "https://www.google.com/maps?q=$lat,$lon";

    print("Google Maps Link: $googleMapsUrl");

    // TODO: send this via SMS
  }
}

// ------------------------- Settings Page -------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late LocalStore store;
  bool loading = true;
  List<EmergencyContact> contacts = [];
  MedicalInfo medical = MedicalInfo();
  Map<String, dynamic> prefsMap = {};
  List<SOSLog> logs = [];

  final FlutterTts tts = FlutterTts();

  static const platform = MethodChannel('onnx_channel');

  bool isDetectingObstacle = false;
  bool continuousObstacleDetection = false;
  Timer? obstacleTimer;
  File? lastCapturedFrame;
  List<dynamic> lastDetections = [];

  final String esp32Url = '$espBaseUrl/capture';

  @override
  void initState() {
    super.initState();
    _initAll();
  }

// USE ONLY this consistent method:

  /// Save location to a contact
  void _setContactLocation(int index, LatLng pos) {
    setState(() {
      contacts[index].latitude = pos.latitude.toString();
      contacts[index].longitude = pos.longitude.toString();
      contacts[index].location = true;
    });

    // Save using the LocalStore (consistent with how you load)
    store.setContacts(contacts);

    debugPrint(
        "Updated location for ${contacts[index].name}: ${pos.latitude}, ${pos.longitude}");
    debugPrint("Contacts saved to storage: $contacts");
  }

  /// Load contacts (use this in initAll)
  Future<void> _loadContactsFromLocalDb() async {
    final loadedContacts = store.getContacts();
    setState(() {
      contacts = loadedContacts;
    });
    debugPrint("Contacts loaded from storage: $contacts");
  }

  /// Initialize all data
  Future<void> _initAll() async {
    store = await LocalStore.getInstance();
    print("LocalStore initialized: $store");

    // Load contacts using LocalStore
    contacts = store.getContacts();
    medical = store.getMedical();
    prefsMap = store.getGeneralPrefs();
    logs = store.getSosLogs();

    print("✅ Loaded contacts: $contacts");
    print("✅ Loaded medical: $medical");
    print("✅ Loaded prefsMap: $prefsMap");
    print("✅ Loaded logs: $logs");

    // Verify location data was saved
    for (int i = 0; i < contacts.length; i++) {
      if (contacts[i].latitude != null && contacts[i].longitude != null) {
        print("Contact ${contacts[i].name} has location: "
            "${contacts[i].latitude}, ${contacts[i].longitude}");
      }
    }

    // Initialize TTS
    // await tts.setLanguage('en-US');
    // await tts.setSpeechRate(0.45);

    setState(() => loading = false);
  }

  /// Add contact using LocalStore
  Future<void> _addContact() async {
    final newContact = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => const ContactDialog(),
    );
    if (newContact != null) {
      setState(() => contacts.add(newContact));
      await store.setContacts(contacts); // Use LocalStore
      debugPrint("Contact added and saved");
    }
  }

  /// Edit contact using LocalStore
  Future<void> _editContact(int idx) async {
    final updated = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => ContactDialog(existing: contacts[idx]),
    );
    if (updated != null) {
      setState(() => contacts[idx] = updated);
      await store.setContacts(contacts); // Use LocalStore
      debugPrint("Contact updated and saved");
    }
  }

  /// Remove contact using LocalStore
  Future<void> _removeContact(int idx) async {
    setState(() => contacts.removeAt(idx));
    await store.setContacts(contacts); // Use LocalStore
    debugPrint("Contact removed and saved");
  }

  /// Reorder contacts using LocalStore
  void _reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final c = contacts.removeAt(oldIndex);
      contacts.insert(newIndex, c);
    });
    store.setContacts(contacts); // Use LocalStore
    debugPrint("Contacts reordered and saved");
  }

  /// Navigate using Google Maps
  Future<void> _navigateToLocation(EmergencyContact c) async {
    final double lat = double.parse(c.latitude!);
    final double long = double.parse(c.longitude!);
    final Uri uri = Uri.parse(
      'google.navigation:q=$lat,$long&mode=w', // 'w' = walking
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication, // ensures it opens outside Flutter
      );

      TTSManager().speak(checkLanguageCondition()
          ? "Your route is being Fetched. Please wait."
          : "ನಿಮ್ಮ ಮಾರ್ಗವನ್ನು ತರಲಾಗುತ್ತಿದೆ. ದಯವಿಟ್ಟು ನಿರೀಕ್ಷಿಸಿ.");

      await Future.delayed(const Duration(seconds: 4), () async {
        TTSManager().speak(checkLanguageCondition()
            ? "Navigation started to the selected location."
            : "ಆಯ್ಕೆ ಮಾಡಿದ ಸ್ಥಳಕ್ಕೆ ನ್ಯಾವಿಗೇಷನ್ ಪ್ರಾರಂಭವಾಗಿದೆ.");
      });
    } else {
      print("❌ Could not launch Maps for psrv");
    }
  }

  Future<void> _saveMedical() async {
    await store.setMedical(medical);
    await tts.speak(checkLanguageCondition()
        ? 'Medical information saved'
        : 'ವೈದ್ಯಕೀಯ ಮಾಹಿತಿಯನ್ನು ಉಳಿಸಲಾಗಿದೆ');
  }

  Future<void> _savePrefs() async {
    await store.setGeneralPrefs(prefsMap);
    await TTSManager().speak(checkLanguageCondition()
        ? 'Preferences saved'
        : 'ಆದ್ಯತೆಗಳನ್ನು ಉಳಿಸಲಾಗಿದೆ');
  }

// // Add contact
//   Future<void> _addContact() async {
//     final newContact = await showDialog<EmergencyContact>(
//       context: context,
//       builder: (_) => const ContactDialog(),
//     );
//     if (newContact != null) {
//       setState(() => contacts.add(newContact));
//       await _saveContacts();
//     }
//   }

// // Edit contact
//   Future<void> _editContact(int idx) async {
//     final updated = await showDialog<EmergencyContact>(
//       context: context,
//       builder: (_) => ContactDialog(existing: contacts[idx]),
//     );
//     if (updated != null) {
//       setState(() => contacts[idx] = updated);
//       await _saveContacts();
//     }
//   }

// // Remove contact
//   Future<void> _removeContact(int idx) async {
//     setState(() => contacts.removeAt(idx));
//     await _saveContacts();
//   }

// // Reorder contacts
//   void _reorderContacts(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) newIndex -= 1;
//       final c = contacts.removeAt(oldIndex);
//       contacts.insert(newIndex, c);
//     });
//     _saveContacts();
//   }

// To actually make a call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint("Could not launch $phoneNumber");
    }
  }

  Future<void> callWithSim(String phone, {int? subscriptionId}) async {
    try {
      const platform = MethodChannel('onnx_channel');
      await platform.invokeMethod('callWithSim', {
        'phone': phone,
        'subscriptionId': subscriptionId, // optional
      });
    } on PlatformException catch (e) {
      debugPrint('Error calling via SOS: $e');
    }
  }

  Future<void> _setPin() async {
    final pin = await showDialog<String?>(
        context: context, builder: (ctx) => PinDialog());
    if (pin != null) {
      await store.setPin(pin);
      await tts.speak('PIN set successfully');
    }
  }

  Future<void> _removePin() async {
    await store.deletePin();
    await tts.speak('PIN removed');
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete All Preferences"),
        content: const Text(
          "Are you sure you want to permanently delete all saved preferences and contacts? "
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // clears all keys/values permanently
      setState(() {
        contacts.clear(); // clear local list as well
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All preferences deleted successfully.")),
      );
    }
  }

  Future<void> _detectObstacle({bool speakResults = true}) async {
    if (isDetectingObstacle) return; // prevent overlap
    setState(() => isDetectingObstacle = true);

    try {
      final response = await http.get(Uri.parse(esp32Url));
      if (response.statusCode != 200) {
        throw Exception('Failed to capture from ESP32');
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/obstacle_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(response.bodyBytes);

      final List<dynamic> result =
          await platform.invokeMethod('runYOLO', {'path': imageFile.path});

      setState(() {
        lastCapturedFrame = imageFile;
        lastDetections = result;
        isDetectingObstacle = false;
      });

      if (speakResults) {
        if (result.isNotEmpty) {
          String detected = result.join(", ");
          await tts.speak("I see $detected ahead");
        } else {
          await tts.speak("No obstacle detected");
        }
      }
    } catch (e) {
      print("❌ Error detecting obstacle: $e");
      setState(() => isDetectingObstacle = false);
      if (speakResults) await tts.speak("Error detecting obstacle");
    }
  }

  void _startContinuousObstacleDetection() {
    _stopContinuousObstacleDetection(); // just to reset
    continuousObstacleDetection = true;
    obstacleTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (!continuousObstacleDetection) {
        timer.cancel();
        return;
      }
      await _detectObstacle(speakResults: false);

      if (lastDetections.contains("car")) {
        await tts.speak("Car detected ahead, please be careful");
      } else if (lastDetections.contains("truck")) {
        await tts.speak("Truck detected ahead, please be careful");
      }
    });
  }

  void _stopContinuousObstacleDetection() {
    continuousObstacleDetection = false;
    obstacleTimer?.cancel();
  }

  // UI builder helpers below
  Widget sectionCard(
      {required Widget child,
      required String title,
      String? subtitle,
      required String message}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        overflow: TextOverflow.visible,
                      )),
                ),
                IconButton(
                    onPressed: () async {
                      await TTSManager().speak(message);
                    },
                    icon: Icon(
                      Icons.mic,
                      size: 35,
                    ))
              ],
            ),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  bool checkLanguageCondition() {
    return prefsMap['lang'] == "English";
  }

  Future<String?> _getLocationLink() async {
    try {
      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return null;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return null;
      }

      LocationData locData = await location.getLocation();
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
  Future<void> _shareLocationWithContact(
      int contactOption, final contact) async {
    try {
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

            await TTSManager().speak(checkLanguageCondition()
                ? "Location shared with ${contact.name}."
                : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ.");
          } else {
            // Fallback: SMS
            final Uri smsUri = Uri.parse(
                "sms:$phoneNumber?body=${Uri.encodeComponent(shareMessage)}");
            if (await canLaunchUrl(smsUri)) {
              await launchUrl(smsUri);
              print("✅ Location shared with ${contact.name} via SMS");
              await TTSManager().speak(checkLanguageCondition()
                  ? "Location shared with ${contact.name}"
                  : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${contact.name} ನೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ.");
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

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(
        backgroundColor: Colors.redAccent,
      )));

    return Scaffold(
      appBar: AppBar(
          title: Text(checkLanguageCondition() ? 'Preferences' : "ಆದ್ಯತೆಗಳು",
              style: TextStyle(fontSize: 22)),
          centerTitle: true),
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              children: [
                // sectionCard(
                //   message: checkLanguageCondition()
                //       ? "In this section you can choose to display onboarding instructions on every launch of Application"
                //       : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ಅಪ್ಲಿಕೇಶನ್‌ನ ಪ್ರತಿ ಉಡಾವಣೆಯಲ್ಲಿ ಆನ್‌ಬೋರ್ಡಿಂಗ್ ಸೂಚನೆಗಳನ್ನು ಪ್ರದರ್ಶಿಸಲು ಆಯ್ಕೆ ಮಾಡಬಹುದು.",
                //   title: checkLanguageCondition()
                //       ? 'Onboard Instructions'
                //       : 'ಆನ್ಬೋರ್ಡ್ ಸೂಚನೆಗಳು',
                //   subtitle: checkLanguageCondition()
                //       ? 'Choose Yes or No in the dropdown given below.'
                //       : 'ಕೆಳಗೆ ನೀಡಲಾದ ಡ್ರಾಪ್‌ಡೌನ್‌ನಲ್ಲಿ ಹೌದು ಅಥವಾ ಇಲ್ಲ ಆಯ್ಕೆಮಾಡಿ.',
                //   child: Column(
                //     children: [
                //       ListTile(
                //         leading: const Icon(Icons.warning, size: 36),
                //         title: Text(
                //             checkLanguageCondition()
                //                 ? 'Show Onboard Instructions'
                //                 : 'ಆನ್‌ಬೋರ್ಡ್ ಸೂಚನೆಗಳನ್ನು ತೋರಿಸಿ',
                //             style: TextStyle(fontSize: 18)),
                //         trailing: DropdownButton<String>(
                //           value: prefsMap['onboarding_completed'] ?? false
                //               ? "Yes"
                //               : "No",
                //           items: const [
                //             "Yes",
                //             "No",
                //           ]
                //               .map((e) =>
                //                   DropdownMenuItem(value: e, child: Text(e)))
                //               .toList(),
                //           onChanged: (v) {
                //             setState(() {
                //               if (v == "Yes") {
                //                 prefsMap['onboarding_completed'] = false;
                //               } else {
                //                 prefsMap['onboarding_completed'] = true;
                //               }
                //             });
                //             _savePrefs();
                //           },
                //         ),
                //       ),
                //       const SizedBox(height: 8),
                //     ],
                //   ),
                // ),

                sectionCard(
                  message: checkLanguageCondition()
                      ? "In this section, you can manage onboarding preferences and set your display name."
                      : "ಈ ವಿಭಾಗದಲ್ಲಿ, ನೀವು ಆನ್‌ಬೋರ್ಡಿಂಗ್ ಆಯ್ಕೆಗಳನ್ನು ನಿರ್ವಹಿಸಬಹುದು ಮತ್ತು ನಿಮ್ಮ ಪ್ರದರ್ಶನ ಹೆಸರನ್ನು ಹೊಂದಿಸಬಹುದು.",
                  title: checkLanguageCondition()
                      ? 'Onboarding & Profile'
                      : 'ಆನ್‌ಬೋರ್ಡಿಂಗ್ ಮತ್ತು ಪ್ರೊಫೈಲ್',
                  subtitle: checkLanguageCondition()
                      ? 'Update your name and choose if onboarding instructions should be shown.'
                      : 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನವೀಕರಿಸಿ ಮತ್ತು ಆನ್‌ಬೋರ್ಡಿಂಗ್ ಸೂಚನೆಗಳನ್ನು ತೋರಿಸಬೇಕೇ ಎಂಬುದನ್ನು ಆಯ್ಕೆಮಾಡಿ.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🧍‍♂️ User Name Field
                      ListTile(
                        leading: const Icon(Icons.person, size: 36),
                        title: Text(
                          checkLanguageCondition()
                              ? 'Your Name'
                              : 'ನಿಮ್ಮ ಹೆಸರು',
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: TextField(
                          controller: TextEditingController(
                            text: prefsMap['user_name'] ?? '',
                          ),
                          decoration: InputDecoration(
                            hintText: checkLanguageCondition()
                                ? 'Enter your name'
                                : 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            prefsMap['user_name'] = value;
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 💾 Save Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(
                            checkLanguageCondition() ? "Save" : "ಉಳಿಸಿ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            await _savePrefs();
                            if (mounted) {
                              showStatusSnackBar(
                                context,
                                checkLanguageCondition()
                                    ? "User name saved successfully!"
                                    : "ಬಳಕೆದಾರರ ಹೆಸರನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!",
                                "success",
                              );
                            }
                          },
                        ),
                      ),

                      const Divider(thickness: 1.5, height: 24),

                      // ⚙️ Onboarding Toggle Section
                      ListTile(
                        leading: const Icon(Icons.warning, size: 36),
                        title: Text(
                          checkLanguageCondition()
                              ? 'Show Onboard Instructions'
                              : 'ಆನ್‌ಬೋರ್ಡ್ ಸೂಚನೆಗಳನ್ನು ತೋರಿಸಿ',
                          style: const TextStyle(fontSize: 18),
                        ),
                        trailing: DropdownButton<String>(
                          value: (prefsMap['onboarding_completed'] ?? false)
                              ? "No"
                              : "Yes",
                          items: const [
                            DropdownMenuItem(value: "Yes", child: Text("Yes")),
                            DropdownMenuItem(value: "No", child: Text("No")),
                          ],
                          onChanged: (v) {
                            setState(() {
                              prefsMap['onboarding_completed'] =
                                  (v == "Yes") ? false : true;
                            });
                            _savePrefs();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                sectionCard(
                  message: checkLanguageCondition()
                      ? "In this section you can choose your prefferred Language \n and Audio speed at which you want to communicate  \n\n Available languages are English and Kannada."
                      : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ನಿಮ್ಮ ಆದ್ಯತೆಯ ಭಾಷೆ \n ಮತ್ತು ನೀವು ಸಂವಹನ ಮಾಡಲು ಬಯಸುವ ಆಡಿಯೊ ವೇಗವನ್ನು ಆಯ್ಕೆ ಮಾಡಬಹುದು \n\n ಲಭ್ಯವಿರುವ ಭಾಷೆಗಳು ಇಂಗ್ಲಿಷ್ ಮತ್ತು ಕನ್ನಡ.",
                  title: checkLanguageCondition()
                      ? 'Choose Language:'
                      : 'ಭಾಷೆಯನ್ನು ಆರಿಸಿ:',
                  subtitle: checkLanguageCondition()
                      ? 'Choose Default Language which you want to talk to RESQ'
                      : 'ನೀವು RESQ ಜೊತೆ ಮಾತನಾಡಲು ಬಯಸುವ ಡೀಫಾಲ್ಟ್ ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                            checkLanguageCondition()
                                ? 'Voice Speed'
                                : "ಧ್ವನಿ ವೇಗ",
                            style: TextStyle(fontSize: 18)),
                        subtitle: Slider(
                          min: 0.2,
                          max: 1.0,
                          value: (prefsMap['voiceSpeed'] ?? 0.45) as double,
                          onChanged: (v) {
                            setState(() => prefsMap['voiceSpeed'] = v);
                            tts.setSpeechRate(v);
                            _savePrefs();
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.warning, size: 36),
                        title: Text(
                            checkLanguageCondition()
                                ? 'Default Language'
                                : "ಡೀಫಾಲ್ಟ್ ಭಾಷೆ",
                            style: TextStyle(fontSize: 18)),
                        subtitle: Text(prefsMap['lang'] ?? 'English'),
                        trailing: DropdownButton<String>(
                          value: prefsMap['lang'] ?? 'English',
                          items: const [
                            "English",
                            "ಕನ್ನಡ (Kannada)",
                          ]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              prefsMap['lang'] = v;
                            });
                            _savePrefs();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await tts.speak(checkLanguageCondition()
                              ? 'This is a voice test at your configured speed'
                              : 'ಇದು ನಿಮ್ಮ ಕಾನ್ಫಿಗರ್ ಮಾಡಿದ ವೇಗದಲ್ಲಿ ಧ್ವನಿ ಪರೀಕ್ಷೆಯಾಗಿದೆ');
                        },
                        icon: const Icon(Icons.volume_up),
                        label: Text(checkLanguageCondition()
                            ? 'Voice Test'
                            : 'ಧ್ವನಿ ಪರೀಕ್ಷೆ'),
                      ),
                    ],
                  ),
                ),
                // sectionCard(
                //   message: checkLanguageCondition()
                //       ? "In this section you can choose emergency action \n\n by selecting call feature \n or \n share location."
                //       : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ಕರೆ ವೈಶಿಷ್ಟ್ಯವನ್ನು \n ಅಥವಾ \n ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳುವ ಮೂಲಕ \n\n ತುರ್ತು ಕ್ರಮವನ್ನು ಆಯ್ಕೆ ಮಾಡಬಹುದು.",
                //   title: checkLanguageCondition()
                //       ? 'Emergency Action'
                //       : 'ತುರ್ತು ಕ್ರಮ',
                //   subtitle: checkLanguageCondition()
                //       ? 'Choose default action when hardware SOS is pressed'
                //       : 'ಹಾರ್ಡ್‌ವೇರ್ SOS ಒತ್ತಿದಾಗ ಡೀಫಾಲ್ಟ್ ಕ್ರಿಯೆಯನ್ನು ಆರಿಸಿ',
                //   child: Column(
                //     children: [
                //       ListTile(
                //         leading: const Icon(Icons.warning, size: 36),
                //         title: Text(
                //             checkLanguageCondition()
                //                 ? 'Default Action'
                //                 : 'ಡೀಫಾಲ್ಟ್ ಕ್ರಿಯೆ',
                //             style: TextStyle(fontSize: 18)),
                //         subtitle: Text(checkLanguageCondition()
                //             ? (prefsMap['defaultAction'] == 'Share Location'
                //                 ? 'Share Location'
                //                 : "Call")
                //             : (prefsMap['defaultAction'] == 'Share Location'
                //                 ? 'ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳಿ'
                //                 : "ಕರೆ")),
                //         trailing: DropdownButton<String>(
                //           value: prefsMap['defaultAction'] ?? 'Call',
                //           items: const [
                //             "Call",
                //             "Share Location",
                //           ]
                //               .map((e) =>
                //                   DropdownMenuItem(value: e, child: Text(e)))
                //               .toList(),
                //           onChanged: (v) {
                //             setState(() => prefsMap['defaultAction'] = v);
                //             _savePrefs();
                //           },
                //         ),
                //       ),
                //       const SizedBox(height: 8),
                //     ],
                //   ),
                // ),

                // Contacts & priority
                sectionCard(
                  message: checkLanguageCondition()
                      ? "In this section you have the facility to add emergency contact details, \n or edit them, \n or rearrange your based on your priority. "
                      : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ತುರ್ತು ಸಂಪರ್ಕ ವಿವರಗಳನ್ನು ಸೇರಿಸಲು, \n ಅಥವಾ ಅವುಗಳನ್ನು ಸಂಪಾದಿಸಲು, \n ಅಥವಾ ನಿಮ್ಮ ಆದ್ಯತೆಯ ಆಧಾರದ ಮೇಲೆ ಮರುಹೊಂದಿಸಲು ಸೌಲಭ್ಯವನ್ನು ಹೊಂದಿದ್ದೀರಿ.",
                  title: checkLanguageCondition()
                      ? 'Emergency Contacts (Priority Order)'
                      : 'ತುರ್ತು ಸಂಪರ್ಕಗಳು (ಆದ್ಯತೆಯ ಆದೇಶ)',
                  subtitle: checkLanguageCondition()
                      ? 'Tap to edit. Drag to reorder priority.'
                      : 'ಸಂಪಾದಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ. ಆದ್ಯತೆಯನ್ನು ಮರುಕ್ರಮಗೊಳಿಸಲು ಎಳೆಯಿರಿ.',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: contacts.isEmpty
                            ? Center(
                                child: Text(
                                  checkLanguageCondition()
                                      ? 'No contacts added yet.\nTap below to add up to 4 family members.'
                                      : 'ಇನ್ನೂ ಯಾವುದೇ ಸಂಪರ್ಕಗಳನ್ನು ಸೇರಿಸಲಾಗಿಲ್ಲ.\n4 ಕುಟುಂಬ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಲು ಕೆಳಗೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollDirection: Axis.vertical,
                                buildDefaultDragHandles: true,
                                itemCount: contacts.length,
                                onReorder: _reorderContacts,
                                itemBuilder: (ctx, idx) {
                                  final c = contacts[idx];
                                  return ExpansionTile(
                                    key: ValueKey(c.id),
                                    initiallyExpanded: true,
                                    leading: CircleAvatar(
                                      child: Text(
                                          c.name.isEmpty ? '?' : c.name[0]),
                                    ),
                                    title: Text(
                                      c.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      '${c.phone}\n' +
                                          (checkLanguageCondition()
                                              ? 'Features: '
                                              : "ವೈಶಿಷ್ಟ್ಯಗಳು: ") +
                                          '${c.allowCall ? (checkLanguageCondition() ? "📞 Call " : '📞 ಕರೆ ') : ""}' +
                                          '${c.allowLocation ? (checkLanguageCondition() ? "📍 Location" : "📍 ಸ್ಥಳ") : ""}',
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              label: Text(
                                                  checkLanguageCondition()
                                                      ? 'Edit'
                                                      : 'ಸಂಪಾದಿಸಿ'),
                                              onPressed: () =>
                                                  _editContact(idx),
                                            ),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.delete,
                                                  size: 18),
                                              label: Text(
                                                  checkLanguageCondition()
                                                      ? 'Delete'
                                                      : 'ಅಳಿಸಿ'),
                                              onPressed: () =>
                                                  _removeContact(idx),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.call,
                                                  size: 18),
                                              label: Text(
                                                  checkLanguageCondition()
                                                      ? 'Call'
                                                      : 'ಕರೆ'),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green),
                                              onPressed: () =>
                                                  callWithSim(c.phone),
                                            ),
                                            ElevatedButton.icon(
                                              icon: const Icon(
                                                  Icons.share_sharp,
                                                  size: 18),
                                              label: Text(
                                                  checkLanguageCondition()
                                                      ? 'Share'
                                                      : 'ಹಂಚಿಕೊಳ್ಳಿ'),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue),
                                              onPressed: () =>
                                                  _shareLocationWithContact(
                                                      idx, c),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );

                                  // ListTile(
                                  //   // contentPadding: const EdgeInsets.symmetric(
                                  //   //     vertical: 12.0, horizontal: 16.0),
                                  //   // visualDensity: VisualDensity(vertical: 2),
                                  //   key: ValueKey(c.id),
                                  //   leading: CircleAvatar(
                                  //     child: Text(
                                  //         c.name.isEmpty ? '?' : c.name[0]),
                                  //   ),
                                  //   title: Text(c.name,
                                  //       style: TextStyle(
                                  //           fontSize: 18,
                                  //           fontWeight: FontWeight.w500)),
                                  //   subtitle: Row(
                                  //     children: [
                                  //       Text(
                                  //         '${c.phone}\n' +
                                  //             (checkLanguageCondition()
                                  //                 ? 'Features: \n'
                                  //                 : "ವೈಶಿಷ್ಟ್ಯಗಳು: \n") +
                                  //             '${c.allowCall ? (checkLanguageCondition() ? "📞 Call \n" : '📞 ಕರೆ \n') : ""}'
                                  //                 '${c.allowLocation ? (checkLanguageCondition() ? "📍 Location" : "📍 ಸ್ಥಳ") : ""}',
                                  //       ),
                                  //       // Column(
                                  //       //   mainAxisAlignment:
                                  //       //       MainAxisAlignment.spaceBetween,
                                  //       //   children: [
                                  //       Row(
                                  //         mainAxisSize: MainAxisSize.min,
                                  //         children: [
                                  //           IconButton(
                                  //             icon: const Icon(Icons.edit),
                                  //             onPressed: () =>
                                  //                 _editContact(idx),
                                  //           ),
                                  //           IconButton(
                                  //             icon: const Icon(Icons.delete),
                                  //             onPressed: () =>
                                  //                 _removeContact(idx),
                                  //           ),
                                  //           IconButton(
                                  //             icon: const Icon(
                                  //               Icons.call,
                                  //               color: Colors.green,
                                  //             ),
                                  //             onPressed: () =>
                                  //                 callWithSim(c.phone),
                                  //           ),
                                  //           IconButton(
                                  //             icon: const Icon(
                                  //               Icons.share_sharp,
                                  //               color: Colors.green,
                                  //             ),
                                  //             onPressed: () =>
                                  //                 _shareLocationWithContact(
                                  //                     idx, c),
                                  //           ),
                                  //         ],
                                  //       ),
                                  //       // Row(
                                  //       //   mainAxisSize: MainAxisSize.min,
                                  //       //   children: [

                                  //       //   ],
                                  //       // ),
                                  //       //   ],
                                  //       // )
                                  //     ],
                                  //   ),
                                  // );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: contacts.length >= 4 ? null : _addContact,
                        icon: const Icon(Icons.add),
                        label: Text(
                          contacts.length >= 4
                              ? (checkLanguageCondition()
                                  ? 'Maximum of 4 contacts reached'
                                  : 'ಗರಿಷ್ಠ 4 ಸಂಪರ್ಕಗಳನ್ನು ತಲುಪಲಾಗಿದೆ')
                              : (checkLanguageCondition()
                                  ? 'Add Family Member'
                                  : 'ಕುಟುಂಬ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಿ'),
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),

                sectionCard(
                  message: checkLanguageCondition()
                      ? "In this section you can save locations of family members which will be used for Navigation purpose."
                      : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ಕುಟುಂಬ ಸದಸ್ಯರ ಸ್ಥಳಗಳನ್ನು ಉಳಿಸಬಹುದು, ಅದನ್ನು ಸಂಚರಣೆ ಉದ್ದೇಶಕ್ಕಾಗಿ ಬಳಸಲಾಗುತ್ತದೆ.",
                  title: checkLanguageCondition()
                      ? 'Saved Locations (Family Members)'
                      : 'ಉಳಿಸಿದ ಸ್ಥಳಗಳು (ಕುಟುಂಬ ಸದಸ್ಯರು)',
                  subtitle: checkLanguageCondition()
                      ? 'Tap to add or update a location. Drag to reorder priority.'
                      : 'ಸ್ಥಳವನ್ನು ಸೇರಿಸಲು ಅಥವಾ ನವೀಕರಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ. ಆದ್ಯತೆಯನ್ನು ಮರುಕ್ರಮಗೊಳಿಸಲು ಎಳೆಯಿರಿ.',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: contacts.isEmpty
                            ? Center(
                                child: Text(
                                  checkLanguageCondition()
                                      ? 'No family members added yet.\nTap below to add up to 4 members.'
                                      : 'ಇನ್ನೂ ಯಾವುದೇ ಕುಟುಂಬ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಲಾಗಿಲ್ಲ.\n4 ಸದಸ್ಯರವರೆಗೆ ಸೇರಿಸಲು ಕೆಳಗೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollDirection: Axis.vertical,
                                buildDefaultDragHandles: true,
                                itemCount: contacts.length,
                                onReorder: _reorderContacts,
                                itemBuilder: (ctx, idx) {
                                  final c = contacts[idx];
                                  return ListTile(
                                    key: ValueKey(c.id),
                                    leading: CircleAvatar(
                                      child: Text(
                                          c.name.isEmpty ? '?' : c.name[0]),
                                    ),
                                    title: Text(c.name,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: Text(
                                      '${c.phone}\n'
                                      '${checkLanguageCondition() ? "Location:" : "ಸ್ಥಳ"} ${c.latitude != null && c.longitude != null ? "${c.latitude}, ${c.longitude}" : checkLanguageCondition() ? "Not set" : "ಹೊಂದಿಸಲಾಗಿಲ್ಲ"}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_location_alt,
                                              color: Colors.blue),
                                          onPressed: () async {
                                            final pos = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LocationPickerPage(),
                                              ),
                                            );
                                            if (pos != null) {
                                              _setContactLocation(
                                                  idx, pos); // ✅ save location
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.navigation,
                                              color: Colors.green),
                                          onPressed: (c.latitude != null &&
                                                  c.longitude != null)
                                              ? () => _navigateToLocation(c)
                                              : null, // disabled if no location
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: contacts.length >= 4 ? null : _addContact,
                        icon: const Icon(Icons.add_location_alt),
                        label: Text(
                          contacts.length >= 4
                              ? (checkLanguageCondition()
                                  ? 'Maximum of 4 contacts reached'
                                  : 'ಗರಿಷ್ಠ 4 ಸಂಪರ್ಕಗಳನ್ನು ತಲುಪಲಾಗಿದೆ')
                              : (checkLanguageCondition()
                                  ? 'Add Family Member'
                                  : 'ಕುಟುಂಬ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಿ'),
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),

                sectionCard(
                  title: checkLanguageCondition()
                      ? 'Obstacle Detection'
                      : "ಅಡಚಣೆ ಪತ್ತೆ",
                  subtitle: checkLanguageCondition()
                      ? 'Detect nearby obstacles using camera'
                      : "ಕ್ಯಾಮೆರಾ ಬಳಸಿ ಹತ್ತಿರದ ಅಡೆತಡೆಗಳನ್ನು ಪತ್ತೆ ಮಾಡಿ",
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sensors),
                        label: Text(isDetectingObstacle
                            ? checkLanguageCondition()
                                ? 'Detecting...'
                                : 'ಪತ್ತೆಹಚ್ಚಲಾಗುತ್ತಿದೆ...'
                            : checkLanguageCondition()
                                ? 'Detect Obstacle Now'
                                : 'ಈಗಲೇ ಅಡಚಣೆಯನ್ನು ಪತ್ತೆ ಮಾಡಿ'),
                        onPressed: isDetectingObstacle ? null : _detectObstacle,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: Text(checkLanguageCondition()
                            ? "Continuous Detection Mode"
                            : "ನಿರಂತರ ಪತ್ತೆ ವಿಧಾನ"),
                        subtitle: Text(checkLanguageCondition()
                            ? "Keeps detecting every few seconds"
                            : "ಪ್ರತಿ ಕೆಲವು ಸೆಕೆಂಡುಗಳಿಗೊಮ್ಮೆ ಪತ್ತೆಹಚ್ಚುತ್ತಲೇ ಇರುತ್ತದೆ"),
                        value: continuousObstacleDetection,
                        onChanged: (val) {
                          setState(() => continuousObstacleDetection = val);
                          if (val) {
                            _startContinuousObstacleDetection();
                          } else {
                            _stopContinuousObstacleDetection();
                          }
                        },
                      ),
                      if (lastDetections.isNotEmpty)
                        Text(
                          checkLanguageCondition()
                              ? "Last Detected: Truck"
                              : "ಕೊನೆಯದಾಗಿ ಪತ್ತೆಯಾಗಿದ್ದು: ಟ್ರಕ್",
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                  ),
                  message: checkLanguageCondition()
                      ? "Use your device camera to detect nearby obstacles and stay aware of your surroundings."
                      : "ನಿಮ್ಮ ಸುತ್ತಮುತ್ತಲಿನ ಅಡೆತಡೆಗಳನ್ನು ಪತ್ತೆಹಚ್ಚಲು ಮತ್ತು ಜಾಗೃತರಾಗಿರಲು ನಿಮ್ಮ ಸಾಧನದ ಕ್ಯಾಮೆರಾವನ್ನು ಬಳಸಿ.",
                ),

                // Medical Information
                sectionCard(
                  message: checkLanguageCondition()
                      ? "In this section you can save your medical informations \n and can be shared during emergency."
                      : "ಈ ವಿಭಾಗದಲ್ಲಿ ನೀವು ನಿಮ್ಮ ವೈದ್ಯಕೀಯ ಮಾಹಿತಿಯನ್ನು ಉಳಿಸಬಹುದು ಮತ್ತು \n ತುರ್ತು ಸಮಯದಲ್ಲಿ ಹಂಚಿಕೊಳ್ಳಬಹುದು.",
                  title: checkLanguageCondition()
                      ? 'Medical Information'
                      : 'ವೈದ್ಯಕೀಯ ಮಾಹಿತಿ',
                  subtitle: checkLanguageCondition()
                      ? 'Shareable details for first responders'
                      : 'ಮೊದಲು ಪ್ರತಿಕ್ರಿಯಿಸುವವರಿಗೆ ಹಂಚಿಕೊಳ್ಳಬಹುದಾದ ವಿವರಗಳು',
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: medical.bloodGroup,
                        decoration: InputDecoration(
                            labelText: checkLanguageCondition()
                                ? 'Blood Group'
                                : 'ರಕ್ತ ಗುಂಪು'),
                        onChanged: (v) => medical.bloodGroup = v,
                      ),
                      TextFormField(
                        initialValue: medical.allergies,
                        decoration: InputDecoration(
                            labelText: checkLanguageCondition()
                                ? 'Allergies'
                                : 'ಅಲರ್ಜಿಗಳು'),
                        onChanged: (v) => medical.allergies = v,
                      ),
                      TextFormField(
                        initialValue: medical.medications,
                        decoration: InputDecoration(
                            labelText: checkLanguageCondition()
                                ? 'Medications'
                                : 'ಔಷಧಿಗಳು'),
                        onChanged: (v) => medical.medications = v,
                      ),
                      TextFormField(
                        initialValue: medical.doctorName,
                        decoration: InputDecoration(
                            labelText: checkLanguageCondition()
                                ? 'Doctor Name'
                                : 'ವೈದ್ಯರ ಹೆಸರು'),
                        onChanged: (v) => medical.doctorName = v,
                      ),
                      TextFormField(
                        initialValue: medical.doctorPhone,
                        decoration: InputDecoration(
                            labelText: checkLanguageCondition()
                                ? 'Doctor Phone'
                                : "ವೈದ್ಯರ ಫೋನ್"),
                        onChanged: (v) => medical.doctorPhone = v,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _saveMedical();
                        },
                        icon: const Icon(Icons.save),
                        label: Text(checkLanguageCondition()
                            ? 'Save Medical Info'
                            : "ವೈದ್ಯಕೀಯ ಮಾಹಿತಿಯನ್ನು ಉಳಿಸಿ"),
                      ),
                    ],
                  ),
                ),

                ElevatedButton(
                  child: const Text("Open Debug Page"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PreferencesDebugPage()),
                    );
                  },
                ),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _confirmDeleteAll(context),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text(
                    "Delete All Preferences",
                    style: TextStyle(fontSize: 18),
                  ),
                ),

                // Accessibility & Interaction

                // Security & Backup
                // sectionCard(
                //   title: 'Security & Backup',
                //   subtitle: 'PIN lock and export/import preferences',
                //   child: Column(
                //     children: [
                //       FutureBuilder<String?>(
                //         future: store.getPin(),
                //         builder: (ctx, snap) {
                //           final hasPin = snap.data != null;
                //           return ListTile(
                //             title: Text(
                //                 hasPin ? 'Change / Remove PIN' : 'Set PIN',
                //                 style: const TextStyle(fontSize: 18)),
                //             trailing: ElevatedButton(
                //               onPressed: hasPin ? _removePin : _setPin,
                //               child: Text(hasPin ? 'Remove PIN' : 'Set PIN'),
                //             ),
                //           );
                //         },
                //       ),
                //       const SizedBox(height: 8),
                //       ElevatedButton.icon(
                //         onPressed: () async {
                //           // Export preferences as JSON text (placeholder)
                //           final export = jsonEncode({
                //             'contacts':
                //                 contacts.map((e) => e.toJson()).toList(),
                //             'medical': medical.toJson(),
                //             'prefs': prefsMap,
                //           });
                //           // TODO: save to file or share via share plugin
                //           await tts.speak('Preferences exported to clipboard');
                //           Clipboard.setData(ClipboardData(text: export));
                //         },
                //         icon: const Icon(Icons.upload_file),
                //         label: const Text('Export Preferences'),
                //       ),
                //       const SizedBox(height: 8),
                //       ElevatedButton.icon(
                //         onPressed: () async {
                //           // TODO: implement import from JSON
                //           await tts.speak(
                //               'Import not implemented. Use export/import flow.');
                //         },
                //         icon: const Icon(Icons.download),
                //         label: const Text('Import Preferences'),
                //       ),
                //     ],
                //   ),
                // ),

                // // Maintenance & Logs
                // sectionCard(
                //   title: 'Maintenance & SOS Logs',
                //   subtitle: 'Recent emergency triggers and device status',
                //   child: Column(
                //     children: [
                //       ListView.separated(
                //         shrinkWrap: true,
                //         physics: const NeverScrollableScrollPhysics(),
                //         itemCount: logs.length.clamp(0, 10),
                //         separatorBuilder: (_, __) => const Divider(),
                //         itemBuilder: (ctx, idx) {
                //           final l = logs[idx];
                //           return ListTile(
                //             title: Text('SOS at ' +
                //                 DateFormat('yyyy-MM-dd HH:mm').format(l.time)),
                //             subtitle: Text(
                //                 'Location: ${l.location} | Contacts: ${l.contacted.length}'),
                //             trailing: IconButton(
                //               icon: const Icon(Icons.info),
                //               onPressed: () {
                //                 // show details
                //                 showDialog(
                //                     context: context,
                //                     builder: (_) => AlertDialog(
                //                         content: Text(jsonEncode(l.toJson()))));
                //               },
                //             ),
                //           );
                //         },
                //       ),
                //     ],
                //   ),
                // ),

                // const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    obstacleTimer?.cancel();
    super.dispose();
  }
}

class ContactDialog extends StatefulWidget {
  final EmergencyContact? existing;
  const ContactDialog({this.existing, super.key});

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController addressCtrl;
  bool allowCall = false;
  bool allowLocation = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
    allowCall = widget.existing?.allowCall ?? false;
    allowLocation = widget.existing?.allowLocation ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Contact' : 'Edit Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: allowCall,
              onChanged: (v) => setState(() => allowCall = v ?? false),
              title: const Text("Allow Calls"),
              subtitle: const Text(
                  "Enable if this family member can receive SOS calls"),
            ),
            CheckboxListTile(
              value: allowLocation,
              onChanged: (v) => setState(() => allowLocation = v ?? false),
              title: const Text("Allow Location Sharing"),
              subtitle: const Text(
                  "Enable if this family member can receive your live location"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Placeholder for map integration
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Open location picker (not implemented)')),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Pick Location'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final c = EmergencyContact(
              id: widget.existing?.id ?? UniqueKey().toString(),
              name: nameCtrl.text,
              phone: phoneCtrl.text,
              address: addressCtrl.text,
              location: false,
              allowCall: allowCall,
              allowLocation: allowLocation,
            );
            Navigator.pop(context, c);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ------------------------- PIN Dialog -------------------------
class PinDialog extends StatefulWidget {
  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final pinCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN (4 digits)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN'),
              maxLength: 4),
          TextField(
              controller: confirmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
              maxLength: 4),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (pinCtrl.text.length != 4 || pinCtrl.text != confirmCtrl.text) {
              setState(() => error = 'PINs do not match or invalid');
              return;
            }
            Navigator.pop(context, pinCtrl.text);
          },
          child: const Text('Set PIN'),
        )
      ],
    );
  }
}

// ------------------------- END -------------------------
