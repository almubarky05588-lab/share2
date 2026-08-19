import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// حالة الحساب — حظر أو حذف مجدول
class AccountStatus {
  const AccountStatus({
    this.banned = false,
    this.reason,
    this.until,
    this.deleted = false,
    this.purgeAt,
  });

  final bool banned;
  final String? reason;
  final DateTime? until;

  /// طُلب حذفه وما زال في مهلة الاستعادة
  final bool deleted;
  final DateTime? purgeAt;

  bool get blocked => banned || deleted;

  /// نص مدة الإيقاف
  String get untilLabel {
    final u = until;
    if (u == null) return 'إيقاف دائم';

    final left = u.difference(DateTime.now());
    if (left.isNegative) return 'انتهى الإيقاف';
    if (left.inDays > 0) return 'ينتهي بعد ${left.inDays} يومًا';
    if (left.inHours > 0) return 'ينتهي بعد ${left.inHours} ساعة';
    return 'ينتهي بعد ${left.inMinutes} دقيقة';
  }

  /// الأيام المتبقية قبل الحذف النهائي
  int get daysLeft {
    final p = purgeAt;
    if (p == null) return 0;
    final d = p.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }
}

/// جلسة المستخدم — تسجيل الدخول وفحص حالة الحساب
class SessionService {
  SessionService._();
  static final instance = SessionService._();

  /// يسجّل جلسة الدخول (IP والدولة) في السيرفر
  Future<void> recordLogin() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    try {
      await client.functions.invoke('record-login');
    } catch (e) {
      debugPrint('تعذّر تسجيل الجلسة: $e');
    }
  }

  /// يفحص حالة الحساب: محظور أو مجدول للحذف
  Future<AccountStatus> checkStatus() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return const AccountStatus();

    try {
      final res = await client.rpc('my_account_status');
      final map = (res as Map).cast<String, dynamic>();

      DateTime? parse(String key) {
        final v = map[key] as String?;
        return v == null ? null : DateTime.tryParse(v)?.toLocal();
      }

      final until = parse('ban_until');

      // انتهت مدة الإيقاف تلقائيًا
      final banned = (map['banned'] as bool? ?? false) &&
          (until == null || until.isAfter(DateTime.now()));

      return AccountStatus(
        banned: banned,
        reason: map['ban_reason'] as String?,
        until: until,
        deleted: map['deleted'] as bool? ?? false,
        purgeAt: parse('purge_at'),
      );
    } catch (e) {
      debugPrint('تعذّر فحص حالة الحساب: $e');
      return const AccountStatus();
    }
  }

  /// استعادة حساب مجدول للحذف
  Future<void> restoreAccount() async {
    await Supabase.instance.client.rpc('restore_my_account');
  }
}
