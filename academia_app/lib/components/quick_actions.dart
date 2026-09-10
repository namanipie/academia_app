import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// --- Your Actual Screen Imports ---
import '../screens/cgpa_calculator.dart';
import '../screens/calender_screen.dart'; 
import '../screens/annoucement_screen.dart';
import '../screens/imp_links_screen.dart';
import '../screens/studymaterial_screen.dart';
import '../screens/mess_menu_screen.dart';
import '../screens/nearby_chat_screen.dart';
import '../screens/student_portal_screen.dart';
import '../club_events_social/screens/feed_screen.dart';
import '../services/theme_controller.dart';
import '../screens/theme_settings_screen.dart';

class QuickActions extends StatelessWidget {
  final Color primaryColor;
  const QuickActions({super.key, required this.primaryColor});

  static const double radius = 30.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20, top: 10),
          child: Text(
            ' Quick Actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),

        // --- SECTION 0: BANNERS ---
        _buildBanner(
          context,
          icon: Icons.auto_awesome_mosaic_rounded,
          title: 'Social Space',
          subtitle: 'Checkout campus feed, clubs and more',
          color: const Color(0xFF65ABE8),
          target: const FeedScreen(),
        ),
        const SizedBox(height: 12),
        
        _buildBanner(
          context,
          icon: Icons.notifications_active_rounded,
          title: 'Campus Announcements',
          subtitle: 'Latest news and official updates',
          color: const Color.fromARGB(255, 211, 225, 230),
          target: const AnnouncementScreen(),
        ),
        const SizedBox(height: 12),

        // --- SECTION 1: BENTO GRID ---
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildActionCard(
                  context,
                  icon: Icons.note_alt,
                  title: 'Study\nMaterial',
                  subtitle: 'Notes & PYQs',
                  color: theme.primaryAccent,
                  target: const MaterialsScreen(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildSmallCard(
                      context,
                      icon: Icons.event_repeat_rounded,
                      title: 'Calendar',
                      color: const Color(0xFFE96BAE),
                      target: const CalendarScreen(),
                    ),
                    const SizedBox(height: 12),
                    _buildSmallCard(
                      context,
                      icon: Icons.explore_rounded,
                      title: 'Nearby',
                      color: theme.primaryAccent,
                      target: const NearbyChatScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- SECTION 2: semester results ---
        _buildBanner(
          context,
          icon: Icons.auto_graph_rounded,
          title: 'Semester Results',
          subtitle: 'Detailed breakdown of your grades',
          color: theme.primaryAccent,
          target: const MainPortalPage(),
        ),
        const SizedBox(height: 12),

        // --- SECTION 3: UTILITY ROW ---
        Row(
          children: [
            _buildUtilityTile(context, Icons.analytics_outlined, 'CGPA', theme.primaryAccent, const CGPACalculator()),
            const SizedBox(width: 10),
            _buildUtilityTile(context, Icons.fastfood_rounded, 'Mess', theme.primaryAccent, const MessMenuScreen()),
            const SizedBox(width: 10),
            _buildUtilityTile(context, Icons.link_sharp, 'Links', theme.primaryAccent, const LinksScreen()),
            const SizedBox(width: 10),
            _buildUtilityTile(context, Icons.palette_outlined, 'Themes', theme.primaryAccent, const ThemeSettingsScreen()),
          ],
        ),
      ],
    );
  }

  Widget _buildIconHalo(IconData icon, Color color, double size) {
    return Container(
      padding: EdgeInsets.all(size * 0.4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required Widget target}) {
    final theme = ThemeController.instance;

    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => target)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIconHalo(icon, color, 24),
            const Spacer(),
            Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold, height: 1.2)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(BuildContext context, {required IconData icon, required String title, required Color color, required Widget target}) {
    final theme = ThemeController.instance;

    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => target)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(radius - 4),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            children: [
              _buildIconHalo(icon, color, 16),
              const SizedBox(width: 10),
              Flexible(child: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required Widget target}) {
    final theme = ThemeController.instance;

    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => target)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            _buildIconHalo(icon, color, 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: theme.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityTile(BuildContext context, IconData icon, String title, Color color, Widget target) {
    final theme = ThemeController.instance;

    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => target)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            children: [
              _buildIconHalo(icon, color, 20),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}