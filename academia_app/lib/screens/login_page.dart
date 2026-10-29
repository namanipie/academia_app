import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

// Assuming these paths remain the same in your project
import '../utils/responsive_helper.dart';
import '../utils/day_order_backup.dart';
import 'package:academia_app/screens/dasboardscreen.dart';
import '../club_events_social/services/club_main_service.dart';
import '../services/student_portal_service.dart';
import '../config/backend_config.dart';

class CLoginPage extends StatefulWidget {
  const CLoginPage({super.key});

  @override
  State<CLoginPage> createState() => _CLoginPageState();
}

Map<String, dynamic> _decodeJson(String source) => jsonDecode(source);
String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);

class _CLoginPageState extends State<CLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  /// New Method to show the Bottom Sheet Error
  void _showErrorBottomSheet(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final res = ResponsiveHelper(context);
        return Container(
          padding: EdgeInsets.all(res.width(6)),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A), // Dark elegant background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: res.height(3)),
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              SizedBox(height: res.height(2)),
              Text(
                'Login Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: res.fontSize(5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: res.height(1.5)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: res.fontSize(3.8),
                ),
              ),
              SizedBox(height: res.height(4)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: res.height(1.8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: res.height(2)),
            ],
          ),
        );
      },
    );
  }

  Future<void> loginUser() async {
    // Basic Validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorBottomSheet("Please enter both email and password.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    Map<String, dynamic>? data;
    String? failureReason;

    // 1. Try local/remote backend server (/scrape)
    try {
      debugPrint('[SRM AUTH] Starting login attempt via backend /scrape...');
      final response = await BackendConfig.postWithFallback(
        '/scrape',
        body: {"email": email, "password": password},
        perAttemptTimeout: const Duration(seconds: 25),
      );

      if (response.statusCode == 200) {
        final decoded = await compute(_decodeJson, response.body);
        if (decoded['status'] == 'success') {
          data = decoded;
        } else {
          failureReason = decoded['detail'] ?? decoded['message'];
        }
      } else if (response.statusCode == 401) {
        try {
          final decoded = await compute(_decodeJson, response.body);
          failureReason = decoded['detail'] ?? decoded['message'];
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SRM AUTH] Backend /scrape unavailable ($e). Falling back to direct Student Portal login...');
    }

    // 2. Direct native Student Portal fallback
    if (data == null) {
      try {
        debugPrint('[SRM AUTH] Authenticating directly with Student Portal...');
        final gwData = await StudentPortalService.loginAndBuildFullUserData(
          username: email,
          password: password,
        );
        if (gwData != null && gwData['status'] == 'success') {
          data = gwData;
        }
      } catch (e) {
        debugPrint('[SRM AUTH] Student Portal error: $e');
      }
    }

    try {
      if (data != null && data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('userEmail', email);
        await prefs.setString('userPassword', password);
        await prefs.setBool('student_portal_connected', true);
        if (prefs.getString('studentPortalPassword') == null) {
          await prefs.setString('studentPortalPassword', password);
        }
        if (prefs.getString('studentPortalNetId') == null) {
          await prefs.setString('studentPortalNetId', email.split('@')[0]);
        }

        int? dayOrder;
        if (data['attendance'] != null &&
            data['attendance']['day_order'] != null) {
          dayOrder = data['attendance']['day_order'] as int;
          await DayOrderManager.saveDayOrderData(
            currentDayOrder: dayOrder,
            currentDate: DateTime.now(),
          );
        } else {
          dayOrder = await DayOrderManager.getCurrentDayOrder();
          if (dayOrder != null) {
            data['attendance'] ??= {};
            data['attendance']['day_order'] = dayOrder;
          }
        }

        final encodedData = await compute(
          _encodeJson,
          data,
        );
        await prefs.setString('userData', encodedData);
        await prefs.setString(
          'lastRefreshTime',
          DateTime.now().toIso8601String(),
        );

        final emailPart = email.split('@')[0];
        // Background task without blocking login transition
        ApiService().autoResubscribeToClubs(emailPart).catchError((e) {
          debugPrint('⚠ Auto-resubscription failed: $e');
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        _showErrorBottomSheet(
          failureReason ?? 'Login failed. Please verify your NetID and password.',
        );
      }
    } catch (e) {
      _showErrorBottomSheet('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(res.width(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: res.height(32),
                child: Lottie.asset(
                  'assets/login_animation.json',
                  repeat: true,
                  animate: true,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: res.height(10)),
              Text(
                'Welcome to Academia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: res.fontSize(7),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Console',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: res.fontSize(7),
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 255, 136, 67),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: res.height(1)),
              Text(
                'Sign in to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: res.fontSize(3.8),
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: res.height(4)),
              _buildTextField(
                controller: _emailController,
                hint: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                res: res,
              ),
              SizedBox(height: res.height(2)),
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                obscureText: _obscurePassword,
                onTogglePassword: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                res: res,
              ),
              SizedBox(height: res.height(3)),
              _buildLoginButton(res),
              SizedBox(height: res.height(3)),
              Center(
                child: InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Continue without Login',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 218, 143, 103),
                      fontSize: res.fontSize(3.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ResponsiveHelper res,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[600],
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: res.width(4),
            vertical: res.height(2.2),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(ResponsiveHelper res) {
    return Container(
      height: res.height(7),
      decoration: BoxDecoration(
        color: _isLoading ? Colors.grey[300] : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : loginUser,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
