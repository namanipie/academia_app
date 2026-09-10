import 'package:flutter/material.dart';

class StatsBar extends StatelessWidget {
  final double overallAttendance;
  final int courseCount;
  final int totalCredits;
  final Color primaryColor;

  const StatsBar({
    super.key,
    required this.overallAttendance,
    required this.courseCount,
    required this.totalCredits,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final attendance = overallAttendance;
    final courses = courseCount > 0 ? courseCount.toString() : '—';
    final credits = totalCredits > 0 ? totalCredits.toString() : '—';

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _buildStatItem(attendance.toStringAsFixed(1), 'Attendance', Colors.greenAccent[400]!),
              _buildDivider(),
              _buildStatItem(courses, 'Courses', Colors.cyanAccent[400]!),
              _buildDivider(),
              _buildStatItem(credits, 'Credits', primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha:0.4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return VerticalDivider(
      color: Colors.white.withValues(alpha:0.1),
      thickness: 1,
      indent: 5,
      endIndent: 5,
    );
  }
}