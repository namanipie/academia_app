import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  bool _isNavBarVisible = true;
  
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isNavBarVisible) setState(() => _isNavBarVisible = false);
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_isNavBarVisible) setState(() => _isNavBarVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListenableBuilder(
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
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: _isNavBarVisible ? Offset.zero : const Offset(0, 1.5),
        child: _buildFloatingNavBar(),
      ),
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
            child: Material(
              type: MaterialType.transparency,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
              borderRadius: BorderRadius.circular(30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 65,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
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