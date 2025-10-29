import 'package:flutter/material.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================
// FIXED ONBOARDING DIALOG WITH LANGUAGE TOGGLE
// ============================================

class OnboardingDialog extends StatefulWidget {
  final Function(String) onPlayTTS;
  final String screen;
  final String language;
  final bool language_status;
  final VoidCallback onToggleLanguage;
  
  const OnboardingDialog({
    Key? key,
    required this.onPlayTTS,
    required this.screen,
    required this.language,
    required this.language_status,
    required this.onToggleLanguage,
  }) : super(key: key);

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<bool> _ttsPlayed = [false, false, false, false];
  bool _isPlayingTTS = false;

  // ✅ Use internal language state that updates immediately
  late bool _currentLanguageStatus;

  final List<String> _ttsContent = [
    "Welcome to Res-Q, your personal assistance application. This app is designed to help visually impaired users navigate their surroundings, read text, detect objects, and get assistance. Let's walk you through the features and how to use them.",
    "Res-Q offers four main features: Scene Description analyzes and describes your surroundings in detail. Object Detection helps you identify objects around you using your camera. OCR or Optical Character Recognition reads text from images and documents. Navigation provides walking route guidance to your destination.",
    "To use the voice assistant, long press your headset microphone button to start listening. Speak your command clearly. Single tap the button to stop listening and send your request. You can also use the manual button on the screen if needed. The app will transcribe your speech and respond accordingly.",
    "You're all set to use Res-Q! Remember, you can access settings anytime from the home screen. For emergency situations, use the SOS button at the bottom. We're here to assist you every step of the way. Thank you for using ResQ!"
  ];

  final List<String> _kannadaContent = [
    "ನಿಮ್ಮ ವೈಯಕ್ತಿಕ ಸಹಾಯ ಅಪ್ಲಿಕೇಶನ್, Res-Q ಗೆ ಸುಸ್ವಾಗತ. ದೃಷ್ಟಿಹೀನ ಬಳಕೆದಾರರು ತಮ್ಮ ಸುತ್ತಮುತ್ತಲಿನ ಪ್ರದೇಶಗಳನ್ನು ನ್ಯಾವಿಗೇಟ್ ಮಾಡಲು, ಪಠ್ಯವನ್ನು ಓದಲು, ವಸ್ತುಗಳನ್ನು ಪತ್ತೆಹಚ್ಚಲು ಮತ್ತು ಸಹಾಯವನ್ನು ಪಡೆಯಲು ಸಹಾಯ ಮಾಡಲು ಈ ಅಪ್ಲಿಕೇಶನ್ ಅನ್ನು ವಿನ್ಯಾಸಗೊಳಿಸಲಾಗಿದೆ. ವೈಶಿಷ್ಟ್ಯಗಳು ಮತ್ತು ಅವುಗಳನ್ನು ಹೇಗೆ ಬಳಸುವುದು ಎಂಬುದರ ಮೂಲಕ ನಿಮ್ಮನ್ನು ಕರೆದೊಯ್ಯೋಣ.",
    "Res-Q ನಾಲ್ಕು ಪ್ರಮುಖ ವೈಶಿಷ್ಟ್ಯಗಳನ್ನು ನೀಡುತ್ತದೆ: ದೃಶ್ಯ ವಿವರಣೆಯು ನಿಮ್ಮ ಸುತ್ತಮುತ್ತಲಿನ ಪ್ರದೇಶಗಳನ್ನು ವಿವರವಾಗಿ ವಿಶ್ಲೇಷಿಸುತ್ತದೆ ಮತ್ತು ವಿವರಿಸುತ್ತದೆ. ಆಬ್ಜೆಕ್ಟ್ ಡಿಟೆಕ್ಷನ್ ನಿಮ್ಮ ಕ್ಯಾಮೆರಾವನ್ನು ಬಳಸಿಕೊಂಡು ನಿಮ್ಮ ಸುತ್ತಲಿನ ವಸ್ತುಗಳನ್ನು ಗುರುತಿಸಲು ನಿಮಗೆ ಸಹಾಯ ಮಾಡುತ್ತದೆ. OCR ಅಥವಾ ಆಪ್ಟಿಕಲ್ ಕ್ಯಾರೆಕ್ಟರ್ ರೆಕಗ್ನಿಷನ್ ಚಿತ್ರಗಳು ಮತ್ತು ದಾಖಲೆಗಳಿಂದ ಪಠ್ಯವನ್ನು ಓದುತ್ತದೆ. ನ್ಯಾವಿಗೇಷನ್ ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನಕ್ಕೆ ವಾಕಿಂಗ್ ಮಾರ್ಗ ಮಾರ್ಗದರ್ಶನವನ್ನು ಒದಗಿಸುತ್ತದೆ.",
    "ಧ್ವನಿ ಸಹಾಯಕವನ್ನು ಬಳಸಲು, ಕೇಳುವುದನ್ನು ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ ಹೆಡ್‌ಸೆಟ್ ಮೈಕ್ರೊಫೋನ್ ಬಟನ್ ಅನ್ನು ದೀರ್ಘಕಾಲ ಒತ್ತಿರಿ. ನಿಮ್ಮ ಆಜ್ಞೆಯನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ. ಕೇಳುವುದನ್ನು ನಿಲ್ಲಿಸಲು ಮತ್ತು ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಕಳುಹಿಸಲು ಬಟನ್ ಅನ್ನು ಒಮ್ಮೆ ಟ್ಯಾಪ್ ಮಾಡಿ. ಅಗತ್ಯವಿದ್ದರೆ ನೀವು ಪರದೆಯ ಮೇಲಿನ ಹಸ್ತಚಾಲಿತ ಬಟನ್ ಅನ್ನು ಸಹ ಬಳಸಬಹುದು. ಅಪ್ಲಿಕೇಶನ್ ನಿಮ್ಮ ಭಾಷಣವನ್ನು ಲಿಪ್ಯಂತರ ಮಾಡುತ್ತದೆ ಮತ್ತು ಅದಕ್ಕೆ ಅನುಗುಣವಾಗಿ ಪ್ರತಿಕ್ರಿಯಿಸುತ್ತದೆ.",
    "ನೀವು Res-Q ಬಳಸಲು ಸಿದ್ಧರಾಗಿದ್ದೀರಿ! ನೆನಪಿಡಿ, ನೀವು ಮುಖಪುಟ ಪರದೆಯಿಂದ ಯಾವುದೇ ಸಮಯದಲ್ಲಿ ಸೆಟ್ಟಿಂಗ್‌ಗಳನ್ನು ಪ್ರವೇಶಿಸಬಹುದು. ತುರ್ತು ಸಂದರ್ಭಗಳಲ್ಲಿ, ಕೆಳಭಾಗದಲ್ಲಿರುವ SOS ಬಟನ್ ಬಳಸಿ. ಪ್ರತಿ ಹಂತದಲ್ಲೂ ನಿಮಗೆ ಸಹಾಯ ಮಾಡಲು ನಾವು ಇಲ್ಲಿದ್ದೇವೆ. ResQ ಬಳಸಿದ್ದಕ್ಕಾಗಿ ಧನ್ಯವಾದಗಳು!"
  ];

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Welcome to ResQ",
      "icon": Icons.waving_hand,
      "color": Colors.blue,
      "description":
          "Your personal assistance application designed to help you navigate, read, and understand your surroundings.",
    },
    {
      "title": "App Features",
      "icon": Icons.apps,
      "color": Colors.green,
      "description":
          "\n• Scene Description\n• Object Detection\n• Text Recognition (OCR)\n• Walking Navigation",
    },
    {
      "title": "Using Voice Assistant",
      "icon": Icons.mic,
      "color": Colors.orange,
      "description":
          "Control with your voice:\n\n• Long press to start\n• Speak your command\n• Single tap to stop\n• Get instant response",
    },
    {
      "title": "You're Ready!",
      "icon": Icons.check_circle,
      "color": Colors.purple,
      "description":
          "All set to begin your journey with ResQ. Access settings anytime and use the SOS button for emergencies.",
    },
  ];

  final List<Map<String, dynamic>> _kannadaPages = [
    {
      "title": "ResQ ಗೆ ಸುಸ್ವಾಗತ",
      "icon": Icons.waving_hand,
      "color": Colors.blue,
      "description":
          "ನಿಮ್ಮ ಸುತ್ತಮುತ್ತಲಿನ ಪ್ರದೇಶಗಳನ್ನು ನ್ಯಾವಿಗೇಟ್ ಮಾಡಲು, ಓದಲು ಮತ್ತು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲು ನಿಮಗೆ ಸಹಾಯ ಮಾಡಲು ವಿನ್ಯಾಸಗೊಳಿಸಲಾದ ನಿಮ್ಮ ವೈಯಕ್ತಿಕ ಸಹಾಯ ಅಪ್ಲಿಕೇಶನ್.",
    },
    {
      "title": "ಅಪ್ಲಿಕೇಶನ್ ವೈಶಿಷ್ಟ್ಯಗಳು",
      "icon": Icons.apps,
      "color": Colors.green,
      "description":
          "\n• ದೃಶ್ಯ ವಿವರಣೆ\n• ವಸ್ತು ಪತ್ತೆ\n• ಪಠ್ಯ ಗುರುತಿಸುವಿಕೆ (OCR)\n• ನಡಿಗೆ ಸಂಚರಣೆ",
    },
    {
      "title": "ಧ್ವನಿ ಸಹಾಯಕವನ್ನು ಬಳಸುವುದು",
      "icon": Icons.mic,
      "color": Colors.orange,
      "description":
          "ನಿಮ್ಮ ಧ್ವನಿಯೊಂದಿಗೆ ನಿಯಂತ್ರಿಸಿ:\n\n• ಪ್ರಾರಂಭಿಸಲು ದೀರ್ಘವಾಗಿ ಒತ್ತಿರಿ\n• ನಿಮ್ಮ ಆಜ್ಞೆಯನ್ನು ಹೇಳಿ\n• ನಿಲ್ಲಿಸಲು ಒಂದೇ ಟ್ಯಾಪ್ ಮಾಡಿ\n• ತ್ವರಿತ ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಿರಿ",
    },
    {
      "title": "ನೀವು ಸಿದ್ಧರಿದ್ದೀರಿ!",
      "icon": Icons.check_circle,
      "color": Colors.purple,
      "description":
          "ResQ ನೊಂದಿಗೆ ನಿಮ್ಮ ಪ್ರಯಾಣವನ್ನು ಪ್ರಾರಂಭಿಸಲು ಎಲ್ಲವೂ ಸಿದ್ಧವಾಗಿದೆ. ಯಾವುದೇ ಸಮಯದಲ್ಲಿ ಸೆಟ್ಟಿಂಗ್‌ಗಳನ್ನು ಪ್ರವೇಶಿಸಿ ಮತ್ತು ತುರ್ತು ಸಂದರ್ಭಗಳಲ್ಲಿ SOS ಬಟನ್ ಬಳಸಿ.",
    },
  ];

  @override
  void initState() {
    super.initState();
    // ✅ Initialize with widget's language status
    _currentLanguageStatus = widget.language_status;
  }

  @override
  void dispose() {
    // ✅ Stop TTS before disposing
    TTSManager().stop();
    _pageController.dispose();
    super.dispose();
  }

  void _playTTS(int pageIndex) {
    // ✅ Stop any playing TTS first
    TTSManager().stop();
    
    setState(() {
      _isPlayingTTS = true;
    });

    // ✅ Use current internal language status
    final ttsText = _currentLanguageStatus 
        ? _ttsContent[pageIndex] 
        : _kannadaContent[pageIndex];
    
    widget.onPlayTTS(ttsText);

    // ✅ Dynamic duration based on page
    int seconds = _currentLanguageStatus ? [14, 20, 18, 14][pageIndex] : [25, 29, 26, 19][pageIndex];

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          _ttsPlayed[pageIndex] = true;
          _isPlayingTTS = false;
        });
      }
    });
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    // ✅ Stop TTS when navigating
    TTSManager().stop();
    setState(() {
      _isPlayingTTS = false;
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    // ✅ Stop TTS when navigating
    TTSManager().stop();
    setState(() {
      _isPlayingTTS = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ✅ Handle language toggle WITHOUT closing dialog
  void _handleLanguageToggle() {
    // Stop any playing TTS
    TTSManager().stop();
    
    setState(() {
      // Toggle internal language status
      _currentLanguageStatus = !_currentLanguageStatus;
      _isPlayingTTS = false;
      // Reset TTS played status for current page
      _ttsPlayed[_currentPage] = false;
    });
    
    // Call parent's toggle (updates parent state)
    widget.onToggleLanguage();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use internal language status for UI
    final currentPages = _currentLanguageStatus ? _pages : _kannadaPages;
    final currentPage = currentPages[_currentPage];
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: _handleLanguageToggle,
                    icon: const Icon(Icons.language),
                    label: Text(
                      _currentLanguageStatus ? "English" : "ಕನ್ನಡ (Kannada)",
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w700
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () {
                      TTSManager().stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
            
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? currentPage['color']
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 4,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = currentPages[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page['icon'],
                            size: 60,
                            color: page['color'],
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          page['title'],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              page['description'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isPlayingTTS ? null : () => _playTTS(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: page['color'],
                            padding: EdgeInsets.symmetric(
                              horizontal: 32, 
                              vertical: 16
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            minimumSize: Size(200, 56),
                          ),
                          icon: Icon(
                            _isPlayingTTS && _currentPage == index
                                ? Icons.volume_up
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                          label: Text(
                            _isPlayingTTS && _currentPage == index
                                ? (_currentLanguageStatus
                                    ? 'Playing...'
                                    : 'ಆಡುತ್ತಿದ್ದೇನೆ...')
                                : (_currentLanguageStatus
                                    ? 'Play Instructions'
                                    : 'ಪ್ಲೇ ಸೂಚನೆಗಳು'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_ttsPlayed[index])
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _currentLanguageStatus
                                      ? 'Instructions played'
                                      : 'ಸೂಚನೆಗಳನ್ನು ನುಡಿಸಲಾಗಿದೆ',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: _previousPage,
                      icon: Icon(Icons.arrow_back),
                      label: Text(
                        _currentLanguageStatus ? 'Previous' : 'ಹಿಂದಿನದು',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: 20, 
                          vertical: 12
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 100),
                    
                  ElevatedButton.icon(
                    onPressed: _ttsPlayed[_currentPage]
                        ? (_currentPage == 3 
                            ? _completeOnboarding 
                            : _nextPage)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage == 3
                          ? Colors.green
                          : currentPage['color'],
                      padding: EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: 12
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    icon: Icon(
                      _currentPage == 3 ? Icons.check : Icons.arrow_forward,
                      color: Colors.white,
                    ),
                    label: Text(
                      _currentPage == 3
                          ? (_currentLanguageStatus ? 'Complete' : 'ಸಂಪೂರ್ಣ')
                          : (_currentLanguageStatus ? 'Next' : 'ಮುಂದೆ'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}