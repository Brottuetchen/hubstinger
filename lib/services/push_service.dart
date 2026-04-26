import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Top-level handler for background messages (required by FCM).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[PushService] Background message: ${message.messageId}');
}

/// Manages FCM push notification setup and token registration with the backend.
///
/// Requires google-services.json (Android) / GoogleService-Info.plist (iOS).
/// Silently no-ops when Firebase is not initialized so the app always runs.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;

  /// Call once after successful login.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      await _requestAndRegister();
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _register(token).catchError((_) {}),
      );
      FirebaseMessaging.onMessage.listen(_handleForeground);
    } catch (e) {
      // Firebase not configured (no google-services.json / GoogleService-Info.plist)
      debugPrint('[PushService] Firebase not available: $e');
    }
  }

  Future<void> _requestAndRegister() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String fcmToken) async {
    try {
      final base = await AuthService.instance.getBaseUrl();
      final jwt = await AuthService.instance.getToken();
      if (base.isEmpty || jwt == null) return;
      await http.post(
        Uri.parse('$base/api/push/subscribe-fcm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[PushService] FCM token registered');
    } catch (e) {
      debugPrint('[PushService] register error: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    // In-app notification can be shown via flutter_local_notifications if added later.
    debugPrint('[PushService] Foreground message: ${message.notification?.title}');
  }
}
