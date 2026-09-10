import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:academia_app/screens/cgpa_calculator.dart';

class MarksStatsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> marks;
  final Map<String, int>? courseCredits;

  const MarksStatsWidget({
    super.key,
    required this.marks,
    this.courseCredits,
  });

  // Premium Green Palette (Deep Emerald)
  static const Color _emeraldGreen = Color(0xFF1B5E20); 
  static const Color _lightEmerald = Color(0xFF2E7D32); 
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    // 1. Core Logic remains untouched
    final stats = _calculateStats();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_emeraldGreen, _lightEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _emeraldGreen.withValues(alpha:0.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Percentage and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACADEMIC PERFORMANCE',
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
                        stats['percentage'].toStringAsFixed(1),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart_rounded, color: _white, size: 22),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Glass Stats Bar (Functionality: CGPA, Score, Grade)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha:0.06)),
            ),
            child: Row(
              children: [
                _buildStat('EST. CGPA', stats['cgpa'].toStringAsFixed(2)),
                _buildVerticalDivider(),
                _buildStat('SCORE', '${stats['obtainedMarks'].toStringAsFixed(1)}/${stats['maxMarks'].toStringAsFixed(0)}'),
                _buildVerticalDivider(),
                _buildStat('GRADE', stats['grade']),
              ],
            ),
          ),

          // Information Note (Logic from your original code)
          if (stats['totalTests'] > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color.fromARGB(255, 11, 11, 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Based on ${stats['totalTests']} test(s) across ${stats['totalCourses']} course(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color.fromARGB(255, 5, 5, 5).withValues(alpha:0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Nav Button (Functionality: Navigation to Calculator)
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact(); // Added tactile feedback
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CGPACalculator()),
                );
              },
              icon: const Icon(Icons.calculate_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Open CGPA Calculator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 195, 190, 190).withValues(alpha:0.1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha:0.1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String val) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: const TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: _white.withValues(alpha:0.35),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 18, width: 1, color: Colors.white.withValues(alpha:0.1));
  }

  // ===========================================================================
  // --- CORE LOGIC FOR STATS CALCULATION ---
  // ===========================================================================

  Map<String, dynamic> _calculateStats() {
    double totalObtained = 0;
    double totalMax = 0;
    int totalTests = 0;
    double weightedGradePoints = 0;
    double totalCredits = 0;

    for (final course in marks) {
      final tests = course['tests'] as List;
      if (tests.isEmpty) continue;

      double courseObtained = 0;
      double courseMax = 0;
      
      for (final test in tests) {
        courseObtained += (test['obtained'] as num).toDouble();
        courseMax += (test['max'] as num).toDouble();
        totalTests++;
      }

      totalObtained += courseObtained;
      totalMax += courseMax;

      if (courseMax > 0) {
        final marksCut = courseMax - courseObtained;
        final gradePoint = _marksCutToGradePoint(marksCut);
        int credits = courseCredits?[course['title']] ?? 3;
        weightedGradePoints += gradePoint * credits;
        totalCredits += credits.toDouble();
      }
    }

    final percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0.0;
    final cgpa = totalCredits > 0 ? weightedGradePoints / totalCredits : 0.0;

    return {
      'obtainedMarks': totalObtained,
      'maxMarks': totalMax,
      'percentage': percentage,
      'cgpa': cgpa,
      'grade': _percentageToGrade(percentage),
      'totalTests': totalTests,
      'totalCourses': marks.length,
    };
  }

  double _marksCutToGradePoint(double marksCut) {
    if (marksCut < 10) return 10.0;
    if (marksCut < 20) return 9.0;
    if (marksCut < 30) return 8.0;
    if (marksCut < 40) return 7.0;
    if (marksCut < 45) return 6.0;
    if (marksCut < 50) return 5.0;
    return 0.0;
  }

  String _percentageToGrade(double percentage) {
    if (percentage >= 90) return 'O';
    if (percentage >= 80) return 'A+';
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B+';
    if (percentage >= 55) return 'B';
    if (percentage >= 50) return 'C';
    return 'F';
  }
}