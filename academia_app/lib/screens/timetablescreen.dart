// File: timetable_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/timetable_service.dart';
import '../widgets/day_order_card.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    // FIX: Initialize immediately with page 0 to avoid "LateInitializationError"
    _pageController = PageController(initialPage: 0);
    _loadTimetable();
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

      // Update the active index state
      _activePageIndex = targetDay - 1;

      // FIX: Use jumpToPage after the first frame is drawn to sync with data
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
          final events = calendarData[todayKey]?['event'] as List?;
          if (events != null) {
            for (var event in events) {
              if (event is Map && event['type'] == 'holiday') {
                if (mounted) {
                  setState(() {
                    _isTodayHoliday = true;
                    _holidayName = event['name'] ?? 'Holiday';
                  });
                }
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking holiday: $e');
    }
  }

  // PRESERVED: Original Holiday Banner UI
  Widget _buildHolidayBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _holidayOrange.withValues(alpha:0.9),
            _holidayGold.withValues(alpha:0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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

  // PRESERVED: Original "No Data" UI Handler
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
          const SizedBox(height: 20),
          const Text(
            'No timetable found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We couldn\'t load any class schedules.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _white.withValues(alpha:0.5),
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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _neonPink),
            )
          : !hasData 
              ? _buildNoDataView() 
              : Column(
                  children: [
                    if (_isTodayHoliday) _buildHolidayBanner(),
                    
                    // Day indicator dots (PRESERVED LOGIC)
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
                    
                    // Page view (FIXED & PRESERVED)
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
    );
  }
}