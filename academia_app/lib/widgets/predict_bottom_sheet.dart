import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PredictBottomSheet extends StatefulWidget {
  final List<DateTime> initialSkippedDates;
  final bool initialIsOdMlMode;
  final Function(List<DateTime> skippedDates, bool isOdMlMode) onApply;

  const PredictBottomSheet({
    super.key,
    required this.initialSkippedDates,
    required this.initialIsOdMlMode,
    required this.onApply,
  });

  @override
  State<PredictBottomSheet> createState() => _PredictBottomSheetState();
}

class _PredictBottomSheetState extends State<PredictBottomSheet> {
  late List<DateTime> _selectedDates;
  late bool _isOdMlMode;

  @override
  void initState() {
    super.initState();
    _selectedDates = List.from(widget.initialSkippedDates);
    _isOdMlMode = widget.initialIsOdMlMode;
  }

  void _toggleDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      final exists = _selectedDates.any((d) => _isSameDay(d, date));
      if (exists) {
        _selectedDates.removeWhere((d) => _isSameDay(d, date));
      } else {
        _selectedDates.add(date);
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _quickSelect(int days) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDates.clear();
      final today = DateTime.now();
      for (int i = 0; i < days; i++) {
        _selectedDates.add(today.add(Duration(days: i)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _isOdMlMode ? const Color(0xFF00FF9D) : const Color(0xFF61A5DD);
    final bgDark = const Color(0xFF0A0A0A).withValues(alpha:0.85);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha:0.1), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withValues(alpha:0.3), width: 1),
                    ),
                    child: Icon(Icons.auto_awesome, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Am I Cooked?', 
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                        ),
                        Text(
                          'Check your margins before u skip.', 
                          style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha:0.5)),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 24),
              
              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha:0.05)),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isOdMlMode = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: !_isOdMlMode ? const Color(0xFF61A5DD).withValues(alpha:0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isOdMlMode ? const Color(0xFF61A5DD).withValues(alpha:0.3) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bedtime_outlined, color: !_isOdMlMode ? const Color(0xFF61A5DD) : Colors.white.withValues(alpha:0.4), size: 16),
                              const SizedBox(width: 6),
                              Text('Bunking', style: TextStyle(color: !_isOdMlMode ? const Color(0xFF61A5DD) : Colors.white.withValues(alpha:0.4), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isOdMlMode = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _isOdMlMode ? const Color(0xFF00FF9D).withValues(alpha:0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isOdMlMode ? const Color(0xFF00FF9D).withValues(alpha:0.3) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_outlined, color: _isOdMlMode ? const Color(0xFF00FF9D) : Colors.white.withValues(alpha:0.4), size: 16),
                              const SizedBox(width: 6),
                              Text('Free Attd (OD/ML)', style: TextStyle(color: _isOdMlMode ? const Color(0xFF00FF9D) : Colors.white.withValues(alpha:0.4), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Info banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha:0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isOdMlMode 
                          ? 'W. Free attendance for every class today.'
                          : 'Select the days u wanna ghost.',
                        style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!_isOdMlMode) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _quickSelectChip('Just Today', 1),
                      const SizedBox(width: 10),
                      _quickSelectChip('Tmrw too', 2),
                      const SizedBox(width: 10),
                      _quickSelectChip('Next 3 days', 3),
                      const SizedBox(width: 10),
                      _quickSelectChip('Full Week', 7),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Calendar Grid
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha:0.05)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha:0.4)),
                        const Text('Pick the days', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha:0.4)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                          Text(day, style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(35, (index) {
                        final dayNum = index - 0; 
                        if (dayNum < 1 || dayNum > 30) return const SizedBox(width: 36, height: 36);
                        
                        final date = DateTime.now().add(Duration(days: dayNum - DateTime.now().day));
                        final isSelected = _selectedDates.any((d) => _isSameDay(d, date));
                        
                        return GestureDetector(
                          onTap: () => _toggleDate(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.white.withValues(alpha:0.03),
                              shape: BoxShape.circle,
                              boxShadow: isSelected ? [
                                BoxShadow(color: primaryColor.withValues(alpha:0.4), blurRadius: 10, offset: const Offset(0, 4))
                              ] : [],
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white.withValues(alpha:0.7),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedDates.clear());
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Nah, reset', style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onApply(_selectedDates, _isOdMlMode);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _isOdMlMode ? 'Lock in OD/ML' : 'See if I\'m Cooked',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickSelectChip(String label, int days) {
    return GestureDetector(
      onTap: () => _quickSelect(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha:0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white.withValues(alpha:0.6), size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
