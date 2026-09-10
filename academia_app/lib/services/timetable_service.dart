import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// TIMETABLE SERVICE - Reusable logic for timetable operations
// ============================================================================
class TimetableService {
  // Singleton pattern
  static final TimetableService _instance = TimetableService._internal();
  factory TimetableService() => _instance;
  TimetableService._internal();

  Map<String, dynamic>? _batchTimetable;
  List<Map<String, dynamic>> _courses = [];
  List<String> _timeSlots = [];
  String? _studentBatch;
  int _currentDayOrder = 0;

  // Getters
  Map<String, dynamic>? get batchTimetable => _batchTimetable;
  List<Map<String, dynamic>> get courses => _courses;
  List<String> get timeSlots => _timeSlots;
  String? get studentBatch => _studentBatch;
  int get currentDayOrder => _currentDayOrder;

  /// Load timetable data from SharedPreferences
  Future<bool> loadTimetable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('userData')) return false;
      
      final raw = prefs.getString('userData');
      if (raw == null || raw.isEmpty) return false;
      
      final Map<String, dynamic> data = json.decode(raw);
      
      // Load day order from localStorage
      var dayOrder = data['attendance']?['day_order'];
      if (dayOrder is String) {
        dayOrder = int.tryParse(dayOrder) ?? 0;
      } else if (dayOrder is! int) {
        dayOrder = 0;
      }
      _currentDayOrder = dayOrder as int;
      
      // Identify batch
      _studentBatch = data['timetable']?['student_info']?['batch'] ?? '1';
      final Map<String, dynamic> fullBatchTimetable = _hardcodedBatchTimetable();
      final batchKey = 'Batch$_studentBatch';
      
      if (!fullBatchTimetable.containsKey(batchKey)) {
        return false;
      }
      
      _batchTimetable = fullBatchTimetable[batchKey];
      _timeSlots = List<String>.from(_batchTimetable!['time_slots']);
      
      // Load student courses
      final List<dynamic>? courseList = data['timetable']?['courses'];
      if (courseList != null) {
        _courses = courseList.map((e) {
          final slot = e['slot']?.toString() ?? '';
          final code = e['course_code']?.toString() ?? '';
          final title = e['course_title']?.toString() ?? '';
          final venue = e['room_no']?.toString() ?? 'TBA';
          return {
            'slot': slot,
            'display': '$code — $title',
            'venue': venue,
          };
        }).toList();
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading timetable: $e');
      return false;
    }
  }

  /// Get hardcoded batch timetable data
  Map<String, dynamic> _hardcodedBatchTimetable() {
    return {
      "Batch1": {
        "time_slots": [
          "08:00 - 08:50",
          "08:50 - 09:40",
          "09:45 - 10:35",
          "10:40 - 11:30",
          "11:35 - 12:25",
          "12:30 - 01:20",
          "01:25 - 02:15",
          "02:20 - 03:10",
          "03:10 - 04:00",
          "04:00 - 04:50",
          "04:50 - 05:30",
          "05:30 - 06:10"
        ],
        "schedule": {
          "Day 1": ["A", "A / X", "F / X", "F", "G", "P6", "P7", "P8", "P9", "P10", "L11", "L12"],
          "Day 2": ["P11", "P12/X", "P13/X", "P14", "P15", "B", "B", "G", "G", "A", "L21", "L22"],
          "Day 3": ["C", "C / X", "A / X", "D", "B", "P26", "P27", "P28", "P29", "P30", "L31", "L32"],
          "Day 4": ["P31", "P32/X", "P33/X", "P34", "P35", "D", "D", "B", "E", "C", "L41", "L42"],
          "Day 5": ["E", "E / X", "C / X", "F", "D", "P46", "P47", "P48", "P49", "P50", "L51", "L52"]
        }
      },
      "Batch2": {
        "time_slots": [
          "08:00 - 08:50",
          "08:50 - 09:40",
          "09:45 - 10:35",
          "10:40 - 11:30",
          "11:35 - 12:25",
          "12:30 - 01:20",
          "01:25 - 02:15",
          "02:20 - 03:10",
          "03:10 - 04:00",
          "04:00 - 04:50",
          "04:50 - 05:30",
          "05:30 - 06:10"
        ],
        "schedule": {
          "Day 1": ["P1", "P2/X", "P3/X", "P4", "P5", "A", "A", "F", "F", "G", "L11", "L12"],
          "Day 2": ["B", "B / X", "G / X", "G", "A", "P16", "P17", "P18", "P19", "P20", "L21", "L22"],
          "Day 3": ["P21", "P22/X", "P23/X", "P24", "P25", "C", "C", "A", "D", "B", "L31", "L32"],
          "Day 4": ["D", "D / X", "B / X", "E", "C", "P36", "P37", "P38", "P39", "P40", "L41", "L42"],
          "Day 5": ["P41", "P42/X", "P43/X", "P44", "P45", "E", "E", "C", "F", "D", "L51", "L52"]
        }
      }
    };
  }

Map<String, String> getCourseForSlot(String slot) {
  // Split schedule slot by "/" to handle cases like "A / X"
  final slotOptions = slot.split('/').map((s) => s.trim()).toList();
  
  for (var course in _courses) {
    final courseSlot = (course['slot'] as String).replaceAll(RegExp(r'-+$'), '').trim();
    
    // Handle multi-slot ranges like L41-L42
    if (courseSlot.contains('-')) {
      final parts = courseSlot.split('-');
      for (var p in parts) {
        p = p.trim();
        if (p.isEmpty) continue;
        // Check if any of the slot options match
        if (slotOptions.contains(p)) {
          return {
            'display': course['display'],
            'venue': course['venue'] ?? 'TBA',
          };
        }
      }
    } else {
      // Check if any of the slot options match the course slot
      if (slotOptions.contains(courseSlot)) {
        return {
          'display': course['display'],
          'venue': course['venue'] ?? 'TBA',
        };
      }
    }
  }
  return {'display': '', 'venue': ''};
}

  /// Get all classes for a specific day (1-5)
  List<Map<String, String>> getClassesForDay(int day) {
    if (day < 1 || day > 5 || _batchTimetable == null) {
      return [];
    }
    
    final dayLabel = 'Day $day';
    final schedule = _batchTimetable!['schedule'];
    if (schedule == null || schedule[dayLabel] == null) {
      return [];
    }

    final slots = List<String>.from(schedule[dayLabel]);
    final List<Map<String, String>> dayClasses = [];
    
    for (int i = 0; i < slots.length && i < _timeSlots.length; i++) {
      final slotCode = slots[i];
      final courseInfo = getCourseForSlot(slotCode);
      
      if (courseInfo['display']!.isNotEmpty) {
        dayClasses.add({
          'time': _timeSlots[i],
          'course': courseInfo['display']!,
          'classroom': courseInfo['venue']!,
          'slot': slotCode,
        });
      }
    }
    
    return dayClasses;
  }

  /// Get classes for all days (1-5)
  Map<int, List<Map<String, String>>> getAllDaysClasses() {
    final Map<int, List<Map<String, String>>> allClasses = {};
    for (int day = 1; day <= 5; day++) {
      allClasses[day] = getClassesForDay(day);
    }
    return allClasses;
  }

  /// Get classes for current day order
  List<Map<String, String>> getCurrentDayClasses() {
    if (_currentDayOrder < 1 || _currentDayOrder > 5) {
      return [];
    }
    return getClassesForDay(_currentDayOrder);
  }

  /// Check if a specific day has classes
  bool hasDayClasses(int day) {
    return getClassesForDay(day).isNotEmpty;
  }

  /// Get total class count for a day
  int getClassCountForDay(int day) {
    return getClassesForDay(day).length;
  }

  /// Clear cached data
  void clear() {
    _batchTimetable = null;
    _courses = [];
    _timeSlots = [];
    _studentBatch = null;
    _currentDayOrder = 0;
  }
}