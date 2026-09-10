import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MessMenuMap = Map<String, dynamic>;

class MessMenuCache {
  static const String dataKey = "mess_menu_data";
  static const String timeKey = "mess_menu_last_refresh";
  static const Duration cacheDuration = Duration(days: 10);

  // optional in-memory cache (fast access)
  static MessMenuMap? memoryData;
  static DateTime? memoryTime;
}

class MessMenuService {
  static Future<MessMenuMap?> getMessMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 🔹 1. Check MEMORY cache first (fastest)
    if (MessMenuCache.memoryData != null &&
        MessMenuCache.memoryTime != null &&
        now.difference(MessMenuCache.memoryTime!) <
            MessMenuCache.cacheDuration) {
      if (kDebugMode) debugPrint("⚡ Using memory cache");
      return MessMenuCache.memoryData;
    }

    // 🔹 2. Check PERSISTENT cache (SharedPreferences)
    final cachedJson = prefs.getString(MessMenuCache.dataKey);
    final cachedTime = prefs.getInt(MessMenuCache.timeKey);

    if (cachedJson != null && cachedTime != null) {
      final savedTime =
          DateTime.fromMillisecondsSinceEpoch(cachedTime);

      if (now.difference(savedTime) <
          MessMenuCache.cacheDuration) {
        if (kDebugMode) debugPrint("📦 Using persistent cache");

        final decoded =
            Map<String, dynamic>.from(jsonDecode(cachedJson));

        // update memory cache
        MessMenuCache.memoryData = decoded;
        MessMenuCache.memoryTime = savedTime;

        return decoded;
      }
    }

    // 🔴 3. Fetch from Firestore ONLY if cache expired
    if (kDebugMode) debugPrint("☁ Fetching from Firestore...");
    final db = FirebaseFirestore.instance;

    try {
      final docSnapshot = await db
          .collection('mess')
          .doc('messmenu')
          .get(const GetOptions(source: Source.server));

      if (docSnapshot.exists) {
        final data =
            Map<String, dynamic>.from(docSnapshot.data()!);

        // 🔹 Save to persistent cache
        await prefs.setString(
          MessMenuCache.dataKey,
          jsonEncode(data),
        );

        await prefs.setInt(
          MessMenuCache.timeKey,
          now.millisecondsSinceEpoch,
        );

        // 🔹 Update memory cache
        MessMenuCache.memoryData = data;
        MessMenuCache.memoryTime = now;

        if (kDebugMode) debugPrint("✅ Data saved (persistent + memory)");

        return data;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Firestore fetch failed: $e");

      // 🔹 fallback to stale persistent cache
      if (cachedJson != null) {
        if (kDebugMode) debugPrint("⚠ Using stale persistent cache");

        return Map<String, dynamic>.from(
            jsonDecode(cachedJson));
      }
    }

    return null;
  }
}