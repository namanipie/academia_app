import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/timetable_service.dart'; // Import the service

class AttendancePredictor extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  
  const AttendancePredictor({
    super.key,
    required this.courses,
  });

  @override
  State<AttendancePredictor> createState() => _AttendancePredictorState();
}

class _AttendancePredictorState extends State<AttendancePredictor> {
  // --- UPDATED COLOR THEME: NAVY BLUE ---
  static const Color _navyBlue = Color(0xFF2C5F9E);
  static const Color _lightNavy = Color(0xFF4A7DC4);
  static const Color _skyBlue = Color(0xFF64B5F6);
  static const Color _paleBlue = Color(0xFF90CAF9);
  static const Color _pitchBlack = Color(0xFF000000);
  static const Color _white = Colors.white;
  // --------------------------------------

  final TimetableService _timetableService = TimetableService();
  // Using _enrichedCourses to hold combined data from attendance and timetable
  List<Map<String, dynamic>> _enrichedCourses = []; 
  Set<String> _optionalClassIds = {}; // Track optional classes
  
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, Map<String, dynamic>> _calendarData = {};
  List<Map<String, dynamic>> _predictions = [];
  List<int> _dayOrdersInRange = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _timetableService.loadTimetable();
    await _loadCalendarData();
    await _loadOptionalClasses();
    await _loadAndEnrichCourses();
  }

  Future<void> _loadOptionalClasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedOptionals = prefs.getStringList('optional_classes_prefs');
      if (savedOptionals != null) {
        setState(() {
          _optionalClassIds = savedOptionals.toSet();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading optional classes: $e');
    }
  }

  Future<void> _loadAndEnrichCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('userData');
      
      if (raw == null || raw.isEmpty) return;
      
      final Map<String, dynamic> data = json.decode(raw);
      
      // Get attendance courses
      final attendanceCourses = data['attendance']?['attendance']?['courses'] as Map<String, dynamic>?;
      
      // Get timetable courses (which have slots)
      final timetableCoursesRaw = data['timetable']?['courses'] as List<dynamic>?;
      
      if (attendanceCourses == null || timetableCoursesRaw == null) return;
      
      // Build enriched courses list
      List<Map<String, dynamic>> enriched = [];
      
      attendanceCourses.forEach((key, value) {
        final courseTitle = value['course_title'] ?? '';
        final category = value['category'] ?? '';
        final conducted = value['hours_conducted'] ?? 0;
        final absent = value['hours_absent'] ?? 0;
        final percentage = value['attendance_percentage'] ?? 0.0;
        
        // Find matching course in timetable by title AND category
        var timetableCourse = timetableCoursesRaw.firstWhere(
          (tc) {
            bool titleMatch = tc['course_title'] == courseTitle;
            if (!titleMatch) return false;
            
            String courseType = tc['course_type']?.toString() ?? '';
            
            if (category == 'Theory') {
              // Match Theory or any Theory-based course (Lab Based Theory, Project Based Theory)
              return courseType.contains('Theory');
            } else if (category == 'Practical') {
              // Match Practical courses
              return courseType == 'Practical';
            }
            
            return false;
          },
          orElse: () => null,
        );
        
        enriched.add({
          'title': courseTitle,
          'category': category,
          'slot': timetableCourse?['slot'] ?? '',
          'conducted': conducted,
          'absent': absent,
          'percentage': percentage,
        });
      });
      
      setState(() {
        _enrichedCourses = enriched;
      });
      
    } catch (e) {
      // Error loading and enriching courses
    }
  }

Future<void> _loadCalendarData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final calendarJson = prefs.getString('calendar_cache'); // ✅ updated key
    
    if (calendarJson != null && calendarJson.isNotEmpty) {
      final decoded = json.decode(calendarJson) as Map<String, dynamic>;

      setState(() {
        _calendarData = decoded.map((key, value) => MapEntry(
          key, 
          Map<String, dynamic>.from(value as Map),
        ));
      });

      if (kDebugMode) debugPrint('📦 Loaded calendar data from SharedPreferences');
    } else {
      if (kDebugMode) debugPrint('⚠️ No cached calendar data in SharedPreferences');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Error loading calendar data from SharedPreferences: $e');
  }
}


List<int> _getDayOrdersInRange(DateTime start, DateTime end) {
  List<int> dayOrders = [];
  
  DateTime today = DateTime.now();
  // Normalize to start of day
  today = DateTime(today.year, today.month, today.day);
  start = DateTime(start.year, start.month, start.day);
  end = DateTime(end.year, end.month, end.day);
  
  // Start calculating from tomorrow's day order if start date is in the future
  DateTime current = today;
  int dayOrderCounter = _timetableService.currentDayOrder;
  
  // ✅ If today is weekend or holiday, increment to get next working day's order
  if (current.weekday >= 6) {
    dayOrderCounter = (dayOrderCounter % 5) + 1;
  } else {
    String todayKey = '${today.day}_${today.month}_${today.year}';
    bool isTodayHoliday = _isHoliday(todayKey);
    if (isTodayHoliday) {
      dayOrderCounter = (dayOrderCounter % 5) + 1;
    }
  }
  
  // Calculate day order for start date by counting working days
  while (current.isBefore(start)) {
    // Skip weekends
    if (current.weekday >= 6) {
      current = current.add(const Duration(days: 1));
      continue;
    }
    
    // Check if it's a holiday
    String dateKey = '${current.day}_${current.month}_${current.year}';
    bool isHoliday = _isHoliday(dateKey);
    
    if (!isHoliday) {
      dayOrderCounter = (dayOrderCounter % 5) + 1;
    }
    
    current = current.add(const Duration(days: 1));
  }
  
  // Now collect day orders from start to end
  current = start;
  while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
    if (current.weekday >= 6) {
      current = current.add(const Duration(days: 1));
      continue;
    }
    
    String dateKey = '${current.day}_${current.month}_${current.year}';
    bool isHoliday = _isHoliday(dateKey);
    
    if (!isHoliday) {
      dayOrders.add(dayOrderCounter);
      dayOrderCounter = (dayOrderCounter % 5) + 1;
    }
    
    current = current.add(const Duration(days: 1));
  }
  
  return dayOrders;
}
  bool _isHoliday(String dateKey) {
    if (!_calendarData.containsKey(dateKey)) return false;
    
    final events = _calendarData[dateKey]?['event'] as List?;
    if (events == null) return false;
    
    for (var event in events) {
      if (event['type'] == 'holiday') {
        return true;
      }
    }
    return false;
  }

Map<String, int> _countClassesPerCourse(List<int> dayOrders) {
  
  // Create unique keys using course title + category + slot
  Map<String, int> courseClassCount = {};
  
  // Initialize all courses to 0 with unique keys
  for (var course in _enrichedCourses) {
    final title = course['title'] ?? '';
    final category = course['category'] ?? '';
    final slot = course['slot'] ?? '';
    if (title.isNotEmpty) {
      final key = '$title|$category|$slot';
      courseClassCount[key] = 0;
    }
  }
  
  // Count classes for each day order
  for (int dayOrder in dayOrders) {
    final dayClasses = _timetableService.getClassesForDay(dayOrder);
    
    for (var scheduledClass in dayClasses) {
      final scheduledCourse = scheduledClass['course'] ?? '';
      final scheduledSlot = scheduledClass['slot'] ?? '';
      
      // Match with user's courses by checking if course title is in the scheduled class
      
      for (var course in _enrichedCourses) {
        final title = course['title'] ?? '';
        final category = course['category'] ?? '';
        final slot = course['slot'] ?? '';
        
        if (title.isEmpty) continue;
        
        // Check if this class is marked as optional and skip if it is
        final classId = "${dayOrder}_$scheduledSlot";
        if (_optionalClassIds.contains(classId)) {
          continue; // Skip optional classes from prediction
        }
        
        final key = '$title|$category|$slot';
        final courseSlotClean = slot.replaceAll(RegExp(r'-+$'), '').trim();
        
        // 1. Match by title: scheduledCourse must contain the user's course title
        final titleMatches = scheduledCourse.contains(title);
        
        // 2. Match by slot: check if the slot from timetable matches course slot
        bool slotMatches = false;
        if (titleMatches) {
          // For multi-slot courses like P29-P30, check if scheduled slot matches any part
          if (courseSlotClean.contains('-')) {
            final parts = courseSlotClean.split('-');
            for (var p in parts) {
              if (p.trim().isNotEmpty && scheduledSlot.contains(p.trim())) {
                slotMatches = true;
                break;
              }
            }
          } else {
            // Single slot match
            slotMatches = scheduledSlot.contains(courseSlotClean);
          }
        }

        if (titleMatches && slotMatches) {
          courseClassCount[key] = (courseClassCount[key] ?? 0) + 1;
          break; // Move to the next scheduled class
        }
      }
    }
  }
  
  return courseClassCount;
}

void _calculatePredictions() {
  if (_startDate == null || _endDate == null) return;
  
  setState(() => _loading = true);
  
  // Get day orders between today and start date (classes you'll attend)
  DateTime today = DateTime.now();
  today = DateTime(today.year, today.month, today.day);
  DateTime startNormalized = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
  
  List<int> dayOrdersBetween = [];
  if (startNormalized.isAfter(today)) {
    // Only calculate if start date is in the future
    DateTime dayBeforeStart = startNormalized.subtract(const Duration(days: 1));
    dayOrdersBetween = _getDayOrdersInRange(today.add(const Duration(days: 1)), dayBeforeStart);
  }
  
  // Get day orders in the selected date range (classes you'll miss)
  final dayOrders = _getDayOrdersInRange(_startDate!, _endDate!);
  _dayOrdersInRange = dayOrders;
  
  // Count classes you'll attend (between today and start date)
  final courseClassCountBetween = _countClassesPerCourse(dayOrdersBetween);
  
  // Count classes you'll miss (in the selected range)
  final courseClassCount = _countClassesPerCourse(dayOrders);
  
  List<Map<String, dynamic>> predictions = [];
    
  for (var course in _enrichedCourses) {
      final String title = course['title'] ?? '';
      final String category = course['category'] ?? '';
      final String slot = course['slot'] ?? '';
      
      // Create unique key for this course
      final key = '$title|$category|$slot';
      
      // Get class count for classes you'll attend BEFORE leave
      final int classesToAttend = courseClassCountBetween[key] ?? 0;
      
      // Get class count for classes you'll miss DURING leave
      final int classesToMiss = courseClassCount[key] ?? 0;
      
      // Calculate INITIAL state (from stored data)
      final int initialConducted = course['conducted'] ?? 0;
      final int initialAbsent = course['absent'] ?? 0;
      final int initialPresent = initialConducted - initialAbsent;
      
      // Calculate CURRENT state (after attending classes before leave)
      final int currentConducted = initialConducted + classesToAttend;
      final int currentPresent = initialPresent + classesToAttend;
      final int currentAbsent = initialAbsent; // Absent count doesn't change until leave period
      final double currentPercentage = currentConducted > 0
          ? (currentPresent / currentConducted) * 100
          : (course['percentage'] ?? 0.0);
      
      // Predict new values (after missing classes during leave)
      final int predictedPresent = currentPresent; // No additional attendance during leave
      final int predictedConducted = currentConducted + classesToMiss;
      final int predictedAbsent = currentAbsent + classesToMiss;
    final double predictedPercentage = predictedConducted > 0
        ? (predictedPresent / predictedConducted) * 100
        : 0.0;
    
    final double percentageDrop = currentPercentage - predictedPercentage;
    
    // Create display name with category if there are duplicates
    String displayTitle = title;
    if (category.isNotEmpty && category.toLowerCase() != 'theory') {
      displayTitle = '$title ($category)';
    }
    
  predictions.add({
      'title': displayTitle,
      'currentPercentage': currentPercentage,
      'predictedPercentage': predictedPercentage,
      'percentageDrop': percentageDrop,
      'additionalClasses': classesToMiss,
      'currentConducted': currentConducted,
      'predictedConducted': predictedConducted,
      'classesToAttend': classesToAttend,
      'currentAbsent': currentAbsent,
      'currentAttended': currentPresent,
      'predictedAbsent': predictedAbsent,
      'slot': slot,
    });
  }
  
  setState(() {
    _predictions = predictions;
    _loading = false;
  });
}
  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _navyBlue, // Changed to navyBlue
              surface: _pitchBlack,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
        _predictions.clear();
        _dayOrdersInRange.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pitchBlack,
      appBar: AppBar(
        title: const Text(
          'Predict Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _white,
          ),
        ),
        backgroundColor: _pitchBlack,
        foregroundColor: _lightNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateSelector(),

            const SizedBox(height: 12), // spacing added

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: Text(
                    "Assumes today's attendance is already marked for all subjects. "
                    "Predictions are based on that assumption.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(232, 246, 170, 170),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_startDate != null && _endDate != null) ...[
              _buildCalculateButton(),
              const SizedBox(height: 20),
            ],

            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: _lightNavy),
              )
            else if (_predictions.isNotEmpty) ...[
              _buildDayOrdersCard(),
              const SizedBox(height: 20),
              _buildPredictionsList(),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildDayOrdersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lightNavy.withValues(alpha:0.1), // Changed color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightNavy.withValues(alpha:0.3), width: 1), // Changed color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week, color: _lightNavy, size: 20), // Changed color
              const SizedBox(width: 8),
              const Text(
                'Day Orders in Selected Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dayOrdersInRange.map((dayOrder) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _pitchBlack,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _lightNavy.withValues(alpha:0.5), width: 1), // Changed color
                ),
                child: Text(
                  '$dayOrder',
                  style: const TextStyle(
                    color: _skyBlue, // Changed to skyBlue for contrast
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '${_dayOrdersInRange.length} working day${_dayOrdersInRange.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: _white.withValues(alpha:0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('dd MMM yyyy');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lightNavy.withValues(alpha:0.1), // Changed color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightNavy.withValues(alpha:0.3), width: 1), // Changed color
      ),
      child: Column(
        children: [
          _buildDateButton(
            label: 'Start Date',
            date: _startDate,
            onTap: () => _selectDate(true),
            dateFormat: dateFormat,
          ),
          const SizedBox(height: 16),
          _buildDateButton(
            label: 'End Date',
            date: _endDate,
            onTap: () => _selectDate(false),
            dateFormat: dateFormat,
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required DateFormat dateFormat,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pitchBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _lightNavy.withValues(alpha:0.5), width: 1), // Changed color
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _white.withValues(alpha:0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date != null ? dateFormat.format(date) : 'Select Date',
                  style: const TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today, color: _lightNavy, size: 20), // Changed color
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return ElevatedButton(
      onPressed: _calculatePredictions,
      style: ElevatedButton.styleFrom(
        backgroundColor: _navyBlue, // Changed to navyBlue
        foregroundColor: _pitchBlack,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Calculate Predictions',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Predicted Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _white,
          ),
        ),
        const SizedBox(height: 12),
        ..._predictions.map((prediction) => _buildPredictionCard(prediction)),
      ],
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final double percentageDrop = prediction['percentageDrop'];
    // Changed drop colors to blue shades
    final Color dropColor = percentageDrop > 0 ? Colors.redAccent : _paleBlue; 
    
// GET CURRENT AND PREDICTED VALUES
final int predictedConducted = prediction['predictedConducted'] ?? 0;
final double predictedPercentage = prediction['predictedPercentage'] ?? 0.0;
final int additionalClasses = prediction['additionalClasses'] ?? 0;

// CALCULATE CURRENT ATTENDED (present)
final int currentAttended = prediction['currentAttended'] ?? 0;

// CALCULATE PREDICTED ATTENDED (same as current since no attendance during leave)
final int predictedAttended = currentAttended;

// TARGET CALCULATION FOR PREDICTED STATE
String targetText = '';
Color targetColor = _lightNavy; // Changed to lightNavy
IconData targetIcon = Icons.info_outline;

if (predictedConducted == 0) {
  targetText = 'No classes predicted';
  targetColor = Colors.grey;
  targetIcon = Icons.info_outline;
} else {
  if (predictedPercentage < 75.0) {
    // Need to attend x more classes to reach 75%
    // Formula: To reach 75% from predicted state
    // (predictedAttended + N) / (predictedConducted + N) >= 0.75
    // predictedAttended + N >= 0.75 * (predictedConducted + N)
    // predictedAttended + N >= 0.75 * predictedConducted + 0.75 * N
    // N - 0.75 * N >= 0.75 * predictedConducted - predictedAttended
    // 0.25 * N >= 0.75 * predictedConducted - predictedAttended
    // N >= (0.75 * predictedConducted - predictedAttended) / 0.25
    
    final double rawNeeded = (0.75 * predictedConducted - predictedAttended) / 0.25;
    final int need = rawNeeded <= 0 ? 0 : rawNeeded.ceil();
    
    targetIcon = Icons.trending_up;
    targetColor = Colors.redAccent; // Keep red for 'need more'
    targetText = need == 0
        ? 'Almost at 75%'
        : 'Need $need more class${need > 1 ? 'es' : ''} to reach 75%';
  } else {
    // Can miss up to m classes and remain >= 75%
    // Formula: How many more can be missed from predicted state
    // (predictedAttended) / (predictedConducted + M) >= 0.75
    // predictedAttended >= 0.75 * (predictedConducted + M)
    // predictedAttended >= 0.75 * predictedConducted + 0.75 * M
    // predictedAttended - 0.75 * predictedConducted >= 0.75 * M
    // M <= (predictedAttended - 0.75 * predictedConducted) / 0.75
    
    final double rawMargin = (predictedAttended - 0.75 * predictedConducted) / 0.75;
    final int margin = rawMargin < 0 ? 0 : rawMargin.floor();
    
    if (margin <= 0) {
      targetIcon = Icons.error_outline;
      targetColor = Colors.orangeAccent;
      targetText = 'At 75% threshold — avoid missing more';
    } else {
      targetIcon = Icons.check_circle_outline;
      targetColor = _skyBlue; // Changed to skyBlue for success/safe state
      targetText = 'Can miss $margin more class${margin > 1 ? 'es' : ''} and stay ≥75%';
    }
  }
}
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pitchBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightNavy.withValues(alpha:0.3), width: 1), // Changed color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prediction['title'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Slot: ${prediction['slot']}',
                style: TextStyle(
                  fontSize: 11,
                  color: _lightNavy.withValues(alpha:0.7), // Changed color
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 11,
                  color: _white.withValues(alpha:0.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$additionalClasses class${additionalClasses != 1 ? 'es' : ''} will be missed',
                style: TextStyle(
                  fontSize: 11,
                  color: _white.withValues(alpha:0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn(
                'Current',
                '${prediction['currentPercentage'].toStringAsFixed(1)}%',
                _white,
              ),
              Icon(Icons.arrow_forward, color: _lightNavy, size: 20), // Changed color
              _buildStatColumn(
                'Predicted',
                '${prediction['predictedPercentage'].toStringAsFixed(1)}%',
                dropColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dropColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dropColor.withValues(alpha:0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  percentageDrop > 0 ? Icons.trending_down : Icons.check_circle,
                  color: dropColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    additionalClasses == 0
                        ? 'No classes scheduled in range'
                        : percentageDrop > 0
                            ? 'Will drop by ${percentageDrop.toStringAsFixed(1)}%'
                            : 'No drop',
                    style: TextStyle(
                      color: dropColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ADD TARGET INFO CARD HERE
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: targetColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: targetColor.withValues(alpha:0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(targetIcon, color: targetColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    targetText,
                    style: TextStyle(
                      color: targetColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _white.withValues(alpha:0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}