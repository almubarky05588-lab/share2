import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// محادثة في قائمة الرسائل الخاصة — الشاشة ٣ من التصميم
class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.handle,
    required this.lastMessage,
    required this.time,
    this.verified = false,
    this.unread = false,
    this.sentByMe = false,
  });

  final String id;
  final String name;
  final String handle; // بدون @
  final String lastMessage;
  final String time; // الآن · 11:20 · أمس · الأحد
  final bool verified;
  final bool unread;

  /// آخر رسالة أرسلتها أنا — تُسبق بـ «أنت:»
  final bool sentByMe;

  /// نص المعاينة كما يظهر في القائمة
  String get preview => sentByMe ? 'أنت: $lastMessage' : lastMessage;

  /// الحرف الأول للصورة الرمزية
  String get initial => name.isEmpty ? '؟' : name.characters.first;

  /// لون ثابت لكل مستخدم — نفس منطق المنشور والإشعار
  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }

  /// للربط مع Supabase لاحقًا
  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'].toString(),
        name: map['name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        lastMessage: map['last_message'] as String? ?? '',
        time: map['time'] as String? ?? '',
        verified: map['verified'] as bool? ?? false,
        unread: map['unread'] as bool? ?? false,
        sentByMe: map['sent_by_me'] as bool? ?? false,
      );
}
