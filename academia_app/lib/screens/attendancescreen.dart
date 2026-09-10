import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../widgets/attendance_course_card.dart';
import '../widgets/predict_bottom_sheet.dart';
import '../services/attendance_simulator_service.dart';
import '../services/timetable_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Theme Colors
  static const Color _bgBlack = Color(0xFF0A0A0A);
  static const Color _navyBlue = Color(0xFF2C5F9E);
  static const Color _darkNavy = Color(0xFF1E4271);
  static const Color _white = Color(0xFFFFFFFF);

  bool _loading = true;
  List<Map<String, dynamic>> _courses = [];
  double _overallAttendance = 0;
  int _totalConducted = 0;
  int _totalAbsent = 0;

  // Prediction State
  List<DateTime> _skippedDates = [];
  bool _isOdMlMode = false;
  
  // Simulated Values
  double? _simulatedOverallPercentage;
  int? _simulatedTotalConducted;
  int? _simulatedTotalAbsent;
  List<Map<String, dynamic>> _simulatedCourses = [];

  final AttendanceSimulatorService _simService = const AttendanceSimulatorService();

  @override
  void initState() {
    super.initState();
    _loadAttendanceFromPrefs();
  }

  Future<void> _loadAttendanceFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('userData');
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(raw);
        final overall = data['attendance']?['attendance'];
        if (overall != null) {
          setState(() {
            _overallAttendance = (overall['overall_attendance'] ?? 0).toDouble();
            _totalConducted = (overall['total_hours_conducted'] ?? 0).toInt();
            _totalAbsent = (overall['total_hours_absent'] ?? 0).toInt();

            final coursesMap = overall['courses'];
            if (coursesMap is Map) {
              _courses = coursesMap.entries.map((entry) {
                final v = entry.value;
                return {
                  'unique_id': entry.key,
                  'title': v['course_title'] ?? entry.key,
                  'category': (v['category'] ?? '').toString().split('(').first.trim(),
                  'conducted': (v['hours_conducted'] ?? 0).toInt(),
                  'absent': (v['hours_absent'] ?? 0).toInt(),
                  'percentage': (v['attendance_percentage'] ?? 0.0).toDouble(),
                };
              }).toList();
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyPrediction(List<DateTime> dates, bool isOdMl) {
    setState(() {
      _skippedDates = dates;
      _isOdMlMode = isOdMl;
      
      if (dates.isEmpty) {
        _simulatedOverallPercentage = null;
        _simulatedTotalConducted = null;
        _simulatedTotalAbsent = null;
        _simulatedCourses = [];
        return;
      }
      
      // Calculate global simulation
      final globalInput = AttendanceSimulationInput(
        conducted: _totalConducted,
        absent: _totalAbsent,
        skippedDates: _isOdMlMode ? null : _skippedDates,
        odHours: _isOdMlMode ? (_skippedDates.length * 4) : 0, // Roughly 4 hours per day for global
        resolveDayOrder: _predictDayOrder,
        getClassesForDayOrder: TimetableService().getClassesForDay,
      );
      final globalResult = _simService.simulate(globalInput);
      _simulatedOverallPercentage = globalResult.simulatedPercentage;
      _simulatedTotalConducted = globalResult.totalSimulatedConducted;
      _simulatedTotalAbsent = globalResult.totalSimulatedConducted - globalResult.totalSimulatedAttended;
      
      // Calculate for each course
      _simulatedCourses = _courses.map((course) {
        final c = Map<String, dynamic>.from(course);
        final input = AttendanceSimulationInput(
          conducted: course['conducted'],
          absent: course['absent'],
          skippedDates: _isOdMlMode ? null : _skippedDates,
          odHours: _isOdMlMode ? 4 : 0, // Simple mockup for OD per subject
          selectedCourseKey: course['unique_id'],
          resolveDayOrder: _predictDayOrder,
          getClassesForDayOrder: TimetableService().getClassesForDay,
        );
        final result = _simService.simulate(input);
        c['percentage'] = result.simulatedPercentage;
        c['conducted'] = result.totalSimulatedConducted;
        c['absent'] = result.totalSimulatedConducted - result.totalSimulatedAttended;
        return c;
      }).toList();
    });
  }

  int _predictDayOrder(DateTime date) {
    if (date.weekday == DateTime.sunday || date.weekday == DateTime.saturday) return -1;
    // VERY simple mock: just return weekday 1-5
    return date.weekday;
  }

  void _showPredictBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: PredictBottomSheet(
            initialSkippedDates: _skippedDates,
            initialIsOdMlMode: _isOdMlMode,
            onApply: _applyPrediction,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSimulating = _skippedDates.isNotEmpty;
    final displayCourses = isSimulating ? _simulatedCourses : _courses;
    
    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: AppBar(
        title: const Text(
          'Attendance', 
          style: TextStyle(fontWeight: FontWeight.w700, color: _white, letterSpacing: -0.5)
        ),
        backgroundColor: _bgBlack,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: _white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator(color: _navyBlue)) 
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildOverallCard(isSimulating),
                const SizedBox(height: 32),
                
                if (isSimulating)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isOdMlMode ? const Color(0xFF00FF9D).withValues(alpha:0.1) : const Color(0xFF61A5DD).withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isOdMlMode ? const Color(0xFF00FF9D).withValues(alpha:0.3) : const Color(0xFF61A5DD).withValues(alpha:0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(isSimulating && _isOdMlMode ? Icons.verified : Icons.auto_awesome, 
                          color: _isOdMlMode ? const Color(0xFF00FF9D) : const Color(0xFF61A5DD), size: 18),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Crystal Ball Active. Here\'s your future.', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _applyPrediction([], false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )
                      ],
                    ),
                  ),

                if (displayCourses.isNotEmpty) ...[
                  ...displayCourses.map(
                    (course) => CourseAttendanceCard(
                      course: course,
                      onTapSimulate: null,
                    ),
                  ),
                ] else 
                  _buildEmptyState(),
                const SizedBox(height: 100),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0, right: 10.0),
        child: FloatingActionButton(
          onPressed: _showPredictBottomSheet,
          backgroundColor: const Color(0xFF61A5DD),
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }




  Widget _buildOverallCard(bool isSimulating) {
    final int conducted = isSimulating ? (_simulatedTotalConducted ?? _totalConducted) : _totalConducted;
    final int absent = isSimulating ? (_simulatedTotalAbsent ?? _totalAbsent) : _totalAbsent;
    final double percentage = isSimulating ? (_simulatedOverallPercentage ?? _overallAttendance) : _overallAttendance;
    final present = conducted - absent;
    
    final Color simPrimary = _isOdMlMode ? const Color(0xFF00FF9D) : const Color(0xFF61A5DD);
    final Color simBg = _isOdMlMode ? const Color(0xFF064E3B) : const Color(0xFF1E3A8A);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isSimulating ? simPrimary.withValues(alpha:0.2) : _navyBlue.withValues(alpha:0.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSimulating ? [simBg.withValues(alpha:0.7), simBg.withValues(alpha:0.4)] : [_navyBlue.withValues(alpha:0.7), _darkNavy.withValues(alpha:0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha:0.1)),
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSimulating ? 'PREDICTED PROGRESS' : 'TOTAL PROGRESS',
                    style: TextStyle(
                      color: _white.withValues(alpha:0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        percentage.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '%',
                        style: TextStyle(
                          color: _white.withValues(alpha:0.4),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Status Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(isSimulating ? Icons.auto_awesome : Icons.how_to_reg_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Glass Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha:0.06)),
            ),
            child: Row(
              children: [
                _buildStat('$conducted', 'Conducted'),
                _buildVerticalDivider(),
                _buildStat('$present', 'Present'),
                _buildVerticalDivider(),
                _buildStat('$absent', 'Absent'),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: const TextStyle(
              color: _white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _white.withValues(alpha:0.35),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white.withValues(alpha:0.1),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off_rounded, color: _white.withValues(alpha: 0.15), size: 60),
          const SizedBox(height: 16),
          Text(
            'Attendance dropped into the void 🕳️', 
            style: TextStyle(color: _white.withValues(alpha: 0.8), fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh, or check back later.',
            style: TextStyle(color: _white.withValues(alpha: 0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }
}