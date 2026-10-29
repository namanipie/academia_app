import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/day_order_backup.dart';
import '../services/student_portal_service.dart';
import '../config/backend_config.dart';

String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String source) => jsonDecode(source);

class DataRefreshService {
  static Future<bool> refreshData() async {
    try {
      debugPrint('[SRM REFRESH] Starting background refresh...');
      final prefs = await SharedPreferences.getInstance();
      var email = prefs.getString('userEmail');
      var password = prefs.getString('userPassword');
      final studentPortalPassword = prefs.getString('studentPortalPassword');
      final studentPortalNetId = prefs.getString('studentPortalNetId');

      if ((email == null || email.isEmpty) && studentPortalNetId != null) {
        email = '$studentPortalNetId@srmist.edu.in';
      }
      if (email == null || email.isEmpty) {
        final raw = prefs.getString('userData');
        if (raw != null) {
          try {
            final parsed = json.decode(raw);
            final netid = parsed['netid'] ?? parsed['student_info']?['reg_no'] ?? parsed['attendance']?['student_info']?['reg_no'];
            if (netid != null && netid.toString().isNotEmpty) {
              email = '${netid.toString().trim()}@srmist.edu.in';
            }
          } catch (_) {}
        }
      }
      if ((password == null || password.isEmpty || password == 'guest') && studentPortalPassword != null) {
        password = studentPortalPassword;
      }

      if (email == null || password == null || email == 'guest@srmist.edu.in' || password == 'guest') {
        if (kDebugMode) {
          debugPrint("ℹ Background refresh skipped: guest mode or no credentials");
        }
        return false;
      }

      // 1. Read existing userData string
      final userDataString = prefs.getString('userData');
      Map<String, dynamic>? sessionData;
      Map<String, dynamic>? fullData;

      if (userDataString != null && userDataString.isNotEmpty) {
        fullData = await compute(
          _decodeJson,
          userDataString,
        );
        // Extract session_data from the existing blob
        sessionData = fullData?['session_data'];
      }

      // 2. Build the request body
      final Map<String, dynamic> requestBody = {
        "email": email,
        "password": password,
        if (studentPortalPassword != null && studentPortalPassword.isNotEmpty)
          "student_portal_password": studentPortalPassword,
        if (sessionData != null)
          "session_data": sessionData, // Inline null check
      };

      final response = await BackendConfig.postWithFallback(
        '/scrape',
        body: requestBody,
        perAttemptTimeout: const Duration(seconds: 20),
      );

      debugPrint('[SRM REFRESH] HTTP Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint("❌ Background API failed (${response.statusCode}), falling back to Gateway sync...");
        }
        final spPass = studentPortalPassword ?? password;
        final gwRes = await StudentPortalService.syncViaGateway(username: email, password: spPass);
        if (gwRes.success) {
          await prefs.setString('lastRefreshTime', DateTime.now().toIso8601String());
          return true;
        }
        return false;
      }

      final data = await compute(_decodeJson, response.body);
      if (data['status'] != 'success') {
        if (kDebugMode) {
          debugPrint("❌ Background API returned non-success status: ${data['status']}");
        }
        return false;
      }

      // Safeguard: Never overwrite valid cached academic data with empty or malformed responses
      if (fullData != null) {
        final existingAttendanceCourses = fullData['attendance']?['attendance']?['courses'];
        final bool hadValidAttendance = existingAttendanceCourses is Map && existingAttendanceCourses.isNotEmpty;
        final newAttendanceCourses = data['attendance']?['attendance']?['courses'];
        final bool hasNewAttendance = newAttendanceCourses is Map && newAttendanceCourses.isNotEmpty;

        if (hadValidAttendance && !hasNewAttendance) {
          if (kDebugMode) {
            debugPrint("⚠ Preserving cached attendance because refreshed payload has empty courses");
          }
          if (fullData['attendance'] != null) {
            data['attendance'] = fullData['attendance'];
          }
        }

        final existingTimetableCourses = fullData['timetable']?['courses'];
        final bool hadValidTimetable = existingTimetableCourses is List && existingTimetableCourses.isNotEmpty;
        final newTimetableCourses = data['timetable']?['courses'];
        final bool hasNewTimetable = newTimetableCourses is List && newTimetableCourses.isNotEmpty;

        bool newHasRealSlots = false;
        if (hasNewTimetable) {
          newHasRealSlots = newTimetableCourses.any((c) => c is Map && (c['slot']?.toString().trim().isNotEmpty ?? false));
        }

        if (hadValidTimetable && (!hasNewTimetable || !newHasRealSlots)) {
          if (kDebugMode) {
            debugPrint("⚠ Preserving cached timetable because refreshed payload has no slots");
          }
          if (fullData['timetable'] != null) {
            data['timetable'] = fullData['timetable'];
          }
        }
      }

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
        data,
      );
      await prefs.setString('userData', encodedData);
      await prefs.setString(
        'lastRefreshTime',
        DateTime.now().toIso8601String(),
      );

      if (kDebugMode) {
        debugPrint("✅ Background refresh success using nested session data");
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Background refresh error: $e");
      return false;
    }
  }
}
