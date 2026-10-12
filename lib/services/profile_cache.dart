import '../models/user_profile.dart';

/// ذاكرة مؤقتة لملفي الشخصي — تمنع وميض الصورة القديمة
///
/// الشاشات تقرأ [me] فورًا عند البناء، ثم تحدّثها بعد الجلب.
class ProfileCache {
  ProfileCache._();

  static UserProfile? _me;

  /// ملفي المحفوظ — قد يكون null قبل أول جلب
  static UserProfile? get me => _me;

  /// يحفظ أحدث نسخة
  static void save(UserProfile? profile) {
    if (profile != null) _me = profile;
  }

  /// يُمسح عند تسجيل الخروج
  static void clear() => _me = null;
}
