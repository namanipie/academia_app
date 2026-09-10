import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_controller.dart';
import '../screens/theme_settings_screen.dart';
import '../utils/logout_user.dart';
import '../services/user_data_refresh.dart'; // Ensure this points to the refresh service
import 'login_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isGuest = false;
  String? netId;
  String? name;
  String? regno;
  String? program;
  String? semester;
  String? department;
  String? batch;
  int? courseCount;
  int? credits;

  String? _appVersion;
  String? _playStoreVersion;
  bool _loading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }

      final response = await http.get(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=${info.packageName}&hl=en',
        ),
      );
      if (response.statusCode == 200) {
        final match = RegExp(
          r'\[\[\["([0-9]+\.[0-9]+\.[0-9]+.*?)"\]\]',
        ).firstMatch(response.body);
        if (match != null && mounted) {
          setState(() {
            _playStoreVersion = match.group(1);
          });
        }
      }
    } catch (_) {
      // Graceful fallback: do nothing if Play Store fetch fails
    }
  }

  Future<void> _handleSync() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CLoginPage()),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final success = await DataRefreshService.refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Sync complete. Last updated just now.'
                  : 'Sync failed. Your existing data has been kept.',
              style: TextStyle(color: ThemeController.instance.textPrimary),
            ),
            backgroundColor: ThemeController.instance.cardBg,
          ),
        );
        if (success) {
          await _loadUserData();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');

    _isGuest = email == null || email.isEmpty;

    String? loadedNetId;
    if (!_isGuest) {
      loadedNetId = email!.split('@').first;
    }

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

        int? loadedCourses;
        if (tt != null &&
            tt is Map &&
            tt['courses'] != null &&
            tt['courses'] is List) {
          loadedCourses = (tt['courses'] as List).length;
        }

        int? loadedCredits;
        if (tt != null && tt is Map && tt['total_credits'] != null) {
          loadedCredits = int.tryParse(tt['total_credits'].toString());
        }

        if (mounted) {
          setState(() {
            netId = loadedNetId;
            if (studentInfo != null) {
              name = studentInfo['name']?.toString();
              regno = studentInfo['registration_number']?.toString();
              program = studentInfo['program']?.toString();
              semester = studentInfo['semester']?.toString();
              department = studentInfo['department']?.toString();
              batch = studentInfo['batch']?.toString();
            }
            courseCount = loadedCourses;
            credits = loadedCredits;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            netId = loadedNetId;
            _loading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          netId = loadedNetId;
          _loading = false;
        });
      }
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
            body: Center(
              child: CircularProgressIndicator(color: theme.primaryAccent),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBg,
          body: CustomScrollView(
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
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('PROFILE', theme),
                      _buildProfileCard(theme),
                      const SizedBox(height: 32),

                      _buildSectionHeader('ACADEMICS', theme),
                      _buildAcademicsCard(theme),
                      const SizedBox(height: 32),

                      _buildSectionHeader('APPEARANCE', theme),
                      _buildActionTile(
                        theme: theme,
                        icon: Icons.palette_outlined,
                        title: 'Themes & Colors',
                        subtitle: 'Change app theme, accents, and gradients',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThemeSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      _buildSectionHeader('ACCOUNT / SYNC', theme),
                      _buildActionTile(
                        theme: theme,
                        icon: Icons.sync_rounded,
                        title: 'Sync with SRM Portal',
                        subtitle: _isSyncing
                            ? 'Syncing...'
                            : 'Refresh academic data',
                        isLoading: _isSyncing,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (!_isSyncing) {
                            _handleSync();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        theme: theme,
                        icon: Icons.bug_report_outlined,
                        title: 'Report a Problem',
                        subtitle: 'Help improve Academia',
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final url = Uri.parse(
                            'https://github.com/Akshat2711/academia_app/issues',
                          );
                          final canLaunch = await canLaunchUrl(url);
                          if (!context.mounted) return;

                          if (canLaunch) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not open GitHub link.',
                                  style: TextStyle(color: theme.textPrimary),
                                ),
                                backgroundColor: theme.cardBg,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 32),

                      _buildSectionHeader('ABOUT', theme),
                      _buildActionTile(
                        theme: theme,
                        icon: Icons.info_outline_rounded,
                        title: 'About Academia',
                        subtitle: _appVersion != null
                            ? 'Version $_appVersion${_playStoreVersion != null ? '\nLatest on Play Store: $_playStoreVersion' : ''}'
                            : 'Loading version...',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        theme: theme,
                        icon: Icons.code_rounded,
                        title: 'Open Source',
                        subtitle: 'View project details',
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final url = Uri.parse(
                            'https://github.com/Akshat2711/academia_app',
                          );
                          final canLaunch = await canLaunchUrl(url);
                          if (!context.mounted) return;

                          if (canLaunch) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not open GitHub link.',
                                  style: TextStyle(color: theme.textPrimary),
                                ),
                                backgroundColor: theme.cardBg,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 48),

                      // Logout Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          logoutAction(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'LOGOUT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 100), // padding for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, ThemeController theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProfileCard(ThemeController theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: theme.surfaceBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.primaryAccent.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 32,
              color: theme.primaryAccent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null && name!.isNotEmpty || _isGuest) ...[
                  Text(
                    _isGuest ? 'Guest User' : name!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _isGuest ? 'Not Logged In' : (netId ?? 'Unknown ID'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                if (regno != null && regno!.isNotEmpty && !_isGuest) ...[
                  const SizedBox(height: 2),
                  Text(
                    regno!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isGuest ? Colors.grey : Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isGuest ? "Not connected" : "SRM account connected",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isGuest ? Colors.grey : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicsCard(ThemeController theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          if (program != null) ...[
            _buildInfoRow('Program', program!, theme),
            Divider(color: theme.dividerColor, height: 1),
          ],
          if (department != null) ...[
            _buildInfoRow('Branch', department!, theme),
            Divider(color: theme.dividerColor, height: 1),
          ],
          if (semester != null) ...[
            _buildInfoRow('Semester', 'Semester $semester', theme),
            Divider(color: theme.dividerColor, height: 1),
          ],
          if (batch != null) ...[
            _buildInfoRow('Batch', 'Batch $batch', theme, isLast: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeController theme, {
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required ThemeController theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.surfaceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: theme.primaryAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: theme.primaryAccent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.textSecondary.withValues(alpha: 0.5),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
