import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/day_order_backup.dart';


class DataRefreshService {
  static Future<bool> refreshData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail');
      final password = prefs.getString('userPassword');
      
      // 1. Read existing userData string
      final userDataString = prefs.getString('userData');
      Map<String, dynamic>? sessionData;

      if (userDataString != null) {
        final Map<String, dynamic> fullData = jsonDecode(userDataString);
        // Extract session_data from the existing blob
        sessionData = fullData['session_data'];
      }

      if (email == null || password == null) {
        if (kDebugMode) debugPrint("❌ Background refresh failed: no credentials");
        return false;
      }

      final url = Uri.parse('https://academia-scrapper-api-fast.onrender.com/scrape');
      
      // 2. Build the request body
      final Map<String, dynamic> requestBody = {
        "email": email,
        "password": password,
        if (sessionData != null) "session_data": sessionData, // Inline null check
      };

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint("❌ Background API failed: ${response.statusCode}");
        return false;
      }

      final data = jsonDecode(response.body);

      // 3. Handle Day Order (data -> attendance -> day_order)
      if (data['attendance']?['day_order'] != null) {
        await DayOrderManager.saveDayOrderData(
          currentDayOrder: data['attendance']['day_order'] as int,
          currentDate: DateTime.now(),
        );
      }

      // 4. Validate data before overwriting cache
      // The API might return 200 OK but with empty data due to SSO Captcha.
      // We don't want to wipe the user's cached attendance and marks.
      bool hasValidData = false;
      if (data['attendance'] != null && data['attendance'] is Map && data['attendance'].isNotEmpty) {
        if (data['attendance']['attendance'] != null && data['attendance']['attendance'] is Map && data['attendance']['attendance'].isNotEmpty) {
           hasValidData = true;
        }
      }

      if (hasValidData) {
        await prefs.setString('userData', jsonEncode(data));
        await prefs.setString('lastRefreshTime', DateTime.now().toIso8601String());
        if (kDebugMode) debugPrint("✅ Background refresh success using nested session data");
        return true;
      } else {
        if (kDebugMode) debugPrint("⚠️ Background refresh returned empty data (likely Captcha block). Retaining old cache.");
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Background refresh error: $e");
      return false;
    }
  }
}