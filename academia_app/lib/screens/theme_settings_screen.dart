import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/theme_controller.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final isDark = theme.isDark;

        return Scaffold(
          backgroundColor: theme.scaffoldBg,
          body: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBg,
              gradient: theme.backgroundGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- CUSTOM TOP APP BAR ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.cardBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.dividerColor,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: theme.textPrimary,
                              size: 16,
                            ),
                          ),
                        ),

                        // Center Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: theme.primaryAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryAccent.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CONSOLE // THEME',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reset Pill Button
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await theme.resetToDefaults();
                            if (context.mounted) {
                              final t = ThemeController.instance;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: t.primaryAccent, size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Theme reset to signature default',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: t.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: t.cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(color: t.dividerColor),
                                  ),
                                ),
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.cardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: theme.dividerColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, color: theme.primaryAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'RESET',
                                  style: TextStyle(
                                    color: theme.primaryAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- HEADER TITLE ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tune your console canvas and chromatic accents',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- SECTION 1: LIVE CONSOLE MOCKUP ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _buildConsoleMockup(theme, isDark),
                  ),
                ),

                // --- SECTION 2: BASE CANVAS SELECTOR ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, '01 // BASE CANVAS'),
                        const SizedBox(height: 12),
                        Row(
                          children: AppThemeMode.values.map((mode) {
                            final isSelected = theme.mode == mode;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: mode != AppThemeMode.values.last ? 8 : 0,
                                ),
                                child: _buildCanvasCard(theme, mode, isSelected),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // --- SECTION 3: ACCENT CHROMATICS ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, '02 // ACCENT CHROMATICS'),
                        const SizedBox(height: 14),
                        _buildChromaticsGrid(theme),
                      ],
                    ),
                  ),
                ),

                // --- FOOTER INFO ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: theme.primaryAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Instant local persistence active • Zero runtime latency',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildSectionHeader(ThemeController theme, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: theme.primaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  // --- LIVE CONSOLE DEVICE MOCKUP ---
  Widget _buildConsoleMockup(ThemeController theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: theme.scaffoldBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.primaryAccent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryAccent.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock Console Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Console',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      'Updated just now',
                      style: TextStyle(
                        color: theme.primaryAccent.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primaryAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.primaryAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        theme.accent.hex,
                        style: TextStyle(
                          color: theme.primaryAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Mini Profile Bento Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryAccent,
                          theme.primaryAccent.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Console',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'B.Tech CSE • Semester 5',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '88.5%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Mini Bento Action Tiles
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_mosaic_rounded, color: const Color(0xFF65ABE8), size: 18),
                        const SizedBox(height: 8),
                        Text(
                          'Social Space',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt, color: theme.primaryAccent, size: 18),
                        const SizedBox(height: 8),
                        Text(
                          'Study Material',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Mini Floating Navigation Bar Pill
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.navBarBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(Icons.home_rounded, color: theme.primaryAccent, size: 20),
                  Icon(Icons.how_to_reg_rounded, color: const Color(0xFF61A5DD).withValues(alpha: 0.6), size: 18),
                  Icon(Icons.bar_chart_rounded, color: const Color(0xFF9DF8A0).withValues(alpha: 0.6), size: 18),
                  Icon(Icons.schedule_rounded, color: const Color(0xFFFD3974).withValues(alpha: 0.6), size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BASE CANVAS CARDS ---
  Widget _buildCanvasCard(ThemeController theme, AppThemeMode mode, bool isSelected) {
    Color previewBg = Colors.black;
    LinearGradient? previewGradient;
    Color previewCard;
    String tag;

    switch (mode) {
      case AppThemeMode.amoled:
        previewBg = const Color(0xFF000000);
        previewCard = const Color(0xFF141414);
        tag = 'AMOLED';
        break;
      case AppThemeMode.midnight:
        previewBg = const Color(0xFF0F172A);
        previewCard = const Color(0xFF1E293B);
        tag = 'SLATE';
        break;
      case AppThemeMode.light:
        previewBg = const Color(0xFFF1F5F9);
        previewCard = const Color(0xFFFFFFFF);
        tag = 'LIGHT';
        break;
      case AppThemeMode.abyss:
        previewGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        );
        previewCard = const Color(0xFF1E293B).withValues(alpha: 0.6);
        tag = 'ABYSS';
        break;
      case AppThemeMode.cyberpunk:
        previewGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C0B3E), Color(0xFF1A0B2E)],
        );
        previewCard = const Color(0xFF3B1A53).withValues(alpha: 0.5);
        tag = 'CYBER';
        break;
    }

    return GestureDetector(
      onTap: () => theme.setThemeMode(mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryAccent : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryAccent.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Visual Mini-Swatch
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: previewGradient == null ? previewBg : null,
                gradient: previewGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 28,
                  height: 18,
                  decoration: BoxDecoration(
                    color: previewCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tag Pill
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tag,
                style: TextStyle(
                  color: isSelected ? theme.primaryAccent : theme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHROMATICS GRID ---
  Widget _buildChromaticsGrid(ThemeController theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: AppAccentColor.values.length,
      itemBuilder: (context, index) {
        final accent = AppAccentColor.values[index];
        final isSelected = theme.accent == accent;

        return GestureDetector(
          onTap: () => theme.setAccentColor(accent),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.color.withValues(alpha: 0.15)
                  : theme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accent.color : theme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.color.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Glowing Color Orb
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        accent.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? accent.color : theme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        accent.hex,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
