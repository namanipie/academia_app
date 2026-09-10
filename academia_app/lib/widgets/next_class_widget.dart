import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/theme_controller.dart';
import '../services/timetable_service.dart';
import '../screens/timetablescreen.dart';

class NextClassInfo {
  final Map<String, String> classData;
  final DateTime startTime;
  final DateTime endTime;
  final bool isOngoing;

  NextClassInfo(this.classData, this.startTime, this.endTime, this.isOngoing);
}

class NextClassWidget extends StatefulWidget {
  const NextClassWidget({super.key});

  @override
  State<NextClassWidget> createState() => _NextClassWidgetState();
}

class _NextClassWidgetState extends State<NextClassWidget> {
  Timer? _timer;
  NextClassInfo? _currentOrNextClass;
  bool _isFreeDay = false;

  @override
  void initState() {
    super.initState();
    _initAndRefresh();
    // Update every minute to recalculate time remaining / progress
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _refreshClassStatus();
      }
    });
  }

  Future<void> _initAndRefresh() async {
    final tService = TimetableService();
    if (tService.courses.isEmpty) {
      await tService.loadTimetable();
    }
    if (mounted) {
      _refreshClassStatus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshClassStatus() {
    final tService = TimetableService();
    // Check if there are any classes for the current day order
    final classes = tService.getCurrentDayClasses();

    if (classes.isEmpty) {
      setState(() {
        _currentOrNextClass = null;
        _isFreeDay = true;
      });
      return;
    }

    final now = DateTime.now();
    NextClassInfo? nextClass;

    for (var c in classes) {
      final timeStr = c['time']; // e.g., "08:00 - 08:50"
      if (timeStr == null) continue;

      final parts = timeStr.split('-');
      if (parts.length != 2) continue;

      final start = _parseTime(parts[0].trim());
      final end = _parseTime(parts[1].trim());

      if (now.isAfter(start) && now.isBefore(end)) {
        // Class is currently ongoing
        setState(() {
          _currentOrNextClass = NextClassInfo(c, start, end, true);
          _isFreeDay = false;
        });
        return; // Prioritize ongoing class
      } else if (now.isBefore(start)) {
        // Upcoming class
        if (nextClass == null || start.isBefore(nextClass.startTime)) {
          nextClass = NextClassInfo(c, start, end, false);
        }
      }
    }

    setState(() {
      _currentOrNextClass = nextClass;
      _isFreeDay = false;
    });
  }

  DateTime _parseTime(String timeStr) {
    // Expected format: "08:00" or "12:30" or "01:25"
    final parts = timeStr.split(':');
    if (parts.length != 2) return DateTime.now();

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;

    // Convert SRM 12-hour (no AM/PM) format to 24-hour
    // Usually classes are from 8 AM to 6 PM.
    // So 01 to 07 are definitely PM (13 to 19).
    // 08 to 11 are AM. 12 is PM.
    if (hour >= 1 && hour <= 7) {
      hour += 12;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatTimeRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return "Now";

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours > 0) {
      return "In ${hours}h ${minutes}m";
    }
    return "In ${minutes}m";
  }

  double _calculateProgress(DateTime start, DateTime end) {
    final now = DateTime.now();
    final total = end.difference(start).inMinutes;
    final elapsed = now.difference(start).inMinutes;
    if (total == 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  void _openTimetable() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const TimetableScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;

        // Determine what to show
        if (_isFreeDay) {
          return _buildEmptyState(
            theme,
            Icons.celebration_rounded,
            "No Classes Today",
            "Enjoy your day off!",
          );
        }

        if (_currentOrNextClass == null) {
          return _buildEmptyState(
            theme,
            Icons.done_all_rounded,
            "Day Complete",
            "All classes finished for today.",
          );
        }

        final info = _currentOrNextClass!;
        final courseTitle = info.classData['course'] ?? 'Unknown Course';
        final room = info.classData['classroom'] ?? 'TBA';
        final slot = info.classData['slot'] ?? 'N/A';
        final timeStr = info.classData['time'] ?? 'N/A';

        // Extract just the course name without the code prefix if possible
        // Expected "21CSC204J — Design and Analysis of Algorithms"
        String displayTitle = courseTitle;
        if (courseTitle.contains('—')) {
          displayTitle = courseTitle.split('—').last.trim();
        } else if (courseTitle.contains('-')) {
          displayTitle = courseTitle.split('-').last.trim();
        }

        return GestureDetector(
          onTap: _openTimetable,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
              boxShadow: info.isOngoing
                  ? [
                      BoxShadow(
                        color: theme.primaryAccent.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: -5,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Progress bar background if ongoing
                  if (info.isOngoing)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 4,
                      child: Container(
                        color: theme.surfaceBg,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _calculateProgress(
                            info.startTime,
                            info.endTime,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.primaryAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: info.isOngoing
                                    ? theme.primaryAccent.withValues(
                                        alpha: 0.15,
                                      )
                                    : theme.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: info.isOngoing
                                      ? theme.primaryAccent.withValues(
                                          alpha: 0.3,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (info.isOngoing) ...[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: theme.primaryAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    info.isOngoing
                                        ? "ONGOING NOW"
                                        : "NEXT CLASS",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: info.isOngoing
                                          ? theme.primaryAccent
                                          : theme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (!info.isOngoing)
                              Text(
                                _formatTimeRemaining(info.startTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryAccent,
                                ),
                              )
                            else
                              Text(
                                "Ends ${info.classData['time']?.split('-').last.trim() ?? ''}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Main Course Info
                        Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 16),

                        // Footer row
                        Row(
                          children: [
                            _buildInfoBadge(theme, Icons.room_outlined, room),
                            const SizedBox(width: 12),
                            _buildInfoBadge(
                              theme,
                              Icons.schedule_outlined,
                              timeStr,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBadge(ThemeController theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    ThemeController theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return GestureDetector(
      onTap: _openTimetable,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surfaceBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.textSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}
