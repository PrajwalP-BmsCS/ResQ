import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OCRHomePage extends StatefulWidget {
  @override
  _OCRHomePageState createState() => _OCRHomePageState();
}

class _OCRHomePageState extends State<OCRHomePage> {
  String _extractedText = '';
  File? _selectedImage;
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    String scannedText = '';
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        scannedText += line.text + '\n';
      }
    }

    setState(() {
      _selectedImage = imageFile;
      _extractedText = scannedText;
    });

    _speakText(scannedText);
  }

  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
    setState(() => _isSpeaking = true);
  }

  Future<void> _pauseSpeech() async {
    await flutterTts.pause();
    setState(() => _isSpeaking = false);
  }

  Future<void> _resumeSpeech() async {
    await flutterTts.speak(_extractedText);
    setState(() => _isSpeaking = true);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OCR & TTS Smart Reader')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera),
                  label: Text('Camera'),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedImage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(_selectedImage!, height: 250),
                  const SizedBox(height: 20),
                  Text(
                    _extractedText,
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_extractedText.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSpeaking ? _pauseSpeech : null,
                    icon: Icon(Icons.pause),
                    label: Text('Pause'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: !_isSpeaking ? _resumeSpeech : null,
                    icon: Icon(Icons.play_arrow),
                    label: Text('Resume'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
