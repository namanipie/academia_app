import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';

// --- PREMIUM DESIGN CONSTANTS ---
const Color kPitchBlack = Color(0xFF000000);
const Color kCardBlack = Color(0xFF111111);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kSurfaceGrey = Color(0xFF1E1E1E);
const Color kMutedText = Colors.white54;

// Key constants for your SharedPreferences
const String USER_DATA_KEY = 'userData';
const String GRAPH_DATA_KEY = 'GRAPH_ATTENDANCE';

// =================================================================
// 1. DATA MODELS
// =================================================================

class CourseAttendanceData {
  final String courseTitle, facultyName;
  final double attendancePercentage;
  final int hoursConducted, hoursAbsent;

  CourseAttendanceData({
    required this.courseTitle,
    required this.facultyName,
    required this.attendancePercentage,
    required this.hoursConducted,
    required this.hoursAbsent,
  });
}

class TestMarks {
  final String testName;
  final double obtainedMarks, maxMarks, percentage;
  TestMarks({
    required this.testName,
    required this.obtainedMarks,
    required this.maxMarks,
    required this.percentage,
  });
}

class GraphDataPoint {
  final String date;
  final double percentage;
  GraphDataPoint({required this.date, required this.percentage});
}

// =================================================================
// 2. DATA SERVICE (Logic directly from your implementation)
// =================================================================

class CourseDataService {
  late SharedPreferences _prefs;
  late Map<String, dynamic> _userData;
  late Map<String, dynamic> _graphAttendance;

  static final CourseDataService _instance = CourseDataService._internal();
  factory CourseDataService() => _instance;
  CourseDataService._internal();

  Future<void> loadData() async {
    _prefs = await SharedPreferences.getInstance();
    String? userDataString = _prefs.getString(USER_DATA_KEY);
    String? graphDataString = _prefs.getString(GRAPH_DATA_KEY);

    try {
      _userData = (userDataString != null) ? json.decode(userDataString) : {};
    } catch (e) {
      _userData = {};
    }

    try {
      _graphAttendance = (graphDataString != null) ? json.decode(graphDataString) : {};
    } catch (e) {
      _graphAttendance = {};
    }
  }

  String _getCourseKey(String courseCode, Map<String, dynamic> dataMap) {
    try {
      return dataMap.keys.firstWhere((key) => key.startsWith(courseCode), orElse: () => '');
    } catch (e) {
      return '';
    }
  }

  CourseAttendanceData? getCourseAttendance(String courseCode) {
    try {
      final attendanceMap = _userData['attendance']?['attendance']?['courses'] as Map<String, dynamic>?;
      if (attendanceMap == null) return null;
      final key = _getCourseKey(courseCode, attendanceMap);
      if (key.isEmpty) return null;
      final data = attendanceMap[key];
      if (data == null) return null;

      return CourseAttendanceData(
        courseTitle: (data['course_title'] ?? 'Unknown Course').toString(),
        facultyName: (data['faculty_name'] ?? 'N/A').toString(),
        attendancePercentage: ((data['attendance_percentage'] ?? 0) as num).toDouble(),
        hoursConducted: ((data['hours_conducted'] ?? 0) as num).toInt(),
        hoursAbsent: ((data['hours_absent'] ?? 0) as num).toInt(),
      );
    } catch (e) {
      return null;
    }
  }

  List<TestMarks> getCourseMarks(String courseCode) {
    try {
      final marksMap = _userData['attendance']?['marks'] as Map<String, dynamic>?;
      if (marksMap == null) return [];
      final relatedKeys = marksMap.keys.where((k) => k.startsWith(courseCode)).toList();
      List<TestMarks> allMarks = [];
      for (var k in relatedKeys) {
        final data = marksMap[k];
        if (data != null && data['tests'] != null && data['tests'] is List) {
          for (var test in data['tests']) {
            allMarks.add(TestMarks(
              testName: (test['test_name'] ?? 'Unknown Test').toString(),
              obtainedMarks: ((test['obtained_marks'] ?? 0) as num).toDouble(),
              maxMarks: ((test['max_marks'] ?? 100) as num).toDouble(),
              percentage: ((test['percentage'] ?? 0) as num).toDouble(),
            ));
          }
        }
      }
      return allMarks;
    } catch (e) {
      return [];
    }
  }

  List<GraphDataPoint> getCourseGraphData(String courseCode) {
    try {
      final attendanceMap = _userData['attendance']?['attendance']?['courses'] as Map<String, dynamic>?;
      if (attendanceMap == null) return [];
      final key = _getCourseKey(courseCode, attendanceMap);
      if (key.isEmpty || !_graphAttendance.containsKey(key)) return [];
      final singleDataList = _graphAttendance[key] as List;
      
      return singleDataList.map<GraphDataPoint>((item) {
        String dateStr = (item['date'] ?? '00-00').toString();
        String formattedDate = dateStr.length >= 7 ? dateStr.substring(5) : dateStr;
        return GraphDataPoint(
          date: formattedDate,
          percentage: ((item['percentage'] ?? 0) as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

// =================================================================
// 3. COURSE DETAIL SCREEN (REDESIGN + INTEGRATION)
// =================================================================

class CourseDetailScreen extends StatelessWidget {
  final String courseCode;
  const CourseDetailScreen({super.key, required this.courseCode});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: CourseDataService().loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kPitchBlack,
            body: Center(child: CircularProgressIndicator(color: kAccentOrange)),
          );
        }

        final dataService = CourseDataService();
        final attendance = dataService.getCourseAttendance(courseCode);
        final marks = dataService.getCourseMarks(courseCode);
        final graphData = dataService.getCourseGraphData(courseCode);

        // Fallback for safety
        final courseData = attendance ?? CourseAttendanceData(
          courseTitle: 'Course: $courseCode',
          facultyName: 'Data Not Available',
          attendancePercentage: 0.0,
          hoursConducted: 0,
          hoursAbsent: 0,
        );

        return Scaffold(
          backgroundColor: kPitchBlack,
          appBar: AppBar(
            backgroundColor: kPitchBlack,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(courseData.courseTitle, courseCode),
                const SizedBox(height: 30),
                
                // Info Section
                Row(
                  children: [
                    Expanded(child: _buildMetricTile("Faculty", courseData.facultyName.split('(').first, Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTile("Type", courseData.courseTitle.contains('Practical') ? 'Practical' : 'Theory', Icons.layers_outlined)),
                  ],
                ),
                const SizedBox(height: 32),

                // Attendance Section
                _buildSectionTitle("Attendance Overview"),
                _buildAttendanceCard(courseData),
                const SizedBox(height: 32),

                // Graph Section
                _buildSectionTitle("Attendance Trend"),
                _buildTrendCard(graphData),
                const SizedBox(height: 32),

                // Marks Section
                _buildSectionTitle("Assessment Marks"),
                if (marks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No assessments found.", style: TextStyle(color: kMutedText, fontStyle: FontStyle.italic)),
                  ),
                ...marks.map((m) => _buildMarkEntry(m)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildHeader(String title, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kAccentOrange.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kAccentOrange.withValues(alpha:0.2)),
          ),
          child: Text(code, style: const TextStyle(color: kAccentOrange, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBlack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccentOrange, size: 20),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: kMutedText, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAttendanceCard(CourseAttendanceData data) {
    final isLow = data.attendancePercentage < 75;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 85, height: 85,
                child: CircularProgressIndicator(
                  value: data.attendancePercentage / 100,
                  strokeWidth: 9,
                  backgroundColor: kSurfaceGrey,
                  color: isLow ? Colors.redAccent : kAccentOrange,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text("${data.attendancePercentage.toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildCompactRow("Conducted", "${data.hoursConducted} Hours"),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _buildCompactRow("Absent", "${data.hoursAbsent} Hours"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrendCard(List<GraphDataPoint> graphData) {
    if (graphData.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kCardBlack, borderRadius: BorderRadius.circular(24)),
        child: const Text("No trend data available", style: TextStyle(color: kMutedText)),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kCardBlack, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: graphData.take(5).map((point) {
          final barHeight = (point.percentage / 100) * 110;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("${point.percentage.toInt()}%", style: const TextStyle(color: kAccentOrange, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: 28, height: max(barHeight, 5.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccentOrange, kAccentOrange.withValues(alpha:0.3)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(point.date, style: const TextStyle(color: kMutedText, fontSize: 10)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarkEntry(TestMarks marks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBlack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kSurfaceGrey, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.analytics_outlined, color: kAccentOrange, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marks.testName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text("Score: ${marks.obtainedMarks}/${marks.maxMarks}", style: const TextStyle(color: kMutedText, fontSize: 11)),
              ],
            ),
          ),
          Text("${marks.percentage.toInt()}%", style: const TextStyle(color: kAccentOrange, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildCompactRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMutedText, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}