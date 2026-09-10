import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_page.dart';

Future<void> logoutAction(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Prepare data for API logout
  final email = prefs.getString('userEmail');
  final password = prefs.getString('userPassword');
  final userDataString = prefs.getString('userData');
  
  Map<String, dynamic>? sessionData;
  if (userDataString != null) {
    try {
      final Map<String, dynamic> fullData = jsonDecode(userDataString);
      sessionData = fullData['session_data'];
    } catch (e) {
      if (kDebugMode) debugPrint("Error parsing session data for logout: $e");
    }
  }

  // 2. Call API logout (Fire and forget or minimal wait)
  if (email != null && password != null) {
    try {
      final url = Uri.parse('https://academia-scrapper-api-fast.onrender.com/logout');
      
      // We don't necessarily need to 'await' this if we want a snappy UI response,
      // but it's cleaner to let the server know we're done.
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
          if (sessionData != null) "session_data": sessionData,
        }),
      ).timeout(const Duration(seconds: 3)); // Don't let a slow API hang the logout UI
      
      if (kDebugMode) debugPrint("✅ API Logout successful");
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ API Logout failed (likely already expired): $e");
    }
  }

  // 3. Wipe all local storage
  final keysToRemove = [
    'userData',
    'customEvents',
    'GRAPH_ATTENDANCE',
    'userEmail',
    'userPassword',
    'lastRefreshTime',
    'student_portal_result',
    'nearby_history',
  ];

  for (String key in keysToRemove) {
    await prefs.remove(key);
  }

  if (!context.mounted) return;

  // 4. Navigate to Login
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const CLoginPage()),
    (route) => false,
  );
}