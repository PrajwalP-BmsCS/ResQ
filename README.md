# ResQ Lens - AI Powered Smart Glasses for Visually Imapaired Individuals
ResQ Lens is a smart safety and monitoring system designed to improve campus security and student well-being. It uses edge-based image processing, BLE technology, and instant alert mechanisms to detect risks and notify the right people quickly. With features like parent notifications, live student updates, and anti-ragging alerts, ResQ Lens provides a fast, privacy-focused, and reliable safety solution for educational institutions.
<h2>Table of Contents</h2>
<ul>
  <li> <a href = "#About"> About </a></li>
  <ul>
   <li><a href="#wa"> What is ResQ? </a></li> 
   <li><a href="#features"> Features </a></li> 
   <li><a href="#why"> Why ResQ? </a></li>
  </ul>
  <li> <a href = "#getting_started"> Getting Started </a></li>
  <ul>
   <li><a href="#prerequisites"> Prerequisites </a></li> 
   <li><a href="#installation"> Installation </a></li> 
   <li><a href="#backend_setup"> Backend Setup </a></li>
   <li><a href="#frontend_setup"> Building the App </a></li>
  </ul>
  <li> <a href = "#tech_used"> TechStack Used </a></li>
  <li> <a href = "#architecture"> System Architecture </a></li>
  <li> <a href = "#screenshots"> Screenshots and App Demonstration </a></li>
  <li> <a href = "#conclusion"> Conclusion </a></li>
  <li> <a href = "#team"> Developed By </a></li>
</ul>
<section id = "About">
  <h2> About </h2>
  <h3 id = "wa"> What is ResQ? </h3>
    ResQ is a safety and assistance system designed to provide rapid support during emergencies. It combines smart sensing, real-time alerts, and automated decision-making to detect risks and notify trusted contacts or authorities instantly. The system is built to enhance personal safety—whether through monitoring, live location sharing, incident detection, or quick-response communication—making it ideal for schools, campuses, workplaces, and public environments.
  <h3 id = "features"> Features </h3>
<ul>
    <li><strong>Voice-Based Interaction</strong>
        <ul>
            <li>Hands-free commands using long-press mic activation</li>
            <li>Fast and accurate speech recognition via Groq Whisper API</li>
            <li>Supports multilingual voice input (English & Kannada)</li>
        </ul>
    </li>
    <br>
    <li><strong>Scene Description</strong>
        <ul>
            <li>Real-time visual understanding using YOLOv5-Nano</li>
            <li>Identifies objects, people, and surroundings</li>
            <li>Generates concise and clear audio descriptions</li>
        </ul>
    </li>
    <br>
    <li><strong>Object Detection & Obstacle Awareness</strong>
        <ul>
            <li>Detects nearby objects for enhanced situational safety</li>
            <li>Alerts users about obstacles within the camera frame</li>
            <li>Optimized for low-latency inference on mobile</li>
        </ul>
    </li>
    <br>
    <li><strong>OCR & Text Reading</strong>
        <ul>
            <li>Reads printed text using Google ML Kit OCR</li>
            <li>Supports documents, signboards, labels, and screens</li>
            <li>Cleaned and structured output for clarity</li>
        </ul>
    </li>
    <br>
    <li><strong>Navigation Assistance</strong>
        <ul>
            <li>Walking-route guidance using Google Maps API</li>
            <li>Turn-by-turn audio navigation for safe mobility</li>
            <li>Location-based context awareness</li>
        </ul>
    </li>
    <br>
    <li><strong>SOS & Emergency Support</strong>
        <ul>
            <li>Instant SOS trigger with long-press gesture</li>
            <li>Auto-shares live location with trusted contacts</li>
            <li>Emergency call option included</li>
        </ul>
    </li>
    <br>
    <li><strong>Voice-Guided Onboarding</strong>
        <ul>
            <li>Step-by-step instructions for first-time users</li>
            <li>Explains app features, preferences, and mic usage</li>
            <li>Available in English and Kannada</li>
        </ul>
    </li>
    <br>
    <li><strong>Optimized Mobile Architecture</strong>
        <ul>
            <li>Flutter-based app with smooth UI and animations</li>
            <li>FastAPI backend for intent processing</li>
            <li>Groq LPU-powered classification for ultra-low latency</li>
        </ul>
    </li>
</ul>
 <h3 id="why"> Why ResQ Lens? </h3>
<ul>
    <li><strong>Hands-Free Assistance</strong>: Designed for visually impaired users who rely on voice and audio guidance for daily tasks.</li>
    <li><strong>Real-Time Understanding</strong>: Instantly describes surroundings, reads text, and detects objects using advanced vision models.</li>
    <li><strong>Improved Safety</strong>: Obstacle alerts, SOS mode, and live location sharing enhance user safety during navigation.</li>
    <li><strong>Accurate Voice Interaction</strong>: High-precision speech recognition ensures smooth and reliable command execution.</li>
    <li><strong>All-in-One Support</strong>: Combines scene description, OCR, navigation, and emergency features into a single lightweight app.</li>
    <li><strong>Inclusive & Multilingual</strong>: Built with accessibility-first design and supports both English and Kannada voice guidance.</li>
</ul>
</section>
<section id = "getting_started">
  <h2> Getting Started </h2>
  <h3 id = "prerequisites"> Prerequisites </h3>
  <p>Before you begin, ensure that you have the following prerequisites installed on your development environment:</p>
<h4>For Backend (FastAPI):</h4>
<ul>
  <li>
    <strong>Python 3.8+</strong>: ResQ backend requires Python 3.8 or higher.
    <ul>
      <li><a href="https://www.python.org/downloads/">Download Python</a></li>
    </ul>
  </li>
  <li>
    <strong>pip</strong>: Python package manager (usually comes with Python installation)
  </li>
  <li>
    <strong>Groq API Keys</strong>: Obtain API keys from <a href="https://console.groq.com">Groq Console</a>
    <ul>
      <li>Sign up for a free account</li>
      <li>Generate multiple API keys (recommended: 5 keys for better rate limit handling)</li>
    </ul>
  </li>
</ul>
<h4>For Frontend (Flutter):</h4>
<ul>
  <li>
    <strong>Flutter SDK (3.0+)</strong>: To build and run the ResQ mobile application
    <ul>
      <li><a href="https://flutter.dev/docs/get-started/install">Flutter Installation Guide</a></li>
    </ul>
  </li>
  <li>
    <strong>Android Studio or VS Code</strong>: IDE for Flutter development
    <ul>
      <li><a href="https://developer.android.com/studio">Android Studio</a></li>
      <li><a href="https://code.visualstudio.com/">VS Code</a> with Flutter extension</li>
    </ul>
  </li>
  <li>
    <strong>Android SDK</strong>: Required for building Android applications
    <ul>
      <li>Ensure Android SDK paths are added to PATH environment variables</li>
    </ul>
  </li>
</ul>
<p>After installing Flutter, run the following command to verify your setup:</p>
<pre><code>flutter doctor</code></pre>
  <h3 id = "installation"> Installation </h3>
<h4>Clone the Repository:</h4>
<pre><code>https://github.com/PrajwalP-BmsCS/ResQ.git
cd ResQ</code></pre>
  <h3 id = "backend_setup"> Backend Setup (FastAPI) </h3>
<ol>
  <li>
    <p><strong>Navigate to server directory</strong>:</p>
    <pre><code>cd server</code></pre>
  </li>
  <li>
    <p><strong>Create Virtual Environment</strong> (Recommended):</p>
    <pre><code># Windows
python -m venv venv</code></pre>
  </li>
  <li>
    <p><strong>Install Required Python Packages</strong>:</p>
    <p>
      Once inside the backend directory and after activating your virtual environment, install all necessary dependencies using:
    </p>
    <pre><code>pip install -r requirements.txt</code></pre>
  </li>

   <li>
    <p><strong>Activate Virtual Environment</strong></p>
    <pre><code># Windows
venv\Scripts\activate </code></pre>
  </li>

  <li>
    <p><strong>Run the FastAPI Application</strong>:</p>
    <p>
      Start the development server locally using Uvicorn with auto-reload enabled:
    </p>
    <pre><code>uvicorn app:app --reload --host 0.0.0.0 --port 8000</code></pre>
  </li>
 
  <li>
    <p><strong>Configure API Endpoints</strong>:</p>
    <p>Update <code>lib/utils/util.dart</code>:</p>
    <pre><code>// lib/utils/util.dart

  // For Android Emulator
  const String baseUrl1 = 'http://10.0.2.2:8000';
  
  // For iOS Simulator
  // const String baseUrl1 = 'http://localhost:8000';
  
  // For Physical Device (replace with your computer's IP)
  // const String baseUrl1 = 'http://172.154.1.110:8000';
</code></pre>
    
  <p><strong>Find your IP address</strong>:</p>
  <pre><code> Windows: ipconfig </code></pre>
  <pre><code> macOS/Linux: ipconfig or ip addr show </code></pre>

  </li>
</ol>


 <h3 id = "frontend_setup"> Building the App </h3>
<ol>
  <li>
    <strong>Navigate to App Directory</strong>: If you haven't already, navigate to the directory containing the Flutter app code. In this case, it appears to be in the "ResQ" directory.
  </li>
  <li>
   <p> <strong>Get Dependencies</strong>: Run the below command to fetch and install the necessary Flutter dependencies for the app. This step ensures that your app has access to required packages.</p>
    <pre><code>flutter pub get</code></pre>
  </li>
  <li>
    <strong>Connect Android Device or Emulator</strong>: Ensure your Android device is connected to your computer via USB, and USB debugging is enabled in developer mode. Alternatively, you can use an emulator to test the app.
  </li>
  <li>
    <p><strong>Launch the App</strong>: Run the below command after selecting the target device or emulator. This command will install and launch the app on the specified device.</p>
    <pre><code>flutter run</code></pre>
  </li>
</ol>
</section>


<section id = "tech_used">
  <h2> TechStack - Built with
    <img src="https://cdn.icon-icons.com/icons2/2530/PNG/512/flutter_button_icon_151957.png" alt="Flutter" height="20" style="vertical-align: middle; filter: none;"/>
   
  <img src="https://cdn.icon-icons.com/icons2/2530/PNG/512/dart_colour_button_icon_151934.png" alt="Dart" height="20" style="vertical-align: middle; filter: none;"/>
  <img src="https://github.com/user-attachments/assets/b4b3e453-bee1-402c-afd2-c02b137704a6" alt="Firebase" height="20" style="vertical-align: middle; filter: none;"/>
 

  </h2>
 
  Flutter: Flutter is Google's UI toolkit for building natively compiled apps for various platforms.

  Dart: Dart is a fast, modern programming language primarily used in Flutter development.
  
  FastAPI: A modern, high-performance Python web framework for building APIs quickly using async support and automatic documentation.

</section>
  
<section id = "architecture">
  <h2> System Architecture </h2>
  
<h3>🏗️ High-Level Architecture:</h3>

<pre>
┌───────────────────────────────────────────────────────────────────────┐
│                            RESQ LENS APP                              │
│   ┌──────────────┐  ┌───────────────┐  ┌──────────────────────────┐   │
│   │  Home Screen │→ │  Voice Input  │→ │  Intent Classification   │   │
│   └──────────────┘  └───────────────┘  └──────────────────────────┘   │
│                 ↓                 ↓                 ↓                 │
│       ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐   │
│       │ Scene Module   │  │  OCR Module     │  │ Navigation Module│   │
│       │ (YOLOv5-Nano)  │  │ (Google ML Kit) │  │ (Google Maps API)│   │
│       └────────────────┘  └─────────────────┘  └──────────────────┘   │
│                                   ↓                                   │
│                        ┌────────────────────────┐                     │
│                        │ Emergency SOS Module   │                     │
│                        │ • One-tap Call/Share   │                     │
│                        │ • Live Location        │                     │
│                        └────────────────────────┘                     │
│                                   ↓                                   │
│                         ┌───────────────────────┐                     │
│                         │   HTTP Client (DIO)   │                     │
│                         └───────────────────────┘                     │
└───────────────────────────────│───────────────────────────────────────┘
                                │
                       ═════════╪══════════
                        API CALLS │ JSON RESPONSE
                       ═════════╪══════════
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                           FASTAPI BACKEND                            │
│   ┌────────────────────────────────────────────────────────────────┐ │
│   │            Intent Processing & Routing Engine                  │ │
│   │  • Receives speech text                                        │ │
│   │  • Groq-based intent classifier (Scene / OCR / Navigate / SOS) │ │
│   │  • Sends response back to app                                  │ │
│   └────────────────────────────────────────────────────────────────┘ │
│                                │                                     │
│     ┌──────────────────────┐   │   ┌──────────────────────────────┐  │
│     │ /predict-intent      │───┘   │ /vision-processing           │  │
│     └──────────────────────┘       └──────────────────────────────┘  │
└───────────────────────────────│──────────────────────────────────────┘
                                │
                       ═════════╪══════════
                        API CALLS │ AI RESPONSES
                       ═════════╪══════════
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                           GROQ AI PLATFORM                           │
│    ┌──────────────────────────────┐  ┌────────────────────────────┐  │
│    │ Whisper-v3-turbo             │  │ Llama 3.1 / 3.3 Models     │  │
│    │ • Speech-to-Text             │  │ • Intent Classification    │  │
│    │ • Multi-language             │  │ • Dialogue Understanding   │  │
│    │ • High Accuracy              │  │ • Fast Inference           │  │
│    └──────────────────────────────┘  └────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
</pre>

<h3>📊 Data Flow Diagram:</h3>

<pre>
  USER GIVES VOICE COMMAND
        │
        ▼
┌────────────────────────────────────┐
│        Flutter App (RESQ Lens)     │
│  • Mic long-press listener         │
│  • Speech capture                  │
│  • Pre-processing                  │
└───────────────────┬────────────────┘
                    │  HTTP POST (JSON: transcript)
                    ▼
┌────────────────────────────────────┐
│            FastAPI Backend         │
│  • Receive text command            │
│  • Clean & normalize input         │
└───────────────────┬────────────────┘
                    │
                    ▼
┌────────────────────────────────────┐
│     Intent Classifier (Groq AI)    │
│  • Identify intent:                │
│    scene / object / OCR /          │
│    navigation / SOS                │
└───────────────────┬────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│         Route to Appropriate Module        │
│  • Scene → YOLOv5-Nano (image description) │
│  • Object Detection → YOLOv5-Nano          │
│  • OCR → Google ML Kit (text reading)      │
│  • Navigation → Google Maps API            │
│  • SOS → Call / Share location             │
└───────────────────┬────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────┐
│         Module Processing          │
│  • ESP32 Camera image capture      │
│  • Vision / OCR inference          │
│  • Walking route computation       │
│  • Emergency operations            │
└───────────────────┬────────────────┘
                    │
                    ▼
┌────────────────────────────────────┐
│           JSON Response            │
│  • Objects detected                │
│  • Scene summary                   │
│  • Extracted text                  │
│  • Navigation instructions         │
│  • SOS confirmation                │
└───────────────────┬────────────────┘
                    │  HTTP JSON Response
                    ▼
┌────────────────────────────────────┐
│      Flutter App (Front-End)       │
│  • Parse JSON                      │
│  • Convert to Text-to-Speech       │
│  • Show navigation steps           │
│  • Display detection results       │
│  • Trigger SOS actions             │
└────────────────────────────────────┘
                    │
                    ▼
            USER RECEIVES OUTPUT
</pre>

<h3>🔄 API Key Rotation Workflow:</h3>
<pre>
INITIAL STATE
┌─────────────────────┐
│ Keys: [K1, K2, K3]  │
│ Current: K1         │
│ Index: 0            │
└──────────┬──────────┘
           │
           ▼
    API REQUEST WITH K1
           │
           ├──── SUCCESS ────► Return Result
           │
           └──── RATE LIMIT ERROR
                      │
                      ▼
           ┌──────────────────┐
           │ Log Error        │
           │ Rotate to K2     │
           │ Index: 1         │
           └─────────┬────────┘
                     │
                     ▼
           RETRY WITH K2
                     │
                     ├──── SUCCESS ────► Return Result
                     │
                     └──── RATE LIMIT ERROR
                                │
                                ▼
                     ┌──────────────────┐
                     │ Rotate to K3     │
                     │ Index: 2         │
                     └─────────┬────────┘
                               │
                               ▼
                     RETRY WITH K3
                               │
                               └──── If all keys exhausted
                                            │
                                            ▼
                                   Return 429 Error
                                   "All keys rate limited"
</pre>

<h3>🗂️ Project Structure:</h3>

<pre>
ResQ/
│
├── ResQ/                # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── pages              # Features Screens
│   ├── pubspec.yaml           # Flutter dependencies
│   ├── android/               # Android-specific config
│   ├── ios/                   # iOS-specific config
│   └── README.md
│   ├── server/                 # FastAPI Backend
│       ├── server.py           # Main application file
│       ├── requirements.txt    # Python dependencies
│
├── README.md                  # Main project documentation
└── LICENSE
</pre>

<h3>🔐 ResQ Security Architecture</h3>

<ul>
  <li><strong>API Key Management</strong>:
    <ul>
      <li>Secure storage of API keys in .env (never committed to Git)</li>
      <li>Server-side key rotation for uninterrupted AI processing</li>
      <li>Keys never exposed to frontend or client devices</li>
    </ul>
  </li>
  
  <li><strong>Data Privacy</strong>:
    <ul>
      <li>Audio is processed completely in-memory</li>
      <li>No audio or generated content stored on the server</li>
      <li>Temporary files auto-deleted after processing</li>
      <li>Zero user tracking — ResQ does not collect or retain personal data</li>
    </ul>
  </li>
  
  <li><strong>API Security</strong>:
    <ul>
      <li>Strict CORS policies for trusted domains</li>
      <li>Request validation, sanitization, and safe error handling</li>
      <li>Protected backend routes to prevent unauthorized usage</li>
    </ul>
  </li>
</ul>

<h3>⚡ ResQ Performance Optimizations</h3>

<ul>
  <li><strong>Backend</strong>:
    <ul>
      <li>FastAPI backend with highly optimized async processing</li>
      <li>Groq LLM inference speeds up to 330 tokens/sec</li>
      <li>Memory-efficient pipeline for handling long audio files</li>
      <li>Automatic key rotation prevents API rate-limit slowdowns</li>
    </ul>
  </li>
  
  <li><strong>Frontend</strong>:
    <ul>
      <li>Lazy-loaded UI components for faster initial load</li>
      <li>Optimized PDF generation with cached fonts</li>
      <li>Compressed and optimized images</li>
      <li>Smooth and efficient state management for a responsive UI</li>
    </ul>
  </li>
</ul>
</section>

<section id="screenshots">
  <h2 id="screenshots">App Demonstration</h2>
  <button> <a href="https://drive.google.com/file/d/1n1-7fQX8kG-AyN3iRzpJ3jv9V25sCGOn/view?usp=sharing" target="_blank">Clear here to watch</button></a>  
  <h2> Screenshots </h2>   
  <img src="https://github.com/user-attachments/assets/d6bd2d65-d428-42fb-85ec-74c09cb683cf" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/8e57886b-b97d-4e0f-a5b2-5b706a504648" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/4cc12fba-0970-4075-8817-d9f5fc1175b7" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/12ef30fb-c8ef-4002-8895-a6eb8a92c82f" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/a5a7a83d-a530-4dac-9f4e-15809d40e187" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/69b02efd-b210-4333-83a1-d4d3573adf2c" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/c779e588-933b-418c-b02c-43b988e50107" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/92a35f92-bd16-4df0-871a-c51502b645d7" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/140f5198-8a1d-4201-9961-c4885a6aa90d" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/8b9f325c-ff8b-4510-ae0b-c485cac584eb" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/af308e05-06b2-4ca0-8291-d7338f82a54f" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/cfe636ad-b298-44c7-bf60-4c681b1a532b" style="width: 200px;" />
  <img src="https://github.com/user-attachments/assets/f9c92b41-cf4b-4343-a97b-80551fbb6997" style="width: 200px;" />
</section>


<section id="conclusion">
  <h2>Conclusion</h2>
  <p>
   ResQ Lens represents a practical, human-centered assistive technology designed to empower visually impaired individuals with enhanced perception, awareness, and independence. By integrating ESP32-CAM based edge processing with an intelligent mobile application, the system provides essential features such as scene description, object recognition, text reading, and situational navigation without heavy dependence on cloud services. Its modular design, low-cost hardware, and real-time audio feedback make it both accessible and scalable for everyday use. Ultimately, ResQ Lens demonstrates how affordable innovation, thoughtful engineering, and user-centric design can work together to significantly improve the quality of life for people with vision impairments.
  </p>
</section>



<section id = "team">
  <h2> The Team </h2>
  <h3> Pannaga R Bhat </h3>
<p align="left">
  <a href="https://github.com/pannaga-rj" style="text-decoration: none;" target="_blank" rel="nofollow">
    <img src="https://img.shields.io/badge/GitHub-black?style=flat&logo=github" alt="GitHub" style="max-width: 100%;">
  </a>
  <a href="https://www.linkedin.com/in/pannaga-r-bhat-ba8bb6289/" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/LinkedIn-blue?style=flat&logo=linkedin" alt="LinkedIn" />
  </a>
</p>

<h3> Pradeep P T </h3>
<p align="left">
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/GitHub-black?style=flat&logo=github" alt="GitHub" />
  </a>
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/LinkedIn-blue?style=flat&logo=linkedin" alt="LinkedIn" />
  </a>
</p>

<h3> Prajwal P </h3>
<p align="left">
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/GitHub-black?style=flat&logo=github" alt="GitHub" />
  </a>
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/LinkedIn-blue?style=flat&logo=linkedin" alt="LinkedIn" />
  </a>
</p>

<h3> Pranav Anantha Rao </h3>
<p align="left">
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/GitHub-black?style=flat&logo=github" alt="GitHub" />
  </a>
  <a href="" style="text-decoration: none;" target="_blank">
    <img src="https://img.shields.io/badge/LinkedIn-blue?style=flat&logo=linkedin" alt="LinkedIn" />
  </a>
</p>
</section>
