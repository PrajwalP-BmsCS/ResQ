import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

// ------------------------- Models -------------------------
class EmergencyContact {
  String id;
  String name;
  String phone;
  String address;
  String location; // lat,lng placeholder
  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'location': location,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] ?? UniqueKey().toString(),
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        location: j['location'] ?? '',
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

// ------------------------- Storage Helpers -------------------------
class LocalStore {
  static const _contactsKey = 'contacts_v1';
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

  List<EmergencyContact> getContacts() {
    final raw = prefs.getStringList(_contactsKey) ?? [];
    return raw.map((e) => EmergencyContact.fromJson(jsonDecode(e))).toList();
  }

  Future<void> setContacts(List<EmergencyContact> list) async {
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_contactsKey, raw);
  }

  MedicalInfo getMedical() {
    final raw = prefs.getString(_medicalKey);
    if (raw == null) return MedicalInfo();
    return MedicalInfo.fromJson(jsonDecode(raw));
  }

  Future<void> setMedical(MedicalInfo m) async {
    await prefs.setString(_medicalKey, jsonEncode(m.toJson()));
  }

  Map<String, dynamic> getGeneralPrefs() {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> setGeneralPrefs(Map<String, dynamic> p) async {
    await prefs.setString(_prefsKey, jsonEncode(p));
  }

  List<SOSLog> getSosLogs() {
    final raw = prefs.getStringList(_sosLogsKey) ?? [];
    return raw.map((e) => SOSLog.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addSosLog(SOSLog log) async {
    final list = getSosLogs();
    list.insert(0, log);
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_sosLogsKey, raw);
  }

  // Secure storage for PIN
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

  Future<void> _initAll() async {
    store = await LocalStore.getInstance();
    contacts = store.getContacts();
    medical = store.getMedical();
    prefsMap = store.getGeneralPrefs();
    logs = store.getSosLogs();

    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);

    setState(() => loading = false);
  }

  Future<void> _saveContacts() async {
    await store.setContacts(contacts);
    // announce
    await tts.speak('Contacts saved');
  }

  Future<void> _saveMedical() async {
    await store.setMedical(medical);
    await tts.speak('Medical information saved');
  }

  Future<void> _savePrefs() async {
    await store.setGeneralPrefs(prefsMap);
    await tts.speak('Preferences saved');
  }

  void _addContact() async {
    final c = await showDialog<EmergencyContact?>(
      context: context,
      builder: (ctx) => ContactDialog(),
    );
    if (c != null) {
      setState(() => contacts.add(c));
      await _saveContacts();
    }
  }

  void _editContact(int idx) async {
    final c = await showDialog<EmergencyContact?>(
      context: context,
      builder: (ctx) => ContactDialog(existing: contacts[idx]),
    );
    if (c != null) {
      setState(() => contacts[idx] = c);
      await _saveContacts();
    }
  }

  void _removeContact(int idx) async {
    final removed = contacts.removeAt(idx);
    setState(() {
      contacts = contacts;
    });
    
    await _saveContacts();
    await tts.speak('${removed.name} removed');
  }

  void _reorderContacts(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = contacts.removeAt(oldIndex);
      contacts.insert(newIndex, item);
    });
    await _saveContacts();
  }

  Future<void> _triggerSOS() async {
    // Simulate contacting based on priority list
    final contactedIds = contacts.map((c) => c.id).toList();
    final location = prefsMap['lastKnownLocation'] ?? 'unknown';
    final log = SOSLog(
        id: UniqueKey().toString(),
        time: DateTime.now(),
        contacted: contactedIds,
        location: location);
    await store.addSosLog(log);
    setState(() => logs = store.getSosLogs());

    // Announce and vibrate
    await tts.speak('Emergency triggered. Contacts will be notified.');
    HapticFeedback.heavyImpact();

    // Placeholder: integrate real call/SMS/location sharing code here.
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                // Emergency Action
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
                            "SMS",
                            "Share Location",
                            "Group Call"
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
                          // allow testing SOS from UI
                          await _triggerSOS();
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text('Test SOS',
                            style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                      ),
                    ],
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
                            ? Center(
                                child: Text(
                                  'No contacts added yet.\nTap below to add up to 5 family members.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
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
                                            c.name.isEmpty ? '?' : c.name[0])),
                                    title: Text(c.name,
                                        style: const TextStyle(fontSize: 18)),
                                    subtitle: Text(c.phone),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.location_on),
                                          onPressed: () {
                                            // Navigate to map/location picker
                                          },
                                          tooltip: 'Set location for ${c.name}',
                                        ),
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
                        onPressed: contacts.length >= 5
                            ? null
                            : _addContact, // limit to 5
                        icon: const Icon(Icons.add),
                        label: Text(
                          contacts.length >= 5
                              ? 'Maximum of 5 contacts reached'
                              : 'Add Family Member',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                      ),
                    ],
                  ),
                ),

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

                // Maintenance & Logs
                sectionCard(
                  title: 'Maintenance & SOS Logs',
                  subtitle: 'Recent emergency triggers and device status',
                  child: Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length.clamp(0, 10),
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, idx) {
                          final l = logs[idx];
                          return ListTile(
                            title: Text('SOS at ' +
                                DateFormat('yyyy-MM-dd HH:mm').format(l.time)),
                            subtitle: Text(
                                'Location: ${l.location} | Contacts: ${l.contacted.length}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.info),
                              onPressed: () {
                                // show details
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                        content: Text(jsonEncode(l.toJson()))));
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------- Contact Dialog -------------------------
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

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Contact' : 'Edit Contact'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Placeholder: open map to pick location and set address/location
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Open location picker (not implemented)')));
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Pick Location'),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final c = EmergencyContact(
              id: widget.existing?.id ?? UniqueKey().toString(),
              name: nameCtrl.text,
              phone: phoneCtrl.text,
              address: addressCtrl.text,
              location: '',
            );
            Navigator.pop(context, c);
          },
          child: const Text('Save'),
        )
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