import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// نوع الإشعار
enum NotificationType {
  mention,
  commentMention,
  follow,
  reshare,
  like,
}

/// عنصر واحد في شاشة المنشن والإشعارات
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.actorName,
    required this.handle,
    required this.timeAgo,
    this.postId,
    this.actorId,
    this.preview,
    this.verified = false,
    this.unread = false,
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String handle;
  final String timeAgo;

  /// معرّف المنشور المرتبط — للانتقال إليه والرد
  final String? postId;

  /// معرّف صاحب الإشعار — لفتح ملفه
  final String? actorId;

  final String? preview;
  final bool verified;
  final bool unread;

  bool get isFollow => type == NotificationType.follow;

  String get actionLabel {
    switch (type) {
      case NotificationType.mention:
        return 'ذكرك في منشور';
      case NotificationType.commentMention:
        return 'ذكرك في تعليق';
      case NotificationType.follow:
        return 'بدأ بمتابعتك';
      case NotificationType.reshare:
        return 'أعاد نشر منشورك (ريشير)';
      case NotificationType.like:
        return 'أعجب بمنشورك';
    }
  }

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

  String get initial => actorName.isEmpty ? '؟' : actorName.characters.first;

  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }
}
