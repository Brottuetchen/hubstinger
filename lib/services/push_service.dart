import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Push notification service.
///
/// Currently registers the device endpoint with the backend so the server
/// can reach this device.  Firebase Messaging (FCM) is intentionally NOT
/// included as a hard dependency – add firebase_messaging + firebase_core to
/// pubspec.yaml and supply google-services.json / GoogleService-Info.plist
/// when you're ready to enable native push on iOS/Android.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;

  /// Call once after login.  No-ops if already called.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[PushService] initialized (FCM not configured – web-push only)');
  }

  /// Register an FCM token with the backend.
  /// Call this after obtaining a token from firebase_messaging.
  Future<void> registerFcmToken(String fcmToken) async {
    try {
      final base = await AuthService.instance.getBaseUrl();
      final jwt  = await AuthService.instance.getToken();
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
      debugPrint('[PushService] registerFcmToken error: $e');
    }
  }
}
