import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/student_portal_service.dart';

class StudentPortalAuthDialog extends StatefulWidget {
  const StudentPortalAuthDialog({super.key});

  /// Static helper to display the native dialog
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
  static const Color _accentGreen = Color(0xFF76FF03);
  static const Color _mutedText = Color(0xFF9E9E9E);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoadingCaptcha = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  CaptchaSession? _captchaSession;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
    _fetchFreshCaptcha();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
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
          final netid = data['netid'];
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

      // Decouple from userPassword: Never auto-insert Academia password into Student Portal!
      final savedPortalPass = prefs.getString('studentPortalPassword');
      if (savedPortalPass != null && savedPortalPass.isNotEmpty) {
        _passwordController.text = savedPortalPass;
      }
    } catch (_) {}
  }

  Future<void> _fetchFreshCaptcha({bool clearError = true}) async {
    if (mounted) {
      setState(() {
        _isLoadingCaptcha = true;
        if (clearError) {
          _errorMessage = null;
        }
        _captchaController.clear();
      });
    }

    try {
      final session = await StudentPortalService.fetchCaptcha();
      if (mounted) {
        setState(() {
          _captchaSession = session;
          _isLoadingCaptcha = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCaptcha = false;
          _errorMessage = 'Failed to load CAPTCHA: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
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

      // 1. Try zero-CAPTCHA gateway first (fastest, no user friction)
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

      // 2. If gateway failed and user entered CAPTCHA, attempt direct portal login
      if (_captchaSession != null && _captchaController.text.trim().isNotEmpty) {
        final result = await StudentPortalService.loginAndSync(
          username: cleanUsername,
          password: password,
          captcha: _captchaController.text.trim(),
          session: _captchaSession!,
        );

        if (!mounted) return;

        if (result.success) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('studentPortalPassword', password);
          await prefs.setString('studentPortalNetId', cleanUsername);
          await prefs.setBool('student_portal_connected', true);
          if (mounted) Navigator.pop(context, true);
          return;
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = result.errorMessage ?? 'Authentication failed.';
          });
          _fetchFreshCaptcha(clearError: false);
          return;
        }
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = gwResult.errorMessage ?? 'Authentication failed. Please verify credentials.';
      });
      _fetchFreshCaptcha(clearError: false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Error: $e';
        });
        _fetchFreshCaptcha(clearError: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
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
                const SizedBox(height: 20),

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
                const SizedBox(height: 16),

                // CAPTCHA Section
                Row(
                  children: [
                    const Text("Enter CAPTCHA", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _primaryOrange.withValues(alpha: 0.4)),
                      ),
                      child: const Text("Case-sensitive (a ≠ A)", style: TextStyle(color: _primaryOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // High-contrast CAPTCHA Image Container
                    Container(
                      height: 48,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: _isLoadingCaptcha
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black54)),
                            )
                          : (_captchaSession != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _captchaSession!.imageBytes,
                                    height: 44,
                                    width: 136,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : const Text('Error', style: TextStyle(color: Colors.black54, fontSize: 12))),
                    ),
                    const SizedBox(width: 10),

                    // Refresh Button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: _accentGreen, size: 24),
                      tooltip: 'Refresh CAPTCHA',
                      onPressed: (_isLoadingCaptcha || _isSubmitting) ? null : () => _fetchFreshCaptcha(clearError: true),
                    ),

                    const Expanded(
                      child: Text(
                        "Tap icon if unclear",
                        style: TextStyle(color: _mutedText, fontSize: 11),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CAPTCHA Input Field (Case-sensitive, no auto-capitalization)
                TextFormField(
                  controller: _captchaController,
                  enabled: !_isSubmitting && !_isLoadingCaptcha,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter CAPTCHA exactly as shown',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13, letterSpacing: 0),
                    filled: true,
                    fillColor: _inputFill,
                    prefixIcon: const Icon(Icons.security_rounded, color: Colors.white38, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => null, // Optional for zero-CAPTCHA gateway sync
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
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text("LOGIN & SYNC", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
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
