import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ============================================================================
// ATTENDANCE TREND WIDGET - Shows last 5 days attendance with modern line graph
// ============================================================================

class AttendanceTrendData {
  final String courseId;
  final String date;
  final double percentage;
  final int conducted;
  final int absent;

  AttendanceTrendData({
    required this.courseId,
    required this.date,
    required this.percentage,
    required this.conducted,
    required this.absent,
  });

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'date': date,
    'percentage': percentage,
    'conducted': conducted,
    'absent': absent,
  };

  factory AttendanceTrendData.fromJson(Map<String, dynamic> json) =>
      AttendanceTrendData(
        courseId: json['courseId'],
        date: json['date'],
        percentage: (json['percentage'] is num) ? (json['percentage'] as num).toDouble() : 0.0,
        conducted: (json['conducted'] is num) ? (json['conducted'] as num).toInt() : 0,
        absent: (json['absent'] is num) ? (json['absent'] as num).toInt() : 0,
      );
}

class AttendanceTrendWidget extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final double currentPercentage;
  final int currentConducted;
  final int currentAbsent;

  const AttendanceTrendWidget({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.currentPercentage,
    required this.currentConducted,
    required this.currentAbsent,
  });

  @override
  State<AttendanceTrendWidget> createState() => _AttendanceTrendWidgetState();

  /// Static method to save attendance data for all courses (call from app initialization)
  static Future<void> saveAttendanceDataForAllCourses(
    List<Map<String, dynamic>> courses,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const mainKey = 'GRAPH_ATTENDANCE';

      // Load existing graph data
      Map<String, dynamic> allGraphData = {};
      if (prefs.containsKey(mainKey)) {
        final raw = prefs.getString(mainKey);
        if (raw != null && raw.isNotEmpty) {
          allGraphData = json.decode(raw) as Map<String, dynamic>;
        }
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Process each course
      for (var course in courses) {
        final courseId = course['id'] ?? course['title'] ?? 'unknown';
        final percentage = (course['percentage'] is num)
            ? (course['percentage'] as num).toDouble()
            : 0.0;
        final conducted = (course['conducted'] is num)
            ? (course['conducted'] as num).toInt()
            : 0;
        final absent = (course['absent'] is num)
            ? (course['absent'] as num).toInt()
            : 0;

        // Initialize course data if not exists
        if (!allGraphData.containsKey(courseId)) {
          allGraphData[courseId] = [];
        }

        List<dynamic> courseData = allGraphData[courseId];
        List<AttendanceTrendData> trends = courseData
            .map((item) => AttendanceTrendData.fromJson(item as Map<String, dynamic>))
            .toList();

        // Clean old data
        final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
        trends.removeWhere((trend) {
          final trendDate = DateTime.parse(trend.date);
          return trendDate.isBefore(fiveDaysAgo);
        });

        // Check if today's data exists
        final todayExists = trends.any((t) => t.date == todayStr);

        if (!todayExists) {
          // Add today's data
          trends.add(AttendanceTrendData(
            courseId: courseId,
            date: todayStr,
            percentage: percentage,
            conducted: conducted,
            absent: absent,
          ));
        } else {
          // Update today's data if changed
          final todayIndex = trends.indexWhere((t) => t.date == todayStr);
          if (todayIndex != -1) {
            trends[todayIndex] = AttendanceTrendData(
              courseId: courseId,
              date: todayStr,
              percentage: percentage,
              conducted: conducted,
              absent: absent,
            );
          }
        }

        // Sort by date
        trends.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

        // Update main data
        allGraphData[courseId] = trends.map((e) => e.toJson()).toList();
      }

      // Save all data
      await prefs.setString(mainKey, json.encode(allGraphData));
    } catch (e) {
      // Silently fail
    }
  }
}

class _AttendanceTrendWidgetState extends State<AttendanceTrendWidget> {
  // --- BLUE SHADES ONLY COLOR PALETTE ---
  static const Color _skyBlue = Color(0xFF64B5F6);
  static const Color _white = Color(0xFFFFFFFF);

  List<AttendanceTrendData> _trendData = [];
  bool _hasDeclined = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateTrendData();
  }

  Future<void> _loadOrCreateTrendData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const mainKey = 'GRAPH_ATTENDANCE';
      
      // Load all graph data
      Map<String, dynamic> allGraphData = {};
      if (prefs.containsKey(mainKey)) {
        final raw = prefs.getString(mainKey);
        if (raw != null && raw.isNotEmpty) {
          allGraphData = json.decode(raw) as Map<String, dynamic>;
        }
      }

      // Get or initialize this course's data
      List<AttendanceTrendData> trends = [];
      if (allGraphData.containsKey(widget.courseId)) {
        final courseData = allGraphData[widget.courseId];
        if (courseData is List) {
          trends = courseData
              .map((item) => AttendanceTrendData.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      // Clean up old data (keep only last 5 days)
      final today = DateTime.now();
      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      trends.removeWhere((trend) {
        final trendDate = DateTime.parse(trend.date);
        return trendDate.isBefore(fiveDaysAgo);
      });

      // Check if today's data exists
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final todayExists = trends.any((t) => t.date == todayStr);

      if (!todayExists) {
        // Add today's data
        trends.add(AttendanceTrendData(
          courseId: widget.courseId,
          date: todayStr,
          percentage: widget.currentPercentage,
          conducted: widget.currentConducted,
          absent: widget.currentAbsent,
        ));
      } else {
        // Update today's data if attendance changed
        final todayIndex = trends.indexWhere((t) => t.date == todayStr);
        if (todayIndex != -1) {
          trends[todayIndex] = AttendanceTrendData(
            courseId: widget.courseId,
            date: todayStr,
            percentage: widget.currentPercentage,
            conducted: widget.currentConducted,
            absent: widget.currentAbsent,
          );
        }
      }

      // Sort by date
      trends.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

      // Detect if attendance declined (only relevant if there are 2 or more points)
      _hasDeclined = false;
      if (trends.length >= 2) {
        final currentPercentage = trends.last.percentage;
        final previousPercentage = trends[trends.length - 2].percentage;
        if (currentPercentage < previousPercentage) {
            _hasDeclined = true;
        }
      }

      // Update this course in the main graph data
      allGraphData[widget.courseId] = trends.map((e) => e.toJson()).toList();

      // Save back to prefs with clean structure
      await prefs.setString(mainKey, json.encode(allGraphData));

      setState(() {
        _trendData = trends;
      });
    } catch (e) {
      // Silently fail
    }
  }

 @override
  Widget build(BuildContext context) {
    final displayData = _trendData.length > 5 
        ? _trendData.sublist(_trendData.length - 5)
        : _trendData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER SECTION
        _buildHeader(displayData),

        const SizedBox(height: 16),

        // 2. CONDITIONAL CONTENT (The 3 Cases)
        _buildContent(displayData),
      ],
    );
  }

  Widget _buildHeader(List<AttendanceTrendData> displayData) {
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
         
          if (_hasDeclined && displayData.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color.fromARGB(226, 234, 86, 83),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'DECLINING',
                style: TextStyle(
                  color: Color.fromARGB(225, 52, 49, 49),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );  
}

  Widget _buildContent(List<AttendanceTrendData> displayData) {

    // CASE 1: No data recorded yet
    if (displayData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No attendance history available yet',
              style: TextStyle(
                color: _white.withValues(alpha:0.2),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    // CASE 2: Only one data point
    if (displayData.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _white.withValues(alpha:0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _skyBlue.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights,
                  color: _skyBlue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Initial point: ${displayData.first.percentage.toStringAsFixed(1)}% recorded on ${displayData.first.date}',
                  style: TextStyle(
                    color: _white.withValues(alpha:0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // CASE 3: 2+ points (graph remains full width)
    return _buildModernGraphSection(displayData);
  }

  Widget _buildModernGraphSection(List<AttendanceTrendData> displayData) {
    return Column(
      children: [
        SizedBox(
          height: 80,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineGraphPainter(
              data: displayData,
              lineColor: _skyBlue,
              dotColor: _white,
              targetLineColor: _white.withValues(alpha:0.1),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // X-Axis Date & % Labels
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: displayData.map((data) {
            final date = DateTime.parse(data.date);
            final dayName = DateFormat('EEE').format(date).toUpperCase();
            final isToday =
                DateFormat('yyyy-MM-dd').format(DateTime.now()) == data.date;

            return Column(
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday ? _skyBlue : _white.withValues(alpha:0.3),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday ? _white : _white.withValues(alpha:0.6),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      )
      ],
    );
  }
}

// ============================================================================
// CUSTOM PAINTER FOR LINE GRAPH
// ============================================================================
class _LineGraphPainter extends CustomPainter {
  final List<AttendanceTrendData> data;
  final Color lineColor;
  final Color dotColor;
  final Color targetLineColor;

  _LineGraphPainter({
    required this.data,
    required this.lineColor,
    required this.dotColor,
    required this.targetLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double xStep = size.width / (data.length - 1);
    final List<Offset> points = [];

    // Calculate Points
    for (int i = 0; i < data.length; i++) {
      double y = size.height - (data[i].percentage / 100 * size.height);
      points.add(Offset(i * xStep, y.clamp(5, size.height - 5)));
    }

    // 1. Draw 75% Target Line (Dashed)
    final targetY = size.height - (75 / 100 * size.height);
    final dashPaint = Paint()
      ..color = targetLineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    double dashWidth = 5, dashSpace = 5, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, targetY), Offset(startX + dashWidth, targetY), dashPaint);
      startX += dashWidth + dashSpace;
    }

    // 2. Draw Area Gradient
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      var p0 = points[i];
      var p1 = points[i + 1];
      fillPath.cubicTo(p0.dx + (p1.dx - p0.dx) / 2, p0.dy, p0.dx + (p1.dx - p0.dx) / 2, p1.dy, p1.dx, p1.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha:0.15), lineColor.withValues(alpha:0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // 3. Draw Smooth Line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      var p0 = points[i];
      var p1 = points[i + 1];
      linePath.cubicTo(p0.dx + (p1.dx - p0.dx) / 2, p0.dy, p0.dx + (p1.dx - p0.dx) / 2, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(linePath, Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // 4. Draw Data Points (Bead Style)
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      // Shadow/Glow
      canvas.drawCircle(points[i], isLast ? 6 : 4, Paint()
        ..color = lineColor.withValues(alpha:0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Point
      canvas.drawCircle(points[i], isLast ? 3.5 : 2.5, Paint()..color = isLast ? dotColor : lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}