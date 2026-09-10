// File: timetable_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/timetable_service.dart';
import '../widgets/day_order_card.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/timetable_export_widget.dart';
import '../services/export_service.dart';

// ============================================================================
// TIMETABLE SCREEN - Fixed Initialization while maintaining all features
// ============================================================================
class TimetableScreen extends StatefulWidget {
  final int? view_dayorder;

  const TimetableScreen({super.key, this.view_dayorder});
  
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  // --- COLOR PALETTE (PRESERVED) ---
  static const Color _pitchBlack = Color(0xFF000000);
  static const Color _neonPink = Color.fromARGB(255, 199, 8, 110);
  static const Color _white = Colors.white;
  static const Color _holidayGold = Color.fromARGB(255, 223, 223, 219);
  static const Color _holidayOrange = Color.fromARGB(255, 169, 164, 162);

  bool _loading = true;
  late PageController _pageController; // Now initialized in initState
  final TimetableService _timetableService = TimetableService();
  
  // Holiday state (PRESERVED)
  bool _isTodayHoliday = false;
  String _holidayName = '';
  int _activePageIndex = 0;

  final GlobalKey _exportKey = GlobalKey();
  String _program = '';
  String _semester = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadTimetable();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final dataString = prefs.getString('userData');
    if (dataString != null && dataString.isNotEmpty) {
      try {
        final parsedData = json.decode(dataString);
        final att = parsedData['attendance'];
        final tt = parsedData['timetable'];

        Map<String, dynamic>? studentInfo;
        if (att != null && att is Map && att['student_info'] != null) {
          studentInfo = att['student_info'];
        } else if (tt != null && tt is Map && tt['student_info'] != null) {
          studentInfo = tt['student_info'];
        }

        if (studentInfo != null) {
          final program = studentInfo['program']?.toString() ?? '';
          final semester = studentInfo['semester']?.toString() ?? '';
          if (mounted) {
            setState(() {
              _program = program;
              _semester = semester;
            });
          }
        }
      } catch (_) {}
    }
  }

  void _exportTimetable() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating timetable image...', style: TextStyle(color: Colors.white)), duration: Duration(seconds: 1)),
    );
    await ExportService.exportAndShare(_exportKey, context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final success = await _timetableService.loadTimetable();
    
    if (success && _timetableService.batchTimetable != null && _timetableService.batchTimetable!.isNotEmpty) {
      await _checkTodayHoliday();
      
      final int? passedDayOrder = widget.view_dayorder;
      final int currentDay = _timetableService.currentDayOrder;
      
      int targetDay = 1;
      if (passedDayOrder != null && passedDayOrder >= 1 && passedDayOrder <= 5) {
        targetDay = passedDayOrder;
      } else if (currentDay >= 1 && currentDay <= 5) {
        targetDay = currentDay;
      }

      _activePageIndex = targetDay - 1;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_activePageIndex);
        }
      });
    }
    
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkTodayHoliday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final calendarJson = prefs.getString('calendar_cache');

      if (calendarJson != null && calendarJson.isNotEmpty) {
        final decoded = json.decode(calendarJson) as Map<String, dynamic>;
        final calendarData = decoded.map((key, value) => MapEntry(
          key,
          Map<String, dynamic>.from(value as Map),
        ));

        final today = DateTime.now();
        final todayKey = "${today.day}_${today.month}_${today.year}";

        if (calendarData.containsKey(todayKey)) {
          final event = calendarData[todayKey];
          if (event != null && event['event_type'] == 'holiday') {
            if (mounted) {
              setState(() {
                _isTodayHoliday = true;
                _holidayName = event['title'] ?? 'Holiday';
              });
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking holiday: $e');
    }
  }

  Widget _buildHolidayBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: _holidayOrange,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _holidayGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _holidayGold.withValues(alpha:0.5),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, color: _white, size: 32),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _holidayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.celebration, color: _white, size: 32),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available, color: _white, size: 16),
                SizedBox(width: 8),
                Text(
                  'No Classes Today',
                  style: TextStyle(
                    color: _white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Swipe to view timetable for other days',
            style: TextStyle(
              color: _white.withValues(alpha:0.9),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 80,
            color: _neonPink.withValues(alpha:0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Timetable Data',
            style: TextStyle(
              color: _white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _timetableService.batchTimetable != null && 
                         _timetableService.batchTimetable!.isNotEmpty;

    return Scaffold(
      backgroundColor: _pitchBlack,
      appBar: AppBar(
        title: const Text(
          'Timetable',
          style: TextStyle(fontWeight: FontWeight.w600, color: _white),
        ),
        backgroundColor: _pitchBlack,
        foregroundColor: _neonPink,
        elevation: 0,
        actions: [
          if (hasData)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _exportTimetable,
              tooltip: 'Export Timetable',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (hasData)
            Positioned(
              left: -5000,
              top: -5000,
              child: RepaintBoundary(
                key: _exportKey,
                child: Material(
                  color: Colors.transparent,
                  child: TimetableExportWidget(
                    program: _program,
                    semester: _semester,
                    service: _timetableService,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _neonPink),
                  )
                : !hasData 
                    ? _buildNoDataView() 
                    : Column(
                        children: [
                          if (_isTodayHoliday) _buildHolidayBanner(),
                          
                          // Day indicator dots
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final bool isActive = _activePageIndex == index;
                                return GestureDetector(
                                  onTap: () {
                                    _pageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? 32 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _neonPink
                                          : _white.withValues(alpha:0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          
                          // Page view
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: 5,
                              onPageChanged: (index) {
                                setState(() {
                                  _activePageIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final day = index + 1;
                                final currentDay = _timetableService.currentDayOrder;
                                final isToday = currentDay == day && 
                                                     currentDay >= 1 && 
                                                     currentDay <= 5;
                                final classes = _timetableService.getClassesForDay(day);
                                
                                return DayOrderCard(
                                  day: day,
                                  isCurrentDay: isToday,
                                  classes: classes,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}