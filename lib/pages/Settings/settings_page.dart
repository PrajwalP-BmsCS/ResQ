import 'dart:convert';
import 'dart:io'; // <-- add this at the top of your Dart file
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:req_demo/debug_data.dart';
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
Future<void> _navigateToLocation(EmergencyContact c) async {
  final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${c.latitude},${c.longitude}");
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    debugPrint("Could not launch Maps for ${c.name}");
  }
}

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

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  // REMOVE these conflicting methods:
// _saveContactsToLocalDb()
// _loadContactsFromLocalDb()
// _saveContacts()

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
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);

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

  // Future<void> _initAll() async {
  //   store = await LocalStore.getInstance();
  //   print("FINAL $store");

  //   // Always fetch existing data from storage (persisted)
  //   contacts = store.getContacts();
  //   medical = store.getMedical();
  //   prefsMap =
  //       store.getGeneralPrefs(); // <-- will load old values if they exist
  //   logs = store.getSosLogs();

  //   print("Loaded contacts: $contacts");
  //   print("Loaded medical: $medical");
  //   print("Loaded prefsMap: $prefsMap");
  //   print("Loaded logs: $logs");

  //   // Initialize TTS
  //   await tts.setLanguage('en-US');
  //   await tts.setSpeechRate(0.45);

  //   setState(() => loading = false);
  // }

  // /// Save location to a contact
  // void _setContactLocation(int index, LatLng pos) {
  //   setState(() {
  //     contacts[index].latitude = pos.latitude.toString();
  //     contacts[index].longitude = pos.longitude.toString();
  //     contacts[index].location = true;
  //   });

  //   // _saveContactsToLocalDb();
  //   debugPrint(
  //       "Updated location for ${contacts[index].name}: ${pos.latitude}, ${pos.longitude}");
  // }

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

      TTSManager().speak("Navigation started to the selected location.");
    } else {
      print("❌ Could not launch Maps for psrv");
    }
  }

  Future<void> _saveMedical() async {
    await store.setMedical(medical);
    await tts.speak('Medical information saved');
  }

  Future<void> _savePrefs() async {
    await store.setGeneralPrefs(prefsMap);
    TTSManager().speak('Preferences saved');
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
        return "https://www.google.com/maps?q=${locData.latitude},${locData.longitude}";
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }

  Future<void> sendSms(String phone, String message) async {
    print("Sending SMS to $phone: $message");
    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      debugPrint("Could not launch SMS to $phone");
    }
  }

  Future<void> _triggerSOS(String method) async {
    final preferredSubId = prefsMap['preferredSim']; // stored subscriptionId

    // 🚨 SOS CALL
    if (method == "call") {
      print("CALLING");
      // print("Contacts: $contacts");
      final callContacts = contacts.where((c) => c.allowCall).toList();
      if (callContacts.isEmpty) {
        await tts
            .speak('No emergency contacts with call enabled. Please add one.');
        return;
      }
      print("Contacts: $callContacts");

      // Step 1: Announce options via TTS
      for (var i = 0; i < callContacts.length; i++) {
        await tts.awaitSpeakCompletion(true); // ensures we wait
        await tts.speak('Option ${i + 1}: Call ${callContacts[i].name}');
      }

      // Step 2 (Future): Wait for user audio input or choice
      // For now, you can just log or mock it
      // Example: Assume user says "1"
      final userChoice = 1; // <-- later replace with audio recognition

      if (userChoice > 0 && userChoice <= callContacts.length) {
        final selected = callContacts[userChoice - 1];

        await tts.speak(
            'You have selected ${selected.name}. Now we are calling ${selected.name}');
        print(
            'You have selected ${selected.name}. Now we are calling ${selected.name}');
        await callWithSim(
          selected.phone,
          subscriptionId: preferredSubId,
        );
      } else {
        await tts.speak('Invalid choice. Please try again.');
      }
    }

    // 📍 SOS LOCATION SHARING
    else if (method == "location" || method == "sms") {
      print("SHARING LOCATION");
      final sharingContacts = contacts.where((c) => c.allowLocation).toList();
      if (sharingContacts.isEmpty) {
        await tts
            .speak('No emergency contacts with SMS enabled. Please add one.');
        return;
      }

      for (var i = 0; i < sharingContacts.length; i++) {
        await tts.speak('Sending location to ${sharingContacts[i].name}');
      }

      // Get Google Maps Location Link
      final locationLink = await _getLocationLink();
      if (locationLink != null && sharingContacts.isNotEmpty) {
        for (var contact in sharingContacts) {
          final message =
              "🚨 SOS! I need help. My live location: $locationLink";
          await sendSms(contact.phone, message);
        }
      } else {
        await tts.speak("Unable to fetch location. Please check GPS settings.");
      }
    }
  }

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

  // UI builder helpers below
  Widget sectionCard(
      {required Widget child, required String title, String? subtitle}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
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
          title: const Text('Preferences', style: TextStyle(fontSize: 22)),
          centerTitle: true),
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              children: [
                sectionCard(
                  title: 'Emergency Action',
                  subtitle:
                      'Choose default action when hardware SOS is pressed',
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.warning, size: 36),
                        title: const Text('Default Action',
                            style: TextStyle(fontSize: 18)),
                        subtitle: Text(prefsMap['defaultAction'] ?? 'Call'),
                        trailing: DropdownButton<String>(
                          value: prefsMap['defaultAction'] ?? 'Call',
                          items: const [
                            "Call",
                            "Share Location",
                          ]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => prefsMap['defaultAction'] = v);
                            _savePrefs();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final action =
                              prefsMap['defaultAction']?.toLowerCase();

                          print("Triggering SOS action: $action");

                          // Step 1: Trigger SOS logic
                          if (action == "call") {
                            await _triggerSOS("call");
                          } else if (action == "sms" ||
                              action == "share location") {
                            await _triggerSOS("location");
                          }

                          // Step 2: Get eligible contacts
                          List<EmergencyContact> eligible = [];
                          if (action == "call") {
                            eligible =
                                contacts.where((c) => c.allowCall).toList();
                          } else if (action == "share location" ||
                              action == "sms") {
                            eligible =
                                contacts.where((c) => c.allowLocation).toList();
                          }

                          // Step 3: If no contacts → show warning dialog
                          if (eligible.isEmpty) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("No Eligible Contacts"),
                                content: const Text(
                                  "Please add family members and enable the correct options.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          // Step 4: Show dialog ONLY for CALL action
                          if (action == "call") {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  "Emergency ${action[0].toUpperCase()}${action.substring(1)} Options",
                                ),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: eligible.length,
                                    itemBuilder: (ctx, i) {
                                      final c = eligible[i];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text(c.name.isNotEmpty
                                              ? c.name[0]
                                              : "?"),
                                        ),
                                        title: Text(c.name),
                                        subtitle: Text(c.phone),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.phone,
                                              color: Colors.green),
                                          onPressed: () {
                                            callNumber(c.phone); // actual call
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Close"),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // For SMS or share location → no dialog
                            showStatusSnackBar(
                                context,
                                "Location shared with emergency contacts",
                                "success");
                          }
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text(
                          'Test SOS',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
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

                // Contacts & priority
                sectionCard(
                  title: 'Emergency Contacts (Priority Order)',
                  subtitle: 'Tap to edit. Drag to reorder priority.',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: contacts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No contacts added yet.\nTap below to add up to 4 family members.',
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
                                      'Features: \n'
                                      '${c.allowCall ? "📞 Call \n" : ""}'
                                      '${c.allowLocation ? "📍 Location" : ""}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editContact(idx),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _removeContact(idx),
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
                        icon: const Icon(Icons.add),
                        label: Text(
                          contacts.length >= 4
                              ? 'Maximum of 4 contacts reached'
                              : 'Add Family Member',
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
                  title: 'Saved Locations (Family Members)',
                  subtitle:
                      'Tap to add or update a location. Drag to reorder priority.',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: contacts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No family members added yet.\nTap below to add up to 4 members.',
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
                                      'Location: ${c.latitude != null && c.longitude != null ? "${c.latitude}, ${c.longitude}" : "Not set"}',
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
                              ? 'Maximum of 4 contacts reached'
                              : 'Add Family Member',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),

                // sectionCard(
                //   title: 'Preferred SIM for SOS Calls',
                //   subtitle:
                //       'Select which SIM to use when calling emergency contacts',
                //   child: ListTile(
                //     leading: const Icon(Icons.sim_card, size: 36),
                //     title: const Text('Select SIM',
                //         style: TextStyle(fontSize: 18)),
                //     trailing: DropdownButton<int>(
                //       value: prefsMap['preferredSim'] ?? 0,
                //       items: const [
                //         DropdownMenuItem(value: 0, child: Text('SIM 1')),
                //         DropdownMenuItem(value: 1, child: Text('SIM 2')),
                //       ],
                //       onChanged: (v) {
                //         setState(() => prefsMap['preferredSim'] = v);
                //         store.setGeneralPrefs(prefsMap);
                //       },
                //     ),
                //   ),
                // ),

                // Medical Information
                sectionCard(
                  title: 'Medical Information',
                  subtitle: 'Shareable details for first responders',
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: medical.bloodGroup,
                        decoration:
                            const InputDecoration(labelText: 'Blood Group'),
                        onChanged: (v) => medical.bloodGroup = v,
                      ),
                      TextFormField(
                        initialValue: medical.allergies,
                        decoration:
                            const InputDecoration(labelText: 'Allergies'),
                        onChanged: (v) => medical.allergies = v,
                      ),
                      TextFormField(
                        initialValue: medical.medications,
                        decoration:
                            const InputDecoration(labelText: 'Medications'),
                        onChanged: (v) => medical.medications = v,
                      ),
                      TextFormField(
                        initialValue: medical.doctorName,
                        decoration:
                            const InputDecoration(labelText: 'Doctor Name'),
                        onChanged: (v) => medical.doctorName = v,
                      ),
                      TextFormField(
                        initialValue: medical.doctorPhone,
                        decoration:
                            const InputDecoration(labelText: 'Doctor Phone'),
                        onChanged: (v) => medical.doctorPhone = v,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _saveMedical();
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Medical Info'),
                      ),
                    ],
                  ),
                ),

                // Accessibility & Interaction
                sectionCard(
                  title: 'Accessibility & Interaction',
                  subtitle: 'Customize voice, haptics and shortcuts',
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Voice Speed',
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
                      SwitchListTile(
                        title: const Text('Haptic Feedback (Vibrate)'),
                        value: prefsMap['haptics'] ?? true,
                        onChanged: (v) {
                          setState(() => prefsMap['haptics'] = v);
                          _savePrefs();
                        },
                      ),
                      ListTile(
                        title: const Text('Default Language',
                            style: TextStyle(fontSize: 18)),
                        subtitle: Text(prefsMap['language'] ?? 'en-US'),
                        trailing: DropdownButton<String>(
                          value: prefsMap['language'] ?? 'en-US',
                          items: const ['en-US', 'hi-IN']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) async {
                            setState(() => prefsMap['language'] = v);
                            await tts.setLanguage(v!);
                            _savePrefs();
                          },
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await tts.speak(
                              'This is a voice test at your configured speed');
                        },
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Voice Test'),
                      ),
                    ],
                  ),
                ),

                // Security & Backup
                sectionCard(
                  title: 'Security & Backup',
                  subtitle: 'PIN lock and export/import preferences',
                  child: Column(
                    children: [
                      FutureBuilder<String?>(
                        future: store.getPin(),
                        builder: (ctx, snap) {
                          final hasPin = snap.data != null;
                          return ListTile(
                            title: Text(
                                hasPin ? 'Change / Remove PIN' : 'Set PIN',
                                style: const TextStyle(fontSize: 18)),
                            trailing: ElevatedButton(
                              onPressed: hasPin ? _removePin : _setPin,
                              child: Text(hasPin ? 'Remove PIN' : 'Set PIN'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Export preferences as JSON text (placeholder)
                          final export = jsonEncode({
                            'contacts':
                                contacts.map((e) => e.toJson()).toList(),
                            'medical': medical.toJson(),
                            'prefs': prefsMap,
                          });
                          // TODO: save to file or share via share plugin
                          await tts.speak('Preferences exported to clipboard');
                          Clipboard.setData(ClipboardData(text: export));
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Export Preferences'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // TODO: implement import from JSON
                          await tts.speak(
                              'Import not implemented. Use export/import flow.');
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Import Preferences'),
                      ),
                    ],
                  ),
                ),

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
