import 'package:flutter/material.dart';
import 'package:req_demo/pages/ocr_ml_kit.dart';
import 'object_detection.dart';
import 'settings_page.dart';
import 'package:camera/camera.dart';
import 'package:req_demo/pages/navigation.dart';
class HomePage extends StatelessWidget {
  final List<CameraDescription> cameras;
  HomePage({required this.cameras});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        "title": "Object Detection",
        "icon": Icons.camera_alt,
        "page": ObjectDetectionScreen(cameras: cameras)
      },
      {
        "title": "OCR",
        "icon": Icons.text_fields,
        "page": OCRHomePage()
      },
      {
        "title": "Navigation",
        "icon": Icons.navigation,
        "page": WalkingRouteMapPage()
      },
      {
        "title": "Scene Description",
        "icon": Icons.image_search,
        "page": PlaceholderPage(title: "Scene Description")
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("ResQ"),
        actions: [
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
      body: Column(
        children: [
          // Big Connect Glasses button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: Size(double.infinity, 100), // taller button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // TODO: implement connect glasses logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Connecting to glasses...")),
                );
              },
              icon: Icon(Icons.wifi_tethering, color: Colors.white, size: 32),
              label: Text(
                "Connect Glasses",
                style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Grid of 4 feature squares
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                itemCount: features.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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
                          Icon(feature["icon"], size: 50, color: Colors.white),
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
          ),
        ],
      ),

      // Emergency SOS floating button with margin
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12.0), // add bottom margin
        child: FloatingActionButton.extended(
          backgroundColor: Colors.red,
          icon: Icon(Icons.emergency, color: Colors.white),
          label: Text("SOS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              )),
          onPressed: () {
            // TODO: implement SOS
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("🚨 Emergency SOS Triggered!")),
            );
          },
        ),
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
