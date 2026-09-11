// File: calendar_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Note: Assuming 'calender_widgets.dart' is correctly resolved by the path '../widgets/calender_widgets.dart'
// If you put them in the same folder, you would use: 'calender_widgets.dart'
import '../widgets/calender_widgets.dart'; 
import 'dart:convert';
//to import calender data
import '../services/calender_data.dart';
//for custom taks
import '../widgets/custom_task_widget.dart';
//to open timtable drawer window
import '../screens/timetablescreen.dart';
//for ios like animation
import 'package:flutter/cupertino.dart'; 

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late PageController _pageController;
  late DateTime _currentDisplayMonth;
  final DateTime _today = DateTime.now();

  // Color scheme loaded from (dummy) local storage
  Map<String, Color> _priorityColorMap = {};
  
  // Sample events data (will be merged with loaded data)
  Map<String, Map<String, dynamic>> eventsData = {};

  // NEW: Variable to store the initial day order fetched from 'userData'
  int? _initialDayOrder; 

  // NEW: State variable to track loading status
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    // Use Future.wait to track all async loading processes
    _initializeData();
    
    // Initialize to the start of the current month
    _currentDisplayMonth = DateTime(_today.year, _today.month); 
    _pageController = PageController(initialPage: _getInitialPage());
  }

  // NEW: Helper to manage multiple async calls and loading state
  Future<void> _initializeData() async {
    // Start with data being loaded
    setState(() {
      _isLoadingData = true;
    });

    await Future.wait([
      _loadData(), // Loads shared preferences data
      loadEvents(), // Loads firestore data
    ]);
    
    // Once all data is fetched, set loading to false and refresh UI
    setState(() {
      _isLoadingData = false;
    });
  }

//helper func for firestore
  Future<void> loadEvents() async {
      final firestoreEvents = await getEventsData();
      // Carefully merge Firestore events with existing events
      firestoreEvents.forEach((dateKey, dayData) {
        if (eventsData.containsKey(dateKey)) {
          // If we already have events for this date, add new ones
          List existingEvents = eventsData[dateKey]!['event'] as List;
          List newEvents = dayData['event'] as List;
          // Only add events that aren't custom (custom events take precedence)
          newEvents.where((event) => event['type'] != 'custom').forEach((event) {
            existingEvents.add(event);
          });
        } else {
          // If no events exist for this date, just add the Firestore events
          eventsData[dateKey] = dayData;
        }
      });
      // Note: We avoid calling setState here, as it's called once in _initializeData after all data loads.
    }

  // --- Local Storage Functions  ---
  
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Custom Color Scheme
    final colorMapJson = prefs.getString('priorityColorMap');
    if (colorMapJson != null) {
      Map<String, dynamic> decodedMap = json.decode(colorMapJson);
      _priorityColorMap = decodedMap.map((key, value) => MapEntry(key, Color(value as int)));
    } else {
      // Default color map if none is saved
      _priorityColorMap = {
        'low': Colors.green,
        'mid': Colors.amber,
        'high': Colors.red,
      };
      _savePriorityColorMap(); // Save defaults for next time
    }

    // 2. Load Custom Events (and merge with static data)
    final customEventsJson = prefs.getString('customEvents');
    if (customEventsJson != null) {
      Map<String, dynamic> loadedEvents = json.decode(customEventsJson);
      loadedEvents.forEach((key, value) {
        final castedValue = (value as Map).cast<String, dynamic>();
        if (eventsData.containsKey(key)) {
          // Merge events for same date
          final existingEvents = eventsData[key]!['event'] as List;
          final customEvents = castedValue['event'] as List;
          existingEvents.addAll(customEvents);
        } else {
          eventsData[key] = castedValue;
        }
      });
    }

    // 3. Load Initial Day Order from 'userData'
    final dataString = prefs.getString('userData');
    if (dataString != null && dataString.isNotEmpty) {
      try {
        final parsedData = json.decode(dataString);
        // Safely extract and parse the day_order
        final order = parsedData['attendance']?['day_order'];
        if (order != null) {
            // Try to parse as int if it's a string, or use the int value
            int? parsedOrder = (order is String) ? int.tryParse(order) : order as int?;
            
            // Check if it's a valid day order (1 to 5)
            if (parsedOrder != null && parsedOrder >= 1 && parsedOrder <= 5) {
                _initialDayOrder = parsedOrder;
            } else {
                // ignore: avoid_print
                if (kDebugMode) debugPrint("Warning: Parsed day_order is invalid (not 1-5). Value: $order");
            }
        }
      } catch (e) {
        // ignore: avoid_print
        if (kDebugMode) debugPrint("Error decoding userData or finding day_order: $e");
      }
    }
    // Note: We avoid calling setState here, as it's called once in _initializeData after all data loads.
  }

  Future<void> _savePriorityColorMap() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> encodedMap = 
        _priorityColorMap.map((key, value) => MapEntry(key, value.toARGB32()));
    await prefs.setString('priorityColorMap', json.encode(encodedMap));
  }

  Future<void> _saveEvents() async {
      final prefs = await SharedPreferences.getInstance();
      // Extract ONLY custom events to save
      Map<String, Map<String, dynamic>> customOnlyEvents = {};
      
      eventsData.forEach((dateKey, dayData) {
        final events = dayData['event'] as List?;
        if (events != null) {
          final customEvents = events.where((e) => e['type'] == 'custom').toList();
          if (customEvents.isNotEmpty) {
            customOnlyEvents[dateKey] = {'event': customEvents};
          }
        }
      });
      
      await prefs.setString('customEvents', json.encode(customOnlyEvents));
    }
  
  void _saveCustomEvent(Map<String, dynamic> eventData) {
    // 1. Format date key
    final date = eventData['date'] as DateTime;
    final key = "${date.day}_${date.month}_${date.year}";

    // 2. Build the new event object
    final newEvent = {
      "type": "custom",
      "title": eventData['title'],
      "desc": eventData['desc'],
      "priority": eventData['priority'],
      "time": eventData['time'],
      'notification': eventData['notification'],
      'notificationId':eventData['notificationId'],
    };

    setState(() {
      // 3. Add to or initialize the list of events for that day
      if (eventsData.containsKey(key)) {
        // Ensure 'event' is a List
        if (eventsData[key]!['event'] is List) {
           (eventsData[key]!['event'] as List).add(newEvent);
        } else {
           eventsData[key] = {"event": [newEvent]};
        }
      } else {
        eventsData[key] = {"event": [newEvent]};
      }
    });
    
    _saveEvents(); // Save the updated data to local storage
  }


  void _deleteCustomEvent(DateTime date, int eventIndex) {
    final key = "${date.day}_${date.month}_${date.year}";
    
    setState(() {
      if (eventsData.containsKey(key) && eventsData[key]?['event'] is List) {
        (eventsData[key]!['event'] as List).removeAt(eventIndex);
        
        // Remove the date entry if no events left
        if ((eventsData[key]!['event'] as List).isEmpty) {
          eventsData.remove(key);
        }
      }
    });
    
    _saveEvents();
  }

//FOR EDITING CUSTOM EVENT
void _openEditEventSheet(DateTime date, int eventIndex, Map<String, dynamic> existingEvent) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CreateEventBottomSheet(
        onSave: (eventData) {
          final key = "${date.day}_${date.month}_${date.year}";
          
          final updatedEvent = {
            "type": "custom",
            "title": eventData['title'],
            "desc": eventData['desc'],
            "priority": eventData['priority'],
            "time": eventData['time'],
            'notification': eventData['notification'],
            'notificationId': eventData['notificationId'],
          };
          
          setState(() {
            if (eventsData.containsKey(key) && eventsData[key]?['event'] is List) {
              (eventsData[key]!['event'] as List)[eventIndex] = updatedEvent;
            }
          });
          _saveEvents();
        },
        isEditing: true,
        initialData: existingEvent,
      ),
    ),
  );
}


  // --- Utility Methods ---

  int _getInitialPage() {
    final baseDate = DateTime(2020, 1);
    // Calculate the difference in months from the base date
    return (_currentDisplayMonth.year - baseDate.year) * 12 + 
           (_currentDisplayMonth.month - baseDate.month);
  }

  DateTime _getDateFromPage(int page) {
    final baseDate = DateTime(2020, 1);
    // Calculate the date corresponding to the page index
    return DateTime(baseDate.year, baseDate.month + page);
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'holiday':
        return Colors.red;
      case 'event':
        return Colors.blue;
      case 'admin':
        return Colors.orange;
      case 'custom':
        return Colors.deepPurple;  // Fixed color, not priority-based
      default:
        return Colors.grey;
    }
  }

  List<dynamic>? _getEventsForDate(DateTime date) {
    final key = "${date.day}_${date.month}_${date.year}";
    return eventsData[key]?['event'];
  }

  // NEW: Helper to check if a date is a 'holiday'
  bool _isHoliday(DateTime date) {
    final events = _getEventsForDate(date);
    if (events != null) {
        return events.any((event) => event is Map && event['type'] == 'holiday');
    }
    return false;
  }

  // UPDATED: Logic to pause day order on holiday and resume on the next working day.
  String? _getSequentialDayOrder(DateTime date) {
    final todayStart = DateTime(_today.year, _today.month, _today.day);
    
    // 1. Check if the target day is before today or if the initial order is missing.
    if (date.isBefore(todayStart) || _initialDayOrder == null) {
        return null;
    }
    
    // 2. If the target day is a holiday, do not display a day order.
    if (_isHoliday(date)) {
        return null;
    }

    // 3. Handle today's day order separately for initialization
    if (date.isAtSameMomentAs(todayStart)) {
      return _initialDayOrder.toString();
    }
    
    // 4. Initialize the running day order with today's loaded order.
    int currentOrder = _initialDayOrder!;

    // 5. Iterate from the day *after* today up to and including the target date.
    final daysDifference = date.difference(todayStart).inDays;

    for (int i = 1; i <= daysDifference; i++) {
        final dayToCheck = todayStart.add(Duration(days: i));
        
        // Check if the current day is NOT a holiday.
        if (!_isHoliday(dayToCheck)) {
            // Only advance the order if the current date is a working day.
            // Cycle 1 -> 2 -> 3 -> 4 -> 5 -> 1
            currentOrder = (currentOrder % 5) + 1; 
        } 
        // If it IS a holiday, the 'currentOrder' variable simply retains 
        // the last calculated order from the previous working day, effectively pausing the sequence.
    }

    // 6. The resulting 'currentOrder' is the correct sequential day order for the 'date'.
    return currentOrder.toString();
  }


  //HELPER METHOD FOR GET ALL CUSTOM EVENTS
List<Map<String, dynamic>> _getAllCustomEvents() {
  List<Map<String, dynamic>> customEvents = [];
  eventsData.forEach((dateKey, dayData) {
    final dateParts = dateKey.split('_');
    final date = DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
    );
    
    final events = dayData['event'] as List<dynamic>?;
    if (events != null) {
      for (var i = 0; i < events.length; i++) {
        final event = events[i];
        if (event['type'] == 'custom') {
          customEvents.add({
            ...event as Map<String, dynamic>,
            'date': date,
            'originalIndex': i,
          });
        }
      }
    }
  });
  
  customEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  return customEvents;
}


  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // --- Navigation Methods ---

  void _navigateToMonth(int offset) {
    final currentPage = _pageController.page?.round() ?? _getInitialPage();
    _pageController.animateToPage(
      currentPage + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openCreateEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Required for custom shape
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateEventBottomSheet(
          onSave: _saveCustomEvent,
          initialData: {
            // Set initial date to the current display month if needed, 
            // otherwise, the widget defaults to today.
            'date': _currentDisplayMonth.isBefore(_today) ? _today : _currentDisplayMonth,
          },
        ),
      ),
    );
  }


//add to title later
  void _jumpToToday() {
    final todayPage = _getInitialPage();
    _pageController.animateToPage(
      todayPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // --- UI/Building Methods ---

  // ORIGINAL: Shows event details. Used when events exist.
  void _showEventDetails(DateTime date, List<dynamic> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                '${date.day} ${_getMonthName(date.month)} ${date.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // NEW: Display Day Order at the top if it exists
              if (_getSequentialDayOrder(date) != null) ...[
                const SizedBox(height: 8),
                
                GestureDetector(
                  onTap: () {
                    final dayOrderStr = _getSequentialDayOrder(date); // probably returns String
                    if (dayOrderStr != null) {
                      final dayOrder = int.tryParse(dayOrderStr); // safely convert to int
                      if (dayOrder != null) {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => TimetableScreen(view_dayorder: dayOrder),
                          ),
                        );
                      } else {
                        if (kDebugMode) debugPrint('Invalid day order: $dayOrderStr');
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply_outlined, color: const Color.fromARGB(255, 0, 0, 0), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Day Order: ${_getSequentialDayOrder(date)}',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )



              ],
              const SizedBox(height: 20),
              // Use the external widget here
              ...events.map((event) => EventItemWidget(
                event: event as Map<String, dynamic>,
                getEventColor: _getEventColor, // Pass the utility function
              )),
            ],
          ),
        ),
      ),
    );
  }
  
  // NEW: Shows day order details when there are NO events
  void _showDayDetails(DateTime date, String dayOrder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                '${date.day} ${_getMonthName(date.month)} ${date.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  final dayOrderStr = _getSequentialDayOrder(date); // probably returns String
                  if (dayOrderStr != null) {
                    final dayOrder = int.tryParse(dayOrderStr); // safely convert to int
                    if (dayOrder != null) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => TimetableScreen(view_dayorder: dayOrder),
                        ),
                      );
                    } else {
                      if (kDebugMode) debugPrint('Invalid day order: $dayOrderStr');
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_outlined, color: const Color.fromARGB(255, 0, 0, 0), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Day Order: ${_getSequentialDayOrder(date)}',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No events scheduled for this date.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMonthView(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    // Dart's DateTime.weekday is 1 (Monday) to 7 (Sunday). 
    // We want 0 (Sunday) to 6 (Saturday).
    final startWeekday = firstDayOfMonth.weekday % 7; 

    return Column(
      children: [
        // Weekday Headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // Calendar Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayNumber = index - startWeekday + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(month.year, month.month, dayNumber);
                final events = _getEventsForDate(date);
                final hasEvents = events != null && events.isNotEmpty;
                final isToday = date.year == _today.year && 
                               date.month == _today.month && 
                               date.day == _today.day;

                // NEW: Calculate the sequential day order
                final dayOrder = _getSequentialDayOrder(date);
                // NEW: Check if there's anything to show on tap
                final canOpenDetails = hasEvents || dayOrder != null; 

                return GestureDetector(
                  // MODIFIED: If there are events, call _showEventDetails. 
                  // If no events but there IS a day order, call the new _showDayDetails.
                  onTap: canOpenDetails
                      ? () {
                          if (hasEvents) {
                            _showEventDetails(date, events);
                          } else if (dayOrder != null) {
                            _showDayDetails(date, dayOrder);
                          }
                        }
                      : null,
                  // Use the external widget here
                  child: DateCellWidget(
                    day: dayNumber,
                    isToday: isToday,
                    hasEvents: hasEvents,
                    events: events,
                    getEventColor: _getEventColor, // Pass the utility function
                    // NEW: Pass the calculated day order to the DateCellWidget
                    dayOrder: dayOrder, 
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row( // MODIFIED: Use a Row for the title and loading indicator
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Calendar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (_isLoadingData) ...[ // NEW: Display loading indicator if data is being fetched
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _openCreateEventSheet, // Updated to open the new sheet
            tooltip: 'Create Custom Event',
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  onPressed: () => _navigateToMonth(-1),
                ),
                Text(
                  '${_getMonthName(_currentDisplayMonth.month)} ${_currentDisplayMonth.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                  onPressed: () => _navigateToMonth(1),
                ),
              ],
            ),
          ),
          // Calendar PageView (The Calendar Grid)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              pageSnapping: true,
              onPageChanged: (index) {
                setState(() {
                  _currentDisplayMonth = _getDateFromPage(index);
                });
              },
              itemBuilder: (context, index) {
                final month = _getDateFromPage(index);
                return _buildMonthView(month);
              },
            ),
          ),
          // Custom Events List and Legend (Fixed Height, Scrollable List)
          Container(
            height: 300,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 10, 10, 10),
              border: Border(top: BorderSide(color: Colors.white24, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Legends (Cleanly above the list)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Legend moved here with wrapping
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          LegendItemWidget(label: 'Holiday', color: Colors.red),
                          LegendItemWidget(label: 'Event', color: Colors.blue),
                          LegendItemWidget(label: 'Admin', color: Colors.orange),
                          LegendItemWidget(label: 'Custom', color: Colors.deepPurple),
                          LegendItemWidget(label: 'day order', color: const Color.fromARGB(255, 255, 255, 255)),

                        ],
                      ),
                    ],
                  ),
                ),
                // Custom Task List (Scrollable when overflow)
                Expanded(
                  child: _getAllCustomEvents().isEmpty
                      ? const Center(
                          child: Text(
                            'No custom tasks yet',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _getAllCustomEvents().length,
                          itemBuilder: (context, index) {
                            final allEvents = _getAllCustomEvents();
                            final event = allEvents[index];
                            final date = event['date'] as DateTime;
                            final eventIndex = event['originalIndex'] as int;
                            
                            return CustomTaskCard(
                              event: event,
                              date: date,
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    title: const Text('Delete Task', style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                      'Are you sure you want to delete this task?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _deleteCustomEvent(date, eventIndex);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onEdit: () => _openEditEventSheet(date, eventIndex, event),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}