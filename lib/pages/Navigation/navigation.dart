import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Navigation/nav_utility_functions.dart';
import 'package:req_demo/pages/Navigation/set_current_location.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';
import 'package:req_demo/pages/utils/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WalkingRouteMapPage extends StatefulWidget {
  const WalkingRouteMapPage({super.key});

  @override
  State<WalkingRouteMapPage> createState() => _WalkingRouteMapPageState();
}

class _WalkingRouteMapPageState extends State<WalkingRouteMapPage> {
  final MapController _mapController = MapController();
  LatLng? _currentPos;
  LatLng? _destination;
  String result = "Tap on the map or search an address...";
  List<LatLng> _polylinePoints = [];
  final TextEditingController _searchController = TextEditingController();

  late ContactManager contactManager;

  Future<void> initAll() async {
  contactManager = ContactManager();

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('emergency_contacts'); // list of JSON strings
  print(raw);

  if (raw != null && raw.isNotEmpty) {
    // decode each string and convert to EmergencyContact
    final decodedContacts = raw
        .map((e) => EmergencyContact.fromJson(jsonDecode(e)))
        .toList();

    setState(() {
      contactManager.contacts = decodedContacts;
    });

    // Print each contact’s data
    for (var c in contactManager.contacts) {
      print("Name: ${c.name}, Phone: ${c.phone}, LAT: ${c.latitude}, LNG: ${c.longitude}");
    }
  } else {
    print("⚠️ No contacts found in SharedPreferences.");
  }
}


  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    initAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      Location location = Location();

      // Ask for permission
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            TTSManager().speak(
                "Location services are disabled. Please enable location services.");
            showStatusSnackBar(
                context,
                "Location services are disabled. Please enable location services.",
                "wanrning");
            // setState(() {
            //   result = "Location services are disabled.";
            // });
          }
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (mounted) {
            TTSManager().speak(
                "Location permission denied. Please grant location permission.");
            showStatusSnackBar(
                context,
                "Location permission denied. Please grant location permission.",
                "wanrning");
            setState(() {
              result = "Location permission denied.";
            });
          }
          return;
        }
      }

      // Get current location
      LocationData pos = await location.getLocation();

      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude!, pos.longitude!);
        });
      }
    } catch (e) {
      if (mounted) {
        TTSManager().speak("Error getting location. Please try again.");
        showStatusSnackBar(
            context, "Error getting location. Please try again.", "wanrning");
        setState(() {
          result = "Error getting location: $e";
        });
      }
    }
  }

  /// Geocode address to LatLng using Nominatim
  Future<LatLng?> _geocodeAddress(String address) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$address&format=json&limit=1",
    );
    try {
      final response = await http.get(url, headers: {
        "User-Agent": "flutter_route_app/1.0" // required by Nominatim
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]["lat"]);
          final lon = double.parse(data[0]["lon"]);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint("Geocode error: $e");
    }
    return null;
  }

  /// Fetch walking route from OSRM
  Future<void> _getWalkingRoute(LatLng dest) async {
    if (_currentPos == null) return;

    if (mounted) {
      TTSManager().speak("Your route is being Fetched. Please wait.");
      showStatusSnackBar(context, "Fetching route...", "wanrning");
      setState(() {
        result = "Fetching route...";
        _polylinePoints = [];
      });
    }

    // final url = Uri.parse(
    //   "https://router.project-osrm.org/route/v1/foot/"
    //   "${_currentPos!.longitude},${_currentPos!.latitude};"
    //   "${dest.longitude},${dest.latitude}"
    //   "?overview=full&steps=true&geometries=geojson",
    // );

    // Walking navigation
    final Uri uri = Uri.parse(
      'google.navigation:q=${dest.latitude},${dest.longitude}&mode=w', // 'w' = walking
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication, // ensures it opens outside Flutter
      );

      await Future.delayed(const Duration(seconds: 3), () {
        TTSManager().speak("Navigation started to the selected location.");
      });
    } else {
      TTSManager().speak("Could not launch Maps Please try again.");
      showStatusSnackBar(
          context, "Could not launch Maps Please try again.", "wanrning");
      print("❌ Could not launch Maps for psrv");
    }

    // try {
    //   final response = await http.get(url);

    //   if (response.statusCode == 200) {
    //     final data = jsonDecode(response.body);

    //     final route = data["routes"][0];
    //     final duration = route["duration"];
    //     final distance = route["distance"];
    //     final steps = route["legs"][0]["steps"];

    //     final coords = route["geometry"]["coordinates"];
    //     _polylinePoints =
    //         coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

    //     StringBuffer sb = StringBuffer();
    //     sb.writeln("ETA: ${(duration / 60).toStringAsFixed(1)} min");
    //     sb.writeln("Distance: ${(distance / 1000).toStringAsFixed(2)} km");
    //     sb.writeln("\nTurn-by-turn:");

    //     debugPrint("🗺 Walking Route Info:");
    //     debugPrint("ETA: ${(duration / 60).toStringAsFixed(1)} min");
    //     debugPrint("Distance: ${(distance / 1000).toStringAsFixed(2)} km");
    //     debugPrint("Turn-by-turn directions:");

    //     for (var step in steps) {
    //       final maneuver = step["maneuver"];
    //       final instruction =
    //           "${maneuver["modifier"] ?? ""} ${maneuver["type"]}";
    //       final name = step["name"].toString().isEmpty
    //           ? "(no street name)"
    //           : step["name"];
    //       final dist = step["distance"];

    //       final dir =
    //           "➡️ $instruction onto $name for ${dist.toStringAsFixed(0)} m";

    //       sb.writeln(dir);
    //       debugPrint(dir);
    //     }

    //     if (mounted) {
    //       setState(() {
    //         result = sb.toString();
    //         _destination = dest;
    //       });
    //     }

    //     // 🔹 Recenter map to destination automatically
    //     _mapController.move(dest, 16);
    //   } else {
    //     if (mounted) {
    //       setState(() {
    //         result = "Error: ${response.statusCode}";
    //       });
    //     }
    //   }
    // } catch (e) {
    //   if (mounted) {
    //     setState(() {
    //       result = "Failed: $e";
    //     });
    //   }
    // }
  }

  /// Handle search submit
  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final dest = await _geocodeAddress(query);
    if (dest != null) {
      _getWalkingRoute(dest);
    } else {
      if (mounted) {
        TTSManager().speak("Address not found! Please try again.");
        showStatusSnackBar(
            context, "Address not found! Please try again.", "wanrning");
        setState(() {
          result = "❌ Address not found!";
        });
      }
    }
  }

  // Saved LOC Functions
  void _reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      contactManager.reorderContacts(oldIndex, newIndex);
    });
    contactManager.saveContacts();
  }

  void _setContactLocation(int index, LatLng pos) {
    setState(() {
      contactManager.contacts[index].latitude = pos.latitude.toString();
      contactManager.contacts[index].longitude = pos.longitude.toString();
      contactManager.contacts[index].location = true;
    });
    contactManager.saveContacts();
  }

  void _navigateToLocation(EmergencyContact c) {
    if (mounted) {
      TTSManager().speak("Your route is being Fetched. Please wait.");
      showStatusSnackBar(context, "Fetching route...", "wanrning");
      setState(() {
        result = "Fetching route...";
        _polylinePoints = [];
      });
    }
    contactManager.navigateToLocation(c);
  }

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
    final contacts = contactManager.contacts;
    final locationContacts = contacts.where((c) => c.location == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _onSearch(),
          decoration: const InputDecoration(
            hintText: "Search address (e.g., BMSCE)...",
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _onSearch,
          ),
        ],
      ),
      body: _currentPos == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  sectionCard(
                    title: 'Saved Locations (Family Members)',
                    subtitle: 'Drag to reorder priority.',
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
                                  itemCount: locationContacts.length,
                                  onReorder: _reorderContacts,
                                  itemBuilder: (ctx, idx) {
                                    final c = locationContacts[idx];
                                    return (c.location) ? ListTile(
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
                                          'Location:  ${c.latitude != null && c.longitude != null ? "${c.latitude}, ${c.longitude}" : "Not set"}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.navigation,
                                                  size: 40,
                                                  color: Colors.green),
                                              onPressed: (c.latitude != null &&
                                                      c.longitude != null)
                                                  ? () => _navigateToLocation(c)
                                                  : null,
                                            ),
                                          ],
                                        )) : SizedBox();
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 400,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentPos!,
                            initialZoom: 15,
                            onTap: (tapPos, latlng) => _getWalkingRoute(latlng),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.yourapp',
                            ),
                            MarkerLayer(
                              markers: [
                                if (_currentPos != null)
                                  Marker(
                                    point: _currentPos!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.my_location,
                                        color: Colors.blue, size: 30),
                                  ),
                                if (_destination != null)
                                  Marker(
                                    point: _destination!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.flag,
                                        color: Colors.red, size: 30),
                                  ),
                              ],
                            ),
                            if (_polylinePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _polylinePoints,
                                    strokeWidth: 4,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                          ],
                        ),

                        // 🔹 Zoom Controls
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Column(
                            children: [
                              FloatingActionButton(
                                heroTag: "zoomIn",
                                mini: true,
                                onPressed: () {
                                  final center = _mapController.camera.center;
                                  final zoom = _mapController.camera.zoom + 1;
                                  _mapController.move(center, zoom);
                                },
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: "zoomOut",
                                mini: true,
                                onPressed: () {
                                  final center = _mapController.camera.center;
                                  final zoom = _mapController.camera.zoom - 1;
                                  _mapController.move(center, zoom);
                                },
                                child: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Container(
                  //   padding: const EdgeInsets.all(12),
                  //   color: Colors.grey[50],
                  //   child: Text(result,
                  //       style: const TextStyle(fontSize: 14, height: 1.5)),
                  // ),
                ],
              ),
            ),
    );
  }
}
