import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
        setState(() {
          result = "Location services are disabled.";
        });
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() {
          result = "Location permission denied.";
        });
        return;
      }
    }

    // Get current location
    LocationData pos = await location.getLocation();

    setState(() {
      _currentPos = LatLng(pos.latitude!, pos.longitude!);
    });
  } catch (e) {
    setState(() {
      result = "Error getting location: $e";
    });
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

    setState(() {
      result = "Fetching route...";
      _polylinePoints = [];
    });

    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/foot/"
      "${_currentPos!.longitude},${_currentPos!.latitude};"
      "${dest.longitude},${dest.latitude}"
      "?overview=full&steps=true&geometries=geojson",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final route = data["routes"][0];
        final duration = route["duration"];
        final distance = route["distance"];
        final steps = route["legs"][0]["steps"];

        final coords = route["geometry"]["coordinates"];
        _polylinePoints =
            coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

        StringBuffer sb = StringBuffer();
        sb.writeln("ETA: ${(duration / 60).toStringAsFixed(1)} min");
        sb.writeln("Distance: ${(distance / 1000).toStringAsFixed(2)} km");
        sb.writeln("\nTurn-by-turn:");

        debugPrint("🗺 Walking Route Info:");
        debugPrint("ETA: ${(duration / 60).toStringAsFixed(1)} min");
        debugPrint("Distance: ${(distance / 1000).toStringAsFixed(2)} km");
        debugPrint("Turn-by-turn directions:");

        for (var step in steps) {
          final maneuver = step["maneuver"];
          final instruction =
              "${maneuver["modifier"] ?? ""} ${maneuver["type"]}";
          final name = step["name"].toString().isEmpty
              ? "(no street name)"
              : step["name"];
          final dist = step["distance"];

          final dir =
              "➡️ $instruction onto $name for ${dist.toStringAsFixed(0)} m";

          sb.writeln(dir);
          debugPrint(dir);
        }

        setState(() {
          result = sb.toString();
          _destination = dest;
        });

        // 🔹 Recenter map to destination automatically
        _mapController.move(dest, 16);
      } else {
        setState(() {
          result = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        result = "Failed: $e";
      });
    }
  }

  /// Handle search submit
  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final dest = await _geocodeAddress(query);
    if (dest != null) {
      _getWalkingRoute(dest);
    } else {
      setState(() {
        result = "❌ Address not found!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          : Column(
              children: [
Expanded(
  flex: 2,
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Text(result),
                  ),
                ),
              ],
            ),
    );
  }
}
