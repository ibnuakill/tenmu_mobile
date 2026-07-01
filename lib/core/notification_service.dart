import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for OneSignal push notifications.
///
/// - `init()` — call once after Supabase init (auto-attach).
/// - `attachUser(userId)` / `detachUser()` — call when auth state changes.
/// - `sendNewPlaceNotification(placeId, placeName)` — call from admin after approving.
class NotificationService {
  NotificationService._();

  static final _appId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';

  static bool _sdkInitialized = false;

  /// Initialize OneSignal SDK (one-time). Safe to call multiple times.
  static Future<void> init() async {
    if (_sdkInitialized) return;
    if (_appId.isEmpty) {
      debugPrint('[NotificationService] ONESIGNAL_APP_ID not set in .env');
      return;
    }

    OneSignal.initialize(_appId);

    // Request notification permission
    final result = await OneSignal.Notifications.requestPermission(true);
    debugPrint('[NotificationService] permission: $result');

    // Wajib di v5 — explicit opt-in biar device terdaftar
    debugPrint('[NotificationService] events registered: $result');

    // Display notifications while app is in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    _sdkInitialized = true;
  }

  /// Register push subscription (panggil manual setelah login).
  static Future<void> registerPush() async {
    if (_appId.isEmpty) return;
    await OneSignal.User.pushSubscription.optIn();
    debugPrint('[NotificationService] optIn completed');
  }

  /// Link device to a Supabase user — call on login / session restore.
  static Future<void> attachUser(String userId) async {
    if (_appId.isEmpty) return;
    await OneSignal.login(userId);
    debugPrint('[NotificationService] attached user: $userId');
  }

  /// Unlink device — call on logout.
  static Future<void> detachUser() async {
    if (_appId.isEmpty) return;
    await OneSignal.logout();
    debugPrint('[NotificationService] detached user');
  }

  /// Send push notification via Supabase Edge Function.
  ///
  /// Calls the `send-notification` Edge Function which proxies to OneSignal API.
  /// OneSignal REST API key stays on the server — never exposed to client.
  static Future<bool> sendNewPlaceNotification({
    required int placeId,
    required String placeName,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'placeId': placeId,
          'placeName': placeName,
          'type': 'new_place',
        },
      );
      debugPrint('[NotificationService] edge function OK: ${res.data}');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] edge function error: $e');
      return false;
    }
  }

  /// Notify all admin/superadmin users that a new place needs verification.
  ///
  /// Fetches admin user IDs from the `profiles` table, then calls the
  /// Edge Function with targeted push to those users only.
  static Future<bool> notifyAdminsNewSubmission({
    required int placeId,
    required String placeName,
  }) async {
    try {
      // Fetch all admin & superadmin OneSignal user IDs
      final adminProfiles = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .inFilter('role', ['admin', 'superadmin']);

      final adminIds = adminProfiles
          .map<String>((p) => p['id'] as String)
          .toList();

      if (adminIds.isEmpty) {
        debugPrint('[NotificationService] no admin found to notify');
        return false;
      }

      final res = await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'placeId': placeId,
          'placeName': placeName,
          'targetUserIds': adminIds,
          'type': 'new_submission',
        },
      );
      debugPrint('[NotificationService] admin notified OK: ${res.data}');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] notify admins error: $e');
      return false;
    }
  }
}
