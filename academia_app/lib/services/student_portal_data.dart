import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'student_portal_service.dart';
import '../config/backend_config.dart';

class student_portal_Service {
  /// Fetch student portal result using netId + password.
  /// Seamlessly calls our native first-party scraper API.
  static Future<Map<String, dynamic>> fetchStudentPortalResult(
      String netId, String password) async {
    try {
      final cleanNetId = netId.trim().replaceAll(RegExp(r'@srmist\.edu\.in$', caseSensitive: false), '').trim();

      try {
        final response = await BackendConfig.postWithFallback(
          '/studentportal_result',
          body: {
            "netid": cleanNetId,
            "password": password.trim(),
          },
          perAttemptTimeout: const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("student_portal_result", jsonEncode(data));
          return {
            "success": true,
            "data": data,
            "error": null,
          };
        }
      } catch (e) {
        if (kDebugMode) debugPrint("[PORTAL DATA] Error: $e, trying syncViaGateway...");
      }

      // Fallback via StudentPortalService sync
      final syncResult = await StudentPortalService.syncViaGateway(
        username: cleanNetId,
        password: password,
      );

      if (syncResult.success) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString("student_portal_result") ?? prefs.getString("userData");
        final data = raw != null ? jsonDecode(raw) : {"status": "success"};
        return {
          "success": true,
          "data": data,
          "error": null,
        };
      }

      return {
        "success": false,
        "data": null,
        "error": syncResult.errorMessage ?? "Failed to connect to Student Portal",
      };
    } catch (e) {
      return {
        "success": false,
        "data": null,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>?> getCachedStudentPortalResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString("student_portal_result");
      if (dataString != null) {
        return jsonDecode(dataString);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCachedResult() => getCachedStudentPortalResult();

  static Future<void> clearCachedStudentPortalResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("student_portal_result");
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error clearing student portal result: $e");
      }
    }
  }

  static Future<void> clearResult() => clearCachedStudentPortalResult();
}
