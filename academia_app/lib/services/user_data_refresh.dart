import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/day_order_backup.dart';
import 'srm_native_client.dart';

String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);

class DataRefreshService {
  static Future<bool> refreshData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail');
      final password = prefs.getString('userPassword');
      
      if (email == null || password == null) {
        if (kDebugMode) debugPrint("Background refresh failed: no credentials");
        return false;
      }

      final client = SrmNativeClient();
      final loggedIn = await client.login(email, password);
      
      if (!loggedIn) {
        if (kDebugMode) debugPrint("Background refresh failed: native login failed.");
        return false;
      }
      
      final data = await client.fetchAllData();
      
      if (data.isEmpty) {
        if (kDebugMode) debugPrint("Background refresh returned empty data. Keeping cache.");
        return false;
      }
      
      bool hasValidData = false;
      if (data['attendance'] != null && data['attendance'] is Map && data['attendance'].isNotEmpty) {
        if (data['attendance']['attendance'] != null && data['attendance']['attendance'] is Map && data['attendance']['attendance'].isNotEmpty) {
           hasValidData = true;
        }
      }

      if (hasValidData) {
        // Save Day Order
        if (data['attendance']?['day_order'] != null) {
          await DayOrderManager.saveDayOrderData(
            currentDayOrder: data['attendance']['day_order'] as int,
            currentDate: DateTime.now(),
          );
        }

        // Keep session_data empty or structure from previous schema if necessary,
        // though we no longer rely on backend session_data.
        
        final encodedData = await compute(_encodeJson, data);
        await prefs.setString('userData', encodedData);
        await prefs.setString('lastRefreshTime', DateTime.now().toIso8601String());
        
        // Save marks natively so the student portal screen can access them
        if (data['marks'] != null) {
          final encodedMarks = await compute(_encodeJson, data['marks'] as Map<String, dynamic>);
          await prefs.setString('student_portal_result', encodedMarks);
        }
        
        if (kDebugMode) debugPrint("Background refresh successful.");
        return true;
      } else {
        if (kDebugMode) debugPrint("Background refresh returned empty data (no attendance). Keeping cache.");
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Background refresh error: $e");
      return false;
    }
  }
}
