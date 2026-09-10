import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DayOrderManager {
  static const String _dayOrderBackupKey = 'day_order_backup';
  static const String _lastKnownDayOrderKey = 'last_known_day_order';
  static const String _lastKnownDateKey = 'last_known_date';
  
  /// Save day order data when API returns it successfully
  static Future<void> saveDayOrderData({
    required int currentDayOrder,
    required DateTime currentDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save current day order info
    await prefs.setInt(_lastKnownDayOrderKey, currentDayOrder);
    await prefs.setString(_lastKnownDateKey, _formatDate(currentDate));
    
    // Generate and save 15-day forecast
    final forecast = await _generateDayOrderForecast(
      startDate: currentDate,
      startDayOrder: currentDayOrder,
      days: 15,
    );
    
    await prefs.setString(_dayOrderBackupKey, jsonEncode(forecast));
    
    if (kDebugMode) debugPrint('✅ Day order backup saved: DO $currentDayOrder on ${_formatDate(currentDate)}');
    if (kDebugMode) debugPrint('✅ Generated ${forecast.length} days of forecast');
  }
  
  /// Get day order for a specific date (fallback when API fails)
  static Future<int?> getDayOrderForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final backupJson = prefs.getString(_dayOrderBackupKey);
    
    if (backupJson == null) {
      if (kDebugMode) debugPrint('⚠️ No day order backup found');
      return null;
    }
    
    try {
      final Map<String, dynamic> backup = jsonDecode(backupJson);
      final dateKey = _formatDate(date);
      
      if (backup.containsKey(dateKey)) {
        final dayOrder = backup[dateKey] as int;
        if (kDebugMode) debugPrint('✅ Found day order in backup: DO $dayOrder for $dateKey');
        return dayOrder;
      } else {
        if (kDebugMode) debugPrint('⚠️ Date $dateKey not found in backup');
        // Try to extend forecast if date is beyond saved range
        return await _extendForecastAndGet(date);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error reading day order backup: $e');
      return null;
    }
  }
  
  /// Generate day order forecast for next N days
static Future<Map<String, int>> _generateDayOrderForecast({
  required DateTime startDate,
  required int startDayOrder,
  required int days,
}) async {
  Map<String, int> forecast = {};
  DateTime currentDate = startDate;
  int currentDayOrder = startDayOrder;

  // Fetch calendar events once
  final calendarEvents = await getEventsData();

  for (int i = 0; i < days; i++) {
    final dateKey = _formatDate(currentDate);
    final isHoliday = _isHoliday(dateKey, calendarEvents);

    if (isHoliday) {
      // 🔹 Keep previous working day's day order (don’t increment yet)
      forecast[dateKey] = currentDayOrder;
      if (kDebugMode) debugPrint('🏖️ Holiday detected on $dateKey, keeping DO $currentDayOrder');
    } else {
      // 🔹 For a working day, we assign the current DO
      forecast[dateKey] = currentDayOrder;

      // 🔹 And only AFTER assigning, we increment for next day
      currentDayOrder = (currentDayOrder % 5) + 1;
    }

    currentDate = currentDate.add(const Duration(days: 1));
  }

  return forecast;
}

  
  /// Extend forecast when requested date is beyond saved range
  static Future<int?> _extendForecastAndGet(DateTime targetDate) async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnownDayOrder = prefs.getInt(_lastKnownDayOrderKey);
    final lastKnownDateStr = prefs.getString(_lastKnownDateKey);
    
    if (lastKnownDayOrder == null || lastKnownDateStr == null) {
      if (kDebugMode) debugPrint('⚠️ Cannot extend forecast: no last known data');
      return null;
    }
    
    final lastKnownDate = _parseDate(lastKnownDateStr);
    final daysDifference = targetDate.difference(lastKnownDate).inDays;
    
    if (daysDifference < 0) {
      if (kDebugMode) debugPrint('⚠️ Target date is in the past');
      return null;
    }
    
    // Generate extended forecast
    final extendedDays = daysDifference + 15; // Add buffer
    final newForecast = await _generateDayOrderForecast(
      startDate: lastKnownDate,
      startDayOrder: lastKnownDayOrder,
      days: extendedDays,
    );
    
    // Save extended forecast
    await prefs.setString(_dayOrderBackupKey, jsonEncode(newForecast));
    
    final dateKey = _formatDate(targetDate);
    return newForecast[dateKey];
  }
  
  /// Check if a date is a holiday
  static bool _isHoliday(String dateKey, Map<String, Map<String, dynamic>> calendarEvents) {
    if (!calendarEvents.containsKey(dateKey)) {
      return false;
    }
    
    final events = calendarEvents[dateKey]?['event'] as List?;
    if (events == null || events.isEmpty) {
      return false;
    }
    
    // Check if any event is a holiday
    for (var event in events) {
      if (event is Map && event['type'] == 'holiday') {
        return true;
      }
    }
    
    return false;
  }
  
  /// Format date as "d_M_yyyy" for calendar key matching
  static String _formatDate(DateTime date) {
    return '${date.day}_${date.month}_${date.year}';
  }
  
  /// Parse date from "d_M_yyyy" format
  static DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('_');
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }
  
  /// Get current day order (tries API data first, then backup)
  static Future<int?> getCurrentDayOrder({int? apiDayOrder}) async {
    if (apiDayOrder != null) {
      // API returned day order, save it
      await saveDayOrderData(
        currentDayOrder: apiDayOrder,
        currentDate: DateTime.now(),
      );
      return apiDayOrder;
    }
    
    // API didn't return day order, use backup
    if (kDebugMode) debugPrint('⚠️ API day order missing, checking backup...');
    return await getDayOrderForDate(DateTime.now());
  }
  
  /// Clear all day order backup data
  static Future<void> clearBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dayOrderBackupKey);
    await prefs.remove(_lastKnownDayOrderKey);
    await prefs.remove(_lastKnownDateKey);
    if (kDebugMode) debugPrint('🗑️ Day order backup cleared');
  }
  
  /// Get backup status for debugging
  static Future<Map<String, dynamic>> getBackupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final backupJson = prefs.getString(_dayOrderBackupKey);
    final lastDayOrder = prefs.getInt(_lastKnownDayOrderKey);
    final lastDate = prefs.getString(_lastKnownDateKey);
    
    int forecastDays = 0;
    if (backupJson != null) {
      try {
        final backup = jsonDecode(backupJson) as Map;
        forecastDays = backup.length;
      } catch (_) {}
    }
    
    return {
      'hasBackup': backupJson != null,
      'lastKnownDayOrder': lastDayOrder,
      'lastKnownDate': lastDate,
      'forecastDays': forecastDays,
    };
  }
}

// ==================== CALENDAR CACHE (from your existing code) ====================

class CalendarCache {
  static Map<String, Map<String, dynamic>>? lastData;
  static DateTime? lastRefresh;
  static const Duration cacheDuration = Duration(minutes: 10);
}

/// Fetch calendar events with caching logic
Future<Map<String, Map<String, dynamic>>> getEventsData() async {
  // Return cached data if fresh (within 10 min)
  if (CalendarCache.lastData != null &&
      CalendarCache.lastRefresh != null &&
      DateTime.now().difference(CalendarCache.lastRefresh!) <
          CalendarCache.cacheDuration) {
    if (kDebugMode) debugPrint('⚡ Using cached calendar data (no Firestore call)');
    return CalendarCache.lastData!;
  }

  if (kDebugMode) debugPrint('☁️ Fetching calendar data from Firestore...');

  final FirebaseFirestore db = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> eventsData = {};

  try {
    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    bool isOffline = connectivity == ConnectivityResult.none;

    // Fetch data from Firestore (server or cache)
    final snapshot = await db.collection('calendar').get(
      GetOptions(
        source: isOffline ? Source.cache : Source.serverAndCache,
      ),
    );

    // Process
    for (var doc in snapshot.docs) {
      eventsData[doc.id] = Map<String, dynamic>.from(doc.data() as Map);
    }

    if (eventsData.isEmpty) {
      if (kDebugMode) debugPrint(isOffline
          ? '⚠️ No cached calendar data found (offline).'
          : '⚠️ No calendar data found in Firestore.');
    } else {
      if (kDebugMode) debugPrint('✅ Calendar data fetched from ${isOffline ? 'cache' : 'server/cache'}.');

      // Cache it
      CalendarCache.lastData = eventsData;
      CalendarCache.lastRefresh = DateTime.now();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Error fetching Firestore data: $e');

    // Fallback to last cached data if available
    if (CalendarCache.lastData != null) {
      if (kDebugMode) debugPrint('⚠️ Using previous cached calendar data.');
      return CalendarCache.lastData!;
    }
  }

  return eventsData;
}