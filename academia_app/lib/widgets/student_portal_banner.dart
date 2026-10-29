import 'package:flutter/material.dart';
import 'student_portal_auth_dialog.dart';
import '../services/student_portal_parser.dart';

class StudentPortalBanner extends StatefulWidget {
  final VoidCallback? onSyncCompleted;
  final bool isCompact;

  const StudentPortalBanner({
    super.key,
    this.onSyncCompleted,
    this.isCompact = false,
  });

  @override
  State<StudentPortalBanner> createState() => _StudentPortalBannerState();
}

class _StudentPortalBannerState extends State<StudentPortalBanner> {
  static const Color _cardBg = Color(0xFF141419);
  static const Color _primaryOrange = Color(0xFFFF6B00);
  static const Color _mutedText = Color(0xFF9E9E9E);

  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final connected = await StudentPortalParser.isStudentPortalConnected();
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConnect() async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await StudentPortalAuthDialog.show(context);
    if (success == true && mounted) {
      await _checkConnectionStatus();
      if (widget.onSyncCompleted != null) {
        widget.onSyncCompleted!();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Attendance & Marks synced from Student Portal!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    // If already connected, do not display a recurring banner taking up space
    if (_isConnected) {
      return const SizedBox.shrink();
    }

    // In-line connection card (only shown when not yet connected)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryOrange.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: _primaryOrange, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "You can continue viewing attendance by connecting your SRM Student Portal account.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _handleConnect,
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text(
                "CONTINUE WITH STUDENT PORTAL",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "still waiting for zoho to remember attendance exists",
              style: TextStyle(
                color: _mutedText,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
