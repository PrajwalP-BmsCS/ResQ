import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:req_demo/pages/Flutter_TTS/tts.dart';
import 'package:req_demo/pages/Settings/app_settings.dart';
import 'package:req_demo/pages/Settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactManager {
  List<EmergencyContact> contacts = [];

  /// Load contacts from local storage
  Future<void> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('emergency_contacts') ?? [];
      contacts =
          raw.map((e) => EmergencyContact.fromJson(jsonDecode(e))).toList();
      debugPrint("Contacts loaded: ${contacts.length} contact(s)");
      for (var c in contacts) {
        debugPrint("  - ${c.name}: Lat=${c.latitude}, Lon=${c.longitude}");
      }
    } catch (e) {
      debugPrint("Error loading contacts: $e");
    }
  }

  /// Reorder contacts
  void reorderContacts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final c = contacts.removeAt(oldIndex);
    contacts.insert(newIndex, c);
    debugPrint("Contacts reordered");
  }

  /// Save contacts to local storage
  Future<void> saveContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = contacts.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList('emergency_contacts', data);
      debugPrint("Contacts saved: ${contacts.length} contact(s)");
    } catch (e) {
      debugPrint("Error saving contacts: $e");
    }
  }

  /// Set location for a contact
  Future<void> setContactLocation(int index, LatLng pos) async {
    try {
      if (index < 0 || index >= contacts.length) {
        debugPrint("Invalid contact index: $index");
        return;
      }

      contacts[index].latitude = pos.latitude.toString();
      contacts[index].longitude = pos.longitude.toString();
      contacts[index].location = true;

      await saveContacts();
      debugPrint(
          "Updated location for ${contacts[index].name}: ${pos.latitude}, ${pos.longitude}");
    } catch (e) {
      debugPrint("Error setting contact location: $e");
    }
  }

  /// Navigate using Google Maps
  Future<void> navigateToLocation(EmergencyContact c) async {
    print("COMING");
    try {
      if (c.latitude == null || c.longitude == null) {
        TTSManager().speak(await checkLanguageCondition()
            ? "Location not set for this contact"
            : "ಈ ಸಂಪರ್ಕಕ್ಕೆ ಸ್ಥಳವನ್ನು ಹೊಂದಿಸಲಾಗಿಲ್ಲ.");
        debugPrint("No location set for ${c.name}");
        return;
      }

      debugPrint("Navigating to ${c.name}");
      debugPrint("Latitude: ${c.latitude}, Longitude: ${c.longitude}");

      final double lat = double.parse(c.latitude!);
      final double long = double.parse(c.longitude!);

      // Walking navigation
      final Uri uri = Uri.parse(
        'google.navigation:q=$lat,$long&mode=w', // 'w' = walking
      );

      if (await canLaunchUrl(uri)) {
        await TTSManager().speak(await checkLanguageCondition()
            ? "Navigation started to the selected location."
            : "ಆಯ್ಕೆ ಮಾಡಿದ ಸ್ಥಳಕ್ಕೆ ನ್ಯಾವಿಗೇಷನ್ ಪ್ರಾರಂಭವಾಗಿದೆ.");

        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint("Could not launch Google Maps");
        TTSManager().speak(await checkLanguageCondition()
            ? "Could not open navigation. \nPlease try again."
            : "ನ್ಯಾವಿಗೇಷನ್ ತೆರೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.");
      }
    } catch (e) {
      debugPrint("Error navigating to location: $e");
      TTSManager().speak(await checkLanguageCondition()
          ? "An error occurred while starting navigation."
          : "ನ್ಯಾವಿಗೇಷನ್ ಪ್ರಾರಂಭಿಸುವಾಗ ದೋಷ ಸಂಭವಿಸಿದೆ.");
    }
  }

  /// Share location with a specific contact via SMS/WhatsApp
  Future<void> shareLocationWithContact(int contactIndex) async {
    try {
      if (contactIndex < 0 || contactIndex >= contacts.length) {
        TTSManager().speak(await checkLanguageCondition()
            ? "Invalid contact option"
            : "ಅಮಾನ್ಯ ಸಂಪರ್ಕ ಆಯ್ಕೆ.");
        return;
      }

      final contact = contacts[contactIndex];
      final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (phoneNumber.isEmpty) {
        TTSManager().speak(await checkLanguageCondition()
            ? "Phone number not available for ${contact.name}"
            : "ಈ ಸಂಪರ್ಕಕ್ಕೆ ಫೋನ್ ಸಂಖ್ಯೆ ಲಭ್ಯವಿಲ್ಲ.");
        return;
      }

      // Get current location
      Location location = Location();
      LocationData currentLocation = await location.getLocation();
      final currentLat = currentLocation.latitude;
      final currentLon = currentLocation.longitude;

      if (currentLat == null || currentLon == null) {
        TTSManager().speak(await checkLanguageCondition()
            ? "Unable to fetch your current location"
            : "ನಿಮ್ಮ ಪ್ರಸ್ತುತ ಸ್ಥಳವನ್ನು ಪಡೆಯಲು ಸಾಧ್ಯವಾಗುತ್ತಿಲ್ಲ");
        return;
      }

      // Create share message
      final String shareMessage =
          "My current location: https://maps.google.com/maps?q=$currentLat,$currentLon";

      // Try WhatsApp first
      final Uri whatsappUri = Uri.parse(
          "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareMessage)}");

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
        debugPrint("Location shared with ${contact.name} via WhatsApp");
        TTSManager().speak(await checkLanguageCondition()
            ? "Sharing your location with ${contact.name} now"
            : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${contact.name} ರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ.");
      } else {
        // Fallback to SMS
        final Uri smsUri = Uri.parse(
            "sms:$phoneNumber?body=${Uri.encodeComponent(shareMessage)}");
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          debugPrint("Location shared with ${contact.name} via SMS");
          TTSManager().speak(await checkLanguageCondition()
              ? "Sharing your location with ${contact.name} now"
              : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ${contact.name} ರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ.");
        } else {
          TTSManager().speak(await checkLanguageCondition()
              ? "Could not share location. No messaging app available"
              : "ಸ್ಥಳ ಹಂಚಿಕೊಳ್ಳಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ಯಾವುದೇ ಸಂದೇಶ ಕಳುಹಿಸುವ ಅಪ್ಲಿಕೇಶನ್ ಲಭ್ಯವಿಲ್ಲ");
        }
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
      TTSManager().speak(await checkLanguageCondition()
          ? "An error occurred while sharing your location"
          : "ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ಹಂಚಿಕೊಳ್ಳುವಾಗ ದೋಷ ಸಂಭವಿಸಿದೆ");
    }
  }

  /// Share location with all contacts
  Future<void> shareLocationWithAll() async {
    try {
      if (contacts.isEmpty) {
        TTSManager().speak("You have no contacts to share with");
        return;
      }

      // Get current location
      Location location = Location();
      LocationData currentLocation = await location.getLocation();
      final currentLat = currentLocation.latitude;
      final currentLon = currentLocation.longitude;

      if (currentLat == null || currentLon == null) {
        TTSManager().speak("Unable to fetch your current location");
        return;
      }

      final String shareMessage =
          "My current location: https://maps.google.com/maps?q=$currentLat,$currentLon";

      int successCount = 0;

      for (var contact in contacts) {
        try {
          final phoneNumber = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');

          if (phoneNumber.isNotEmpty) {
            final Uri whatsappUri = Uri.parse(
                "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareMessage)}");

            if (await canLaunchUrl(whatsappUri)) {
              await launchUrl(whatsappUri);
              successCount++;
              debugPrint("Location shared with ${contact.name}");
            }
          }
        } catch (e) {
          debugPrint("Error sharing with ${contact.name}: $e");
        }

        // Small delay between shares
        await Future.delayed(const Duration(milliseconds: 500));
      }

      TTSManager().speak("Location shared with $successCount contact(s)");
      debugPrint("Location shared with $successCount contacts");
    } catch (e) {
      debugPrint("Error sharing location with all: $e");
      TTSManager().speak("An error occurred while sharing your location");
    }
  }

  /// Get list of contacts as comma-separated string (for TTS)
  String getContactsAsString() {
    if (contacts.isEmpty) return "No contacts available";

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < contacts.length; i++) {
      sb.write("Option ${i + 1}: ${contacts[i].name}");
      if (i < contacts.length - 1) sb.write(", ");
    }
    return sb.toString();
  }

  /// Get contact by index
  EmergencyContact? getContactByIndex(int index) {
    if (index < 0 || index >= contacts.length) return null;
    return contacts[index];
  }

  /// Clear all contacts
  Future<void> clearAllContacts() async {
    try {
      contacts.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emergency_contacts');
      debugPrint("All contacts cleared");
    } catch (e) {
      debugPrint("Error clearing contacts: $e");
    }
  }
}
