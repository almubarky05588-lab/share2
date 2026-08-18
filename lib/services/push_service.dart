import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إشعارات الجهاز — الإذن، التوكن، والعرض داخل التطبيق
class PushService {
  PushService._();
  static final instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// يُستدعى مرة واحدة عند إقلاع التطبيق
  Future<void> init() async {
    if (_ready) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('تعذّر تشغيل Firebase: $e');
      return;
    }

    // إعداد عرض الإشعار داخل التطبيق
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _local.initialize(settings);

    // إشعار وصل والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen(_showLocal);

    // تجدّد التوكن
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    _ready = true;
  }

  /// يطلب إذن الإشعارات ويحفظ التوكن — بعد تسجيل الدخول
  Future<void> registerDevice() async {
    if (!_ready) await init();
    if (!_ready) return;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // على iOS ننتظر توكن APNs قبل طلب توكن FCM
      if (Platform.isIOS) {
        final apns = await messaging.getAPNSToken();
        if (apns == null) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('تعذّر تسجيل الجهاز للإشعارات: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('تعذّر حفظ توكن الجهاز: $e');
    }
  }

  /// حذف توكن هذا الجهاز عند تسجيل الخروج
  Future<void> unregisterDevice() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await client
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token', token);
    } catch (e) {
      debugPrint('تعذّر حذف توكن الجهاز: $e');
    }
  }

  /// عرض الإشعار والتطبيق مفتوح
  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title,
      n.body,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'share_default',
          'إشعارات شارِك',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
