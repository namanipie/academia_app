import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/attendance_trend_widget.dart'; // Ensure this path is correct

class CourseAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onTapSimulate;

  const CourseAttendanceCard({
    super.key,
    required this.course,
    this.onTapSimulate,
  });

  // --- REFINED THEME PALETTE ---
  static const Color _surface = Color.fromARGB(150, 20, 20, 24);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _skyBlue = Color(0xFF64B5F6);
  static const Color _warningAmber = Color.fromARGB(255, 255, 250, 242);
  static const Color _errorRed = Color.fromARGB(255, 251, 137, 135);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF9BA1A6);

  @override
  Widget build(BuildContext context) {
    // --- DATA CALCULATIONS ---
    final percentage = (course['percentage'] is num)
        ? (course['percentage'] as num).toDouble()
        : 0.0;

    final int conducted = course['conducted'] is num ? (course['conducted'] as num).toInt() : 0;
    final int absent = course['absent'] is num ? (course['absent'] as num).toInt() : 0;
    final int attended = (conducted - absent).clamp(0, conducted);

    // --- DYNAMIC LOGIC FOR STATUS & COLORS ---
    String targetText = '';
    Color statusColor = _accentBlue;
    IconData statusIcon = Icons.info_outline;
    
    if (conducted == 0) {
      targetText = 'No classes conducted yet';
      statusColor = _textSecondary;
      statusIcon = Icons.info_outline;
    } else {
      if (percentage < 75.0) {
        final need = ((0.75 * conducted - attended) / 0.25).ceil().clamp(0, 999);
        targetText = 'Attend $need more to reach 75%';
        statusColor = _errorRed; 
        statusIcon = Icons.error_outline_rounded;
      } else {
        final margin = ((attended / 0.75) - conducted).floor().clamp(0, 999);
        targetText = margin <= 0 ? 'No Margin' : 'Can miss $margin safely';
        statusColor = margin <= 0 ? _warningAmber : _accentBlue; 
        statusIcon = margin <= 0 ? Icons.warning_amber_rounded : Icons.info_outline;
      }
    }

return Container(
  margin: const EdgeInsets.only(bottom: 20),
  decoration: BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: _white.withValues(alpha:0.08), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha:0.2),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Padded content
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. MODERN HEADER
            _buildHeader(percentage, statusColor),

            const SizedBox(height: 24),

            // 2. PROGRESS BAR
            _buildProgressBar(percentage, statusColor),

            const SizedBox(height: 24),

            // 3. STATS ROW
            _buildStatsRow(attended, absent, conducted),

            const SizedBox(height: 20),

            // 4. INSIGHT BANNER
            _buildInsightBanner(statusColor, statusIcon, targetText),
          ],
        ),
      ),

      const SizedBox(height: 4),

      // Graph WITHOUT padding (edge-to-edge inside card)
      AttendanceTrendWidget(
        courseId: course['unique_id'],
        courseTitle: course['title'],
        currentPercentage: percentage,
        currentConducted: conducted,
        currentAbsent: absent,
      ),

      const SizedBox(height: 20), // bottom spacing inside card
    ],
  ),
);
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(double percentage, Color statusColor) {
    return Row(
      children: [
        // The Vertical Accent Bar
        Container(
          width: 4,
          height: 42,
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
              course['title']?.toString() ?? 'Unknown Course',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
              const SizedBox(height: 2),
              Text(
                (course['category']?.toString() ?? '').toUpperCase(),
                style: TextStyle(
                  color: _white.withValues(alpha:0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        // Modern Typographic Percentage
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.9),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ],
    );
  }

  // --- PROGRESS BAR WIDGET ---
  Widget _buildProgressBar(double percentage, Color statusColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 10,
        width: double.infinity,
        color: _white.withValues(alpha:0.05),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (percentage / 100).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor.withAlpha(255), statusColor.withValues(alpha:0.7)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- STATS ROW WIDGET ---
  Widget _buildStatsRow(int attended, int absent, int conducted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem('Present', attended.toString(), _skyBlue),
        _buildStatItem('Absent', absent.toString(), _errorRed.withValues(alpha:0.8)),
        _buildStatItem('Total', conducted.toString(), _textSecondary),
      ],
    );
  }

  // --- INDIVIDUAL STAT ITEM ---
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _textSecondary.withValues(alpha:0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- INSIGHT BANNER WIDGET ---
  Widget _buildInsightBanner(Color color, IconData icon, String text) {
    final content = Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onTapSimulate != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SIMULATE',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color),
              ],
            ),
          ),
        ],
      ],
    );

    if (onTapSimulate != null) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha:0.15)),
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapSimulate!();
            },
            borderRadius: BorderRadius.circular(16),
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.15)),
      ),
      child: content,
    );
  }
}