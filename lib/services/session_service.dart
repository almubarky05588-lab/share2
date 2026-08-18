import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// حالة حظر الحساب
class BanInfo {
  const BanInfo({required this.banned, this.reason, this.until});

  final bool banned;
  final String? reason;
  final DateTime? until;

  /// نص المدة المتبقية
  String get untilLabel {
    final u = until;
    if (u == null) return 'إيقاف دائم';

    final left = u.difference(DateTime.now());
    if (left.isNegative) return 'انتهى الإيقاف';
    if (left.inDays > 0) return 'ينتهي بعد ${left.inDays} يومًا';
    if (left.inHours > 0) return 'ينتهي بعد ${left.inHours} ساعة';
    return 'ينتهي بعد ${left.inMinutes} دقيقة';
  }
}

/// جلسة المستخدم — تسجيل الدخول وفحص الحظر
class SessionService {
  SessionService._();
  static final instance = SessionService._();

  /// يسجّل جلسة الدخول (IP والدولة) في السيرفر
  Future<void> recordLogin() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    try {
      await client.functions.invoke('record-login');
    } catch (e) {
      debugPrint('تعذّر تسجيل الجلسة: $e');
    }
  }

  /// يفحص إن كان الحساب محظورًا
  Future<BanInfo> checkBan() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      return const BanInfo(banned: false);
    }

    try {
      final res = await client.rpc('my_ban_status');
      final map = (res as Map).cast<String, dynamic>();

      final until = map['until'] == null
          ? null
          : DateTime.tryParse(map['until'] as String)?.toLocal();

      // انتهت مدة الإيقاف
      if (until != null && until.isBefore(DateTime.now())) {
        return const BanInfo(banned: false);
      }

      return BanInfo(
        banned: map['banned'] as bool? ?? false,
        reason: map['reason'] as String?,
        until: until,
      );
    } catch (e) {
      debugPrint('تعذّر فحص حالة الحساب: $e');
      return const BanInfo(banned: false);
    }
  }
}
