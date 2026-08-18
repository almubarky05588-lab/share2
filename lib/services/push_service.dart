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

  /// آخر حالة — للتشخيص من داخل التطبيق
  String status = 'لم يبدأ';
  String? lastToken;

  /// يُستدعى مرة واحدة عند إقلاع التطبيق
  Future<void> init() async {
    if (_ready) return;

    try {
      await Firebase.initializeApp();
      status = 'Firebase جاهز';
    } catch (e) {
      status = 'فشل تشغيل Firebase: $e';
      debugPrint(status);
      return;
    }

    try {
      const settings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _local.initialize(settings);

      FirebaseMessaging.onMessage.listen(_showLocal);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      _ready = true;
    } catch (e) {
      status = 'فشل تهيئة الإشعارات: $e';
      debugPrint(status);
    }
  }

  /// يطلب إذن الإشعارات ويحفظ التوكن
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

      status = 'الإذن: ${settings.authorizationStatus.name}';

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        status = 'الإشعارات مرفوضة من إعدادات الجهاز';
        return;
      }

      // على iOS ننتظر توكن APNs — قد يتأخر ثوانٍ
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 10; i++) {
          apns = await messaging.getAPNSToken();
          if (apns != null) break;
          await Future.delayed(const Duration(seconds: 2));
        }

        if (apns == null) {
          status = 'لم يصل توكن APNs من آبل';
          return;
        }
        status = 'APNs جاهز';
      }

      final token = await messaging.getToken();
      if (token == null) {
        status = 'لم يصل توكن FCM';
        return;
      }

      lastToken = token;
      await _saveToken(token);
    } catch (e) {
      status = 'خطأ: $e';
      debugPrint(status);
    }
  }

  Future<void> _saveToken(String token) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;

    if (uid == null) {
      status = 'لا توجد جلسة — لم يُحفظ التوكن';
      return;
    }

    try {
      await client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      status = 'تم تسجيل الجهاز بنجاح ✅';
    } catch (e) {
      status = 'فشل حفظ التوكن: $e';
      debugPrint(status);
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
