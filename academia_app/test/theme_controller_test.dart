import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/services/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.instance.init();
    await ThemeController.instance.resetToDefaults();
  });

  group('ThemeController tests', () {
    test('Initial defaults are AMOLED Black and Console Orange', () {
      final theme = ThemeController.instance;
      expect(theme.mode, equals(AppThemeMode.amoled));
      expect(theme.accent, equals(AppAccentColor.orange));
      expect(theme.isDark, isTrue);
      expect(theme.scaffoldBg, equals(const Color(0xFF000000)));
      expect(theme.cardBg, equals(const Color(0xFF121212)));
      expect(theme.primaryAccent, equals(const Color(0xFFFF9800)));
    });

    test('Switching to Midnight Slate updates colors and remains dark', () async {
      final theme = ThemeController.instance;
      await theme.setThemeMode(AppThemeMode.midnight);

      expect(theme.mode, equals(AppThemeMode.midnight));
      expect(theme.isDark, isTrue);
      expect(theme.scaffoldBg, equals(const Color(0xFF0F172A)));
      expect(theme.cardBg, equals(const Color(0xFF1E293B)));
    });

    test('Switching to Clean Light updates colors and brightness', () async {
      final theme = ThemeController.instance;
      await theme.setThemeMode(AppThemeMode.light);

      expect(theme.mode, equals(AppThemeMode.light));
      expect(theme.isDark, isFalse);
      expect(theme.scaffoldBg, equals(const Color(0xFFF8FAFC)));
      expect(theme.cardBg, equals(const Color(0xFFFFFFFF)));
      expect(theme.textPrimary, equals(const Color(0xFF0F172A)));
    });

    test('Switching accent colors updates primaryAccent', () async {
      final theme = ThemeController.instance;
      await theme.setAccentColor(AppAccentColor.mint);

      expect(theme.accent, equals(AppAccentColor.mint));
      expect(theme.primaryAccent, equals(const Color(0xFF9DF8A0)));

      await theme.setAccentColor(AppAccentColor.cyberIndigo);
      expect(theme.accent, equals(AppAccentColor.cyberIndigo));
      expect(theme.primaryAccent, equals(const Color(0xFF6366F1)));
    });

    test('Reset to defaults restores AMOLED and Orange', () async {
      final theme = ThemeController.instance;
      await theme.setThemeMode(AppThemeMode.light);
      await theme.setAccentColor(AppAccentColor.electricPurple);

      expect(theme.mode, equals(AppThemeMode.light));
      expect(theme.accent, equals(AppAccentColor.electricPurple));

      await theme.resetToDefaults();
      expect(theme.mode, equals(AppThemeMode.amoled));
      expect(theme.accent, equals(AppAccentColor.orange));
    });

    test('buildThemeData produces valid ThemeData', () {
      final theme = ThemeController.instance;
      final themeData = theme.buildThemeData();

      expect(themeData.brightness, equals(Brightness.dark));
      expect(themeData.scaffoldBackgroundColor, equals(const Color(0xFF000000)));
      expect(themeData.primaryColor, equals(const Color(0xFFFF9800)));
    });
  });
}
