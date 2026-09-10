import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/grade_calc.dart';// Import the grade calculator

class CGPACalculator extends StatefulWidget {
  const CGPACalculator({super.key});

  @override
  State<CGPACalculator> createState() => _CGPACalculatorState();
}

class _CGPACalculatorState extends State<CGPACalculator> {
  List<CourseGrade> courses = [];
  double cgpa = 0.0;
  bool isLoading = true;
  bool showGradeCalculator = false; // Toggle state

  // Grade to grade point mapping
  final Map<String, double> gradePoints = {
    'O': 10.0,
    'A+': 9.0,
    'A': 8.0,
    'B+': 7.0,
    'B': 6.0,
    'C': 5.5,
    'Fail/Det/Abs': 0.0,
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
        
        if (userData['timetable'] != null && userData['timetable']['courses'] != null) {
          final coursesData = userData['timetable']['courses'] as List;
          
          setState(() {
            courses = coursesData
                .where((course) => (course['credit'] ?? 0) > 0)
                .map((course) => CourseGrade(
                      title: course['course_title'] ?? 'Unknown Course',
                      credit: course['credit'] ?? 3,
                      grade: 'O', // Default grade to O
                    ))
                .toList();
            isLoading = false;
            _calculateCGPA(); // Calculate CGPA with default grades
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
      courses.add(CourseGrade(title: '', credit: 3, grade: 'O'));
      _calculateCGPA();
    });
  }

  void _removeCourse(int index) {
    setState(() {
      courses.removeAt(index);
      _calculateCGPA();
    });
  }

  void _calculateCGPA() {
    double totalPoints = 0;
    int totalCredits = 0;

    for (var course in courses) {
      if (course.grade != null && course.credit > 0) {
        totalPoints += gradePoints[course.grade]! * course.credit;
        totalCredits += course.credit;
      }
    }

    setState(() {
      cgpa = totalCredits > 0 ? totalPoints / totalCredits : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          showGradeCalculator ? 'Grade Calculator' : 'CGPA Calculator',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        titleSpacing: 0,
        actions: [
          // Toggle Button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _ToggleButton(
                  label: 'CGPA',
                  isSelected: !showGradeCalculator,
                  onTap: () {
                    setState(() {
                      showGradeCalculator = false;
                    });
                  },
                ),
                _ToggleButton(
                  label: 'Grade',
                  isSelected: showGradeCalculator,
                  onTap: () {
                    setState(() {
                      showGradeCalculator = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: showGradeCalculator
          ? const GradeCalculator()
          : isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : Column(
                  children: [
                    // CGPA Display
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 0, 0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your CGPA',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cgpa.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
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
                                    Icons.school_outlined,
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
                                    'Add courses to calculate CGPA',
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
                                return _CourseCard(
                                  course: courses[index],
                                  index: index,
                                  gradePoints: gradePoints,
                                  onGradeChanged: (grade) {
                                    setState(() {
                                      courses[index].grade = grade;
                                      _calculateCGPA();
                                    });
                                  },
                                  onCreditChanged: (credit) {
                                    setState(() {
                                      courses[index].credit = credit;
                                      _calculateCGPA();
                                    });
                                  },
                                  onTitleChanged: (title) {
                                    setState(() {
                                      courses[index].title = title;
                                    });
                                  },
                                  onDelete: () => _removeCourse(index),
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
                ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class CourseGrade {
  String title;
  int credit;
  String? grade;

  CourseGrade({
    required this.title,
    required this.credit,
    this.grade,
  });
}

class _CourseCard extends StatelessWidget {
  final CourseGrade course;
  final int index;
  final Map<String, double> gradePoints;
  final Function(String?) onGradeChanged;
  final Function(int) onCreditChanged;
  final Function(String) onTitleChanged;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.course,
    required this.index,
    required this.gradePoints,
    required this.onGradeChanged,
    required this.onCreditChanged,
    required this.onTitleChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.title.isEmpty ? 'Course ${index + 1}' : course.title,
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
          const SizedBox(height: 12),
          Row(
            children: [
              // Credit Input
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credits',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextFormField(
                        initialValue: course.credit.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          final credit = int.tryParse(value);
                          if (credit != null && credit > 0) {
                            onCreditChanged(credit);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Grade Dropdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grade',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: course.grade,
                          hint: Text(
                            'Select',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          isExpanded: true,
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          items: gradePoints.keys.map((String grade) {
                            return DropdownMenuItem<String>(
                              value: grade,
                              child: Text(grade),
                            );
                          }).toList(),
                          onChanged: onGradeChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}