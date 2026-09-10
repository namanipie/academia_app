import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AnnouncementMap = Map<String, dynamic>;

class AnnouncementCache {
  static const String dataKey = "announcement_data";
  static const String timeKey = "announcement_last_refresh";
  static const Duration cacheDuration = Duration(hours: 2);
}

Future<Map<String, AnnouncementMap>> getEventsData() async {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final prefs = await SharedPreferences.getInstance();

  // 🔹 Step 1: Check stored timestamp
  final lastRefreshMillis = prefs.getInt(AnnouncementCache.timeKey);
  final now = DateTime.now();

  if (lastRefreshMillis != null) {
    final lastRefresh =
        DateTime.fromMillisecondsSinceEpoch(lastRefreshMillis);

    if (now.difference(lastRefresh) < AnnouncementCache.cacheDuration) {
      // 🔹 Load cached data
      final cachedString = prefs.getString(AnnouncementCache.dataKey);

      if (cachedString != null) {
        if (kDebugMode) debugPrint("⚡ Using persistent cached data (no Firestore call)");

        final Map<String, dynamic> decoded = jsonDecode(cachedString);

        return decoded.map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value)));
      }
    }
  }

  // 🔴 Only reaches here if cache expired or not present
  if (kDebugMode) debugPrint("☁ Fetching from Firestore...");

  Map<String, AnnouncementMap> eventsData = {};

  try {
    final snapshot = await db.collection('announcement').get(
      const GetOptions(source: Source.server), // 🔥 FORCE server ONLY when needed
    );

    for (var doc in snapshot.docs) {
      eventsData[doc.id] = Map<String, dynamic>.from(doc.data());
    }

    // 🔹 Save to SharedPreferences
    await prefs.setString(
      AnnouncementCache.dataKey,
      jsonEncode(eventsData),
    );

    await prefs.setInt(
      AnnouncementCache.timeKey,
      now.millisecondsSinceEpoch,
    );

    if (kDebugMode) debugPrint("✅ Data saved locally");

  } catch (e) {
    if (kDebugMode) debugPrint("❌ Firestore fetch failed: $e");

    // 🔹 Fallback to cache even if expired
    final cachedString = prefs.getString(AnnouncementCache.dataKey);
    if (cachedString != null) {
      if (kDebugMode) debugPrint("⚠ Using stale cached data");

      final Map<String, dynamic> decoded = jsonDecode(cachedString);

      return decoded.map((key, value) =>
          MapEntry(key, Map<String, dynamic>.from(value)));
    }
  }

  return eventsData;
}