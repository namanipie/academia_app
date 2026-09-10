import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationServiceFirestore {
  // Singleton pattern to access it easily
  static final NotificationServiceFirestore _instance = NotificationServiceFirestore._internal();
  factory NotificationServiceFirestore() => _instance;
  NotificationServiceFirestore._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notification service
  Future<void> init() async {
    // Request permission (iOS / Android)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) debugPrint('User permission: ${settings.authorizationStatus}');

    // Subscribe to topic (optional)
    await _messaging.subscribeToTopic("allUsers");

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('Foreground message received: ${message.notification?.title}');
      if (kDebugMode) debugPrint('Body: ${message.notification?.body}');
      // You can show a local notification here if needed
    });

    // Handle background & terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

/// Must be a top-level function for background handling
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('Background message received: ${message.messageId}');
  if (kDebugMode) debugPrint('Title: ${message.notification?.title}');
  if (kDebugMode) debugPrint('Body: ${message.notification?.body}');
}
