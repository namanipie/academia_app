import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// AUTO-SAVE ATTENDANCE HELPER FUNCTION
// ============================================================================
Map<String, dynamic> _decodeJson(String source) => json.decode(source) as Map<String, dynamic>;

Future<void> saveAttendanceDataOnAppStart(String userData) async {
  try {
    final Map<String, dynamic> data = await compute(_decodeJson, userData);
    final attendanceRoot = data['attendance'];
    
    if (attendanceRoot != null) {
      final overall = attendanceRoot['attendance'] ?? {};
      final coursesMap = overall['courses'];
      
      if (coursesMap is Map) {
        List<Map<String, dynamic>> courses = [];
        
        // Parse ALL courses from userData
        coursesMap.forEach((key, value) {
          if (value is Map) {
            courses.add({
              'id': key, // Unique course ID (code)
              'title': value['course_title'] ?? key,
              'percentage': (value['attendance_percentage'] is num) 
                  ? (value['attendance_percentage'] as num).toDouble() 
                  : 0.0,
              'conducted': (value['hours_conducted'] is num)
                  ? (value['hours_conducted'] as num).toInt()
                  : 0,
              'absent': (value['hours_absent'] is num)
                  ? (value['hours_absent'] as num).toInt()
                  : 0,
            });
          }
        });

        // Save attendance trend data for ALL courses
        if (courses.isNotEmpty) {
          if (kDebugMode) debugPrint('🔄 Saving attendance for ${courses.length} courses...');
          
          final prefs = await SharedPreferences.getInstance();
          const mainKey = 'GRAPH_ATTENDANCE';
          final todayStr = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD

          // Load existing graph data
          Map<String, dynamic> allGraphData = {};
          if (prefs.containsKey(mainKey)) {
            final raw = prefs.getString(mainKey);
            if (raw != null && raw.isNotEmpty) {
              allGraphData = json.decode(raw) as Map<String, dynamic>;
            }
          }

          // Process EACH course
          for (var course in courses) {
            final courseId = course['id'];
            
            // Initialize course data if not exists
            if (!allGraphData.containsKey(courseId)) {
              allGraphData[courseId] = [];
            }

            List<dynamic> courseData = allGraphData[courseId];
            List<Map<String, dynamic>> trends = [];
            
            try {
              trends = List<Map<String, dynamic>>.from(
                courseData.map((item) => Map<String, dynamic>.from(item as Map))
              );
            } catch (e) {
              trends = [];
            }

            // Clean old data (before 5 days)
            final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
            trends.removeWhere((trend) {
              try {
                final trendDate = DateTime.parse(trend['date'] as String);
                return trendDate.isBefore(fiveDaysAgo);
              } catch (e) {
                return true;
              }
            });

            // Check if today's data exists
            final todayExists = trends.any((t) => (t['date'] as String) == todayStr);

            if (!todayExists) {
              // Add today's data
              trends.add({
                'courseId': courseId,
                'date': todayStr,
                'percentage': course['percentage'],
                'conducted': course['conducted'],
                'absent': course['absent'],
              });
            } else {
              // Update today's data if changed
              final todayIndex = trends.indexWhere((t) => (t['date'] as String) == todayStr);
              if (todayIndex != -1) {
                trends[todayIndex] = {
                  'courseId': courseId,
                  'date': todayStr,
                  'percentage': course['percentage'],
                  'conducted': course['conducted'],
                  'absent': course['absent'],
                };
              }
            }

            // Sort by date
            trends.sort((a, b) {
              try {
                final dateA = DateTime.parse(a['date'] as String);
                final dateB = DateTime.parse(b['date'] as String);
                return dateA.compareTo(dateB);
              } catch (e) {
                return 0;
              }
            });

            // Update main data
            allGraphData[courseId] = trends;
          }

          // Save all data at once
          await prefs.setString(mainKey, json.encode(allGraphData));
          if (kDebugMode) debugPrint('✅ Attendance data saved for ${courses.length} courses');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Error saving attendance data: $e');
  }
}