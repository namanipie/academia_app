import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  amoled,
  midnight,
  light,
  abyss,
  cyberpunk;

  String get label {
    switch (this) {
      case AppThemeMode.amoled:
        return 'AMOLED Black';
      case AppThemeMode.midnight:
        return 'Midnight Slate';
      case AppThemeMode.light:
        return 'Clean Light';
      case AppThemeMode.abyss:
        return 'Deep Abyss';
      case AppThemeMode.cyberpunk:
        return 'Neon Cyberpunk';
    }
  }

  String get subtitle {
    switch (this) {
      case AppThemeMode.amoled:
        return 'Pure pitch black, OLED battery saver';
      case AppThemeMode.midnight:
        return 'Deep obsidian dark, easy on eyes';
      case AppThemeMode.light:
        return 'Crisp off-white daylight look';
      case AppThemeMode.abyss:
        return 'Oceanic blue-purple gradient';
      case AppThemeMode.cyberpunk:
        return 'Retro sunset neon gradient';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.amoled:
        return Icons.dark_mode_rounded;
      case AppThemeMode.midnight:
        return Icons.nights_stay_rounded;
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
      case AppThemeMode.abyss:
        return Icons.water_drop_rounded;
      case AppThemeMode.cyberpunk:
        return Icons.electric_bolt_rounded;
    }
  }
}

enum AppAccentColor {
  orange('Console Orange', Color(0xFFFF9800), '#FF9800'),
  mint('Terminal Mint', Color(0xFF9DF8A0), '#9DF8A0'),
  iceBlue('Ice Blue', Color(0xFF61A5DD), '#61A5DD'),
  neonPink('Neon Pink', Color(0xFFFD3974), '#FD3974'),
  cyberIndigo('Cyber Indigo', Color(0xFF6366F1), '#6366F1'),
  amberGold('Amber Gold', Color(0xFFF59E0B), '#F59E0B'),
  electricPurple('Electric Violet', Color(0xFF8B5CF6), '#8B5CF6');

  final String label;
  final Color color;
  final String hex;

  const AppAccentColor(this.label, this.color, this.hex);
}

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _prefThemeModeKey = 'app_theme_mode_v2';
  static const String _prefAccentKey = 'app_accent_color_v2';

  AppThemeMode _mode = AppThemeMode.amoled;
  AppAccentColor _accent = AppAccentColor.orange;
  bool _initialized = false;

  AppThemeMode get mode => _mode;
  AppAccentColor get accent => _accent;
  bool get isInitialized => _initialized;

  bool get isDark => _mode != AppThemeMode.light;

  Color get primaryAccent => _accent.color;

  LinearGradient? get backgroundGradient {
    switch (_mode) {
      case AppThemeMode.abyss:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0B0F19)],
        );
      case AppThemeMode.cyberpunk:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C0B3E), Color(0xFF1A0B2E), Color(0xFF050510)],
        );
      default:
        return null;
    }
  }

  Color get scaffoldBg {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color(0xFF000000);
      case AppThemeMode.midnight:
        return const Color(0xFF0F172A);
      case AppThemeMode.light:
        return const Color(0xFFF8FAFC);
      case AppThemeMode.abyss:
      case AppThemeMode.cyberpunk:
        return Colors.transparent; // Gradient handles background
    }
  }

  Color get cardBg {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color(0xFF121212);
      case AppThemeMode.midnight:
        return const Color(0xFF1E293B);
      case AppThemeMode.light:
        return const Color(0xFFFFFFFF);
      case AppThemeMode.abyss:
        return const Color(0xFF1E293B).withValues(alpha: 0.6);
      case AppThemeMode.cyberpunk:
        return const Color(0xFF3B1A53).withValues(alpha: 0.5);
    }
  }

  Color get surfaceBg {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color(0xFF1A1A1A);
      case AppThemeMode.midnight:
        return const Color(0xFF283548);
      case AppThemeMode.light:
        return const Color(0xFFF1F5F9);
      case AppThemeMode.abyss:
        return const Color(0xFF283548).withValues(alpha: 0.6);
      case AppThemeMode.cyberpunk:
        return const Color(0xFF4C1D95).withValues(alpha: 0.5);
    }
  }

  Color get navBarBg {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color.fromARGB(160, 18, 18, 18);
      case AppThemeMode.midnight:
        return const Color.fromARGB(160, 15, 23, 42);
      case AppThemeMode.light:
        return const Color.fromARGB(180, 255, 255, 255);
      case AppThemeMode.abyss:
        return const Color.fromARGB(160, 15, 23, 42);
      case AppThemeMode.cyberpunk:
        return const Color.fromARGB(160, 26, 11, 46);
    }
  }

  Color get textPrimary {
    switch (_mode) {
      case AppThemeMode.amoled:
      case AppThemeMode.midnight:
      case AppThemeMode.abyss:
      case AppThemeMode.cyberpunk:
        return Colors.white;
      case AppThemeMode.light:
        return const Color(0xFF0F172A);
    }
  }

  Color get textSecondary {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color(0xFF9E9E9E);
      case AppThemeMode.midnight:
      case AppThemeMode.abyss:
        return const Color(0xFF94A3B8);
      case AppThemeMode.cyberpunk:
        return const Color(0xFFB4A5D0);
      case AppThemeMode.light:
        return const Color(0xFF64748B);
    }
  }

  Color get dividerColor {
    switch (_mode) {
      case AppThemeMode.amoled:
        return const Color(0xFF262626);
      case AppThemeMode.midnight:
      case AppThemeMode.abyss:
        return const Color(0xFF334155);
      case AppThemeMode.cyberpunk:
        return const Color(0xFF6D28D9).withValues(alpha: 0.4);
      case AppThemeMode.light:
        return const Color(0xFFE2E8F0);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefThemeModeKey);
      if (savedMode != null) {
        _mode = AppThemeMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => AppThemeMode.amoled,
        );
      }

      final savedAccent = prefs.getString(_prefAccentKey);
      if (savedAccent != null) {
        _accent = AppAccentColor.values.firstWhere(
          (e) => e.name == savedAccent,
          orElse: () => AppAccentColor.orange,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing ThemeController: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeModeKey, mode.name);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> setAccentColor(AppAccentColor accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccentKey, accent.name);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving accent color: $e');
    }
  }

  Future<void> resetToDefaults() async {
    _mode = AppThemeMode.amoled;
    _accent = AppAccentColor.orange;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefThemeModeKey);
      await prefs.remove(_prefAccentKey);
    } catch (e) {
      if (kDebugMode) debugPrint('Error resetting theme: $e');
    }
  }

  ThemeData buildThemeData() {
    final Brightness brightness = isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primaryAccent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: brightness,
        primary: primaryAccent,
        surface: cardBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: dividerColor,
      iconTheme: IconThemeData(
        color: textPrimary,
      ),
    );
  }
}
