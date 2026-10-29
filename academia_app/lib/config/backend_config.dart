import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  static const String _prefKeyCustomServer = 'custom_backend_server_url';
  static const String _prefKeyCachedServer = 'cached_working_backend_url';
  
  /// Working base URL cached in-memory after first successful request
  static String? _cachedWorkingBaseUrl;

  /// Candidate backend URLs to attempt in order of priority:
  /// 1. Loopback for desktop or physical Android phone with adb reverse
  /// 2. Android emulator loopback to host PC
  /// 3. PC Local Wi-Fi IP address (physical device on same Wi-Fi)
  static const List<String> candidateBaseUrls = [
    'http://127.0.0.1:8001',
    'http://192.168.1.2:8001',
    'http://192.168.1.13:8001',
    'http://10.0.2.2:8001',
  ];

  /// Get custom server URL saved in preferences (if any)
  static Future<String?> getCustomServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyCustomServer);
    } catch (_) {
      return null;
    }
  }

  /// Set custom server URL (e.g., when deployed to cloud or specific IP)
  static Future<void> setCustomServerUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        await prefs.remove(_prefKeyCustomServer);
      } else {
        await prefs.setString(_prefKeyCustomServer, url.trim().replaceAll(RegExp(r'/+$'), ''));
      }
      _cachedWorkingBaseUrl = null;
    } catch (_) {}
  }

  /// Sends a POST request trying candidate URLs in sequence until one succeeds.
  static Future<http.Response> postWithFallback(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration perAttemptTimeout = const Duration(seconds: 15),
  }) async {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final requestHeaders = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
    final encodedBody = jsonEncode(body);

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (_cachedWorkingBaseUrl == null) {
        _cachedWorkingBaseUrl = prefs.getString(_prefKeyCachedServer);
      }
      if (_cachedWorkingBaseUrl != null && _cachedWorkingBaseUrl!.contains(':8000')) {
        _cachedWorkingBaseUrl = _cachedWorkingBaseUrl!.replaceAll(':8000', ':8001');
      }
    } catch (_) {}

    final customUrl = await getCustomServerUrl();
    final List<String> candidates = [];

    if (_cachedWorkingBaseUrl != null) {
      candidates.add(_cachedWorkingBaseUrl!);
    }
    if (customUrl != null && customUrl.isNotEmpty && !candidates.contains(customUrl)) {
      candidates.add(customUrl);
    }
    for (final base in candidateBaseUrls) {
      if (!candidates.contains(base)) {
        candidates.add(base);
      }
    }

    Exception? lastException;

    for (final base in candidates) {
      final fullUrl = '$base$cleanEndpoint';
      // Use faster timeout for loopbacks on physical device so fallback to LAN happens in ~1.5s
      final isLoopback = base.contains('127.0.0.1') || base.contains('10.0.2.2');
      final attemptTimeout = isLoopback ? const Duration(milliseconds: 1500) : perAttemptTimeout;

      try {
        final response = await http.post(
          Uri.parse(fullUrl),
          headers: requestHeaders,
          body: encodedBody,
        ).timeout(attemptTimeout);

        // If we get an HTTP response (even 401 for bad credentials), the server is reachable
        _cachedWorkingBaseUrl = base;
        try {
          await prefs?.setString(_prefKeyCachedServer, base);
        } catch (_) {}
        return response;
      } catch (e) {
        lastException = Exception('Failed connecting to $fullUrl: $e');
        if (kDebugMode) {
          debugPrint('[BACKEND CONFIG] $fullUrl unreachable ($e), trying next candidate...');
        }
      }
    }

    throw lastException ?? Exception('Unable to reach backend server on any candidate URL.');
  }
}
