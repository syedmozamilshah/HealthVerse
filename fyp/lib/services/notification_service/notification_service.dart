import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fyp/services/api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:fyp/main.dart';
import 'package:fyp/views/appointment_screen/doctor_view_screen/doctor_view_screen.dart';

import '../../models/notification/device_token.dart';
import '../../models/notification/notification_preference.dart';

// M-11 CALLING ALL THE APIS USED IN NOTFICATION SERVICE
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<String?> getToken() => _messaging.getToken();

  Future<void> initAndRegister(String userId) async {
    print('[FCM-Client] initAndRegister called for userId: $userId');

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
    print('[FCM-Client] Local notifications initialized');

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM-Client] Permission status: ${settings.authorizationStatus}');

    // Delete old token and get new one
    print('[FCM-Client] Regenerating token...');
    await _messaging.deleteToken();

    final token = await getToken();
    print(
        '[FCM-Client] FCM token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');

    if (token != null) {
      try {
        final resp = await registerDeviceToken(userId, token);
        print(
            '[FCM-Client] Register token response: ${resp.statusCode} - ${resp.data}');
      } catch (e) {
        print('[FCM-Client] ERROR registering token: $e');
      }
    } else {
      print('[FCM-Client] WARNING: No FCM token received from Firebase!');
    }

    // Handle cold start when app is launched from a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data['referralId'] != null) {
      print('[FCM-Client] 📩 App launched from notification!');
      // Wait for navigation stack to be ready and splash screen to dismiss
      Future.delayed(const Duration(milliseconds: 2000), () {
        String specialty = initialMessage.data['specialty'] ?? 'Optometrist';
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => DoctorViewScreen(speciality: specialty),
        ));
      });
    }

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM-Client] 📩 Foreground message received!');
      print('[FCM-Client]   Title: ${message.notification?.title}');
      print('[FCM-Client]   Body: ${message.notification?.body}');

      // Display notification
      _showNotification(message);
    });

    // Handle deep linking when app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM-Client] 📩 App opened from notification!');
      if (message.data['referralId'] != null) {
        String specialty = message.data['specialty'] ?? 'Optometrist';
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => DoctorViewScreen(speciality: specialty),
        ));
      }
    });

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('[FCM-Client] Token refreshed, re-registering...');
      try {
        await registerDeviceToken(userId, newToken);
      } catch (e) {
        print('[FCM-Client] ERROR re-registering refreshed token: $e');
      }
    });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New notification',
      message.notification?.body ?? '',
      details,
    );
    print('[FCM-Client] ✅ Notification displayed');
  }

  Future<Response> registerDeviceToken(String userId, String token) async {
    final body = DeviceTokenModel(token: token, platform: 'android').toJson();
    print(
        '[FCM-Client] POST /api/Notification/$userId/device-tokens with body: $body');
    return ApiClient()
        .client
        .post('/api/Notification/$userId/device-tokens', data: body);
  }

  Future<Response> deleteDeviceToken(String userId, String token) async {
    return ApiClient().client.delete('/api/Notification/$userId/device-tokens',
        queryParameters: {'token': token});
  }

  Future<NotificationPreference?> getPreferences(String userId) async {
    final res = await ApiClient()
        .client
        .get('/api/NotificationPreferences/$userId/notification-preferences');
    if (res.data != null && res.data['data'] != null) {
      return NotificationPreference.fromJson(res.data['data']);
    }
    return null;
  }

  Future<Response> updatePreferences(
      String userId, NotificationPreference pref) async {
    return ApiClient().client.put(
        '/api/NotificationPreferences/$userId/notification-preferences',
        data: pref.toJson());
  }

  Future<Response> sendTest(String title, String body, String userId) async {
    final payload = {'userId': userId, 'title': title, 'body': body};
    return ApiClient()
        .client
        .post('/api/Notification/send-test', data: payload);
  }

  Future<Response> sendNow(String userId, String title, String body) async {
    final payload = {'userId': userId, 'title': title, 'body': body};
    return ApiClient().client.post('/api/Notification/send-now', data: payload);
  }

  Future<Response> triggerScheduler() async {
    return ApiClient().client.post('/api/Notification/trigger');
  }
}
