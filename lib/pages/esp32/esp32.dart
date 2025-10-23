import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Capture Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ImageCaptureScreen(),
    );
  }
}

// ==================== IMAGE CAPTURE SERVICE ====================

class ImageCaptureService {
  String baseUrl = 'http://10.195.49.101';
  static const String captureEndpoint = '/capture';

  /// Set custom port for the server
  void setPort(int port) {
    baseUrl = 'http://10.195.49.101:$port';
    print('Base URL updated to: $baseUrl');
  }

  /// Captures image using HttpClient with streaming for better timeout handling
  Future<Uint8List?> captureImageWithStreaming() async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 60);
      client.idleTimeout = const Duration(seconds: 90);

      print('Initiating connection to $baseUrl$captureEndpoint...');
      
      final request = await client.getUrl(Uri.parse('$baseUrl$captureEndpoint'));
      
      print('Waiting for response...');
      final response = await request.close().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException('Response timed out after 90 seconds');
        },
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Downloading image data...');
        final bytes = await consolidateHttpClientResponseBytes(response);
        print('Successfully downloaded ${bytes.length} bytes');
        return bytes;
      } else {
        print('Failed with status code: ${response.statusCode}');
        return null;
      }
    } on SocketException catch (e) {
      print('Socket error: Cannot reach server');
      print('Error: $e');
      return null;
    } on TimeoutException catch (e) {
      print('Timeout: $e');
      print('The server is taking too long. Possible issues:');
      print('- Camera/device is slow to capture');
      print('- Server is processing the image');
      print('- Network is very slow');
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    } finally {
      client?.close();
    }
  }

  /// Helper method to consolidate response bytes
  Future<Uint8List> consolidateHttpClientResponseBytes(
    HttpClientResponse response,
  ) async {
    final chunks = <List<int>>[];
    int downloaded = 0;

    await for (var chunk in response) {
      chunks.add(chunk);
      downloaded += chunk.length;
      print('Downloaded: $downloaded bytes');
    }

    final totalLength = chunks.fold<int>(0, (prev, chunk) => prev + chunk.length);
    final bytes = Uint8List(totalLength);
    
    int offset = 0;
    for (var chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return bytes;
  }

  /// Try alternative endpoints that might work faster
  Future<Uint8List?> tryAlternativeEndpoints() async {
    final endpoints = [
      '/capture',
      '/api/capture',
      '/snapshot',
      '/image',
      '/photo',
    ];

    for (final endpoint in endpoints) {
      print('Trying endpoint: $endpoint');
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        
        final request = await client.getUrl(Uri.parse('$baseUrl$endpoint'));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );

        if (response.statusCode == 200) {
          print('Success with endpoint: $endpoint');
          final bytes = await consolidateHttpClientResponseBytes(response);
          client.close();
          return bytes;
        }
        
        client.close();
      } catch (e) {
        print('Failed with $endpoint: $e');
      }
    }

    return null;
  }

  /// Quick ping test to check if server is reachable on multiple ports
  Future<bool> quickPing() async {
    final ports = [80, 8080, 5000, 3000, 8000];
    
    for (final port in ports) {
      try {
        print('Trying port $port...');
        final socket = await Socket.connect(
          '10.195.49.101',
          port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        print('✓ Server is reachable on port $port');
        return true;
      } catch (e) {
        print('✗ Port $port failed: ${e.toString().split('\n')[0]}');
      }
    }
    
    print('Server is not reachable on any common port');
    return false;
  }
  
  /// Find which port the server is running on
  Future<int?> findServerPort() async {
    final ports = [80, 8080, 5000, 3000, 8000, 8888, 9000];
    
    for (final port in ports) {
      try {
        print('Testing port $port...');
        final socket = await Socket.connect(
          '10.195.49.101',
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
        print('✓ Found server on port $port');
        return port;
      } catch (e) {
        // Continue to next port
      }
    }
    
    return null;
  }

  /// Captures image and saves it to a file
  Future<File?> captureAndSaveImage({String? fileName}) async {
    try {
      final bytes = await captureImageWithStreaming();
      
      if (bytes == null) {
        return null;
      }

      final dir = await getTemporaryDirectory();
      final name = fileName ?? 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$name');

      await file.writeAsBytes(bytes);
      print('Image saved to: ${file.path}');
      
      return file;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  /// Captures with retry mechanism
  Future<Uint8List?> captureWithRetry({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      print('Attempt ${i + 1} of $maxRetries...');
      
      final bytes = await captureImageWithStreaming();
      
      if (bytes != null) {
        return bytes;
      }

      if (i < maxRetries - 1) {
        print('Waiting ${retryDelay.inSeconds} seconds before retry...');
        await Future.delayed(retryDelay);
      }
    }

    print('All retry attempts failed');
    return null;
  }

  /// Test with simple HTTP package (shorter timeout)
  Future<Uint8List?> quickCapture() async {
    try {
      print('Quick capture attempt (15s timeout)...');
      final response = await http
          .get(Uri.parse('$baseUrl$captureEndpoint'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Quick capture failed: $e');
      return null;
    }
  }
}

// ==================== UI SCREEN ====================

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImageCaptureService _service = ImageCaptureService();
  
  Uint8List? _imageBytes;
  File? _imageFile;
  bool _isLoading = false;
  String _statusMessage = 'Ready to capture';

  // Method 1: Capture image as bytes
  Future<void> _captureImageAsBytes() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Capturing image...';
      _imageBytes = null;
    });

    try {
      final bytes = await _service.captureImageWithStreaming();
      
      setState(() {
        if (bytes != null) {
          _imageBytes = bytes;
          _statusMessage = 'Image captured successfully! (${bytes.length} bytes)';
        } else {
          _statusMessage = 'Failed to capture image';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method 2: Capture and save to file
  Future<void> _captureAndSaveToFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Capturing and saving image...';
      _imageFile = null;
      _imageBytes = null;
    });

    try {
      final file = await _service.captureAndSaveImage();
      
      setState(() {
        if (file != null) {
          _imageFile = file;
          _statusMessage = 'Image saved to: ${file.path}';
        } else {
          _statusMessage = 'Failed to save image';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method 3: Capture with retry
  Future<void> _captureWithRetry() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Capturing with retry (up to 3 attempts)...';
      _imageBytes = null;
    });

    try {
      final bytes = await _service.captureWithRetry(maxRetries: 3);
      
      setState(() {
        if (bytes != null) {
          _imageBytes = bytes;
          _statusMessage = 'Image captured with retry! (${bytes.length} bytes)';
        } else {
          _statusMessage = 'All retry attempts failed';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method 4: Quick capture (15s timeout)
  Future<void> _quickCapture() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Quick capture (15s timeout)...';
      _imageBytes = null;
    });

    try {
      final bytes = await _service.quickCapture();
      
      setState(() {
        if (bytes != null) {
          _imageBytes = bytes;
          _statusMessage = 'Quick capture successful! (${bytes.length} bytes)';
        } else {
          _statusMessage = 'Quick capture failed';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test server connection
  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing server connection...';
    });

    try {
      final isReachable = await _service.quickPing();
      
      setState(() {
        _statusMessage = isReachable 
            ? '✓ Server is reachable' 
            : '✗ Server is not reachable on ports: 80, 8080, 5000, 3000, 8000';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection test error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Find server port automatically
  Future<void> _findServerPort() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning for server port...';
    });

    try {
      final port = await _service.findServerPort();
      
      setState(() {
        if (port != null) {
          _service.setPort(port);
          _statusMessage = '✓ Server found on port $port! URL: ${_service.baseUrl}';
        } else {
          _statusMessage = '✗ Server not found on any common port (80, 8080, 5000, 3000, 8000, 8888, 9000)';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Port scan error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Manual port entry
  Future<void> _showPortDialog() async {
    final controller = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Server Port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'e.g., 8080',
            labelText: 'Port Number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (port != null && port > 0 && port < 65536) {
                _service.setPort(port);
                setState(() {
                  _statusMessage = 'Port set to $port. URL: ${_service.baseUrl}';
                });
              } else {
                setState(() {
                  _statusMessage = 'Invalid port number';
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Capture'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              color: _isLoading ? Colors.orange[50] : Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_isLoading) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Server Configuration Section
            const Text(
              'Server Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Find Server Port Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _findServerPort,
              icon: const Icon(Icons.search),
              label: const Text('Auto-Find Server Port'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Manual Port Entry Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _showPortDialog,
              icon: const Icon(Icons.settings),
              label: const Text('Set Port Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Test Connection Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: const Icon(Icons.network_check),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 20),

            // Capture Actions Section
            const Text(
              'Capture Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Quick Capture Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _quickCapture,
              icon: const Icon(Icons.flash_on),
              label: const Text('Quick Capture (15s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Normal Capture Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _captureImageAsBytes,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Capture with Retry Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _captureWithRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Capture with Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Save to File Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _captureAndSaveToFile,
              icon: const Icon(Icons.save),
              label: const Text('Capture & Save to File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 24),

            // Image preview
            if (_imageBytes != null || _imageFile != null) ...[
              const Text(
                'Captured Image Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.contain,
                            )
                          : const SizedBox(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}