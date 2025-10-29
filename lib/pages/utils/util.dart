import 'package:flutter/material.dart';

// Base URL
const String baseUrl = "http://192.168.0.104:8000";

// esp32 base URL
const String espBaseUrl = "http://10.46.130.101";



void showStatusSnackBar(BuildContext context, String message, String status) {
  // Set icon and color based on status
  IconData iconData;
  Color backgroundColor;

  switch (status.toLowerCase()) {
    case 'success':
      iconData = Icons.check_circle_outline;
      backgroundColor = Colors.green;
      break;
    case 'fail':
      iconData = Icons.error_outline;
      backgroundColor = Colors.red;
      break;
    default:
      iconData = Icons.warning_amber_outlined;
      backgroundColor = Colors.orangeAccent;
      break;
    
   
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(iconData, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
    ),
  );
}