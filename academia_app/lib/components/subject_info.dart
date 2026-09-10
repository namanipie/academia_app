import 'package:flutter/material.dart';
import '../screens/course_summary_screen.dart';
//FOR IOS LIKE TRANSITION
import 'package:flutter/cupertino.dart'; 
import 'package:flutter/services.dart';
import '../services/theme_controller.dart';

// A reusable course card used by TimetableScreen and other places.
class SubjectInfo extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onTap;

  const SubjectInfo({super.key, required this.course, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        
        final title = (course['title'] ?? course['course_title'] ?? '').toString();
        final code = (course['code'] ?? course['course_code'] ?? '').toString();
        final credits = course['credits'] is num
            ? (course['credits'] as num).toString()
            : (course['credit'] ?? '').toString();
        final faculty = (course['faculty'] ?? course['faculty_name'] ?? '').toString();
        final room = (course['room'] ?? course['room_no'] ?? '').toString();
        final category = (course['category'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardBg, // Use theme card background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.textSecondary.withValues(alpha: 0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => CourseDetailScreen(courseCode: code),
                  ),
                );
                onTap?.call();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- TOP ROW: Title, Code, and Credits ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'course_title_$code',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                code,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.primaryAccent.withValues(alpha: 0.8), // Use theme accent
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Credits Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            '$credits Credits',
                            style: TextStyle(
                              color: theme.primaryAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    Divider(height: 1, color: theme.textSecondary.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),

                    // --- DETAIL ROWS ---
                    _buildCourseDetailRow(Icons.person_outline, 'Faculty:', faculty, theme),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        if (room.isNotEmpty)
                          Expanded(child: _buildCourseDetailRow(Icons.room_outlined, 'Room:', room, theme)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    _buildCourseDetailRow(Icons.category_outlined, 'Category:', category, theme),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildCourseDetailRow(IconData icon, String label, String value, ThemeController theme) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.primaryAccent),
        const SizedBox(width: 8),
        Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary, 
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value.trim(),
            style: TextStyle(
              fontSize: 13,
              color: theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}