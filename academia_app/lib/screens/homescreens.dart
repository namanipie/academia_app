import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import '../components/subject_info.dart';
import '../components/faculty_info.dart';
//user_data_refresh service
import '../services/user_data_refresh.dart';
//logout user utility


//profile card
import '../widgets/profile_card_widget.dart';

//stats bar component
import '../components/stats_bar.dart';
//quick actions component
import '../components/quick_actions.dart';
//for contacting support
import '../components/contact_us.dart';
import '../services/theme_controller.dart';
import '../widgets/next_class_widget.dart';
import 'settings_screen.dart';

// ============================================================================
// HOME SCREEN - Student profile and overview
// ============================================================================
class HomeScreen extends StatefulWidget {
  final VoidCallback? onDataRefreshed;
  
  const HomeScreen({super.key, this.onDataRefreshed});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

Map<String, dynamic> _decodeJson(String source) => jsonDecode(source) as Map<String, dynamic>;

class _HomeScreenState extends State<HomeScreen> {
  Color get _primaryColor => ThemeController.instance.primaryAccent;

  bool _isGuest = false;
  Map<String, dynamic>? studentInfo;
  double _overallAttendance = 0.0;
  int _courseCount = 0;
  int _totalCredits = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic> _advisors = {};
  String _lastRefreshText = '';

  @override
  void initState() {
    super.initState();
    _loadAndAutoRefresh();
  }

  Future<void> _loadAndAutoRefresh() async {
    await _loadUserData(); // Showing cached data first
    
    if (_isGuest) return;

    final prefs = await SharedPreferences.getInstance();
    final lastRefreshTime = prefs.getString('lastRefreshTime');

    if (lastRefreshTime != null) {
      final lastRefresh = DateTime.parse(lastRefreshTime);
      final difference = DateTime.now().difference(lastRefresh);

// Auto-refresh if last refresh was over 10 minutes ago
      if (difference.inMinutes >= 10) {
        await _refreshData();
      }
    }
  }

  // Format the last refresh time
  String _formatLastRefresh(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    
    try {
      final lastRefresh = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(lastRefresh);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return '';
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
  if (!mounted) return;
  
  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Dismiss current one
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_rounded,
            color: isError ? Colors.redAccent : _primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      margin: EdgeInsets.only(
        bottom: 20, // Fixed height from bottom
        left: 24,
        right: 24,
      ),
    ),
  );
}

  Future<void> _refreshData() async {
    if (_isGuest) {
      if (mounted) {
         Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CLoginPage()),
         );
      }
      return;
    }

    try {
      // CALL REFRESH SERVICE
      final success = await DataRefreshService.refreshData();

      if (!success) {
        if (mounted) {
          _showModernSnackBar('Unable to refresh', isError: true);
        }
        return;
      }

      // 🔄 Reset state to force UI rebuild 
      setState(() {
        studentInfo = null;
        _overallAttendance = 0.0;
        _courseCount = 0;
        _totalCredits = 0;
        _courses = [];
        _advisors = {};
        _lastRefreshText = '';
        _loading = true;
      });

      // reload data from SharedPreferences
      await _loadUserData();
      widget.onDataRefreshed?.call();

      if (mounted) {
        _showModernSnackBar('Data refreshed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error refreshing data', isError: true);
      }
    }
  }
  

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final email = prefs.getString('userEmail');
      _isGuest = email == null || email.isEmpty;

      final dataString = prefs.getString('userData');
      final lastRefreshTime = prefs.getString('lastRefreshTime');
      
      // Update last refresh text
      setState(() {
        _lastRefreshText = _formatLastRefresh(lastRefreshTime);
      });
      
      if (dataString != null && dataString.isNotEmpty) {
        final parsedData = await compute(_decodeJson, dataString);

        // Load student info
        try {
          if (parsedData['attendance'] != null && parsedData['attendance'] is Map) {
            final attendanceData = parsedData['attendance'] as Map;
            if (attendanceData['student_info'] != null && attendanceData['student_info'] is Map) {
              studentInfo = Map<String, dynamic>.from(attendanceData['student_info']);
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error loading student info: $e');
        }

        // Load overall attendance
        try {
          if (parsedData['attendance'] != null && parsedData['attendance'] is Map) {
            final attendanceRoot = parsedData['attendance'] as Map;
            if (attendanceRoot['attendance'] != null && attendanceRoot['attendance'] is Map) {
              final attendanceInner = attendanceRoot['attendance'] as Map;
              final oa = attendanceInner['overall_attendance'];
              if (oa != null && oa is num) {
                _overallAttendance = oa.toDouble();
              }
              
              final courses = attendanceInner['courses'];
              if (courses != null && courses is Map) {
                _courseCount = courses.length;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error loading attendance: $e');
        }

        // Load timetable courses
        try {
          if (parsedData['timetable'] != null && parsedData['timetable'] is Map) {
            final timetableRoot = parsedData['timetable'] as Map;
                // Load advisors if present
                try {
                  if (timetableRoot['advisors'] != null && timetableRoot['advisors'] is Map) {
                    final advisors = timetableRoot['advisors'] as Map;
                    _advisors = Map<String, dynamic>.from(advisors.map((k, v) => MapEntry(k.toString(), v)));
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('Error loading advisors: $e');
                }
            
            // Load courses list
            if (timetableRoot['courses'] != null && timetableRoot['courses'] is List) {
              final coursesList = timetableRoot['courses'] as List;
              final List<Map<String, dynamic>> parsed = [];
              
              for (final e in coursesList) {
                if (e != null && e is Map) {
                  final code = e['course_code']?.toString() ?? '';
                  final title = e['course_title']?.toString() ?? '';
                  final credits = e['credit'] is num ? (e['credit'] as num).toInt() : 0;
                  final faculty = e['faculty_name']?.toString() ?? '';
                  final slot = e['slot']?.toString() ?? '';
                  final room = e['room_no']?.toString() ?? e['room']?.toString() ?? '';
                  final category = e['category']?.toString() ?? '';
                  
                  // Only add if it has at least a code or title
                  if (code.isNotEmpty || title.isNotEmpty) {
                    final course = {
                      'code': code,
                      'title': title,
                      'credits': credits,
                      'faculty': faculty,
                      'slot': slot,
                      'room': room,
                      'category': category,
                    };
                    parsed.add(course);
                  }
                }
              }
              
              if (parsed.isNotEmpty) {
                _courses = parsed;
              }
            }
            
            // Load total credits
            if (timetableRoot['total_credits'] != null && timetableRoot['total_credits'] is num) {
              _totalCredits = (timetableRoot['total_credits'] as num).toInt();
            } else if (timetableRoot['courses'] != null && timetableRoot['courses'] is List) {
              // Compute credits sum if total_credits not present
              int sum = 0;
              final coursesList = timetableRoot['courses'] as List;
              for (final e in coursesList) {
                if (e != null && e is Map && e['credit'] != null && e['credit'] is num) {
                  sum += (e['credit'] as num).toInt();
                }
              }
              if (sum > 0) {
                _totalCredits = sum;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error loading timetable: $e');
        }

        setState(() {
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user data: $e');
      setState(() => _loading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;

        if (_loading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBg,
            body: Center(child: CircularProgressIndicator(color: theme.primaryAccent)),
          );
        }

        final displayName = _isGuest ? 'Guest User' : (studentInfo?['name']?.toString() ?? 'No data found');
        final regno = _isGuest ? 'Not Logged In' : (studentInfo?['registration_number']?.toString() ?? 'No data found');
        final program = _isGuest ? 'Guest' : (studentInfo?['program']?.toString() ?? 'No data found');
        final specialization = _isGuest ? 'Mode' : (studentInfo?['specialization']?.toString() ?? 'No data found');
        final semester = _isGuest ? '-' : (studentInfo?['semester']?.toString() ?? 'No data found');

        return Scaffold(
          backgroundColor: theme.scaffoldBg,
          body: Stack(
            children: [
              RefreshIndicator.adaptive(
                onRefresh: _refreshData,
                color: theme.primaryAccent,
                backgroundColor: theme.cardBg,
                edgeOffset: 120,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverAppBar.large(
                      floating: true,
                      pinned: true,
                      stretch: true,
                      backgroundColor: theme.scaffoldBg,
                      foregroundColor: theme.textPrimary,
                      title: Text('Console', 
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1, color: theme.textPrimary)
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Center(
                            child: Column(
                              children: [
                                  Text(
                                    "Pull down to refresh",
                                    style: TextStyle(
                                      color: theme.textSecondary.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (_lastRefreshText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Updated $_lastRefreshText',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryAccent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          RepaintBoundary(
                            child: SlidingProfileAnnouncementWidget(
                              name: displayName,
                              regno: regno,
                              program: program,
                              specialization: specialization,
                              semester: semester,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // The new Next Class / Day Order Widget
                          const NextClassWidget(),

                          // Re-sync banner when backend is CAPTCHA-blocked
                          if (false)
                            _buildResyncBanner(theme),

                          StatsBar(
                            overallAttendance: _overallAttendance,
                            courseCount: _courseCount,
                            totalCredits: _totalCredits,
                            primaryColor: theme.primaryAccent,
                          ),
                          
                          const SizedBox(height: 16),

                          QuickActions(primaryColor: theme.primaryAccent),

                          if (_courses.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            Text(
                              '  Your Courses',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._courses.map((course) => SubjectInfo(course: course)),
                          ],

                          const SizedBox(height: 24),
                          FacultyInfo(advisors: _advisors.isNotEmpty ? _advisors : null),
                          const ContactUs(),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Linear loader pinned to top status bar during refresh
              if (_loading)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryAccent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildResyncBanner(ThemeController theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_problem_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session expired',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to re-sync with SRM Portal',
                      style: TextStyle(
                        color: theme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.textSecondary.withValues(alpha: 0.4),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );

  }
}
