import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/day_order_backup.dart';

String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String source) => jsonDecode(source);

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
        final Map<String, dynamic> fullData = await compute(
          _decodeJson,
          userDataString,
        );
        // Extract session_data from the existing blob
        sessionData = fullData['session_data'];
      }

      if (email == null || password == null) {
        if (kDebugMode)
          debugPrint("❌ Background refresh failed: no credentials");
        return false;
      }

      final url = Uri.parse(
        'https://academia-scrapper-api-fast.onrender.com/scrape',
      );

      // 2. Build the request body
      final Map<String, dynamic> requestBody = {
        "email": email,
        "password": password,
        if (sessionData != null)
          "session_data": sessionData, // Inline null check
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
        if (kDebugMode)
          debugPrint("❌ Background API failed: ${response.statusCode}");
        return false;
      }

      final data = await compute(_decodeJson, response.body);

      // 3. Handle Day Order (data -> attendance -> day_order)
      if (data['attendance']?['day_order'] != null) {
        await DayOrderManager.saveDayOrderData(
          currentDayOrder: data['attendance']['day_order'] as int,
          currentDate: DateTime.now(),
        );
      }

      // 4. Save the entire new response (which includes updated session_data)
      final encodedData = await compute(
        _encodeJson,
        data as Map<String, dynamic>,
      );
      await prefs.setString('userData', encodedData);
      await prefs.setString(
        'lastRefreshTime',
        DateTime.now().toIso8601String(),
      );

      if (kDebugMode)
        debugPrint("✅ Background refresh success using nested session data");
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Background refresh error: $e");
      return false;
    }
  }
}
