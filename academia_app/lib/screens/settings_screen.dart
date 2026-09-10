import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_controller.dart';
import '../screens/theme_settings_screen.dart';
import '../utils/logout_user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? studentInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString('userData');
    
    if (dataString != null && dataString.isNotEmpty) {
      try {
        final parsedData = json.decode(dataString);
        setState(() {
          studentInfo = parsedData['student_info'];
          _loading = false;
        });
      } catch (e) {
        setState(() => _loading = false);
      }
    } else {
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

        final name = studentInfo?['name']?.toString() ?? 'Unknown User';
        final regno = studentInfo?['registration_number']?.toString() ?? 'N/A';
        final program = studentInfo?['program']?.toString() ?? 'N/A';
        final semester = studentInfo?['semester']?.toString() ?? 'N/A';

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
                    letterSpacing: -1,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: theme.surfaceBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.primaryAccent.withValues(alpha: 0.3), width: 2),
                              ),
                              child: Icon(Icons.person_rounded, size: 30, color: theme.primaryAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    regno,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textSecondary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      Text(
                        'APPEARANCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildSettingsTile(
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

                      const SizedBox(height: 30),
                      Text(
                        'ACADEMICS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildSettingsTile(
                        theme: theme,
                        icon: Icons.school_outlined,
                        title: 'Program Details',
                        subtitle: '$program • Semester $semester',
                        onTap: () {},
                      ),

                      const SizedBox(height: 40),
                      
                      // Logout Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          logoutAction(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
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

  Widget _buildSettingsTile({
    required ThemeController theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
              child: Icon(icon, color: theme.primaryAccent, size: 22),
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
            Icon(Icons.arrow_forward_ios_rounded, color: theme.dividerColor, size: 14),
          ],
        ),
      ),
    );
  }
}
