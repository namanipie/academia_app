import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DayOrderCard extends StatefulWidget {
  const DayOrderCard({
    super.key,
    required this.day,
    required this.isCurrentDay,
    required this.classes,
  });

  final int day;
  final bool isCurrentDay;
  final List<Map<String, String>> classes;

  @override
  State<DayOrderCard> createState() => _DayOrderCardState();
}

class _DayOrderCardState extends State<DayOrderCard> {
  // --- Styling Constants ---
  static const Color _pitchBlack = Color(0xFF000000);
  static const Color _neonPink = Color.fromARGB(255, 201, 4, 109);
  static const Color _white = Colors.white;
  static const Color _cardBackground = Color(0xFF161616);

  // --- State Variables ---
  Map<String, Map<String, dynamic>> _calendarData = {};
  Set<String> _optionalClassIds = {};
  String _dayNote = "";
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Calendar Cache
      final calendarJson = prefs.getString('calendar_cache');
      if (calendarJson != null && calendarJson.isNotEmpty) {
        final decoded = json.decode(calendarJson) as Map<String, dynamic>;
        setState(() {
          _calendarData = decoded.map((key, value) => MapEntry(
                key,
                Map<String, dynamic>.from(value as Map),
              ));
        });
      }

      // 2. Load Optional Classes
      final List<String>? savedOptionals = prefs.getStringList('optional_classes_prefs');
      if (savedOptionals != null) {
        setState(() {
          _optionalClassIds = savedOptionals.toSet();
        });
      }

      // 3. Load Custom Day Note
      final String? savedNote = prefs.getString('note_day_${widget.day}');
      if (savedNote != null) {
        setState(() {
          _dayNote = savedNote;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading data: $e');
    }
  }

  bool _isHoliday(String dateKey) {
    if (!_calendarData.containsKey(dateKey)) return false;
    final events = _calendarData[dateKey]?['event'] as List?;
    if (events == null) return false;
    for (var event in events) {
      if (event is Map && event['type'] == 'holiday') return true;
    }
    return false;
  }

  Future<void> _toggleOptional(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_optionalClassIds.contains(classId)) {
        _optionalClassIds.remove(classId);
      } else {
        _optionalClassIds.add(classId);
      }
    });
    await prefs.setStringList('optional_classes_prefs', _optionalClassIds.toList());
  }

  Future<void> _saveNote(String note) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _dayNote = note);
    await prefs.setString('note_day_${widget.day}', note);
  }

  void _showNoteDialog() {
    final TextEditingController controller = TextEditingController(text: _dayNote);
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: _neonPink.withValues(alpha:0.5))),
          title: const Text('Day Note', 
            style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            style: const TextStyle(color: _white),
            decoration: InputDecoration(
              hintText: "Enter reminders, room changes, or tasks...",
              hintStyle: TextStyle(color: _white.withValues(alpha:0.3)),
              filled: true,
              fillColor: _pitchBlack,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), 
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _saveNote(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localClasses = widget.classes;
    final isCurrentDay = widget.isCurrentDay;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentDay ? null : _cardBackground,
        gradient: isCurrentDay
            ? LinearGradient(
                colors: [_neonPink.withValues(alpha:0.85), _neonPink.withValues(alpha:0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isCurrentDay ? _white.withValues(alpha:0.2) : _white.withValues(alpha:0.08),
          width: 1.5,
        ),
        boxShadow: [
          if (isCurrentDay)
            BoxShadow(
              color: _neonPink.withValues(alpha:0.3),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER SECTION ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day ${widget.day}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _white,
                        letterSpacing: -1.2,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showNoteDialog,
                          icon: Icon(Icons.edit_note, color: _white.withValues(alpha:0.8), size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // --- EXPANDABLE NOTE SECTION ---
                if (_dayNote.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _isNoteExpanded = !_isNoteExpanded),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha:isCurrentDay ? 0.15 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _white.withValues(alpha:0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.push_pin, size: 12, color: _white),
                              const SizedBox(width: 6),
                              Text(
                                "DAY NOTE",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _white.withValues(alpha:0.6),
                                  letterSpacing: 1,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _isNoteExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 16,
                                color: _white.withValues(alpha:0.5),
                              )
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: _isNoteExpanded ? 120 : 40,
                            ),
                            child: SingleChildScrollView(
                              physics: _isNoteExpanded 
                                  ? const BouncingScrollPhysics() 
                                  : const NeverScrollableScrollPhysics(),
                              child: Text(
                                _dayNote,
                                style: const TextStyle(
                                  color: _white,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                maxLines: _isNoteExpanded ? null : 2,
                                overflow: _isNoteExpanded ? null : TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // --- CLASSES LIST ---
          if (localClasses.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available, size: 60, color: _white.withValues(alpha:0.2)),
                    const SizedBox(height: 12),
                    Text("No Classes Scheduled", style: TextStyle(color: _white.withValues(alpha:0.4))),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: localClasses.length,
                itemBuilder: (context, index) {
                  final classInfo = localClasses[index];
                  final slot = classInfo['slot'] ?? 'N/A';
                  final classId = "${widget.day}_$slot";
                  final isOptional = _optionalClassIds.contains(classId);

                  return GestureDetector(
                    onDoubleTap: () => _toggleOptional(classId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isOptional 
                            ? Colors.transparent 
                            : (isCurrentDay ? _white.withValues(alpha:0.1) : _pitchBlack),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isOptional 
                              ? _white.withValues(alpha:0.05) 
                              : (isCurrentDay ? _white.withValues(alpha:0.2) : _neonPink.withValues(alpha:0.2)),
                        ),
                      ),
                      child: Opacity(
                        opacity: isOptional ? 0.35 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isOptional ? "OPTIONAL" : slot,
                                  style: TextStyle(
                                    color: isOptional ? Colors.grey : _neonPink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 14, color: _white),
                                    const SizedBox(width: 5),
                                    Text(
                                      classInfo['time'] ?? 'N/A',
                                      style: const TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              classInfo['course'] ?? 'Unknown Course',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _white,
                                decoration: isOptional ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.room_outlined, size: 16, color: _neonPink.withValues(alpha:0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  (classInfo['classroom']?.toString().trim().isNotEmpty ?? false)
                                      ? classInfo['classroom'].toString() 
                                      : 'N/A',
                                  style: TextStyle(fontSize: 14, color: _white.withValues(alpha:0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 66), 
        ],
      ),
    );
  }
}