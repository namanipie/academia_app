import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GradeCalculator extends StatefulWidget {
  const GradeCalculator({super.key});

  @override
  State<GradeCalculator> createState() => _GradeCalculatorState();
}

class _GradeCalculatorState extends State<GradeCalculator> {
  List<CourseMarks> courses = [];
  bool isLoading = true;

  // Grade thresholds (out of 100)
  final Map<String, int> gradeThresholds = {
    'O': 91,
    'A+': 81,
    'A': 71,
    'B+': 61,
    'B': 56,
    'C': 50,
  };

  @override
  void initState() {
    super.initState();
    _loadCoursesFromStorage();
  }

  Future<void> _loadCoursesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('userData');

      if (userDataString != null && userDataString.isNotEmpty) {
        final userData = json.decode(userDataString);

        if (userData['attendance'] != null &&
            userData['attendance']['marks'] != null &&
            userData['timetable'] != null &&
            userData['timetable']['courses'] != null) {
          
          final marksData = userData['attendance']['marks'] as Map<String, dynamic>;
          final coursesData = userData['timetable']['courses'] as List;

          // Create a map for quick course lookup
          Map<String, dynamic> courseMap = {};
          for (var course in coursesData) {
            String courseCode = course['course_code'] ?? '';
            courseMap[courseCode] = course;
          }

          List<CourseMarks> loadedCourses = [];

          marksData.forEach((key, value) {
            // Extract course code (remove Theory/Practical suffix)
            String courseCode = key.replaceAll(RegExp(r'(Theory|Practical)$'), '');
            
            // Get course details
            var courseDetails = courseMap[courseCode];
            if (courseDetails == null) return;

            String courseTitle = courseDetails['course_title'] ?? 'Unknown Course';
            String courseType = value['course_type'] ?? '';

            // Only process Theory courses
            if (courseType != 'Theory') return;

            // Calculate internal marks
            double internalMarks = 0;
            if (value['tests'] != null) {
              List tests = value['tests'] as List;
              for (var test in tests) {
                internalMarks += (test['obtained_marks'] ?? 0).toDouble();
              }
            }

            // Only include courses where internal marks are <= 60
            if (internalMarks <= 60) {
              loadedCourses.add(CourseMarks(
                title: courseTitle,
                courseCode: key,
                internalMarks: internalMarks,
                targetGrade: 'O',
              ));
            }
          });

          setState(() {
            courses = loadedCourses;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading courses: $e');
      setState(() {
        courses = [];
        isLoading = false;
      });
    }
  }

  void _addCourse() {
    setState(() {
      courses.add(CourseMarks(
        title: 'New Course',
        courseCode: '',
        internalMarks: 0,
        targetGrade: 'O',
      ));
    });
  }

  void _removeCourse(int index) {
    setState(() {
      courses.removeAt(index);
    });
  }

  double _calculateRequiredMarks(double internalMarks, String targetGrade) {
    // Internal: 60 marks (60% weightage)
    // External: 75 marks (40% weightage)
    // Total = (Internal * 0.6) + (External/75 * 40)
    
    int threshold = gradeThresholds[targetGrade] ?? 90;
    double requiredTotal = threshold.toDouble();
    
    // Internal contribution to total (max 60)
    double internalContribution = internalMarks;
    
    // Required from external
    // requiredTotal = internalContribution + (externalMarks/75 * 40)
    // externalMarks/75 * 40 = requiredTotal - internalContribution
    // externalMarks = (requiredTotal - internalContribution) * 75/40
    
    double requiredExternal = (requiredTotal - internalContribution) * (75.0 / 40.0);
    
    return requiredExternal.clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          )
        : Column(
            children: [
              // Info Card
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Internal: 60 marks (60%) | Final: 75 marks (40%)',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Courses List
              Expanded(
                child: courses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calculate_outlined,
                              size: 64,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No courses found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add courses to calculate required marks',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          return _CourseMarksCard(
                            course: courses[index],
                            index: index,
                            gradeThresholds: gradeThresholds,
                            onInternalMarksChanged: (marks) {
                              setState(() {
                                courses[index].internalMarks = marks;
                              });
                            },
                            onTargetGradeChanged: (grade) {
                              setState(() {
                                courses[index].targetGrade = grade;
                              });
                            },
                            onTitleChanged: (title) {
                              setState(() {
                                courses[index].title = title;
                              });
                            },
                            onDelete: () => _removeCourse(index),
                            calculateRequiredMarks: _calculateRequiredMarks,
                          );
                        },
                      ),
              ),

              // Add Course Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addCourse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Add Course',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class CourseMarks {
  String title;
  String courseCode;
  double internalMarks;
  String targetGrade;

  CourseMarks({
    required this.title,
    required this.courseCode,
    required this.internalMarks,
    required this.targetGrade,
  });
}

class _CourseMarksCard extends StatelessWidget {
  final CourseMarks course;
  final int index;
  final Map<String, int> gradeThresholds;
  final Function(double) onInternalMarksChanged;
  final Function(String) onTargetGradeChanged;
  final Function(String) onTitleChanged;
  final VoidCallback onDelete;
  final Function(double, String) calculateRequiredMarks;

  const _CourseMarksCard({
    required this.course,
    required this.index,
    required this.gradeThresholds,
    required this.onInternalMarksChanged,
    required this.onTargetGradeChanged,
    required this.onTitleChanged,
    required this.onDelete,
    required this.calculateRequiredMarks,
  });

  @override
  Widget build(BuildContext context) {
    double requiredMarks = calculateRequiredMarks(course.internalMarks, course.targetGrade);
    bool isAchievable = requiredMarks <= 75;
    
    // Calculate current total percentage
    double currentTotal = course.internalMarks + (0 * 40 / 75); // With 0 in finals
    double maxPossibleTotal = course.internalMarks + 40; // With 75/75 in finals

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.grey[600],
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Internal Marks Input
          Text(
            'Internal Marks (out of 60)',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextFormField(
              initialValue: course.internalMarks.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
                onChanged: (value) {
                  final marks = double.tryParse(value);
                  if (marks != null) {
                    if (marks > 60) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Internal marks cannot exceed 60'),
                          backgroundColor: Colors.red[700],
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    if (marks >= 0 && marks <= 60) {
                      onInternalMarksChanged(marks);
                    }
                  }
                },
            ),
          ),
          const SizedBox(height: 16),

          // Target Grade Slider
          Text(
            'Target Grade: ${course.targetGrade}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color.fromARGB(255, 222, 228, 232),
              inactiveTrackColor: Colors.grey[800],
              thumbColor: const Color.fromARGB(255, 102, 106, 109),
              overlayColor: Colors.blue.withValues(alpha:0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: gradeThresholds.keys.toList().indexOf(course.targetGrade).toDouble(),
              min: 0,
              max: (gradeThresholds.length - 1).toDouble(),
              divisions: gradeThresholds.length - 1,
              onChanged: (value) {
                String grade = gradeThresholds.keys.toList()[value.toInt()];
                onTargetGradeChanged(grade);
              },
            ),
          ),
          
          // Grade Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: gradeThresholds.keys.map((grade) {
              return Text(
                grade,
                style: TextStyle(
                  color: course.targetGrade == grade ? const Color.fromARGB(255, 255, 255, 255) : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: course.targetGrade == grade ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Result Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAchievable ? Colors.green.withValues(alpha:0.1) : Colors.orange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAchievable ? Colors.green.withValues(alpha:0.3) : Colors.orange.withValues(alpha:0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAchievable ? Icons.check_circle_outline : Icons.warning_outlined,
                      color: isAchievable ? Colors.green[400] : Colors.orange[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAchievable
                                ? 'Required in Final Exam:'
                                : 'Mathematically Impossible',
                            style: TextStyle(
                              color: isAchievable ? Colors.green[400] : Colors.orange[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isAchievable) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${requiredMarks.toStringAsFixed(2)} / 75 marks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'Only relative grading can save you',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isAchievable) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Total:',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              currentTotal.toStringAsFixed(2),
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Marks Needed:',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${(requiredMarks - 75).toStringAsFixed(2)} marks over 75',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}