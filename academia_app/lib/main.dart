import 'package:flutter/foundation.dart';
import 'package:academia_app/screens/login_page.dart';
import 'package:academia_app/screens/dasboardscreen.dart';
import 'package:academia_app/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/firebase_notification.dart';
import 'package:academia_app/utils/auto_save_graph_data_onlogin.dart';
import 'package:academia_app/services/theme_controller.dart';
import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'package:academia_app/services/user_data_refresh.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final success = await DataRefreshService.refreshData();
      return success;
    } catch (err) {
      if (kDebugMode) debugPrint(err.toString());
      return false;
    }
  });
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize timezone synchronously (fast)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  // Initialize theme early from preferences
  await ThemeController.instance.init();

  // Initialize notifications early (lightweight)
  await NotificationService.init();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask('1', 'backgroundRefresh', frequency: const Duration(hours: 6));

  // Load user data async but don't block app start
  final prefs = await SharedPreferences.getInstance();
  final String? userData = prefs.getString('userData');

  // Show UI immediately
  runApp(MyApp(isLoggedIn: userData != null));

  // Remove splash screen after first frame rendered
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    FlutterNativeSplash.remove();

    // Perform heavy or secondary setups in background
    unawaited(_backgroundSetup(userData));
  });
}

Future<void> _backgroundSetup(String? userData) async {
  try {
    // Initialize Firebase (can take time)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Initialize Firebase notifications
    await NotificationServiceFirestore().init();

    // Save attendance data only if logged in
    if (userData != null && userData.isNotEmpty) {
      await saveAttendanceDataOnAppStart(userData);
    }

    // Optional debug info
    if (kDebugMode) debugPrint('Background setup complete at ${DateTime.now()}');
  } catch (e, st) {
    if (kDebugMode) debugPrint('⚠️ Background setup failed: $e\n$st');
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Console',
          theme: theme.buildThemeData(),
          home: isLoggedIn ? const DashboardScreen() : const CLoginPage(),
        );
      },
    );
  }
}
