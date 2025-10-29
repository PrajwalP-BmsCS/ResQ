import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesDebugPage extends StatefulWidget {
  const PreferencesDebugPage({Key? key}) : super(key: key);

  @override
  State<PreferencesDebugPage> createState() => _PreferencesDebugPageState();
}

class _PreferencesDebugPageState extends State<PreferencesDebugPage> {
  Map<String, Object> _prefsData = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, Object> data = {};

    for (var key in allKeys) {
      final value = prefs.get(key);
      if (value != null) {
        data[key] = value;
      }
    }

    setState(() {
      _prefsData = data;
    });

    // Also log it to console
    debugPrint("🔍 SharedPreferences Data: $_prefsData");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug: SharedPreferences"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPreferences,
          ),
        ],
      ),
      body: _prefsData.isEmpty
          ? const Center(child: Text("No SharedPreferences data found."))
          : ListView.builder(
              itemCount: _prefsData.length,
              itemBuilder: (context, index) {
                final key = _prefsData.keys.elementAt(index);
                final value = _prefsData[key];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.settings, color: Colors.blue),
                    title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(value.toString()),
                  ),
                );
              },
            ),
    );
  }
}
