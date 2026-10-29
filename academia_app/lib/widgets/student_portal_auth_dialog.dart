import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/student_portal_service.dart';

class StudentPortalAuthDialog extends StatefulWidget {
  const StudentPortalAuthDialog({super.key});

  /// Static helper to display the native zero-captcha dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const StudentPortalAuthDialog(),
    );
  }

  @override
  State<StudentPortalAuthDialog> createState() => _StudentPortalAuthDialogState();
}

class _StudentPortalAuthDialogState extends State<StudentPortalAuthDialog> {
  static const Color _bgCard = Color(0xFF141419);
  static const Color _inputFill = Color(0xFF1F1F27);
  static const Color _primaryOrange = Color(0xFFFF6B00);
  static const Color _neonGreen = Color(0xFF00FF9D);
  static const Color _mutedText = Color(0xFF9E9E9E);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPortalNetId = prefs.getString('studentPortalNetId');
      if (savedPortalNetId != null && savedPortalNetId.isNotEmpty) {
        _usernameController.text = savedPortalNetId;
      } else {
        final raw = prefs.getString('userData');
        if (raw != null && raw.isNotEmpty) {
          final data = json.decode(raw) as Map<String, dynamic>;
          final netid = data['netid'] ?? data['student_info']?['reg_no'] ?? data['attendance']?['student_info']?['reg_no'];
          if (netid != null && netid.toString().trim().isNotEmpty) {
            _usernameController.text = netid.toString().trim();
          }
        }
        if (_usernameController.text.isEmpty) {
          final email = prefs.getString('userEmail');
          if (email != null && email.isNotEmpty) {
            _usernameController.text = email.split('@').first.trim();
          }
        }
      }

      final savedPortalPass = prefs.getString('studentPortalPassword');
      if (savedPortalPass != null && savedPortalPass.isNotEmpty) {
        _passwordController.text = savedPortalPass;
      }
    } catch (_) {}
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final cleanUsername = _usernameController.text.trim().replaceAll(RegExp(r'@srmist\.edu\.in$', caseSensitive: false), '').trim();
      final password = _passwordController.text.trim();

      // Zero-CAPTCHA background sync via first-party OCR scraper
      final gwResult = await StudentPortalService.syncViaGateway(
        username: cleanUsername,
        password: password,
      );

      if (!mounted) return;

      if (gwResult.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('studentPortalPassword', password);
        await prefs.setString('studentPortalNetId', cleanUsername);
        await prefs.setBool('student_portal_connected', true);
        if (mounted) Navigator.pop(context, true);
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = gwResult.errorMessage ?? 'Authentication failed. Please verify credentials.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Connection error: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school_rounded, color: _primaryOrange, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Student Portal Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Sync attendance & internal marks",
                            style: TextStyle(color: _mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Zero-Captcha Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neonGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neonGreen.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: _neonGreen, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "Automated Zero-CAPTCHA background solving",
                          style: TextStyle(color: _neonGreen, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Error alert box
                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Username / NetID Field
                const Text("NetID", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isSubmitting,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. nk1629 (without @srmist.edu.in)',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: _inputFill,
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your NetID' : null,
                ),
                const SizedBox(height: 16),

                // Password Field
                const Text("Portal Password", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isSubmitting,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter student portal password',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: _inputFill,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  ),
                                  SizedBox(width: 10),
                                  Text("CONNECTING...", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                                ],
                              )
                            : const Text("CONNECT & SYNC", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
