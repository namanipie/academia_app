import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_controller.dart';

// --- SHARED DESIGN CONSTANTS ---
const Color kPitchBlack = Color(0xFF000000);
const Color kCardBlack = Color(0xFF111111);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kSurfaceGrey = Color(0xFF1E1E1E);
const Color kMutedText = Colors.white54;

class FacultyInfo extends StatelessWidget {
  final Map<String, dynamic>? advisors;

  const FacultyInfo({super.key, this.advisors});

  // --- FUNCTIONAL LOGIC ---

  Future<void> _makeCall(String phoneNumber) async {
    // Strips spaces and special characters for the dialer
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri.parse('tel:$cleanPhone');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final fa = advisors?['faculty_advisor'];
        final aa = advisors?['academic_advisor'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                ' Advisors',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            _buildAdvisorCard(
              role: 'Faculty Advisor',
              name: fa?['name'] ?? 'Not Assigned',
              email: fa?['email'] ?? 'No email provided',
              phone: fa?['phone'] ?? 'No phone provided',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildAdvisorCard(
              role: 'Academic Advisor',
              name: aa?['name'] ?? 'Not Assigned',
              email: aa?['email'] ?? 'No email provided',
              phone: aa?['phone'] ?? 'No phone provided',
              theme: theme,
            ),
      ],
        );
      }
    );
  }

  // --- SUBTLE UI COMPONENTS ---

  Widget _buildAdvisorCard({
    required String role,
    required String name,
    required String email,
    required String phone,
    required ThemeController theme,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Label
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: theme.primaryAccent, 
              fontSize: 10, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          // Name
          Text(
            name,
            style: TextStyle(
              color: theme.textPrimary, 
              fontSize: 17, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 16),
          
          // Static Info Rows (Visible but not clickable)
          _buildInfoRow(Icons.alternate_email_rounded, email, theme),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_iphone_rounded, phone, theme),
          
          const SizedBox(height: 20),
          
          // Action Button (Only Call)
          if (phone != 'No phone provided' && phone.isNotEmpty)
            _buildCallButton(onTap: () => _makeCall(phone), theme: theme),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, ThemeController theme) {
    return Row(
      children: [
        Icon(icon, color: theme.textSecondary.withValues(alpha: 0.5), size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textSecondary, 
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton({required VoidCallback onTap, required ThemeController theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.primaryAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.primaryAccent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_rounded, color: theme.primaryAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              'CALL NOW',
              style: TextStyle(
                color: theme.primaryAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}