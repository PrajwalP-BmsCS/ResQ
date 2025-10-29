import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TranslationService {
  // Option 1: Google Translate API (Free - via MyMemory)
  static Future<String?> translateWithMyMemory(String Text, String pair) async {
    try {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(Text)}&langpair=$pair'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['responseData']['translatedText'];
        
        debugPrint('✅ MyMemory Translation: $Text → $translatedText');
        return translatedText;
      } else {
        debugPrint('❌ MyMemory API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MyMemory Translation Error: $e');
      return null;
    }
  }

  // Option 2: LibreTranslate API (Free, Open Source)
  static Future<String?> translateWithLibreTranslate(String kannadaText) async {
    try {
      final url = Uri.parse('https://libretranslate.com/translate');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': kannadaText,
          'source': 'kn',
          'target': 'en',
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translatedText'];
        
        debugPrint('✅ LibreTranslate: $kannadaText → $translatedText');
        return translatedText;
      } else {
        debugPrint('❌ LibreTranslate API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ LibreTranslate Error: $e');
      return null;
    }
  }

  // Option 3: Google Cloud Translate (Requires API Key - Most Accurate)
  static Future<String?> translateWithGoogleCloud(
    String kannadaText,
    String apiKey,
  ) async {
    try {
      final url = Uri.parse(
        'https://translation.googleapis.com/language/translate/v2?key=$apiKey'
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': kannadaText,
          'source': 'kn',
          'target': 'en',
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = 
            data['data']['translations'][0]['translatedText'];
        
        debugPrint('✅ Google Cloud: $kannadaText → $translatedText');
        return translatedText;
      } else {
        debugPrint('❌ Google Cloud API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Google Cloud Translation Error: $e');
      return null;
    }
  }

  // Option 4: Microsoft Azure Translator (Requires API Key)
  static Future<String?> translateWithAzure(
    String kannadaText,
    String apiKey,
    String region,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=kn&to=en'
      );

      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
          'Ocp-Apim-Subscription-Region': region,
          'Content-Type': 'application/json',
        },
        body: jsonEncode([
          {'text': kannadaText}
        ]),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data[0]['translations'][0]['text'];
        
        debugPrint('✅ Azure: $kannadaText → $translatedText');
        return translatedText;
      } else {
        debugPrint('❌ Azure API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Azure Translation Error: $e');
      return null;
    }
  }

  // Smart Translation with Fallback
  static Future<String?> translateKannadaToEnglish(String kannadaText) async {
    // Try MyMemory first (free, no API key needed)
    String? translated = await translateWithMyMemory(kannadaText, "kn|en");
    if (translated != null && translated.isNotEmpty) {
      return translated;
    }

    // Fallback to LibreTranslate
    translated = await translateWithLibreTranslate(kannadaText);
    if (translated != null && translated.isNotEmpty) {
      return translated;
    }

    debugPrint('❌ All translation services failed');
    return null;
  }

  // Batch translation for multiple texts
  static Future<List<String>> translateBatch(List<String> texts) async {
    List<String> translations = [];
    
    for (String text in texts) {
      final translated = await translateKannadaToEnglish(text);
      translations.add(translated ?? text); // Keep original if translation fails
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return translations;
  }
}

// // Integration with your existing intent detection
// class KannadaIntentProcessor {
//   /// Process Kannada speech and get intent
//   static Future<Map<String, dynamic>?> processKannadaSpeech(
//     String kannadaText,
//   ) async {
//     try {
//       debugPrint('🎤 Kannada Input: $kannadaText');

//       // Step 1: Translate Kannada to English
//       final englishText = await TranslationService.translateKannadaToEnglish(
//         kannadaText,
//       );

//       if (englishText == null || englishText.isEmpty) {
//         debugPrint('❌ Translation failed');
//         return null;
//       }

//       debugPrint('🌐 Translated to English: $englishText');

//       // Step 2: Get intent from your existing API
//       // final intent = await getUserIntent(englishText);

//       debugPrint('🎯 Intent Result: $intent');

//       return intent;
//     } catch (e) {
//       debugPrint('❌ Error processing Kannada speech: $e');
//       return null;
//     }
//   }

//   /// Your existing intent API call
//   static Future<Map<String, dynamic>> getUserIntent(String englishText) async {
//     final url = Uri.parse("YOUR_BASE_URL/get_user_intent");
    
//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'audioText': englishText}),
//     );

//     if (response.statusCode == 200) {
//       return jsonDecode(response.body);
//     } else {
//       throw Exception('Failed to get user intent');
//     }
//   }
// }
