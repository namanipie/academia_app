import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to parse attendance, internal marks, and academic records from
/// the official SRM Student Portal (sp.srmist.edu.in) into the Console schema.
class StudentPortalParser {
  /// Parse Attendance HTML from studentAttendanceDetails.jsp
  static Map<String, dynamic> parseAttendanceHtml(String html) {
    final Map<String, dynamic> result = {
      'courses': <String, dynamic>{},
      'overall_attendance': 0.0,
      'total_hours_conducted': 0,
      'total_hours_absent': 0,
    };

    if (html.trim().isEmpty) return result;

    try {
      final document = html_parser.parse(html);
      final tables = document.querySelectorAll('table');

      if (tables.isEmpty) {
        if (kDebugMode) debugPrint('[PORTAL PARSER] No tables found in attendance HTML');
        return result;
      }

      // Find the most suitable table (contains course/conducted/absent or has numeric columns)
      dom.Element? attendanceTable;
      for (final table in tables) {
        final text = table.text.toLowerCase();
        if (text.contains('course') && (text.contains('conduct') || text.contains('absent') || text.contains('%'))) {
          attendanceTable = table;
          break;
        }
      }

      // Fallback: pick the table with the most rows
      if (attendanceTable == null) {
        int maxRows = 0;
        for (final table in tables) {
          final rows = table.querySelectorAll('tr');
          if (rows.length > maxRows) {
            maxRows = rows.length;
            attendanceTable = table;
          }
        }
      }

      if (attendanceTable == null) return result;

      final rows = attendanceTable.querySelectorAll('tr').where((tr) {
        final parent = tr.parent;
        return parent == attendanceTable || (parent?.localName == 'tbody' && parent?.parent == attendanceTable);
      }).toList();
      if (rows.length < 2) return result;

      // Detect column indices from header
      final headerCells = rows.first.querySelectorAll('th, td');
      int codeCol = -1;
      int titleCol = -1;
      int catCol = -1;
      int conductedCol = -1;
      int absentCol = -1;
      int pctCol = -1;
      int facultyCol = -1;
      int slotCol = -1;
      int roomCol = -1;

      for (int i = 0; i < headerCells.length; i++) {
        final h = headerCells[i].text.toLowerCase().trim();
        if (h.contains('code')) {
          codeCol = i;
        } else if (h.contains('title') || h.contains('desc') || h.contains('subject') || (h.contains('course') && !h.contains('code'))) {
          titleCol = i;
        } else if (h.contains('cat') || h.contains('type')) {
          catCol = i;
        } else if (h.contains('conduct') || h.contains('total') || h.contains('held')) {
          conductedCol = i;
        } else if (h.contains('absent') || h.contains('miss')) {
          absentCol = i;
        } else if (h.contains('%') || h.contains('percent')) {
          pctCol = i;
        } else if (h.contains('facult') || h.contains('staff') || h.contains('teacher')) {
          facultyCol = i;
        } else if (h.contains('slot')) {
          slotCol = i;
        } else if (h.contains('room')) {
          roomCol = i;
        }
      }

      int totalConducted = 0;
      int totalAbsent = 0;
      final Map<String, dynamic> coursesMap = {};

      for (int r = 1; r < rows.length; r++) {
        final cells = rows[r].querySelectorAll('td, th');
        if (cells.isEmpty) continue;

        String rawCode = _cellText(cells, codeCol, fallbackIndex: 0);
        String rawTitle = _cellText(cells, titleCol, fallbackIndex: 1);
        String rawCat = _cellText(cells, catCol, fallbackIndex: 2);
        String rawConducted = _cellText(cells, conductedCol, fallbackIndex: 3);
        String rawAbsent = _cellText(cells, absentCol, fallbackIndex: 4);
        String rawPct = _cellText(cells, pctCol, fallbackIndex: 5);
        String rawFaculty = _cellText(cells, facultyCol, fallbackIndex: -1);
        String rawSlot = _cellText(cells, slotCol, fallbackIndex: -1);
        String rawRoom = _cellText(cells, roomCol, fallbackIndex: -1);

        if (rawCode.isEmpty && rawTitle.isEmpty) continue;

        // Clean code (extract code from "21CSC302J\nRegular" or similar)
        String courseCode = rawCode.split(RegExp(r'\s+')).first.trim();
        if (courseCode.isEmpty) {
          courseCode = rawTitle.split(RegExp(r'\s+')).first.trim();
        }

        String category = rawCat.isNotEmpty ? rawCat : 'Theory';
        if (category.toLowerCase().contains('prac') || category.toLowerCase().contains('lab')) {
          category = 'Practical';
        } else {
          category = 'Theory';
        }

        final int conducted = int.tryParse(rawConducted.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final int absent = int.tryParse(rawAbsent.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        double pct = double.tryParse(rawPct.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

        if (pct == 0.0 && conducted > 0) {
          pct = double.parse((((conducted - absent) / conducted) * 100).toStringAsFixed(2));
        }

        totalConducted += conducted;
        totalAbsent += absent;

        final courseKey = '$courseCode$category';

        coursesMap[courseKey] = {
          'course_code': courseCode,
          'course_title': rawTitle.isNotEmpty ? rawTitle : courseCode,
          'category': category,
          'faculty_name': rawFaculty,
          'slot': rawSlot,
          'room_no': rawRoom,
          'hours_conducted': conducted,
          'hours_absent': absent,
          'attendance_percentage': pct,
        };
      }

      double overallPct = 0.0;
      if (totalConducted > 0) {
        overallPct = double.parse((((totalConducted - totalAbsent) / totalConducted) * 100).toStringAsFixed(2));
      }

      result['courses'] = coursesMap;
      result['overall_attendance'] = overallPct;
      result['total_hours_conducted'] = totalConducted;
      result['total_hours_absent'] = totalAbsent;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL PARSER] Error parsing attendance HTML: $e\n$stack');
    }

    return result;
  }

  /// Parse Internal Marks HTML from studentInternalMarkDetails.jsp
  static Map<String, dynamic> parseMarksHtml(String html) {
    final Map<String, dynamic> marksMap = {};

    if (html.trim().isEmpty) return marksMap;

    try {
      final document = html_parser.parse(html);
      final tables = document.querySelectorAll('table');

      for (final table in tables) {
        // Skip sub-tables that are nested inside cells of an outer table
        dom.Element? p = table.parent;
        bool isNested = false;
        while (p != null) {
          if (p.localName == 'table') {
            isNested = true;
            break;
          }
          p = p.parent;
        }
        if (isNested) continue;

        // Only inspect direct rows of this table
        final rows = table.querySelectorAll('tr').where((tr) {
          final parent = tr.parent;
          return parent == table || (parent?.localName == 'tbody' && parent?.parent == table);
        }).toList();
        if (rows.length < 2) continue;

        for (int r = 1; r < rows.length; r++) {
          final cells = rows[r].querySelectorAll('td');
          if (cells.length < 2) continue;

          final rawCode = cells[0].text.trim().split(RegExp(r'\s+')).first;
          if (rawCode.isEmpty) continue;

          String courseType = cells.length > 1 ? cells[1].text.trim() : 'Theory';
          if (!courseType.toLowerCase().contains('prac') && !courseType.toLowerCase().contains('lab')) {
            courseType = 'Theory';
          } else {
            courseType = 'Practical';
          }

          final courseKey = '$rawCode$courseType';
          final List<Map<String, dynamic>> tests = [];

          // Look for tests in remaining cells or sub-tables
          for (int c = 2; c < cells.length; c++) {
            final cell = cells[c];
            final subTables = cell.querySelectorAll('table');
            if (subTables.isNotEmpty) {
              for (final subTbl in subTables) {
                final subCells = subTbl.querySelectorAll('td, th');
                for (final sc in subCells) {
                  _extractTestFromText(sc.text.trim(), tests);
                }
              }
            } else {
              _extractTestFromText(cell.text.trim(), tests);
            }
          }

          if (tests.isNotEmpty) {
            marksMap[courseKey] = {
              'course_code': rawCode,
              'course_type': courseType,
              'tests': tests,
            };
          }
        }
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL PARSER] Error parsing marks HTML: $e\n$stack');
    }

    return marksMap;
  }

  /// Helper to extract test name and scores from patterns like "CLA-1/15.00 14.50" or "CT-1: 18/20"
  static void _extractTestFromText(String text, List<Map<String, dynamic>> tests) {
    if (text.isEmpty) return;

    // Pattern 1: NAME/MAX OBTAINED (e.g. "CLA-1/15.00 14.50" or "FT-I/5.00 5.00")
    final slashRegex = RegExp(r'([A-Za-z0-9_\-\s]+)/(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)');
    final matches = slashRegex.allMatches(text);
    for (final m in matches) {
      final name = m.group(1)?.trim() ?? '';
      final maxMarks = double.tryParse(m.group(2) ?? '0') ?? 0.0;
      final obtainedMarks = double.tryParse(m.group(3) ?? '0') ?? 0.0;
      final pct = maxMarks > 0 ? double.parse(((obtainedMarks / maxMarks) * 100).toStringAsFixed(2)) : 0.0;

      if (name.isNotEmpty && !tests.any((t) => t['test_name'] == name)) {
        tests.add({
          'test_name': name,
          'max_marks': maxMarks,
          'obtained_marks': obtainedMarks,
          'percentage': pct,
        });
      }
    }

    if (matches.isEmpty) {
      // Pattern 2: "Test Name: OBTAINED / MAX" or "Test Name : OBTAINED"
      final colonRegex = RegExp(r'([A-Za-z0-9_\-\s]+)\s*[:=]\s*(\d+(?:\.\d+)?)(?:\s*/\s*(\d+(?:\.\d+)?))?');
      final cMatches = colonRegex.allMatches(text);
      for (final m in cMatches) {
        final name = m.group(1)?.trim() ?? '';
        final obtainedMarks = double.tryParse(m.group(2) ?? '0') ?? 0.0;
        final maxMarks = double.tryParse(m.group(3) ?? '') ?? (obtainedMarks > 50 ? 100.0 : (obtainedMarks > 25 ? 50.0 : 20.0));
        final pct = maxMarks > 0 ? double.parse(((obtainedMarks / maxMarks) * 100).toStringAsFixed(2)) : 0.0;

        if (name.isNotEmpty && !tests.any((t) => t['test_name'] == name)) {
          tests.add({
            'test_name': name,
            'max_marks': maxMarks,
            'obtained_marks': obtainedMarks,
            'percentage': pct,
          });
        }
      }
    }
  }

  /// Parse 2D array representation from backend student_portal_result (if available)
  static Map<String, dynamic> parseRawAttendanceTable(List<dynamic> tableRows) {
    final Map<String, dynamic> result = {
      'courses': <String, dynamic>{},
      'overall_attendance': 0.0,
      'total_hours_conducted': 0,
      'total_hours_absent': 0,
    };

    if (tableRows.length < 2) return result;

    int totalConducted = 0;
    int totalAbsent = 0;
    final Map<String, dynamic> coursesMap = {};

    for (int i = 1; i < tableRows.length; i++) {
      final row = tableRows[i];
      if (row is! List || row.isEmpty) continue;

      String code = row.isNotEmpty ? row[0].toString().trim() : '';
      String title = row.length > 1 ? row[1].toString().trim() : code;
      String rawPct = row.length > 2 ? row[2].toString().trim() : '0';

      final cleanCode = code.split(RegExp(r'\s+')).first;
      double pct = double.tryParse(rawPct.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      int conducted = row.length > 3 ? (int.tryParse(row[3].toString()) ?? 30) : 30;
      int absent = row.length > 4 ? (int.tryParse(row[4].toString()) ?? 0) : ((conducted * (100 - pct) / 100).round());

      totalConducted += conducted;
      totalAbsent += absent;

      final courseKey = '${cleanCode}Theory';
      coursesMap[courseKey] = {
        'course_code': cleanCode,
        'course_title': title.isNotEmpty ? title : cleanCode,
        'category': 'Theory',
        'hours_conducted': conducted,
        'hours_absent': absent,
        'attendance_percentage': pct,
      };
    }

    double overallPct = 0.0;
    if (totalConducted > 0) {
      overallPct = double.parse((((totalConducted - totalAbsent) / totalConducted) * 100).toStringAsFixed(2));
    }

    result['courses'] = coursesMap;
    result['overall_attendance'] = overallPct;
    result['total_hours_conducted'] = totalConducted;
    result['total_hours_absent'] = totalAbsent;

    return result;
  }

  /// Helper to get text from cell with fallback
  static String _cellText(List<dom.Element> cells, int primaryIndex, {int fallbackIndex = -1}) {
    if (primaryIndex >= 0 && primaryIndex < cells.length) {
      return cells[primaryIndex].text.trim();
    }
    if (fallbackIndex >= 0 && fallbackIndex < cells.length) {
      return cells[fallbackIndex].text.trim();
    }
    return '';
  }

  /// Merge parsed Student Portal data into userData in SharedPreferences
  static Future<bool> mergeStudentPortalDataIntoUserData({
    required Map<String, dynamic> attendanceData,
    required Map<String, dynamic> marksData,
    Map<String, dynamic>? rawPortalResult,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUserData = prefs.getString('userData');
      Map<String, dynamic> userData = {};

      if (rawUserData != null && rawUserData.isNotEmpty) {
        try {
          userData = json.decode(rawUserData) as Map<String, dynamic>;
        } catch (e) {
          userData = {};
        }
      }

      // 1. Merge Attendance
      if (attendanceData['courses'] != null && (attendanceData['courses'] as Map).isNotEmpty) {
        if (userData['attendance'] == null || userData['attendance'] is! Map) {
          userData['attendance'] = <String, dynamic>{};
        }
        final attRoot = userData['attendance'] as Map<String, dynamic>;

        // Preserve existing student_info and day_order if present
        attRoot['attendance'] = attendanceData;
        attRoot['attendance_unavailable'] = false; // Attendance is now live and available!

        // If timetable has course titles, enhance any empty course titles
        if (userData['timetable'] != null && userData['timetable']['courses'] is List) {
          final ttCourses = userData['timetable']['courses'] as List;
          final Map<String, String> titleMap = {};
          for (final c in ttCourses) {
            if (c is Map && c['course_code'] != null && c['course_title'] != null) {
              final code = c['course_code'].toString().split(RegExp(r'\s+')).first;
              titleMap[code] = c['course_title'].toString();
            }
          }

          final coursesMap = attendanceData['courses'] as Map<String, dynamic>;
          coursesMap.forEach((key, val) {
            if (val is Map) {
              final code = (val['course_code'] ?? key).toString().replaceAll(RegExp(r'(Theory|Practical)$'), '');
              if ((val['course_title'] == null || val['course_title'] == code) && titleMap.containsKey(code)) {
                val['course_title'] = titleMap[code];
              }
            }
          });
        }
      }

      // 2. Merge Marks
      if (marksData.isNotEmpty) {
        userData['marks'] = marksData;
        if (userData['attendance'] != null && userData['attendance'] is Map) {
          (userData['attendance'] as Map<String, dynamic>)['marks'] = marksData;
        }
      }

      // 3. Mark Student Portal as connected
      await prefs.setString('userData', json.encode(userData));
      await prefs.setBool('student_portal_connected', true);
      await prefs.setString('student_portal_last_synced', DateTime.now().toIso8601String());

      // 4. Save raw result if provided for MainPortalPage
      if (rawPortalResult != null) {
        await prefs.setString('student_portal_result', json.encode(rawPortalResult));
      }

      if (kDebugMode) {
        debugPrint('[PORTAL PARSER] Successfully merged student portal data into userData! Courses: ${attendanceData['courses']?.length ?? 0}, Marks: ${marksData.length}');
      }
      return true;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL PARSER] Failed to merge into userData: $e\n$stack');
      return false;
    }
  }

  /// Check if Student Portal is currently connected
  static Future<bool> isStudentPortalConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('student_portal_connected') ?? false;
  }

  /// Disconnect Student Portal and clear portal caches
  static Future<void> disconnectStudentPortal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_portal_connected');
    await prefs.remove('student_portal_last_synced');
    await prefs.remove('student_portal_result');
  }
}
