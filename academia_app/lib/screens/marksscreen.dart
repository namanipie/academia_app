import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/marks_stats_widget.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  // --- UPDATED COLOR PALETTE (GREEN/WHITE/BLACK/GRAY ONLY) ---
  static const Color _pitchBlack = Color(0xFF000000);
  static const Color _darkGray = Color(0xFF0F0F0F);
  static const Color _cardBg = Color.fromARGB(255, 20, 20, 24);
  static const Color _neonGreen = Color.fromARGB(255, 70, 71, 73); // Primary Accent
  static const Color _white = Colors.white;
  static const Color _cautionGreen = Color(0xFF76FF03); // Lighter green for caution
  static const Color _declineGray = Color(0xFF505050); // Used in place of red/yellow for decline
  static const Color _textSecondary = Color(0xFFB0B0B0);

  final Map<String, int> _courseCredits = {};
  bool _loading = true;
  List<Map<String, dynamic>> _marks = [];

  @override
  void initState() {
    super.initState();
    _loadMarksFromPrefs();
  }

Future<void> _loadMarksFromPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('userData');
    if (raw == null || raw.isEmpty) return;

    final Map<String, dynamic> data = json.decode(raw);

    // --- Extract course credits and build course map from timetable ---
    final Map<String, dynamic> timetableCourseMap = {};
    _courseCredits.clear();
    if (data['timetable'] != null && data['timetable']['courses'] != null) {
      final timetableCourses = data['timetable']['courses'];
      if (timetableCourses is List) {
        for (final course in timetableCourses) {
          if (course is Map) {
            final title = course['course_title'];
            final credit = course['credit'];
            final codeRaw = course['course_code'] ?? '';

            // normalize keys for lookups: keep original code and base code (without Theory/Practical)
            final baseCode = codeRaw
                .toString()
                .replaceAll(RegExp(r'(Regular)?(Theory|Practical)$'), '');

            if (title != null) {
              timetableCourseMap[codeRaw.toString()] = course;
              timetableCourseMap[baseCode] = course;
            }

            if (title != null && credit != null) {
              _courseCredits[title.toString()] = (credit is int)
                  ? credit
                  : int.tryParse(credit.toString()) ?? 3;
            }
          }
        }
      }
    }

    // --- Find marks root (prefer top-level 'marks', else check attendance.marks like before) ---
    var marksRoot = data['marks'];
    if (marksRoot == null &&
        data['attendance'] != null &&
        data['attendance'] is Map) {
      final attendanceRoot = data['attendance'] as Map;
      if (attendanceRoot['marks'] != null) {
        var candidate = attendanceRoot['marks'];
        if (candidate is String && candidate.isNotEmpty) {
          try {
            candidate = json.decode(candidate);
          } catch (e) {
            // ignore: avoid_print
            if (kDebugMode) debugPrint('Failed to decode attendance.marks string: $e');
          }
        }
        marksRoot = candidate;
      }
    }

    if (marksRoot != null && marksRoot is Map) {
      if (kDebugMode) debugPrint('DEBUG MARKS: $marksRoot');
      final parsed = <Map<String, dynamic>>[];

      // build fallback courseTitleMap from attendance (only if timetable mapping missing)
      final Map<String, String> attendanceTitleMap = {};
      if (data['attendance'] != null &&
          data['attendance']['attendance'] != null) {
        final courses = data['attendance']['attendance']['courses'];
        if (courses is Map) {
          courses.forEach((key, courseData) {
            if (courseData is Map && courseData['course_title'] != null) {
              final baseCode = key
                  .toString()
                  .replaceAll(RegExp(r'Regular(Theory|Practical)$'), '');
              attendanceTitleMap[baseCode] = courseData['course_title'];
            }
          });
        }
      }

      marksRoot.forEach((code, value) {
        if (value is Map) {
          final tests = <Map<String, dynamic>>[];
          final testsRaw = value['tests'];
          if (testsRaw is List) {
            for (final t in testsRaw) {
              if (t is Map) {
                tests.add({
                  'name': t['test_name'] ?? '',
                  'obtained': (t['obtained_marks'] is num)
                      ? (t['obtained_marks'] as num).toDouble()
                      : (t['obtained_marks'] != null
                          ? double.tryParse(t['obtained_marks'].toString()) ??
                              0.0
                          : 0.0),
                  'max': (t['max_marks'] is num)
                      ? (t['max_marks'] as num).toDouble()
                      : (t['max_marks'] != null
                          ? double.tryParse(t['max_marks'].toString()) ?? 0.0
                          : 0.0),
                  'percentage': (t['percentage'] is num)
                      ? (t['percentage'] as num).toDouble()
                      : (t['percentage'] != null
                          ? double.tryParse(t['percentage'].toString()) ?? 0.0
                          : 0.0),
                });
              }
            }
          }

          // normalize course code (remove Theory/Practical suffixes)
          final baseCode =
              code.toString().replaceAll(RegExp(r'(Theory|Practical)$'), '');

          // Try to get course title from timetable first, else attendance fallback, else use code
          String courseTitle = code;
          final courseFromTimetable = timetableCourseMap[code] ??
              timetableCourseMap[baseCode]; // check both keys
          if (courseFromTimetable is Map && courseFromTimetable['course_title'] != null) {
            courseTitle = courseFromTimetable['course_title'].toString();
          } else if (attendanceTitleMap.containsKey(baseCode)) {
            courseTitle = attendanceTitleMap[baseCode]!;
          }

          parsed.add({
            'title': courseTitle,
            'type': value['course_type'] ?? 'Theory',
            'tests': tests,
          });
        }
      });

      if (parsed.isNotEmpty) {
        setState(() {
          _marks = parsed;
        });
      }
    }
  } catch (e) {
    // ignore or log
    // ignore: avoid_print
    if (kDebugMode) debugPrint('Error loading marks: $e');
  } finally {
    setState(() => _loading = false);
  }
}


  Map<String, dynamic> _calculateCourseTotals(
      List<Map<String, dynamic>> tests) {
    double totalObtained = 0.0;
    double totalMax = 0.0;

    for (final test in tests) {
      totalObtained += (test['obtained'] as num).toDouble();
      totalMax += (test['max'] as num).toDouble();
    }

    final overallPercentage =
        (totalMax > 0) ? (totalObtained / totalMax) * 100 : 0.0;

    return {
      'obtained': totalObtained,
      'max': totalMax,
      'percentage': overallPercentage,
    };
  }

  // Logic to use only shades of green and gray (NOT CHANGED)
  Color _getScoreColor(double percentage) {
    if (percentage >= 85) return const Color.fromARGB(255, 147, 229, 132);
    if (percentage >= 70) return const Color.fromARGB(255, 209, 242, 183);
    return const Color.fromARGB(255, 233, 205, 205); // Use dark gray for low scores
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _pitchBlack,
        appBar: AppBar(
          title: const Text('Marks',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _white,
                  fontSize: 20)),
          backgroundColor: _pitchBlack,
          foregroundColor: _neonGreen,
          elevation: 0,
        ),
        body: const Center(
            child: CircularProgressIndicator(color: _neonGreen)),
      );
    }

    return Scaffold(
      backgroundColor: _pitchBlack,
      appBar: AppBar(
        title: const Text('Marks',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: _white, fontSize: 20)),
        backgroundColor: _pitchBlack,
        foregroundColor: _neonGreen,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (_marks.isNotEmpty) ...[
            MarksStatsWidget(
              marks: _marks,
              courseCredits: _courseCredits,
            ),
            const SizedBox(height: 20),
            ..._marks.map((course) => _buildCourseMarksCard(course))
          ] else
                 Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_rounded,
                          color: _white.withValues(alpha: 0.2),
                          size: 60,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Bruh, no marks yet? 💀',
                          style: TextStyle(
                            color: _white.withValues(alpha: 0.8),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cook up some grades and check back later.',
                          style: TextStyle(
                            color: _white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

 Widget _buildCourseMarksCard(Map<String, dynamic> course) {
  final tests = course['tests'] as List<Map<String, dynamic>>;
  final totals = _calculateCourseTotals(tests);

  final double totalObtained = totals['obtained'];
  final double totalMax = totals['max'];
  final double overallPercentage = totals['percentage'];

  List<double> percentages =
      tests.map((t) => (t['percentage'] as num).toDouble()).toList();
  percentages = percentages.reversed.toList();

  // Logic for Trend Colors
  Color statusColor = _getScoreColor(overallPercentage);
  Color sparklineColor = const Color(0xFFAED6A7); 
  
  if (percentages.length >= 2) {
    if (percentages.last < percentages[percentages.length - 2]) {
      sparklineColor = _declineGray; 
    }
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _white.withValues(alpha:0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SLEEK HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vertical Status Accent
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (course['title'].length > 22)
                          ? course['title'].substring(0, 22) + '...'
                          : course['title'],
                      style: const TextStyle(
                        color: _white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      course['type'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _white.withValues(alpha:0.4),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${overallPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _white,
                    ),
                  ),
                  Text(
                    '${totalObtained.toStringAsFixed(1)} / ${totalMax.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _white.withValues(alpha:0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. THE MODERN GRAPH (Area Chart)
        if (percentages.length > 1)
          Container(
            height: 90,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 10),
            child: _MarksTrendSparkline(
              percentages: percentages,
              lineColor: sparklineColor,
              lastPointColor: _white,
            ),
          ),

        // 3. ASSESSMENT LIST
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 14, color: _white.withValues(alpha:0.3)),
                  const SizedBox(width: 6),
                  Text(
                    "DETAILED PERFORMANCE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _white.withValues(alpha:0.3),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tests.map((test) => _buildModernTestRow(test)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildModernTestRow(Map<String, dynamic> test) {
  final color = _getScoreColor(test['percentage']);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                test['name'],
                style: TextStyle(
                  color: _white.withValues(alpha:0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${test['obtained']} / ${test['max']} marks',
                style: TextStyle(color: _white.withValues(alpha:0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha:0.2)),
          ),
          child: Text(
            '${(test['percentage'] as double).toStringAsFixed(0)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
}

// =======================================================================
// Marks Trend Sparkline (NO CHANGES)
// =======================================================================

class _MarksTrendSparkline extends StatelessWidget {
  final List<double> percentages;
  final Color lineColor;
  final Color lastPointColor;

  const _MarksTrendSparkline({
    required this.percentages,
    required this.lineColor,
    required this.lastPointColor,
  });

  @override
  Widget build(BuildContext context) {
    if (percentages.length < 2) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _MarksTrendPainter(
        percentages: percentages,
        lineColor: lineColor,
        lastPointColor: lastPointColor,
      ),
      child: Container(),
    );
  }
}

class _MarksTrendPainter extends CustomPainter {
  final List<double> percentages;
  final Color lineColor;
  final Color lastPointColor;

  _MarksTrendPainter({
    required this.percentages,
    required this.lineColor,
    required this.lastPointColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (percentages.length < 2) return;

    final path = Path();
    final fillPath = Path();
    final double xStep = size.width / (percentages.length - 1);
    
    // Smooth points calculation
    List<Offset> points = [];
    for (int i = 0; i < percentages.length; i++) {
      double y = size.height - (percentages[i] / 100 * size.height);
      points.add(Offset(i * xStep, y.clamp(5, size.height - 5)));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      var p0 = points[i];
      var p1 = points[i + 1];
      var controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      var controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Draw Fill Gradient
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha:0.2), lineColor.withValues(alpha:0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw Smooth Line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Draw Last Point Glow
    final glowPaint = Paint()
      ..color = lastPointColor.withValues(alpha:0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(points.last, 6, glowPaint);
    canvas.drawCircle(points.last, 3, Paint()..color = lastPointColor);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}