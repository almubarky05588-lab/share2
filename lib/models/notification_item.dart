import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// نوع الإشعار — يحدّد نص الحدث والأيقونة
enum NotificationType {
  mention, // ذكرك في منشور
  commentMention, // ذكرك في تعليق
  follow, // بدأ بمتابعتك
  reshare, // أعاد نشر منشورك (ريشير)
  like, // أعجب بمنشورك
}

/// عنصر واحد في شاشة المنشن والإشعارات — الشاشة ٢ من التصميم
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.actorName,
    required this.handle,
    required this.timeAgo,
    this.preview,
    this.verified = false,
    this.unread = false,
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String handle; // بدون @
  final String timeAgo; // مثل: 12د · 2س · يوم
  /// نص المنشور المرتبط — لا يوجد في إشعار المتابعة
  final String? preview;
  final bool verified;
  final bool unread;

  /// هل يعرض زر «متابعة» بدل النص؟
  bool get isFollow => type == NotificationType.follow;

  /// نص الحدث كما في التصميم
  String get actionLabel {
    switch (type) {
      case NotificationType.mention:
        return 'ذكرتك في منشور';
      case NotificationType.commentMention:
        return 'ذكرك في تعليق';
      case NotificationType.follow:
        return 'بدأ بمتابعتك';
      case NotificationType.reshare:
        return 'أعاد نشر منشورك (ريشير)';
      case NotificationType.like:
        return 'أعجبت بمنشورك';
    }
  }

  /// أيقونة الحدث ولونها
  IconData get icon {
    switch (type) {
      case NotificationType.mention:
      case NotificationType.commentMention:
        return Icons.alternate_email;
      case NotificationType.follow:
        return Icons.person_add_alt;
      case NotificationType.reshare:
        return Icons.repeat;
      case NotificationType.like:
        return Icons.favorite;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.mention:
      case NotificationType.commentMention:
        return AppColors.brand;
      case NotificationType.follow:
        return AppColors.blue;
      case NotificationType.reshare:
        return AppColors.reshare;
      case NotificationType.like:
        return AppColors.like;
    }
  }

  /// الحرف الأول للصورة الرمزية
  String get initial =>
      actorName.isEmpty ? '؟' : actorName.characters.first;

  /// لون ثابت لكل مستخدم — نفس منطق المنشور
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
  factory NotificationItem.fromMap(Map<String, dynamic> map) =>
      NotificationItem(
        id: map['id'].toString(),
        type: NotificationType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => NotificationType.mention,
        ),
        actorName: map['actor_name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        timeAgo: map['time_ago'] as String? ?? '',
        preview: map['preview'] as String?,
        verified: map['verified'] as bool? ?? false,
        unread: map['unread'] as bool? ?? false,
      );
}
