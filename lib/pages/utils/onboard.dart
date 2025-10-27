import 'package:flutter/material.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
  
// ============================================
// ONBOARDING DIALOG COMPONENT
// ============================================

class OnboardingDialog extends StatefulWidget {
  final Function(String) onPlayTTS;
  final String screen;
  const OnboardingDialog({
    Key? key,
    required this.onPlayTTS,
    required this.screen,
  }) : super(key: key);

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<bool> _ttsPlayed = [false, false, false, false];
  bool _isPlayingTTS = false;

  final List<String> _ttsContent1 = [
    """Hello there! Welcome to RescueLenses.\n\n I am here to assist you in navigating your surroundings and using your device more easily.\n\n
With the help of your voice and camera, RescueLenses can understand your requests and guide you through different tasks.\n\n
You can speak naturally, and I will help you based on your intent.\n\n
To learn more about what the app can do, please continue to the next instruction page.\n\n
After you go through all the sections, make sure to press the Done button to confirm that you have completed the tutorial.
""",
    """
Now, let me explain the features of RescueLenses.\n\n

First feature: Scene Description.\n
You can ask about your surroundings, and I will describe what the camera sees.\n
You may ask questions like:\n
What is around me?\n
What can you see in front of me?\n
Describe the scene.\n\n

Second feature: Object Detection.\n
I can help you identify specific objects around you.\n
You can ask questions such as:\n
Is there a chair in front of me?\n
Can you find a bottle on the table?\n
Do you see any people nearby?\n\n

Third feature: Optical Character Recognition, also called OCR.\n
This feature helps you read printed or written text from your surroundings.\n
You can ask things like:\n
Read the text on this paper.\n
What is written on this board?\n
Can you read the label for me?\n\n

Last feature: Navigation Assistance.\n
I can guide you by giving step by step directions.\n
You can ask for help by saying:\n
Guide me to the door.\n
Help me walk to the staircase.\n
Show me the direction to the exit.\n\n

After listening to all instructions, please go to the next section or press Done when completed.
""",
    """

Now, let's learn how to use the microphone to communicate with RescueLenses.\n\n
To activate the microphone, press and hold the mic button for about one to two seconds. This is called a long tap.\n\n
Once the mic is activated, speak clearly and announce the instruction or question you want the application to process.\n\n
If you want to stop the recording early, you can do a single tap on the mic button. The application will immediately stop listening and start processing your instruction.\n\n
After a short moment, based on your intent, the application will provide you with the appropriate response.\n\n
Remember, a long tap activates the mic, a single tap stops the mic, and then RescueLenses will take care of the rest.\n\n
You can practice this anytime using the mic instructions button in Practice Area if you forget.
""",
    """
Congratulations! You have completed all the required instructions for using RescueLenses.\n\n
You are now ready to explore and use the application.\n\n
If you would like to practice, you can visit the practice area anytime to try out the features.\n\n
Remember, once you click the 'Completed' button below, these tutorial instructions will not appear on the next launch.\n\n
Enjoy using RescueLenses, and stay safe!

"""
  ];

  final List<String> _ttsContent = [
    "Welcome to ResQ, your personal assistance application. This app is designed to help visually impaired users navigate their surroundings, read text, detect objects, and get assistance. Let's walk you through the features and how to use them.",
    "ResQ offers four main features: Object Detection helps you identify objects around you using your camera. OCR or Optical Character Recognition reads text from images and documents. Navigation provides walking route guidance to your destination. Scene Description analyzes and describes your surroundings in detail.",
    "To use the voice assistant, long press your headset microphone button to start listening. Speak your command clearly. Single tap the button to stop listening and send your request. You can also use the manual button on the screen if needed. The app will transcribe your speech and respond accordingly.",
    "You're all set to use ResQ! Remember, you can access settings anytime from the home screen. For emergency situations, use the SOS button at the bottom. We're here to assist you every step of the way. Thank you for using ResQ!"
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
          "\n• Scene Description\n• Object Detection\n• Text Recognition (OCR)\n• Walking Navigation\n• Scene Description",
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _playTTS(int pageIndex) {
    setState(() {
      _isPlayingTTS = true;
    });

    widget.onPlayTTS(_ttsContent[pageIndex]);

    int seconds = 0;
    if (pageIndex == 0) {
      seconds = 14;
    } else if (pageIndex == 1) {
      seconds = 20;
    } else if (pageIndex == 2) {
      seconds = 18;
    } else if (pageIndex == 3) {
      seconds = 14;
    }

    // Mark as played after 5 seconds (adjust based on actual TTS duration)
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
    TTSManager().stop();
    setState(() {
      _isPlayingTTS = false;
    });
  }

  Future<void> _completeOnboarding() async {

    // if(widget.screen == "home"){
      final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  // }
    

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
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
                          ? _pages[_currentPage]['color']
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
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
                  final page = _pages[index];
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
                          onPressed:
                              _isPlayingTTS ? null : () => _playTTS(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: page['color'],
                            padding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
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
                                ? 'Playing...'
                                : 'Play Instructions',
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
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Instructions played',
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: _previousPage,
                      icon: Icon(Icons.arrow_back),
                      label: Text('Previous'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    SizedBox(width: 100),
                  ElevatedButton.icon(
                    onPressed: _ttsPlayed[_currentPage]
                        ? (_currentPage == 3  ? _completeOnboarding : _nextPage)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage == 3
                          ? Colors.green
                          : _pages[_currentPage]['color'],
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      _currentPage == 3 ? 'Complete' : 'Next',
                      style: TextStyle(
                        fontSize: 16,
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
