import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'attendancescreen.dart';
import 'homescreens.dart';
import 'marksscreen.dart';
import 'timetablescreen.dart';
import '../services/theme_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  
  Key _attendanceKey = UniqueKey();
  Key _marksKey = UniqueKey();
  Key _timetableKey = UniqueKey();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(
        onDataRefreshed: () {
          setState(() {
            _attendanceKey = UniqueKey();
            _marksKey = UniqueKey();
            _timetableKey = UniqueKey();
            _screens = _buildScreens();
          });
        },
      ),
      AttendanceScreen(key: _attendanceKey),
      MarksScreen(key: _marksKey),
      TimetableScreen(key: _timetableKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          final theme = ThemeController.instance;
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBg,
              gradient: theme.backgroundGradient,
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          );
        }
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final isDark = theme.isDark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15), // Floating margins
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(Icons.home_rounded, 0, theme.primaryAccent, isDark),
                      _navItem(Icons.how_to_reg_rounded, 1, const Color(0xFF61A5DD), isDark),
                      _navItem(Icons.bar_chart_rounded, 2, const Color(0xFF9DF8A0), isDark),
                      _navItem(Icons.schedule_rounded, 3, const Color(0xFFFD3974), isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(IconData icon, int index, Color activeColor, bool isDark) {
    bool isSelected = _currentIndex == index;
    final unselectedColor = isDark ? Colors.white24 : Colors.black26;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 300),
          tween: ColorTween(
            begin: unselectedColor,
            end: isSelected ? activeColor : unselectedColor,
          ),
          builder: (context, color, child) {
            return Icon(
              icon,
              color: color,
              size: 26,
            );
          },
        ),
      ),
    );
  }
}