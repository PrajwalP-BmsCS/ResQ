import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart'; // <-- make sure you added location package in pubspec.yaml

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng? _pickedPos;
  LatLng? _currentPos;
  String result = "";
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // auto-get location when page loads
  }

  /// ✅ Your added method
  Future<void> _getCurrentLocation() async {
    try {
      Location location = Location();

      // Ask for service
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

      // Ask for permission
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

      // Get location
      LocationData pos = await location.getLocation();
      setState(() {
        _currentPos = LatLng(pos.latitude!, pos.longitude!);
        _mapController.move(_currentPos!, 15.0); // 👈 move map to current location
      });
    } catch (e) {
      setState(() {
        result = "Error getting location: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick a Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _pickedPos ?? _currentPos);
            },
          )
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPos ?? LatLng(12.9716, 77.5946), // fallback BLR
          initialZoom: 13,
          onTap: (tapPos, latlng) {
            setState(() {
              _pickedPos = latlng;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                "https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png", // ✅ avoid blocked OSM tiles
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          if (_pickedPos != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pickedPos!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                )
              ],
            )
          else if (_currentPos != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPos!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                )
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: _getCurrentLocation, 
      ),
    );
  }
}
