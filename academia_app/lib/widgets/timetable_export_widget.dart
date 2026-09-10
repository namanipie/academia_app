import 'package:flutter/material.dart';
import '../services/timetable_service.dart';

class TimetableExportWidget extends StatelessWidget {
  final String program;
  final String semester;
  final TimetableService service;

  const TimetableExportWidget({
    super.key,
    required this.program,
    required this.semester,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    return Container(
      width: 1080,
      padding: const EdgeInsets.all(60),
      decoration: const BoxDecoration(
        color: Color(0xFF08080A), // Deep dark background
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACADEMIA',
                    style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2),
                  ),
                  const Text(
                    'TIMETABLE',
                    style: TextStyle(color: Color(0xFF61A5DD), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (semester.isNotEmpty)
                    Text('Semester $semester', style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w700)),
                  if (program.isNotEmpty)
                    Text(program, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 60),
          
          // Days
          ...List.generate(5, (index) {
            final dayIndex = index + 1;
            final classes = service.getClassesForDay(dayIndex);
            
            if (classes.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131316),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayNames[index].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9DF8A0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'Day Order $dayIndex',
                              style: const TextStyle(color: Color(0xFF9DF8A0), fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: classes.map((c) => _buildClassRow(c)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Footer
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFD3974), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                const Text('GENERATED BY CONSOLE ACADEMIA', style: TextStyle(color: Colors.white30, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildClassRow(Map<String, String> classData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              classData['time'] ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classData['course'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFFD3974), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      classData['classroom'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        classData['slot'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
